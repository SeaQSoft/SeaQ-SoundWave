import QtQuick
import QtQuick.Layouts
import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.components as PlasmaComponents3
import org.kde.plasma.plasma5support as P5Support
import org.kde.kirigami as Kirigami
import QtQuick.Controls as QQC2
import "js/styles.js" as Styles

// SeaQ SoundWave - audio visualizer for the KDE Plasma 6 desktop.
//
// The visualizer itself lives on a "stage". In "widget" mode the stage
// sits inside the widget. In every other mode it is moved onto the desktop
// layer (the item that holds all desktop widgets), so it floats freely
// behind all windows while the widget itself shrinks to a small card that
// can stay in a corner:
//   panel  - glued to a panel (taskbar), centred, with a gap and an offset
//   screen - a fixed spot on the screen (9 anchor points + margins)
//   free   - wherever the user drags it; unlocked/locked with a shortcut
PlasmoidItem {
    id: root

    readonly property var cfg: Plasmoid.configuration

    // One helper process + port per widget instance.
    // Port of the helper: derived from the widget id, moved on by portShift
    // when another program already uses it.
    property int portShift: 0
    readonly property int port: 40000 + ((Plasmoid.id * 7 + portShift) % 20000)

    // Random secret for this session; every request to the helper carries it
    // (see audio-server.py). It is handed over in the environment, which other
    // users can't read, and changes with every start.
    readonly property string authToken: makeToken()
    function makeToken() {
        var t = "";
        for (var i = 0; i < 4; i++)
            t += Math.floor(Math.random() * 0x100000000).toString(36);
        return t + Date.now().toString(36);
    }

    property var barValues: []
    property bool daemonRunning: false
    property bool cavaMissing: false
    property string errorText: ""

    property string currentSource: ""
    property double startedAt: 0
    property int failStreak: 0
    property int token: 0
    property bool polling: false

    // ---- style ----------------------------------------------------------------
    readonly property var styleInfo: Styles.byId(cfg.vizStyle)
    readonly property var styleOpts: Styles.resolve(cfg.vizStyle, cfg.styleOptions)
    readonly property string paletteJson: cfg.palette
    readonly property bool orbVisible: !!styleInfo.orb && !!styleOpts.orbEnabled

    // ---- media (MPRIS) --------------------------------------------------------
    property string mediaStatus: "None"
    property string mediaPlayer: ""
    property string mediaArt: ""          // cover of the current track (label of the record orb)
    readonly property bool mediaPlaying: mediaStatus !== "Paused" && mediaStatus !== "Stopped"
    property bool mediaBusy: false

    // ---- placement --------------------------------------------------------------
    property bool canPlace: false     // the widget sits on a desktop and can use the desktop layer
    property Item desk: null          // the desktop layer the stage is moved onto
    property Item widgetHolder: null  // the widget's own area (full representation)
    readonly property string placement: (canPlace && desk) ? (cfg.placement || "widget") : "widget"
    readonly property bool external: placement !== "widget"
    property bool unlocked: false     // free positioning: dragging enabled
    property var freeLive: null       // geometry while dragging (global), committed on release
    property var editorWin: null
    property Item container: null      // Plasma's item container of this widget on the desktop
    readonly property bool containerEditing: container !== null && !!container.editMode

    // pop-up card (right click on the visualizer)
    property bool popupOpen: false
    property point popupPos: Qt.point(0, 0)
    readonly property bool editorOpen: editorWin !== null && editorWin.visible

    readonly property string shortcutText: {
        var s = "";
        try {
            s = String(Plasmoid.globalShortcut);
        } catch (e) {
            s = "";
        }
        var m = /QKeySequence,\s*(.*)\)$/.exec(s);
        if (m)
            s = m[1];
        if (!s || s === "undefined" || s === "null" || s.indexOf("QVariant") >= 0)
            s = cfg.shortcutText || "";
        return s.length ? s : i18n("no shortcut");
    }

    // ---- panel attachment state -------------------------------------------
    property var panels: []
    property string panelsJson: ""
    property bool panelsLoaded: false
    readonly property int screenId: (typeof Plasmoid.screen === "number") ? Plasmoid.screen : -1

    readonly property string attachEdge: placement === "panel" ? resolveEdge(panels, true, cfg.attachEdge, screenId) : ""

    // Visible windows (global coordinates); a window touching a floating
    // panel makes Plasma dock the panel to the screen edge.
    property var windows: []
    property var windowWatcher: null

    // The stage in global screen coordinates (null in widget mode).
    readonly property var stageGeo: computeStage(placement, attachEdge, panels, windows, freeLive,
            cfg.attachThickness, cfg.attachGap, cfg.attachOffset, cfg.attachLengthMode, cfg.attachLength, cfg.attachEndInset,
            cfg.screenAnchor, cfg.screenMarginX, cfg.screenMarginY, cfg.screenWidth, cfg.screenHeight,
            cfg.freeX, cfg.freeY, cfg.freeW, cfg.freeH, !!styleInfo.round,
            Screen.virtualX, Screen.virtualY, Screen.width, Screen.height, screenId)

    // Which side the visualizer's base points to (decides rotation).
    readonly property string stageEdge: {
        if (styleInfo.round)
            return "bottom";
        if (placement === "panel")
            return attachEdge !== "" ? attachEdge : "bottom";
        if (placement === "screen")
            return anchorEdge(cfg.screenAnchor);
        if (placement === "free")
            return cfg.freeEdge || "bottom";
        return "bottom";
    }
    readonly property bool stageVertical: stageEdge === "left" || stageEdge === "right"
    readonly property real softStartPx: placement === "panel" && stageGeo && stageGeo.softStart && styleInfo.soft ? cfg.attachSoftEnds : 0
    readonly property real softEndPx: placement === "panel" && stageGeo && stageGeo.softEnd && styleInfo.soft ? cfg.attachSoftEnds : 0

    property var stageLocal: ({ x: 0, y: 0, w: 0, h: 0 })

    property string notice: ""
    function showNotice(m) {
        notice = m;
        noticeTimer.restart();
    }
    Timer { id: noticeTimer; interval: 3500; onTriggered: root.notice = "" }

    preferredRepresentation: fullRepresentation
    Plasmoid.backgroundHints: PlasmaCore.Types.NoBackground | PlasmaCore.Types.ConfigurableBackground
    toolTipMainText: "SeaQ SoundWave"
    toolTipSubText: i18n(styleInfo.name)

    onStageGeoChanged: syncStage()
    onDeskChanged: syncStage()
    onExternalChanged: {
        syncStage();
        containerTimer.restart();
        if (!external)
            unlocked = false;
        popupOpen = false;
    }
    onPlacementChanged: {
        syncWatcher();
        if (placement !== "free")
            unlocked = false;
    }

    // ---- geometry helpers ---------------------------------------------------

    function panelsOn(list, edge, scr) {
        var out = [];
        for (var i = 0; i < list.length; i++) {
            var p = list[i];
            if (p.edge !== edge)
                continue;
            if (scr >= 0 && p.screen >= 0 && p.screen !== scr)
                continue;
            out.push(p);
        }
        return out;
    }

    // Total thickness of the panels on `edge` (screen `scr`), or -1 if none.
    function edgeThickness(list, edge, scr) {
        var ps = panelsOn(list, edge, scr);
        if (ps.length === 0)
            return -1;
        var total = 0;
        for (var i = 0; i < ps.length; i++)
            total += ps[i].hidden ? 0 : ps[i].thickness + (ps[i].floating ? 8 : 0);
        return total;
    }

    function resolveEdge(list, enabled, wanted, scr) {
        if (!enabled)
            return "";
        var order = (wanted === "auto" || !wanted) ? ["bottom", "top", "left", "right"] : [wanted];
        for (var i = 0; i < order.length; i++) {
            if (edgeThickness(list, order[i], scr) >= 0)
                return order[i];
        }
        return "";
    }

    function panelRange(p, S, floatingNow) {
        var L = S;
        if (p.maxLength > 0 && p.maxLength < S - 1 && p.lengthMode !== 0)
            L = p.maxLength;
        var start;
        if (L >= S)
            start = 0;
        else if (p.alignment & 1)
            start = p.offset;
        else if (p.alignment & 2)
            start = S - L - p.offset;
        else
            start = (S - L) / 2 + p.offset;
        var gap = floatingNow ? 8 : 0;
        return { rawStart: start, rawEnd: start + L,
                 start: start + gap, end: start + L - gap,
                 rounded: floatingNow || L < S - 1 };
    }

    function panelTouched(p, S, sx, sy, sw, sh, wins) {
        if (!wins || wins.length === 0)
            return false;
        var r = panelRange(p, S, true);
        var depth = p.thickness + 8 + 2;
        var zx0, zx1, zy0, zy1;
        if (p.edge === "bottom") {
            zx0 = sx + r.rawStart; zx1 = sx + r.rawEnd; zy0 = sy + sh - depth; zy1 = sy + sh;
        } else if (p.edge === "top") {
            zx0 = sx + r.rawStart; zx1 = sx + r.rawEnd; zy0 = sy; zy1 = sy + depth;
        } else if (p.edge === "left") {
            zx0 = sx; zx1 = sx + depth; zy0 = sy + r.rawStart; zy1 = sy + r.rawEnd;
        } else {
            zx0 = sx + sw - depth; zx1 = sx + sw; zy0 = sy + r.rawStart; zy1 = sy + r.rawEnd;
        }
        for (var i = 0; i < wins.length; i++) {
            var w = wins[i];
            if (w.x < zx1 && w.x + w.width > zx0 && w.y < zy1 && w.y + w.height > zy0)
                return true;
        }
        return false;
    }

    function computeStrip(edge, list, thick, gap, offset, lengthMode, length, inset, sx, sy, sw, sh, scr, wins) {
        var eff = [];
        for (var k = 0; k < list.length; k++) {
            var q = list[k];
            var qS = (q.edge === "top" || q.edge === "bottom") ? sw : sh;
            eff.push({
                edge: q.edge, screen: q.screen, thickness: q.thickness, hidden: q.hidden,
                lengthMode: q.lengthMode, maxLength: q.maxLength, minLength: q.minLength,
                offset: q.offset, alignment: q.alignment,
                floating: q.floating && !panelTouched(q, qS, sx, sy, sw, sh, wins)
            });
        }

        var horizontal = (edge === "bottom" || edge === "top");
        var S = horizontal ? sw : sh;
        var own = Math.max(0, edgeThickness(eff, edge, scr)) + gap;

        var ps = panelsOn(eff, edge, scr);
        var pa = S, pb = 0, rounded = false;
        for (var i = 0; i < ps.length; i++) {
            var e = panelRange(ps[i], S, ps[i].floating);
            pa = Math.min(pa, e.start);
            pb = Math.max(pb, e.end);
            rounded = rounded || e.rounded;
        }
        if (ps.length === 0) {
            pa = 0;
            pb = S;
        }

        var a0, a1;
        if (lengthMode === "screen") {
            a0 = Math.max(0, edgeThickness(eff, horizontal ? "left" : "top", scr));
            a1 = S - Math.max(0, edgeThickness(eff, horizontal ? "right" : "bottom", scr));
        } else if (lengthMode === "custom") {
            var mid = (pa + pb) / 2;
            a0 = mid - length / 2;
            a1 = mid + length / 2;
        } else {
            var cut = rounded ? inset : 0;
            a0 = pa + cut;
            a1 = pb - cut;
        }
        // shift along the edge ("Verschiebung"), kept on screen
        var len = Math.max(10, a1 - a0);
        a0 = Math.max(0, Math.min(S - len, a0 + offset));
        a1 = Math.min(S, a0 + len);

        var g = {};
        if (horizontal) {
            g.x = sx + a0;
            g.width = a1 - a0;
            g.height = thick;
            g.y = (edge === "bottom") ? sy + sh - own - thick : sy + own;
        } else {
            g.y = sy + a0;
            g.height = a1 - a0;
            g.width = thick;
            g.x = (edge === "right") ? sx + sw - own - thick : sx + own;
        }
        return {
            x: Math.round(g.x), y: Math.round(g.y),
            width: Math.round(g.width), height: Math.round(g.height),
            softStart: lengthMode !== "screen" && a0 > 0.5,
            softEnd: lengthMode !== "screen" && a1 < S - 0.5
        };
    }

    function anchorEdge(a) {
        a = String(a || "bottom");
        if (a.indexOf("top") === 0)
            return "top";
        if (a.indexOf("bottom") === 0)
            return "bottom";
        if (a === "left")
            return "left";
        if (a === "right")
            return "right";
        return "bottom";
    }

    // The screen without the panels around it.
    function availRect(list, sx, sy, sw, sh, scr) {
        var t = Math.max(0, edgeThickness(list, "top", scr)), b = Math.max(0, edgeThickness(list, "bottom", scr));
        var l = Math.max(0, edgeThickness(list, "left", scr)), r = Math.max(0, edgeThickness(list, "right", scr));
        return { x: sx + l, y: sy + t, width: Math.max(50, sw - l - r), height: Math.max(50, sh - t - b) };
    }

    function screenRect(anchor, mx, my, wPct, size, round, A) {
        var edge = anchorEdge(anchor);
        var vertical = !round && (edge === "left" || edge === "right");
        var W, H;
        if (round) {
            W = H = Math.min(size, A.width, A.height);
        } else if (vertical) {
            W = Math.min(size, A.width);
            H = A.height * wPct / 100;
        } else {
            W = A.width * wPct / 100;
            H = Math.min(size, A.height);
        }
        anchor = String(anchor || "bottom");
        var col = anchor.indexOf("left") >= 0 ? 0 : (anchor.indexOf("right") >= 0 ? 2 : 1);
        var row = anchor.indexOf("top") === 0 ? 0 : (anchor.indexOf("bottom") === 0 ? 2 : 1);
        var x = col === 0 ? A.x + mx : (col === 2 ? A.x + A.width - W - mx : A.x + (A.width - W) / 2 + mx);
        var y = row === 0 ? A.y + my : (row === 2 ? A.y + A.height - H - my : A.y + (A.height - H) / 2 + my);
        return { x: Math.round(x), y: Math.round(y), width: Math.round(W), height: Math.round(H) };
    }

    function defaultFree(round, sx, sy, sw, sh) {
        var W = round ? Math.round(Math.min(sw, sh) * 0.45) : Math.round(sw * 0.55);
        var H = round ? W : Math.round(Math.min(320, sh * 0.3));
        return { x: Math.round(sx + (sw - W) / 2), y: Math.round(sy + (sh - H) / 2), width: W, height: H };
    }

    function computeStage(mode, edge, list, wins, live, thick, gap, offset, lengthMode, length, inset,
                          anchor, mx, my, wPct, size, fx, fy, fw, fh, round, sx, sy, sw, sh, scr) {
        if (mode === "panel") {
            if (edge !== "")
                return computeStrip(edge, list, thick, gap, offset, lengthMode, length, inset, sx, sy, sw, sh, scr, wins);
            // no panel on that edge: sit at the bottom of the screen instead
            return screenRect("bottom", offset, gap, 60, thick, round, availRect(list, sx, sy, sw, sh, scr));
        }
        if (mode === "screen")
            return screenRect(anchor, mx, my, wPct, size, round, availRect(list, sx, sy, sw, sh, scr));
        if (mode === "free") {
            if (live)
                return live;
            if (fw <= 0 || fh <= 0)
                return defaultFree(round, sx, sy, sw, sh);
            return { x: sx + fx, y: sy + fy, width: fw, height: fh };
        }
        return null;
    }

    // ---- moving the stage ------------------------------------------------------

    function findContainer() {
        var it = root.parent;
        for (var depth = 0; it && depth < 12; depth++) {
            if (typeof it.dragActive !== "undefined" && typeof it.editMode !== "undefined" && it.parent)
                return it;
            it = it.parent;
        }
        return null;
    }

    function syncStage() {
        if (!external || !desk || !stageGeo) {
            stageLocal = { x: 0, y: 0, w: 0, h: 0 };
            return;
        }
        var g = stageGeo;
        var p = desk.mapFromGlobal(g.x, g.y);
        stageLocal = { x: Math.round(p.x), y: Math.round(p.y), w: Math.max(10, g.width), h: Math.max(10, g.height) };
    }

    // The stage's current global rectangle (whatever the mode).
    function currentStageGlobal() {
        if (external && stageGeo)
            return { x: stageGeo.x, y: stageGeo.y, width: stageGeo.width, height: stageGeo.height };
        if (widgetHolder) {
            var p = widgetHolder.mapToGlobal(0, 0);
            if (widgetHolder.width > 40 && widgetHolder.height > 20)
                return { x: Math.round(p.x), y: Math.round(p.y), width: Math.round(widgetHolder.width), height: Math.round(widgetHolder.height) };
        }
        return defaultFree(!!styleInfo.round, Screen.virtualX, Screen.virtualY, Screen.width, Screen.height);
    }

    function commitFree(g) {
        cfg.freeX = Math.round(g.x - Screen.virtualX);
        cfg.freeY = Math.round(g.y - Screen.virtualY);
        cfg.freeW = Math.round(g.width);
        cfg.freeH = Math.round(g.height);
    }

    // Shortcut / button: start free positioning, or lock / unlock it.
    function toggleLock() {
        if (!canPlace || !desk) {
            root.showNotice(i18n("Free positioning only works while the widget sits on the desktop."));
            return;
        }
        if (cfg.placement !== "free") {
            var g = currentStageGlobal();
            if (!styleInfo.round && placement !== "widget")
                cfg.freeEdge = stageEdge;
            commitFree(g);
            cfg.placement = "free";
            unlocked = true;
            return;
        }
        unlocked = !unlocked;
        if (!unlocked && freeLive) {
            commitFree(freeLive);
            freeLive = null;
        }
    }

    // Right click on the visualizer: the pop-up card (default) or a menu.
    function stageRightClicked(item, x, y) {
        if (!desk)
            return;
        var p = item.mapToItem(desk, x, y);
        if (cfg.showMiniCard) {
            var cw = Kirigami.Units.gridUnit * 21, ch = Kirigami.Units.gridUnit * 3.6;
            var px = Math.max(8, Math.min(desk.width - cw - 8, p.x - cw / 2));
            var py = p.y - ch - 14;
            if (py < 8)
                py = Math.min(desk.height - ch - 8, p.y + 14);
            popupPos = Qt.point(px, py);
            popupOpen = true;
        } else {
            stageMenu.popup(desk, p.x, p.y);
        }
    }

    function configureWidget() {
        try {
            var a = Plasmoid.internalAction("configure");
            if (a)
                a.trigger();
        } catch (e) {
            openEditor();
        }
    }

    function centerFree() {
        var g = stageGeo || currentStageGlobal();
        commitFree({ x: Screen.virtualX + (Screen.width - g.width) / 2, y: Screen.virtualY + (Screen.height - g.height) / 2,
                     width: g.width, height: g.height });
    }

    function resetFree() {
        cfg.freeW = -1;
        cfg.freeH = -1;
        cfg.freeX = -1;
        cfg.freeY = -1;
    }

    // Keep the widget small while the visualizer floats; give it its size back afterwards.
    function syncContainer() {
        var c = findContainer();
        if (!c)
            return;
        var padW = c.width - root.width, padH = c.height - root.height;
        if (external) {
            var mw = Kirigami.Units.gridUnit * 2.5, mh = Kirigami.Units.gridUnit * 2.5;
            if (root.width > mw * 1.5 || root.height > mh * 1.5) {
                if (!cfg.widgetSize)
                    cfg.widgetSize = Math.round(root.width) + "," + Math.round(root.height);
                c.width = mw + padW;
                c.height = mh + padH;
            }
        } else if (cfg.widgetSize) {
            var a = String(cfg.widgetSize).split(",").map(Number);
            if (a.length === 2 && a[0] > 20 && a[1] > 20) {
                c.width = a[0] + padW;
                c.height = a[1] + padH;
            }
            cfg.widgetSize = "";
        }
    }

    Timer {
        id: containerTimer
        interval: 300
        onTriggered: root.syncContainer()
    }

    Timer {
        id: placeTimer   // the container only exists once the widget has been put on the desktop
        interval: 400
        onTriggered: {
            var c = root.findContainer();
            root.canPlace = c !== null;
            root.container = c;
            root.desk = c ? c.parent : null;
            root.syncWatcher();
            root.syncStage();
            containerTimer.restart();
            if (!root.cfg.shortcutInit) {
                try {
                    if (String(Plasmoid.globalShortcut).replace(/QVariant\(QKeySequence,\s*|\)$/g, "").trim() === "")
                        Plasmoid.globalShortcut = "Meta+Alt+V";
                } catch (e) {
                    console.warn("SeaQ SoundWave: could not set the default shortcut: " + e);
                }
                root.cfg.shortcutInit = true;
            }
        }
    }

    // Plasma may re-lay out the desktop (screen change, ...): put the stage back.
    Timer {
        interval: 3000
        repeat: true
        running: root.external
        onTriggered: root.syncStage()
    }

    // ---- live window tracking (see WindowWatcher.qml) ---------------------

    function syncWatcher() {
        if (cfg.placement === "panel" && canPlace) {
            if (windowWatcher)
                return;
            var comp = Qt.createComponent(Qt.resolvedUrl("WindowWatcher.qml"));
            if (comp.status !== Component.Ready) {
                console.warn("SeaQ SoundWave: window tracking unavailable: " + comp.errorString());
                return;
            }
            var w = comp.createObject(root);
            if (!w)
                return;
            w.rectsChanged.connect(function () { root.windows = w.rects; });
            root.windows = w.rects;
            windowWatcher = w;
        } else if (windowWatcher) {
            windowWatcher.destroy();
            windowWatcher = null;
            windows = [];
        }
    }

    function pollPanels() {
        var xhr = new XMLHttpRequest();
        xhr.timeout = 1500;
        xhr.onreadystatechange = function () {
            if (xhr.readyState !== XMLHttpRequest.DONE || xhr.status !== 200)
                return;
            panelsLoaded = true;
            if (xhr.responseText === panelsJson)
                return;
            try {
                panels = JSON.parse(xhr.responseText);
                panelsJson = xhr.responseText;
            } catch (e) {}
        };
        xhr.open("GET", "http://127.0.0.1:" + port + "/panels");
        xhr.setRequestHeader("X-SeaQ-Token", root.authToken);
        xhr.send();
    }

    Timer {
        interval: root.panelsLoaded ? 5000 : 1000
        repeat: true
        running: root.daemonRunning && (root.cfg.placement === "panel" || root.cfg.placement === "screen")
        triggeredOnStart: true
        onTriggered: root.pollPanels()
    }

    // ---- media control ------------------------------------------------------

    function applyMedia(text) {
        try {
            var m = JSON.parse(text);
            mediaStatus = String(m.status || "None");
            mediaPlayer = String(m.player || "");
            mediaArt = String(m.art || "");
        } catch (e) {}
    }

    function pollMedia() {
        var xhr = new XMLHttpRequest();
        xhr.timeout = 3000;
        xhr.onreadystatechange = function () {
            if (xhr.readyState === XMLHttpRequest.DONE && xhr.status === 200)
                root.applyMedia(xhr.responseText);
        };
        xhr.open("GET", "http://127.0.0.1:" + port + "/media");
        xhr.setRequestHeader("X-SeaQ-Token", root.authToken);
        xhr.send();
    }

    // Pauses whatever plays (audio and video) or resumes it.
    function mediaToggle() {
        if (mediaBusy)
            return;
        mediaBusy = true;
        mediaStatus = mediaPlaying ? "Paused" : "Playing";   // instant feedback
        var xhr = new XMLHttpRequest();
        xhr.timeout = 5000;
        xhr.onreadystatechange = function () {
            if (xhr.readyState !== XMLHttpRequest.DONE)
                return;
            root.mediaBusy = false;
            if (xhr.status === 200)
                root.applyMedia(xhr.responseText);
        };
        xhr.open("GET", "http://127.0.0.1:" + port + "/playpause");
        xhr.setRequestHeader("X-SeaQ-Token", root.authToken);
        xhr.send();
    }

    function orbClicked() {
        if (cfg.orbAction === "none" || unlocked)
            return;
        mediaToggle();
    }

    Timer {
        interval: 1500
        repeat: true
        triggeredOnStart: true
        running: root.daemonRunning && (root.orbVisible || root.editorOpen || root.popupOpen)
        onTriggered: root.pollMedia()
    }

    // ---- audio protection ---------------------------------------------------
    // The helper looks for apps whose sound is muted or at 0 % (playing now or
    // remembered by WirePlumber) and can repair them.

    property var audioIssue: []
    property string audioIssueKey: ""
    property bool audioFixing: false
    property string notifiedApps: ""

    function ignoreApps(list) {
        var ignored = String(cfg.audioGuardIgnore || "").split("\n").filter(function (x) { return x !== ""; });
        String(list).split(", ").forEach(function (a) {
            if (a !== "" && ignored.indexOf(a) < 0)
                ignored.push(a);
        });
        cfg.audioGuardIgnore = ignored.join("\n");
        audioIssue = audioIssue.filter(function (a) { return ignored.indexOf(a) < 0; });
    }

    function applyAudioCheck(text) {
        var r;
        try {
            r = JSON.parse(text);
        } catch (e) {
            return;
        }
        var ignored = String(cfg.audioGuardIgnore || "").split("\n").filter(function (x) { return x !== ""; });
        audioIssue = (r.apps || []).filter(function (a) { return ignored.indexOf(a) < 0; });
        var key = audioIssue.join(", ");
        if (key === "") {
            audioIssueKey = "";
            return;
        }
        if (key === audioIssueKey)
            return;   // already reported
        audioIssueKey = key;
        if (cfg.audioGuard === "auto")
            fixAudio(false);      // automatic: only playing streams, never restarts WirePlumber
        else if (cfg.audioGuard === "notify")
            notifyAudioIssue(key);
    }

    function checkAudio() {
        var xhr = new XMLHttpRequest();
        xhr.timeout = 6000;
        xhr.onreadystatechange = function () {
            if (xhr.readyState === XMLHttpRequest.DONE && xhr.status === 200)
                root.applyAudioCheck(xhr.responseText);
        };
        xhr.open("GET", "http://127.0.0.1:" + port + "/audiocheck");
        xhr.setRequestHeader("X-SeaQ-Token", root.authToken);
        xhr.send();
    }

    // deep = also clean WirePlumber's memory (short restart of the audio
    // service) - only when the user asked for it.
    function fixAudio(deep) {
        if (audioFixing)
            return;
        audioFixing = true;
        var xhr = new XMLHttpRequest();
        xhr.timeout = 20000;
        xhr.onreadystatechange = function () {
            if (xhr.readyState !== XMLHttpRequest.DONE)
                return;
            root.audioFixing = false;
            root.audioIssueKey = "";
            if (xhr.status === 200)
                root.applyAudioCheck(xhr.responseText);
        };
        xhr.open("GET", "http://127.0.0.1:" + port + "/audiofix" + (deep === false ? "" : "?deep=1"));
        xhr.setRequestHeader("X-SeaQ-Token", root.authToken);
        xhr.send();
    }

    // A normal KDE notification with a "Repair" button (notify-send --wait
    // prints the chosen action when the user clicks it).
    function notifyAudioIssue(apps) {
        root.notifiedApps = apps;
        var cmd = "notify-send -a " + shellQuote("SeaQ SoundWave") + " -i audio-volume-muted"
            + " --action=fix=" + shellQuote(i18n("Repair"))
            + " --action=ignore=" + shellQuote(i18n("Don't report again")) + " --wait "
            + shellQuote(i18n("Sound of %1 is muted", apps)) + " "
            + shellQuote(i18n("The system remembered this app as muted or at 0 %. Click “Repair” to give it its sound back."))
            + " ; true # " + Date.now();
        notifier.connectSource(cmd);
    }

    P5Support.DataSource {
        id: notifier
        engine: "executable"
        connectedSources: []
        onNewData: (sourceName, data) => {
            notifier.disconnectSource(sourceName);
            var choice = String(data["stdout"] || "").trim();
            if (choice === "fix")
                root.fixAudio(true);
            else if (choice === "ignore")
                root.ignoreApps(root.notifiedApps);
        }
    }

    Timer {
        interval: 30000
        repeat: true
        triggeredOnStart: true
        running: root.daemonRunning && root.cfg.audioGuard !== "off"
        onTriggered: root.checkAudio()
    }

    // ---- settings editor ----------------------------------------------------

    function openEditor(page) {
        if (!editorWin) {
            var comp = Qt.createComponent(Qt.resolvedUrl("editor/SettingsEditor.qml"));
            if (comp.status !== Component.Ready) {
                console.warn("SeaQ SoundWave: settings editor failed to load: " + comp.errorString());
                root.showNotice(i18n("The settings editor could not be loaded."));
                return;
            }
            editorWin = comp.createObject(root, { app: root });
            if (!editorWin)
                return;
        }
        if (typeof page === "number")
            editorWin.page = page;
        editorWin.show();
        editorWin.raise();
        editorWin.requestActivate();
    }

    function setShortcut(seq, text) {
        try {
            Plasmoid.globalShortcut = seq;
        } catch (e) {
            console.warn("SeaQ SoundWave: " + e);
        }
        if (text !== undefined)
            cfg.shortcutText = text;
    }

    Connections {
        target: Plasmoid
        function onActivated() { root.toggleLock(); }
    }

    Plasmoid.contextualActions: [
        PlasmaCore.Action {
            text: i18n("Open settings editor…")
            icon.name: "configure"
            onTriggered: root.openEditor()
        },
        PlasmaCore.Action {
            text: root.unlocked ? i18n("Lock position") : i18n("Move freely")
            icon.name: root.unlocked ? "object-locked" : "transform-move"
            enabled: root.canPlace
            onTriggered: root.toggleLock()
        },
        PlasmaCore.Action {
            text: root.mediaPlaying ? i18n("Pause playback") : i18n("Resume playback")
            icon.name: root.mediaPlaying ? "media-playback-pause" : "media-playback-start"
            onTriggered: root.mediaToggle()
        }
    ]

    // ---- helper process (audio engine) ------------------------------------

    function shellQuote(s) {
        return "'" + String(s).replace(/'/g, "'\\''") + "'";
    }

    function buildCommand() {
        var script = decodeURIComponent(
            Qt.resolvedUrl("../scripts/audio-server.py").toString().replace(/^file:\/\//, ""));
        token++;
        // "exec env" so the token never stays visible in a process's command line
        return "exec env SEAQ_TOKEN=" + shellQuote(authToken) + " python3 " + shellQuote(script)
            + " --port " + port
            + " --bars " + cfg.barCount
            + " --sensitivity " + cfg.sensitivity
            + " --framerate " + cfg.framerate
            + " --engine " + shellQuote(cfg.engine || "auto")
            + " --method " + shellQuote(cfg.inputMethod)
            + " --source " + shellQuote(cfg.inputSource || "auto")
            + " --taskbar-icon " + (cfg.taskbarIcon ? "1" : "0")
            + " --token " + token;
    }

    function startDaemon() {
        if (cavaMissing)
            return;
        errorText = "";
        startedAt = Date.now();
        currentSource = buildCommand();
        executable.connectSource(currentSource);
        daemonRunning = true;
    }

    function restartDaemon() {
        currentSource = "";
        failStreak = 0;
        barValues = [];
        startDaemon();
    }

    function daemonExited(source, exitCode, stderr) {
        executable.disconnectSource(source);
        if (source !== currentSource)
            return;

        daemonRunning = false;
        barValues = [];

        if (exitCode === 5 && portShift < 40) {
            portShift++;          // another program owns the port: take the next one
            startDaemon();
            return;
        }

        if (exitCode === 2) {
            cavaMissing = true;
            errorText = i18n("No audio capture tool found.\nPlease install “pulseaudio-utils” or “pipewire-utils” (or “cava”) and add the widget again.");
            return;
        }

        failStreak = (Date.now() - startedAt < 4000) ? failStreak + 1 : 0;
        if (failStreak >= 5) {
            errorText = i18n("The audio engine could not be started.") + (stderr ? "\n" + String(stderr).trim() : "");
            return;
        }
        retryTimer.start();
    }

    P5Support.DataSource {
        id: executable
        engine: "executable"
        connectedSources: []
        onNewData: (sourceName, data) => root.daemonExited(sourceName, data["exit code"], data["stderr"])
    }

    Timer {
        id: retryTimer
        interval: 1500
        onTriggered: root.startDaemon()
    }

    Timer {
        id: restartDebounce
        interval: 500
        onTriggered: root.restartDaemon()
    }

    Connections {
        target: Plasmoid.configuration
        function onBarCountChanged() { restartDebounce.restart(); }
        function onSensitivityChanged() { restartDebounce.restart(); }
        function onFramerateChanged() { restartDebounce.restart(); }
        function onEngineChanged() { restartDebounce.restart(); }
        function onInputMethodChanged() { restartDebounce.restart(); }
        function onInputSourceChanged() { restartDebounce.restart(); }
        function onPlacementChanged() { root.syncWatcher(); }
        function onTaskbarIconChanged() {
            var xhr = new XMLHttpRequest();
            xhr.open("GET", "http://127.0.0.1:" + root.port + "/taskbaricon?on=" + (root.cfg.taskbarIcon ? "1" : "0"));
            xhr.setRequestHeader("X-SeaQ-Token", root.authToken);
            xhr.send();
        }
        function onEditorRequestChanged() {
            if (String(root.cfg.editorRequest) !== "")
                root.openEditor();
        }
    }

    // ---- polling frames ---------------------------------------------------

    // Silence: after 1.5 s without sound the helper is asked only 10 times a
    // second (instead of up to 60) - the first sound brings the full rate back
    // within 0.1 s. While music plays nothing changes.
    property bool silent: false
    property double lastSound: 0

    function parseFrame(text) {
        if (!text)
            return;
        var parts = text.split(";");
        var out = [];
        for (var i = 0; i < parts.length; i++) {
            if (parts[i] === "")
                continue;
            var v = parseInt(parts[i], 10);
            if (isNaN(v))
                v = 0;
            out.push(Math.max(0, Math.min(255, v)) / 255);
        }
        if (out.length === 0)
            return;
        var loud = false;
        for (var k = 0; k < out.length; k++)
            if (out[k] > 0.004) { loud = true; break; }
        if (loud)
            lastSound = Date.now();
        silent = !loud && Date.now() - lastSound > 1500;
        barValues = out;
    }

    function poll() {
        if (polling)
            return;
        polling = true;
        var xhr = new XMLHttpRequest();
        xhr.timeout = 1500;
        xhr.onreadystatechange = function () {
            if (xhr.readyState !== XMLHttpRequest.DONE)
                return;
            polling = false;
            if (xhr.status === 200)
                parseFrame(xhr.responseText);
        };
        xhr.open("GET", "http://127.0.0.1:" + port + "/frame");
        xhr.setRequestHeader("X-SeaQ-Token", root.authToken);
        xhr.send();
    }

    Timer {
        interval: root.silent ? 100 : Math.max(7, Math.round(1000 / Math.max(15, root.cfg.framerate)))
        repeat: true
        running: root.daemonRunning
        onTriggered: root.poll()
    }

    Component.onCompleted: {
        startDaemon();
        placeTimer.start();
    }

    Component.onDestruction: {
        if (windowWatcher)
            windowWatcher.destroy();
        if (editorWin)
            editorWin.destroy();
        stage.visible = false;
        currentSource = "";
        try {
            var xhr = new XMLHttpRequest();
            xhr.open("GET", "http://127.0.0.1:" + port + "/quit");
            xhr.setRequestHeader("X-SeaQ-Token", root.authToken);
            xhr.send();
        } catch (e) {}
    }

    // ---- the stage ------------------------------------------------------------

    Item {
        id: stage
        parent: root.external && root.desk ? root.desk : (root.widgetHolder ? root.widgetHolder : root)
        x: root.external ? root.stageLocal.x : 0
        y: root.external ? root.stageLocal.y : 0
        width: root.external ? root.stageLocal.w : (parent ? parent.width : 0)
        height: root.external ? root.stageLocal.h : (parent ? parent.height : 0)
        // behind other desktop widgets, on top while it is being moved
        z: root.unlocked ? 10000 : (root.external ? -1 : 0)
        visible: root.errorText === "" && (!root.external || root.stageGeo !== null)

        // Drawn as a horizontal strip growing upwards from its bottom edge;
        // turned so that its base points to the panel / chosen side.
        Item {
            id: rotor
            anchors.centerIn: parent
            width: root.stageVertical ? parent.height : parent.width
            height: root.stageVertical ? parent.width : parent.height
            rotation: root.stageEdge === "left" ? 90 : (root.stageEdge === "right" ? -90 : 0)
            transform: Scale {
                origin.x: rotor.width / 2
                origin.y: rotor.height / 2
                yScale: root.stageEdge === "top" ? -1 : 1
            }

            // Backing plate. Styles that stand on the bottom edge keep square
            // corners there, so the visualizer sits flush; all others are
            // rounded on every corner.
            Rectangle {
                id: plate
                anchors.fill: parent
                visible: root.cfg.backgroundEnabled
                color: root.cfg.backgroundColor
                readonly property real r: Math.min(root.cfg.backgroundRadius, width / 2, height / 2)
                topLeftRadius: r
                topRightRadius: r
                bottomLeftRadius: root.styleInfo.anchored ? 0 : r
                bottomRightRadius: root.styleInfo.anchored ? 0 : r
            }

            Visualizer {
                id: viz
                anchors.fill: parent
                // keep the drawing inside the rounded corners of the plate
                anchors.topMargin: plate.visible ? plate.r * 0.45 : 0
                anchors.leftMargin: plate.visible && !root.styleInfo.anchored ? plate.r * 0.45 : 0
                anchors.rightMargin: plate.visible && !root.styleInfo.anchored ? plate.r * 0.45 : 0
                anchors.bottomMargin: plate.visible && !root.styleInfo.anchored ? plate.r * 0.45 : 0
                values: root.barValues
                style: root.cfg.vizStyle
                optionsJson: root.cfg.styleOptions
                paletteStops: root.cfg.palette
                colorMapping: root.cfg.colorMapping
                gradientAngle: root.cfg.gradientAngle
                colorShift: root.cfg.colorShift
                colorShiftSpeed: root.cfg.colorShiftSpeed
                opacityLevel: root.cfg.opacity / 100
                smoothing: root.cfg.smoothing / 100
                fps: root.cfg.framerate
                softBase: root.cfg.attachSoftBase
                softLeft: root.stageEdge === "right" ? root.softEndPx : root.softStartPx
                softRight: root.stageEdge === "right" ? root.softStartPx : root.softEndPx
                mediaPlaying: root.mediaPlaying
                mediaSpinning: root.mediaStatus === "Playing" || (root.mediaStatus === "None" && !root.silent)
                mediaArt: root.mediaArt
                idle: root.silent
                orbHover: orbHit.visible && orbHit.inside
                orbInteractive: root.cfg.orbAction !== "none" && !root.unlocked
                iconRotation: -rotor.rotation
                onOrbClicked: root.orbClicked()
            }
        }

        // right click on the visualizer -> pop-up card or menu
        MouseArea {
            anchors.fill: parent
            z: -1
            acceptedButtons: Qt.RightButton
            // inside the widget without the pop-up, Plasma's own widget menu stays in charge
            enabled: root.desk !== null && (root.external || root.cfg.showMiniCard) && !root.containerEditing
            onPressed: (m) => root.stageRightClicked(this, m.x, m.y)
        }

        // ---- free positioning: move / resize -----------------------------
        Item {
            id: editFrame
            anchors.fill: parent
            visible: root.unlocked && root.placement === "free"
            focus: visible
            onVisibleChanged: if (visible) forceActiveFocus()

            property var startGeo: null
            property point startPos
            property bool resizing: false

            function geo() {
                var g = root.stageGeo;
                return { x: g.x, y: g.y, width: g.width, height: g.height };
            }
            // snaps the centre to the screen's centre lines, keeps it on screen
            function settle(g) {
                var sx = Screen.virtualX, sy = Screen.virtualY, sw = Screen.width, sh = Screen.height;
                var cx = g.x + g.width / 2, cy = g.y + g.height / 2;
                if (Math.abs(cx - (sx + sw / 2)) < 10)
                    g.x = sx + (sw - g.width) / 2;
                if (Math.abs(cy - (sy + sh / 2)) < 10)
                    g.y = sy + (sh - g.height) / 2;
                g.x = Math.round(Math.max(sx - g.width + 40, Math.min(sx + sw - 40, g.x)));
                g.y = Math.round(Math.max(sy, Math.min(sy + sh - 40, g.y)));
                g.width = Math.round(g.width);
                g.height = Math.round(g.height);
                return g;
            }
            function nudge(dx, dy) {
                var g = geo();
                g.x += dx;
                g.y += dy;
                root.commitFree(settle(g));
            }
            function scaleBy(f) {
                var g = geo();
                var nw = Math.max(80, Math.min(Screen.width * 1.5, g.width * f));
                var nh = Math.max(40, Math.min(Screen.height * 1.5, g.height * f));
                if (root.styleInfo.round)
                    nh = nw;
                g.x -= (nw - g.width) / 2;
                g.y -= (nh - g.height) / 2;
                g.width = nw;
                g.height = nh;
                root.commitFree(settle(g));
            }

            Keys.onPressed: (event) => {
                var step = (event.modifiers & Qt.ShiftModifier) ? 10 : 1;
                if (event.key === Qt.Key_Left) editFrame.nudge(-step, 0);
                else if (event.key === Qt.Key_Right) editFrame.nudge(step, 0);
                else if (event.key === Qt.Key_Up) editFrame.nudge(0, -step);
                else if (event.key === Qt.Key_Down) editFrame.nudge(0, step);
                else if (event.key === Qt.Key_Plus || event.key === Qt.Key_Equal) editFrame.scaleBy(1.05);
                else if (event.key === Qt.Key_Minus) editFrame.scaleBy(1 / 1.05);
                else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_Escape) root.toggleLock();
                else return;
                event.accepted = true;
            }

            Rectangle {
                anchors.fill: parent
                radius: 14
                color: Qt.rgba(0.04, 0.52, 1, 0.08)
                border.width: 2
                border.color: Qt.rgba(0.04, 0.52, 1, 0.9)
            }

            MouseArea {
                id: moveArea
                anchors.fill: parent
                cursorShape: pressed ? Qt.ClosedHandCursor : Qt.OpenHandCursor
                hoverEnabled: true
                onPressed: (m) => {
                    editFrame.forceActiveFocus();
                    editFrame.startGeo = editFrame.geo();
                    editFrame.startPos = mapToGlobal(m.x, m.y);
                }
                onPositionChanged: (m) => {
                    if (!pressed || !editFrame.startGeo)
                        return;
                    var p = mapToGlobal(m.x, m.y);
                    var s = editFrame.startGeo;
                    root.freeLive = editFrame.settle({ x: s.x + p.x - editFrame.startPos.x, y: s.y + p.y - editFrame.startPos.y,
                                                       width: s.width, height: s.height });
                }
                onReleased: {
                    if (root.freeLive)
                        root.commitFree(root.freeLive);
                    root.freeLive = null;
                    editFrame.startGeo = null;
                }
                onDoubleClicked: root.toggleLock()
                onWheel: (w) => editFrame.scaleBy(w.angleDelta.y > 0 ? 1.06 : 1 / 1.06)
            }

            // Resize handles on all four corners and all four edges.
            // dx/dy: which side moves (-1 = left/top, 1 = right/bottom, 0 = none)
            Repeater {
                model: [
                    { dx: -1, dy: -1, c: Qt.SizeFDiagCursor }, { dx: 0, dy: -1, c: Qt.SizeVerCursor },
                    { dx: 1, dy: -1, c: Qt.SizeBDiagCursor },  { dx: 1, dy: 0, c: Qt.SizeHorCursor },
                    { dx: 1, dy: 1, c: Qt.SizeFDiagCursor },   { dx: 0, dy: 1, c: Qt.SizeVerCursor },
                    { dx: -1, dy: 1, c: Qt.SizeBDiagCursor },  { dx: -1, dy: 0, c: Qt.SizeHorCursor }
                ]
                delegate: Item {
                    id: handle
                    required property var modelData
                    readonly property bool corner: modelData.dx !== 0 && modelData.dy !== 0
                    width: modelData.dx === 0 ? editFrame.width - 40 : 24
                    height: modelData.dy === 0 ? editFrame.height - 40 : 24
                    x: modelData.dx < 0 ? -12 : (modelData.dx > 0 ? editFrame.width - 12 : 20)
                    y: modelData.dy < 0 ? -12 : (modelData.dy > 0 ? editFrame.height - 12 : 20)
                    z: corner ? 3 : 2

                    // visible knob: round on corners, a short pill in the middle of each edge
                    Rectangle {
                        anchors.centerIn: parent
                        width: handle.corner ? 16 : (handle.modelData.dx === 0 ? 34 : 8)
                        height: handle.corner ? 16 : (handle.modelData.dy === 0 ? 34 : 8)
                        radius: Math.min(width, height) / 2
                        color: "#0a84ff"
                        border.color: "white"
                        border.width: 2
                        scale: hMa.containsMouse || hMa.pressed ? 1.2 : 1
                        Behavior on scale { NumberAnimation { duration: 90 } }
                    }

                    MouseArea {
                        id: hMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: handle.modelData.c
                        onPressed: (m) => {
                            editFrame.forceActiveFocus();
                            editFrame.startGeo = editFrame.geo();
                            editFrame.startPos = mapToGlobal(m.x, m.y);
                        }
                        onPositionChanged: (m) => {
                            if (!pressed || !editFrame.startGeo)
                                return;
                            var p = mapToGlobal(m.x, m.y);
                            var s = editFrame.startGeo, d = handle.modelData;
                            var ddx = p.x - editFrame.startPos.x, ddy = p.y - editFrame.startPos.y;
                            var x = s.x, y = s.y, w = s.width, h = s.height;
                            if (d.dx > 0) w = s.width + ddx;
                            if (d.dx < 0) w = s.width - ddx;
                            if (d.dy > 0) h = s.height + ddy;
                            if (d.dy < 0) h = s.height - ddy;
                            w = Math.max(80, w);
                            h = Math.max(40, h);
                            if (root.styleInfo.round) {
                                // round styles stay square
                                var q = d.dx === 0 ? h : (d.dy === 0 ? w : Math.max(w, h));
                                w = h = q;
                            }
                            if (d.dx < 0) x = s.x + s.width - w;
                            if (d.dy < 0) y = s.y + s.height - h;
                            if (root.styleInfo.round && d.dx === 0) x = s.x + (s.width - w) / 2;
                            if (root.styleInfo.round && d.dy === 0) y = s.y + (s.height - h) / 2;
                            root.freeLive = { x: Math.round(x), y: Math.round(y), width: Math.round(w), height: Math.round(h) };
                        }
                        onReleased: {
                            if (root.freeLive)
                                root.commitFree(root.freeLive);
                            root.freeLive = null;
                            editFrame.startGeo = null;
                        }
                    }
                }
            }

            // hint
            Rectangle {
                id: hint
                anchors.horizontalCenter: parent.horizontalCenter
                y: root.stageGeo && root.stageGeo.y - Screen.virtualY > height + 16 ? -height - 10 : 10
                width: Math.min(hintRow.implicitWidth + 28, Math.max(260, parent.width + 200))
                height: hintRow.implicitHeight + 16
                radius: height / 2
                color: Qt.rgba(0.08, 0.08, 0.09, 0.92)
                border.color: Qt.rgba(1, 1, 1, 0.14)
                Row {
                    id: hintRow
                    anchors.centerIn: parent
                    spacing: 12
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        color: "white"
                        font.pixelSize: 12
                        text: i18n("Drag = move · Edges and corners = resize · Wheel = zoom · Arrow keys = 1 px (⇧ 10 px)")
                    }
                    Rectangle {
                        anchors.verticalCenter: parent.verticalCenter
                        width: lockText.implicitWidth + 22
                        height: 24
                        radius: 12
                        color: lockMa.pressed ? "#0062cc" : "#0a84ff"
                        Text {
                            id: lockText
                            anchors.centerIn: parent
                            color: "white"
                            font.pixelSize: 12
                            font.weight: Font.DemiBold
                            text: i18n("Lock (%1 / Enter)", root.shortcutText)
                        }
                        MouseArea {
                            id: lockMa
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.toggleLock()
                        }
                    }
                }
            }
        }
    }

    // ---- orb click target ------------------------------------------------------
    // On the desktop the visualizer lies behind the desktop icons, so the
    // icon layer would catch clicks on the orb. This invisible, round click
    // target sits exactly over the orb, above everything else.

    function syncOrbHit() {
        if (!root.desk || !root.external)
            return;
        var p = viz.mapToItem(root.desk, viz.orbGeo.x, viz.orbGeo.y);
        orbHit.cx = p.x;
        orbHit.cy = p.y;
    }

    MouseArea {
        id: orbHit
        parent: root.desk ? root.desk : root
        property real cx: 0
        property real cy: 0
        width: Math.max(16, viz.orbGeo.r * 2)
        height: width
        x: cx - width / 2
        y: cy - height / 2
        z: 15000
        visible: root.external && stage.visible && viz.orbClickable && !root.unlocked
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton
        cursorShape: inside ? Qt.PointingHandCursor : Qt.ArrowCursor
        property bool inside: false
        function within(m) {
            var dx = m.x - width / 2, dy = m.y - height / 2;
            return dx * dx + dy * dy <= width * width / 4;
        }
        onPositionChanged: (m) => inside = within(m)
        onExited: inside = false
        onPressed: (m) => { m.accepted = within(m); }
        onClicked: root.orbClicked()
    }

    Connections {
        target: viz
        function onOrbGeoChanged() { root.syncOrbHit(); }
        function onWidthChanged() { root.syncOrbHit(); }
        function onHeightChanged() { root.syncOrbHit(); }
    }
    onStageLocalChanged: syncOrbHit()
    Timer {
        interval: 1000
        repeat: true
        running: root.external
        onTriggered: root.syncOrbHit()
    }

    // ---- pop-up card -------------------------------------------------------------

    Item {
        id: popupLayer
        parent: root.desk ? root.desk : root
        anchors.fill: parent
        z: 20000
        visible: root.popupOpen && root.desk !== null

        // a click on any empty spot closes the card again
        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.AllButtons
            onPressed: root.popupOpen = false
            onWheel: root.popupOpen = false
        }

        ControlCard {
            id: popupCard
            x: root.popupPos.x
            y: root.popupPos.y
            width: Kirigami.Units.gridUnit * 21
            height: Kirigami.Units.gridUnit * 3.6
            host: root
            opacity: root.popupOpen ? 1 : 0
            scale: root.popupOpen ? 1 : 0.94
            Behavior on opacity { NumberAnimation { duration: 140 } }
            Behavior on scale { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }
            MouseArea {
                anchors.fill: parent
                z: -1
                acceptedButtons: Qt.AllButtons   // clicks on the card itself don't close it
            }
        }
        Keys.onEscapePressed: root.popupOpen = false
        onVisibleChanged: if (visible) forceActiveFocus()
    }

    QQC2.Menu {
        id: stageMenu
        parent: root.desk ? root.desk : root
        QQC2.MenuItem {
            text: i18n("Open settings editor…")
            icon.name: "configure"
            onTriggered: root.openEditor()
        }
        QQC2.MenuItem {
            text: root.unlocked ? i18n("Lock position") : i18n("Move freely")
            icon.name: root.unlocked ? "object-locked" : "transform-move"
            onTriggered: root.toggleLock()
        }
        QQC2.MenuItem {
            text: root.mediaPlaying ? i18n("Pause playback") : i18n("Resume playback")
            icon.name: root.mediaPlaying ? "media-playback-pause" : "media-playback-start"
            onTriggered: root.mediaToggle()
        }
        QQC2.MenuSeparator {}
        QQC2.MenuItem {
            text: i18n("Configure SeaQ SoundWave…")
            icon.name: "settings-configure"
            onTriggered: root.configureWidget()
        }
    }

    // ---- UI ---------------------------------------------------------------------

    fullRepresentation: Item {
        id: full
        Layout.minimumWidth: Kirigami.Units.gridUnit * 2
        Layout.minimumHeight: Kirigami.Units.gridUnit * 2
        Layout.preferredWidth: root.external ? Kirigami.Units.gridUnit * 2.5 : Kirigami.Units.gridUnit * 30
        Layout.preferredHeight: root.external ? Kirigami.Units.gridUnit * 2.5 : Kirigami.Units.gridUnit * 7

        Component.onCompleted: root.widgetHolder = full
        Component.onDestruction: if (root.widgetHolder === full) root.widgetHolder = null

        // While the visualizer floats the widget itself is invisible; in
        // the desktop's edit mode a small handle shows where it is.
        Rectangle {
            anchors.centerIn: parent
            width: Math.min(parent.width, parent.height)
            height: width
            radius: width / 2
            visible: root.external && root.containerEditing
            color: Qt.rgba(0, 0, 0, 0.55)
            border.color: Qt.rgba(1, 1, 1, 0.3)
            Kirigami.Icon {
                anchors.centerIn: parent
                width: parent.width * 0.6
                height: width
                source: "view-media-equalizer"
                color: "white"
            }
        }

        PlasmaComponents3.Label {
            anchors.centerIn: parent
            width: parent.width - Kirigami.Units.largeSpacing * 2
            visible: root.errorText !== ""
            text: root.errorText
            wrapMode: Text.WordWrap
            horizontalAlignment: Text.AlignHCenter
            elide: Text.ElideRight
        }

        // short notices ("only on the desktop", ...)
        Rectangle {
            anchors.centerIn: parent
            width: Math.min(parent.width, flashText.implicitWidth + 24)
            height: flashText.implicitHeight + 14
            radius: 10
            color: Qt.rgba(0, 0, 0, 0.8)
            opacity: root.notice !== "" ? 1 : 0
            visible: opacity > 0
            z: 50
            Behavior on opacity { NumberAnimation { duration: 200 } }
            PlasmaComponents3.Label {
                id: flashText
                anchors.centerIn: parent
                width: Math.min(implicitWidth, full.width - 24)
                wrapMode: Text.WordWrap
                color: "white"
                text: root.notice
            }
        }
    }
}
