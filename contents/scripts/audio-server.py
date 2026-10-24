#!/usr/bin/env python3
"""
Audio -> localhost HTTP bridge for the "SeaQ SoundWave" Plasma widget.

Plasma's "executable" data engine only hands stdout to QML once a process
has exited, so a long-running audio source can't be streamed into QML
directly. This helper produces spectrum frames, keeps the most recent one
in memory and serves it on http://127.0.0.1:<port>/frame, which the widget
polls with XMLHttpRequest.

Two engines produce the frames:
  cava     - the "cava" tool in raw ASCII mode (used when installed)
  builtin  - captures the system output with parec (PulseAudio/PipeWire-Pulse)
             or pw-record (PipeWire) and runs its own FFT (numpy when
             available, a pure-Python FFT otherwise). Nothing to install on
             most KDE systems.

  GET /frame  -> "12;80;255;..."  (one 0-255 value per bar)
  GET /panels -> JSON list of the Plasma panels (edge, thickness, screen, ...)
                 read from Plasma's config files, used for "attach to panel"
  GET /media  -> JSON {"status": "Playing"|"Paused"|"Stopped"|"None", "player": "..."}
                 state of the MPRIS media players (music players, browsers, ...)
  GET /playpause -> pauses everything that plays (audio and video), or resumes
                 what was paused last; answers like /media
  GET /audiocheck -> JSON {"ok": bool, "apps": [...]} - apps whose sound is
                 muted or at 0 % (playing now, or remembered by WirePlumber)
  GET /audiofix -> unmutes those streams and removes the broken entries from
                 WirePlumber's memory (backup: stream-properties.seaq-backup)
  GET /quit   -> shuts the helper down

The helper stops by itself when nobody has polled it for IDLE_TIMEOUT
seconds (widget removed, Plasma crashed/restarted), so it never lingers.

Exit codes: 0 = clean stop, 2 = no usable audio engine, 3 = engine died,
            4 = port could not be bound, 5 = port used by another program.

Every request except /hello needs the header "X-SeaQ-Token" with the token
from the environment variable SEAQ_TOKEN.
"""

import argparse
import array
import cmath
import errno
import secrets
import json
import math
import os
import re
import select
import shutil
import signal
import subprocess
import sys
import tempfile
import threading
import time
import urllib.request
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

try:
    if os.environ.get("AV_NO_NUMPY"):
        raise ImportError
    import numpy as np
except ImportError:
    np = None

EXIT_OK = 0
EXIT_CAVA_MISSING = 2
EXIT_CAVA_FAILED = 3
EXIT_BIND_FAILED = 4
EXIT_PORT_TAKEN = 5   # the port belongs to another program - the widget picks the next one

IDLE_TIMEOUT = 10.0

# Properties for our own capture stream. WirePlumber remembers volume, mute
# and target of every stream it sees; these keep it from storing or restoring
# anything for the visualizer. (node.passive / node.dont-reconnect are left
# out on purpose: they can stop WirePlumber from linking the stream at all.)
QUIET_STREAM = {
    "state.restore-props": "false",
    "state.restore-target": "false",
    "application.name": "SeaQ-SoundWave",
}


def quiet_env():
    """Environment for PulseAudio clients (parec, cava) with the same properties."""
    env = dict(os.environ)
    env["PULSE_PROP"] = " ".join("%s='%s'" % kv for kv in QUIET_STREAM.items())
    return env

state = {"frame": b"", "last_request": time.monotonic(), "exit_code": EXIT_OK}
stop_event = threading.Event()


# ---------------------------------------------------------------------------
# Plasma panel detection (for "attach to panel")
# ---------------------------------------------------------------------------

PANEL_LOCATIONS = {3: "top", 4: "bottom", 5: "left", 6: "right"}  # Plasma::Types::Location
_panel_cache = {"time": 0.0, "json": b"[]"}


def read_kconfig(path):
    """Minimal KConfig/INI reader: {"[Group][Sub]": {key: value}}."""
    groups, cur = {}, None
    try:
        with open(path, encoding="utf-8", errors="replace") as f:
            for line in f:
                line = line.strip()
                if line.startswith("[") and line.endswith("]"):
                    cur = line
                    groups.setdefault(cur, {})
                elif cur is not None and "=" in line and not line.startswith(("#", ";")):
                    k, v = line.split("=", 1)
                    groups[cur][k.strip()] = v.strip()
    except OSError:
        pass
    return groups


def to_int(value, default):
    try:
        return int(value)
    except (TypeError, ValueError):
        return default


def merged_view(views, base):
    """All settings of one panel view. Plasma spreads them over [Panel N],
    [Panel N][Defaults] and per-screen-size groups ([Horizontal1920], ...);
    later (more specific) groups win."""
    def rank(h):
        if h == base + "[Defaults]":
            return 0
        return 1 if h == base else 2
    out = {}
    for h in sorted((h for h in views if h == base or h.startswith(base + "[")), key=rank):
        out.update(views[h])
    return out


def read_panels():
    cfg = os.environ.get("XDG_CONFIG_HOME") or os.path.expanduser("~/.config")
    applets = read_kconfig(os.path.join(cfg, "plasma-org.kde.plasma.desktop-appletsrc"))
    views = read_kconfig(os.path.join(cfg, "plasmashellrc"))
    panels = []
    for header, kv in applets.items():
        m = re.match(r"^\[Containments\]\[(\d+)\]$", header)
        if not m or kv.get("plugin") != "org.kde.panel":
            continue
        edge = PANEL_LOCATIONS.get(to_int(kv.get("location"), -1))
        if not edge:
            continue
        v = merged_view(views, "[PlasmaViews][Panel %s]" % m.group(1))
        panels.append({
            "id": to_int(m.group(1), 0),
            "edge": edge,
            "screen": to_int(kv.get("lastScreen"), 0),
            "thickness": to_int(v.get("thickness"), 0) or 44,
            "floating": v.get("floating", "0").lower() in ("1", "true"),
            "hidden": to_int(v.get("panelVisibility"), 0) == 1,  # auto-hide
            # 0 = fill width, 1 = fit content, 2 = custom, -1 = not stored
            "lengthMode": to_int(v.get("panelLengthMode"), -1),
            "maxLength": to_int(v.get("maxLength"), 0),
            "minLength": to_int(v.get("minLength"), 0),
            "offset": to_int(v.get("offset"), 0),
            # Qt::Alignment: 1 = left/top, 2 = right/bottom, otherwise centered
            "alignment": to_int(v.get("alignment"), 1),
        })
    return panels


def panels_json():
    now = time.monotonic()
    if now - _panel_cache["time"] > 2.0:
        try:
            _panel_cache["json"] = json.dumps(read_panels()).encode()
        except Exception:
            _panel_cache["json"] = b"[]"
        _panel_cache["time"] = now
    return _panel_cache["json"]


# ---------------------------------------------------------------------------
# Media control (MPRIS over D-Bus) - used by the orb in the middle
# ---------------------------------------------------------------------------

MPRIS_PREFIX = "org.mpris.MediaPlayer2."
MPRIS_PATH = "/org/mpris/MediaPlayer2"
MPRIS_PLAYER = "org.mpris.MediaPlayer2.Player"
_media = {"time": 0.0, "json": b'{"status":"None","player":""}', "paused_by_us": [], "lock": threading.Lock()}


def _run(cmd, timeout=1.5):
    try:
        r = subprocess.run(cmd, stdout=subprocess.PIPE, stderr=subprocess.DEVNULL, timeout=timeout)
        return r.stdout.decode("utf-8", "replace") if r.returncode == 0 else None
    except Exception:
        return None


def _busctl_names():
    out = _run(["busctl", "--user", "--json=short", "call", "org.freedesktop.DBus", "/org/freedesktop/DBus",
                "org.freedesktop.DBus", "ListNames"])
    if out is None:
        return None
    try:
        return [n for n in json.loads(out)["data"][0] if n.startswith(MPRIS_PREFIX)]
    except Exception:
        return None


def _dbus_send_names():
    out = _run(["dbus-send", "--session", "--print-reply", "--dest=org.freedesktop.DBus",
                "/org/freedesktop/DBus", "org.freedesktop.DBus.ListNames"])
    if out is None:
        return []
    return [n for n in re.findall(r'string "([^"]+)"', out) if n.startswith(MPRIS_PREFIX)]


def mpris_players():
    if shutil.which("busctl"):
        names = _busctl_names()
        if names is not None:
            return names
    if shutil.which("dbus-send"):
        return _dbus_send_names()
    return []


def mpris_status(name):
    if shutil.which("busctl"):
        out = _run(["busctl", "--user", "--json=short", "get-property", name, MPRIS_PATH, MPRIS_PLAYER, "PlaybackStatus"])
        if out is not None:
            try:
                return str(json.loads(out)["data"])
            except Exception:
                pass
    if shutil.which("dbus-send"):
        out = _run(["dbus-send", "--session", "--print-reply", "--dest=" + name, MPRIS_PATH,
                    "org.freedesktop.DBus.Properties.Get", "string:" + MPRIS_PLAYER, "string:PlaybackStatus"])
        if out:
            m = re.search(r'string "([^"]+)"', out)
            if m:
                return m.group(1)
    return "Stopped"


def mpris_art(name):
    """Cover picture of the current track (mpris:artUrl), "" if there is none.
    Only file:// and http(s):// addresses are passed on."""
    url = ""
    if shutil.which("busctl"):
        out = _run(["busctl", "--user", "--json=short", "get-property", name, MPRIS_PATH, MPRIS_PLAYER, "Metadata"])
        if out is not None:
            try:
                url = str(json.loads(out)["data"].get("mpris:artUrl", {}).get("data", ""))
            except Exception:
                url = ""
    if not url and shutil.which("dbus-send"):
        out = _run(["dbus-send", "--session", "--print-reply", "--dest=" + name, MPRIS_PATH,
                    "org.freedesktop.DBus.Properties.Get", "string:" + MPRIS_PLAYER, "string:Metadata"])
        if out:
            m = re.search(r'"mpris:artUrl"\s*variant\s*string "([^"]*)"', out)
            if m:
                url = m.group(1)
    if not re.match(r"^(file|https?)://", url or ""):
        return ""
    return url[:2048]


def mpris_call(name, method):
    if shutil.which("busctl"):
        if _run(["busctl", "--user", "call", name, MPRIS_PATH, MPRIS_PLAYER, method]) is not None:
            return True
    if shutil.which("dbus-send"):
        return _run(["dbus-send", "--session", "--type=method_call", "--dest=" + name, MPRIS_PATH,
                     MPRIS_PLAYER + "." + method]) is not None
    return False


def _pretty(name):
    n = name[len(MPRIS_PREFIX):]
    n = re.sub(r"\.instance_?\d+.*$", "", n)
    known = {"plasma-browser-integration": "Browser", "chromium": "Chromium", "firefox": "Firefox",
             "vlc": "VLC", "spotify": "Spotify", "elisa": "Elisa", "mpv": "mpv", "brave": "Brave",
             "google-chrome": "Chrome", "chrome": "Chrome", "strawberry": "Strawberry"}
    return known.get(n.lower(), n[:1].upper() + n[1:])


def _snapshot():
    players = [(n, mpris_status(n)) for n in mpris_players()]
    playing = [n for n, s in players if s == "Playing"]
    paused = [n for n, s in players if s == "Paused"]
    if playing:
        status, who = "Playing", playing[0]
    elif paused:
        status, who = "Paused", paused[0]
    elif players:
        status, who = "Stopped", players[0][0]
    else:
        status, who = "None", ""
    # the browser integration duplicates the browser's own entry - prefer the real one
    if who.endswith("plasma-browser-integration"):
        others = [n for n in (playing or paused) if not n.endswith("plasma-browser-integration")]
        if others:
            who = others[0]
    return players, playing, paused, status, who


def media_json(force=False):
    with _media["lock"]:
        now = time.monotonic()
        if force or now - _media["time"] > 1.0:
            try:
                _, _, _, status, who = _snapshot()
                art = mpris_art(who) if who and status in ("Playing", "Paused") else ""
                _media["json"] = json.dumps({"status": status, "player": _pretty(who) if who else "",
                                             "art": art}).encode()
            except Exception:
                _media["json"] = b'{"status":"None","player":"","art":""}'
            _media["time"] = now
        return _media["json"]


def media_toggle():
    with _media["lock"]:
        try:
            players, playing, paused, _, _ = _snapshot()
            if playing:
                for n in playing:
                    mpris_call(n, "Pause")
                _media["paused_by_us"] = playing
            else:
                names = [n for n, _ in players]
                targets = [n for n in _media["paused_by_us"] if n in paused]
                if not targets and paused:
                    targets = [paused[0]]
                if not targets and names:
                    targets = [names[0]]
                for n in targets:
                    mpris_call(n, "Play")
                _media["paused_by_us"] = []
        except Exception as e:
            sys.stderr.write("media control error: %s\n" % e)
        _media["time"] = 0.0
    time.sleep(0.25)   # let the players report their new state
    return media_json(force=True)


# ---------------------------------------------------------------------------
# Audio guard - finds apps whose sound is muted or at 0 % (live or remembered
# by WirePlumber) and repairs them without touching anything else.
# ---------------------------------------------------------------------------

def _state_file():
    base = os.environ.get("XDG_STATE_HOME") or os.path.expanduser("~/.local/state")
    return os.path.join(base, "wireplumber", "stream-properties")


def _silent(volumes, mute):
    try:
        vols = [float(v) for v in volumes]
    except (TypeError, ValueError):
        vols = []
    return bool(mute) or (len(vols) > 0 and max(vols) <= 0.001)


def _live_streams():
    """Playing app streams that are muted or silent: [{id, name}]"""
    if not shutil.which("pactl"):
        return []
    out = _run(["pactl", "-f", "json", "list", "sink-inputs"], timeout=3)
    try:
        items = json.loads(out or "[]")
    except Exception:
        return []
    bad = []
    for it in items:
        props = it.get("properties", {})
        name = props.get("application.name") or props.get("media.name") or "?"
        if name == "SeaQ-SoundWave":
            continue
        vols = []
        for ch in (it.get("volume") or {}).values():
            try:
                vols.append(float(str(ch.get("value_percent", "100")).rstrip("%")) / 100.0)
            except Exception:
                pass
        if _silent(vols, it.get("mute")):
            bad.append({"id": it.get("index"), "name": name, "mute": bool(it.get("mute")),
                        "zero": len(vols) > 0 and max(vols) <= 0.001})
    return bad


def _remembered():
    """Lines in WirePlumber's memory for app outputs that are muted or at 0 %."""
    path = _state_file()
    bad = []
    try:
        with open(path, encoding="utf-8", errors="replace") as f:
            for line in f:
                if not line.startswith("Output/Audio:") or "=" not in line:
                    continue
                key, val = line.split("=", 1)
                try:
                    d = json.loads(val)
                except Exception:
                    continue
                vols = d.get("channelVolumes") or ([d["volume"]] if "volume" in d else [])
                if _silent(vols, d.get("mute")):
                    bad.append(key.split(":")[-1])
    except OSError:
        pass
    return bad


def audio_check():
    live = _live_streams()
    mem = _remembered()
    names = sorted(set([b["name"] for b in live] + mem))
    return json.dumps({"ok": not names, "apps": names, "pactl": bool(shutil.which("pactl"))}).encode()


def audio_fix(deep=False):
    """Give silent apps their sound back.
    Playing streams: unmute only if muted, set the volume only if it is 0 %
    (to 100 %, the normal level PipeWire gives every new app - an app's
    volume is a share of the system volume, so it never gets louder than that).
    deep=True (only after the user confirmed it): also remove the broken
    entries from WirePlumber's memory, which needs a short restart of it."""
    for b in _live_streams():
        if b.get("mute"):
            _run(["pactl", "set-sink-input-mute", str(b["id"]), "0"])
        if b.get("zero"):
            _run(["pactl", "set-sink-input-volume", str(b["id"]), "100%"])
    if not deep:
        return audio_check()
    if _remembered():
        path = _state_file()
        systemctl = shutil.which("systemctl")
        if systemctl:
            _run([systemctl, "--user", "stop", "wireplumber"], timeout=8)
        try:
            with open(path, encoding="utf-8", errors="replace") as f:
                lines = f.readlines()
            shutil.copyfile(path, path + ".seaq-backup")
            keep = []
            for line in lines:
                drop = False
                if line.startswith("Output/Audio:") and "=" in line:
                    try:
                        d = json.loads(line.split("=", 1)[1])
                        vols = d.get("channelVolumes") or ([d["volume"]] if "volume" in d else [])
                        drop = _silent(vols, d.get("mute"))
                    except Exception:
                        drop = False
                if not drop:
                    keep.append(line)
            with open(path, "w", encoding="utf-8") as f:
                f.writelines(keep)
        except OSError as e:
            sys.stderr.write("audio guard: %s\n" % e)
        if systemctl:
            _run([systemctl, "--user", "start", "wireplumber"], timeout=8)
        time.sleep(1.0)
    return audio_check()


# Access control. The widget starts the helper with a random token in the
# environment variable SEAQ_TOKEN (environment variables, unlike command
# lines, can't be read by other users). Every request has to carry it in the
# "X-SeaQ-Token" header. Web pages can't send such a header to another origin
# without a CORS preflight, which this server never answers, and the Host
# check stops DNS rebinding. Only /hello (identification) needs no token.
AUTH_TOKEN = os.environ.get("SEAQ_TOKEN", "")
SERVER_PORT = [0]


def _allowed_host(host):
    port = SERVER_PORT[0]
    return host in ("127.0.0.1:%d" % port, "localhost:%d" % port)


class Handler(BaseHTTPRequestHandler):
    protocol_version = "HTTP/1.1"  # keep-alive: no new TCP connection per frame

    def log_message(self, *args):
        pass

    def _send(self, body, code=200):
        self.send_response(code)
        self.send_header("Content-Type", "text/plain; charset=utf-8")
        self.send_header("Content-Length", str(len(body)))
        self.send_header("Cache-Control", "no-store")
        self.end_headers()
        self.wfile.write(body)

    def do_GET(self):
        if not _allowed_host(self.headers.get("Host", "")):
            self._send(b"forbidden", 403)
            return
        if self.path.startswith("/hello"):
            self._send(json.dumps({"app": "SeaQ-SoundWave", "uid": os.getuid(), "pid": os.getpid()}).encode())
            return
        if AUTH_TOKEN and not secrets.compare_digest(self.headers.get("X-SeaQ-Token", ""), AUTH_TOKEN):
            self._send(b"forbidden", 403)
            return
        state["last_request"] = time.monotonic()
        if self.path.startswith("/quit"):
            self._send(b"bye")
            stop_event.set()
        elif self.path.startswith("/frame"):
            self._send(state["frame"])
        elif self.path.startswith("/panels"):
            self._send(panels_json())
        elif self.path.startswith("/media"):
            self._send(media_json())
        elif self.path.startswith("/playpause"):
            self._send(media_toggle())
        elif self.path.startswith("/audiocheck"):
            self._send(audio_check())
        elif self.path.startswith("/audiofix"):
            self._send(audio_fix(deep="deep=1" in self.path))
        elif self.path.startswith("/taskbaricon"):
            set_window_rule("on=1" in self.path)
            self._send(b"ok")
        else:
            self._send(b"not found", 404)


class QuietServer(ThreadingHTTPServer):
    daemon_threads = True
    allow_reuse_address = True

    def handle_error(self, request, client_address):
        pass  # client hung up mid-response - not interesting


def _own_helper_pid(port):
    """PID of an older SeaQ SoundWave helper of *this user* on the port, or None."""
    try:
        req = urllib.request.Request("http://127.0.0.1:%d/hello" % port)
        info = json.loads(urllib.request.urlopen(req, timeout=1).read().decode())
    except Exception:
        return None
    if info.get("app") != "SeaQ-SoundWave" or info.get("uid") != os.getuid():
        return None
    pid = int(info.get("pid", 0))
    try:   # double check with the kernel: same user, really our script
        if os.stat("/proc/%d" % pid).st_uid != os.getuid():
            return None
        with open("/proc/%d/cmdline" % pid, "rb") as f:
            if b"audio-server.py" not in f.read():
                return None
    except OSError:
        return None
    return pid


class PortTaken(Exception):
    pass


def bind(port):
    """Bind the port. If an older helper of ours still owns it (settings
    changed, Plasma restarted) it is stopped; if anything else owns it,
    PortTaken is raised and the widget tries the next port."""
    SERVER_PORT[0] = port
    for _ in range(4):
        try:
            return QuietServer(("127.0.0.1", port), Handler)
        except OSError as e:
            if e.errno != errno.EADDRINUSE:
                raise
            pid = _own_helper_pid(port)
            if pid is None:
                raise PortTaken()
            try:
                os.kill(pid, signal.SIGTERM)
            except OSError:
                pass
            time.sleep(0.6)
    raise PortTaken()


def write_config(args):
    runtime = os.environ.get("XDG_RUNTIME_DIR") or tempfile.gettempdir()
    path = os.path.join(runtime, "seaq-soundwave-plasmoid-%d.conf" % args.port)
    config = (
        "[general]\n"
        "bars = %d\n"
        "sensitivity = %d\n"
        "autosens = 1\n"
        "framerate = %d\n"
        "\n"
        "[input]\n"
        "method = %s\n"
        "source = %s\n"
        "\n"
        "[output]\n"
        "method = raw\n"
        "raw_target = /dev/stdout\n"
        "data_format = ascii\n"
        "ascii_max_range = 255\n"
        "bar_delimiter = 59\n"
        "frame_delimiter = 10\n"
        "channels = mono\n"
        "mono_option = average\n"
    ) % (args.bars, args.sensitivity, args.framerate, args.method, args.source)
    with open(path, "w") as f:
        f.write(config)
    return path


def die_with_parent():
    """Make the kernel SIGTERM cava if this helper gets SIGKILLed."""
    try:
        import ctypes
        ctypes.CDLL("libc.so.6", use_errno=True).prctl(1, signal.SIGTERM)  # PR_SET_PDEATHSIG
    except Exception:
        pass


def pump(proc):
    for raw in proc.stdout:
        line = raw.strip()
        if line:
            state["frame"] = line.rstrip(b";")
    if not stop_event.is_set():
        state["exit_code"] = EXIT_CAVA_FAILED
        sys.stderr.write("cava exited unexpectedly (code %s)\n" % proc.poll())
        stop_event.set()


# ---------------------------------------------------------------------------
# Engine 1: cava
# ---------------------------------------------------------------------------

def start_cava(args, procs):
    cava = shutil.which("cava")
    if not cava:
        return False
    conf = write_config(args)
    try:
        proc = subprocess.Popen(
            [cava, "-p", conf],
            stdout=subprocess.PIPE,
            stderr=subprocess.DEVNULL,
            preexec_fn=die_with_parent,
            env=quiet_env(),
        )
    except OSError as e:
        sys.stderr.write("could not start cava: %s\n" % e)
        return False
    procs.append(proc)
    procs.append(conf)
    threading.Thread(target=pump, args=(proc,), daemon=True).start()
    return True


# ---------------------------------------------------------------------------
# Engine 2: built-in capture + FFT
# ---------------------------------------------------------------------------

class Capture:
    """Reads raw mono s16le audio from a capture process into a ring buffer."""

    def __init__(self, rate, size):
        self.rate = rate
        self.keep = size * 2 * 2
        self.buf = bytearray()
        self.lock = threading.Lock()
        self.last_audio = 0.0
        self.proc = None

    def commands(self, source):
        auto = source in ("", "auto")
        cmds = []
        # parec first (works with PipeWire's pulse layer and plain PulseAudio),
        # PipeWire's own recorder as the fallback.
        if shutil.which("parec"):
            cmds.append(["parec", "-d", "@DEFAULT_MONITOR@" if auto else source,
                         "--format=s16le", "--rate=%d" % self.rate, "--channels=1",
                         "--latency-msec=30"] + ["--property=%s=%s" % kv for kv in QUIET_STREAM.items()])
        if shutil.which("pw-record"):
            props = "{ " + " ".join("%s=%s" % kv for kv in QUIET_STREAM.items())
            props += (" stream.capture.sink=true }" if auto else " }")
            c = ["pw-record", "--rate", str(self.rate), "--channels", "1",
                 "--format", "s16", "--latency", "30ms", "-P", props]
            if not auto:
                c += ["--target", source]
            c.append("-")
            cmds.append(c)
        return cmds

    def start(self, source, procs):
        for cmd in self.commands(source):
            try:
                proc = subprocess.Popen(cmd, stdout=subprocess.PIPE, stderr=subprocess.DEVNULL,
                                        bufsize=0, preexec_fn=die_with_parent, env=quiet_env())
            except OSError as e:
                sys.stderr.write("could not start %s: %s\n" % (cmd[0], e))
                continue
            # Give it a moment; reject only if it dies right away (bad flags,
            # no such server). An idle sink may legitimately send nothing yet.
            select.select([proc.stdout], [], [], 1.5)
            if proc.poll() is None:
                self.proc = proc
                procs.append(proc)
                threading.Thread(target=self._read, daemon=True).start()
                return True
        return False

    def _read(self):
        fd = self.proc.stdout.fileno()
        pending = b""
        first = True
        while True:
            try:
                chunk = os.read(fd, 16384)
            except OSError:
                break
            if not chunk:
                break
            if first:
                first = False
                if chunk.startswith(b"RIFF"):  # pw-record may emit a WAV header
                    chunk = chunk[44:]
            data = pending + chunk
            if len(data) % 2:
                pending, data = data[-1:], data[:-1]
            else:
                pending = b""
            with self.lock:
                self.buf += data
                if len(self.buf) > self.keep:
                    del self.buf[:-self.keep]
                self.last_audio = time.monotonic()
        if not stop_event.is_set():
            state["exit_code"] = EXIT_CAVA_FAILED
            sys.stderr.write("audio capture process ended unexpectedly\n")
            stop_event.set()

    def latest(self, n):
        """Last n samples as raw bytes, or None when no audio is arriving."""
        with self.lock:
            if time.monotonic() - self.last_audio > 0.4:
                return None
            data = bytes(self.buf[-n * 2:])
        if len(data) < n * 2:
            data = b"\x00" * (n * 2 - len(data)) + data
        return data


def make_pure_fft(n):
    bits = n.bit_length() - 1
    rev = [int(format(i, "0%db" % bits)[::-1], 2) for i in range(n)]
    tw = [cmath.exp(-2j * math.pi * k / n) for k in range(n // 2)]

    def fft(x):
        a = [complex(x[rev[i]]) for i in range(n)]
        size = 2
        while size <= n:
            half = size // 2
            step = n // size
            for start in range(0, n, size):
                k = 0
                for j in range(start, start + half):
                    t = a[j + half] * tw[k]
                    u = a[j]
                    a[j] = u + t
                    a[j + half] = u - t
                    k += step
            size *= 2
        return a

    return fft


class Spectrum:
    """PCM -> N log-spaced bands, 0-255, with auto-gain and smoothing."""

    DYNAMIC_RANGE_DB = 45.0
    MIN_REF_DB = -45.0

    def __init__(self, bars, sensitivity, rate, size, fps):
        self.bars = bars
        self.size = size
        self.gain = sensitivity / 100.0
        self.fps = fps
        self.ref_db = self.MIN_REF_DB
        self.values = [0.0] * bars
        self.decay_db = 9.0 / fps  # auto-gain release: ~9 dB per second

        res = rate / float(size)
        fmin, fmax = 45.0, min(12000.0, rate / 2.0 * 0.95)
        edges = [fmin * (fmax / fmin) ** (i / float(bars)) for i in range(bars + 1)]
        self.layout = []
        for i in range(bars):
            lo, hi = edges[i] / res, edges[i + 1] / res
            fc = math.sqrt(edges[i] * edges[i + 1])
            tilt = 2.5 * math.log2(fc / 600.0)  # compensate the natural spectral roll-off
            self.layout.append((lo, hi, fc / res, tilt))

        if np is not None:
            self.window = np.hanning(size)
        else:
            self.window = [0.5 - 0.5 * math.cos(2 * math.pi * i / (size - 1)) for i in range(size)]
            self.fft = make_pure_fft(size)

    def _magnitudes(self, pcm):
        norm = 4.0 / self.size  # Hann window: a full-scale sine -> 1.0
        if np is not None:
            x = np.frombuffer(pcm, dtype="<i2").astype(np.float32) / 32768.0
            return np.abs(np.fft.rfft(x * self.window)) * norm
        a = array.array("h")
        a.frombytes(pcm)
        if sys.byteorder == "big":
            a.byteswap()
        x = [a[i] / 32768.0 * self.window[i] for i in range(self.size)]
        spec = self.fft(x)
        return [abs(spec[k]) * norm for k in range(self.size // 2 + 1)]

    def process(self, pcm):
        if pcm is None:
            dbs = [-200.0] * self.bars
        else:
            mags = self._magnitudes(pcm)
            top = len(mags) - 1
            dbs = []
            for lo, hi, center, tilt in self.layout:
                if hi - lo < 1.0:
                    i = min(int(center), top - 1)
                    f = center - i
                    m = mags[i] * (1 - f) + mags[i + 1] * f
                else:
                    m = max(mags[int(lo):min(int(hi) + 1, top + 1)])
                dbs.append(20.0 * math.log10(max(float(m), 1e-7)) + tilt)

        peak = max(dbs)
        if peak > self.ref_db:
            self.ref_db = peak
        else:
            self.ref_db = max(self.MIN_REF_DB, self.ref_db - self.decay_db)
        floor = self.ref_db - self.DYNAMIC_RANGE_DB

        out = []
        for i, db in enumerate(dbs):
            v = max(0.0, min(1.0, (db - floor) / self.DYNAMIC_RANGE_DB * self.gain))
            cur = self.values[i]
            cur = cur * 0.3 + v * 0.7 if v > cur else cur * 0.86 + v * 0.14
            self.values[i] = cur
            out.append(str(int(cur * 255 + 0.5)))
        return ";".join(out).encode()


def start_builtin(args, procs):
    if np is not None:
        rate, size, fps = 44100, 2048, args.framerate
    else:  # keep pure-Python FFT cheap: lower rate, smaller window, capped fps
        rate, size, fps = 22050, 512, min(args.framerate, 30)

    cap = Capture(rate, size)
    if not cap.start(args.source, procs):
        return False
    spectrum = Spectrum(args.bars, args.sensitivity, rate, size, fps)

    def loop():
        interval = 1.0 / fps
        while not stop_event.wait(interval):
            try:
                state["frame"] = spectrum.process(cap.latest(size))
            except Exception as e:  # never let the analysis thread die silently
                sys.stderr.write("analysis error: %s\n" % e)
                state["exit_code"] = EXIT_CAVA_FAILED
                stop_event.set()

    threading.Thread(target=loop, daemon=True).start()
    return True


def install_icon():
    """Puts the widget's icon into the user's icon theme folder (so the widget
    list and the settings show the SeaQ SoundWave logo), once per size."""
    here = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "icons")
    base = os.path.join(os.environ.get("XDG_DATA_HOME") or os.path.expanduser("~/.local/share"), "icons", "hicolor")
    for n in (48, 64, 128, 256):
        src = os.path.join(here, "seaq-soundwave-%d.png" % n)
        dst = os.path.join(base, "%dx%d" % (n, n), "apps", "seaq-soundwave.png")
        try:
            if os.path.exists(src) and (not os.path.exists(dst) or os.path.getsize(dst) != os.path.getsize(src)):
                os.makedirs(os.path.dirname(dst), exist_ok=True)
                shutil.copyfile(src, dst)
        except OSError:
            pass


RULE_ID = "seaq-soundwave-editor"
RULE = {
    "Description": "SeaQ SoundWave (icon)",
    "title": "SeaQ SoundWave", "titlematch": "2",          # title contains ...
    "wmclass": "plasmashell", "wmclassmatch": "2", "wmclasscomplete": "false",
    "desktopfile": "seaq-soundwave", "desktopfilerule": "2",  # force our desktop file
}
DESKTOP_FILE = """[Desktop Entry]
Type=Application
Name=SeaQ SoundWave
Comment=Audio visualizer for KDE Plasma
Icon=seaq-soundwave
Exec=true
NoDisplay=true
"""


def remove_window_rule():
    data = os.environ.get("XDG_DATA_HOME") or os.path.expanduser("~/.local/share")
    try:
        os.remove(os.path.join(data, "applications", "seaq-soundwave.desktop"))
    except OSError:
        pass
    kread, kwrite = shutil.which("kreadconfig6"), shutil.which("kwriteconfig6")
    if not (kread and kwrite):
        return
    if not (_run([kread, "--file", "kwinrulesrc", "--group", RULE_ID, "--key", "desktopfile"]) or "").strip():
        return
    for k in RULE:
        _run([kwrite, "--file", "kwinrulesrc", "--group", RULE_ID, "--key", k, "--delete"])
    rules = [r for r in (_run([kread, "--file", "kwinrulesrc", "--group", "General", "--key", "rules"]) or "").strip().split(",")
             if r and r != RULE_ID]
    _run([kwrite, "--file", "kwinrulesrc", "--group", "General", "--key", "rules", ",".join(rules)])
    _run([kwrite, "--file", "kwinrulesrc", "--group", "General", "--key", "count", str(len(rules))])
    _kwin_reconfigure()


def _kwin_reconfigure():
    if shutil.which("busctl"):
        _run(["busctl", "--user", "call", "org.kde.KWin", "/KWin", "org.kde.KWin", "reconfigure"])
    elif shutil.which("dbus-send"):
        _run(["dbus-send", "--session", "--dest=org.kde.KWin", "/KWin", "org.kde.KWin.reconfigure"])


def set_window_rule(on):
    threading.Thread(target=install_window_rule if on else remove_window_rule, daemon=True).start()


def install_window_rule():
    """The settings windows belong to plasmashell, so the task manager would
    show Plasma's icon. A KWin window rule gives windows titled
    "SeaQ SoundWave ..." our own desktop file, and with it the logo."""
    data = os.environ.get("XDG_DATA_HOME") or os.path.expanduser("~/.local/share")
    try:
        path = os.path.join(data, "applications", "seaq-soundwave.desktop")
        if not os.path.exists(path) or open(path).read() != DESKTOP_FILE:
            os.makedirs(os.path.dirname(path), exist_ok=True)
            with open(path, "w") as f:
                f.write(DESKTOP_FILE)
    except OSError:
        pass
    kread, kwrite = shutil.which("kreadconfig6"), shutil.which("kwriteconfig6")
    if not (kread and kwrite):
        return
    if (_run([kread, "--file", "kwinrulesrc", "--group", RULE_ID, "--key", "desktopfile"]) or "").strip() == RULE["desktopfile"]:
        return   # already there
    for k, v in RULE.items():
        _run([kwrite, "--file", "kwinrulesrc", "--group", RULE_ID, "--key", k, v])
    rules = [r for r in (_run([kread, "--file", "kwinrulesrc", "--group", "General", "--key", "rules"]) or "").strip().split(",") if r]
    if RULE_ID not in rules:
        rules.append(RULE_ID)
    _run([kwrite, "--file", "kwinrulesrc", "--group", "General", "--key", "rules", ",".join(rules)])
    _run([kwrite, "--file", "kwinrulesrc", "--group", "General", "--key", "count", str(len(rules))])
    _kwin_reconfigure()   # let KWin load the new rule


def main():
    p = argparse.ArgumentParser()
    p.add_argument("--port", type=int, required=True)
    p.add_argument("--bars", type=int, default=48)
    p.add_argument("--sensitivity", type=int, default=100)
    p.add_argument("--framerate", type=int, default=60)
    p.add_argument("--engine", default="auto", choices=["auto", "cava", "builtin"])
    p.add_argument("--method", default="pulse")   # cava only
    p.add_argument("--source", default="auto")
    p.add_argument("--token", default="")  # only makes each launch's command line unique (not secret)
    p.add_argument("--taskbar-icon", default="0")
    args = p.parse_args()
    install_icon()
    set_window_rule(args.taskbar_icon == "1")

    args.bars = max(4, min(256, args.bars))
    args.sensitivity = max(10, min(300, args.sensitivity))
    args.framerate = max(10, min(144, args.framerate))

    engine = args.engine
    if engine == "auto":
        engine = "cava" if shutil.which("cava") else "builtin"
    if engine == "cava" and not shutil.which("cava"):
        sys.stderr.write("cava is not installed\n")
        return EXIT_CAVA_MISSING
    if engine == "builtin" and not (shutil.which("parec") or shutil.which("pw-record")):
        sys.stderr.write("neither parec nor pw-record found (install pulseaudio-utils "
                         "or pipewire-utils, or install cava)\n")
        return EXIT_CAVA_MISSING

    try:
        server = bind(args.port)
    except PortTaken:
        sys.stderr.write("port %d is used by another program\n" % args.port)
        return EXIT_PORT_TAKEN
    except OSError as e:
        sys.stderr.write("cannot bind port %d: %s\n" % (args.port, e))
        return EXIT_BIND_FAILED

    for sig in (signal.SIGTERM, signal.SIGINT, signal.SIGHUP):
        signal.signal(sig, lambda *_: stop_event.set())

    procs = []  # subprocesses, plus temp files to delete
    started = start_cava(args, procs) if engine == "cava" else start_builtin(args, procs)
    if not started:
        sys.stderr.write("could not start the %s audio engine\n" % engine)
        server.server_close()
        return EXIT_CAVA_FAILED

    threading.Thread(target=server.serve_forever, daemon=True).start()

    try:
        while not stop_event.wait(1.0):
            if time.monotonic() - state["last_request"] > IDLE_TIMEOUT:
                break
    finally:
        stop_event.set()
        server.shutdown()
        server.server_close()
        for item in procs:
            if isinstance(item, str):
                try:
                    os.remove(item)
                except OSError:
                    pass
                continue
            try:
                item.terminate()
                item.wait(timeout=2)
            except Exception:
                item.kill()

    return state["exit_code"]


if __name__ == "__main__":
    sys.exit(main())
