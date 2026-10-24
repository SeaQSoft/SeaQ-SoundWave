import QtQuick

// The sphere the effects come out of. Clicking it pauses / resumes
// whatever is playing (audio and video, via MPRIS).
Item {
    id: orb

    property real radius: 20
    property string orbStyle: "dark"
    property color accent: "#32d74b"
    property color accent2: "#ffd60a"
    property real level: 0          // bass energy 0..1
    property bool pulse: true
    property bool playing: true
    property bool interactive: true
    property string iconMode: "always"   // always | hover | never
    property bool staticIcon: false      // show the symbol even when not clickable (previews)
    property bool externalHover: false   // hover reported by a click target on top (desktop)
    readonly property bool hovered: (mouse.containsMouse && mouse.inside) || externalHover
    // record style ("vinyl")
    readonly property bool vinyl: orbStyle === "vinyl"
    property bool spin: true             // the record turns while music plays
    property bool spinning: playing      // something is really playing right now
    property bool arm: true              // tone arm that swings onto the record
    property string art: ""              // cover of the current track for the label
    property real turnOverride: -1       // recordings: fixed record angle
    property real armOverride: NaN       // recordings: fixed tone arm angle
    signal clicked()

    width: radius * 2
    height: radius * 2
    scale: pulse ? 1 + Math.min(1, level) * 0.08 : 1
    Behavior on scale { NumberAnimation { duration: 80 } }

    onAccentChanged: body.requestPaint()
    onAccent2Changed: body.requestPaint()
    onOrbStyleChanged: body.requestPaint()
    onRadiusChanged: { body.requestPaint(); glyph.requestPaint(); }
    onPlayingChanged: glyph.requestPaint()
    onIconModeChanged: glyph.requestPaint()
    onArtChanged: {
        if (art !== "")
            disc.loadImage(art);
        disc.requestPaint();
    }

    function mix(c, k, a) {
        // mix colour c towards black (k<0) or white (k>0)
        var t = k >= 0 ? 1 : 0, m = Math.abs(k);
        return "rgba(" + Math.round((c.r + (t - c.r) * m) * 255) + "," + Math.round((c.g + (t - c.g) * m) * 255) + ","
            + Math.round((c.b + (t - c.b) * m) * 255) + "," + (a === undefined ? 1 : a) + ")";
    }

    Canvas {
        id: body
        anchors.fill: parent
        onPaint: {
            var ctx = getContext("2d");
            var r = Math.min(width, height) / 2;
            ctx.reset();
            if (r < 2 || orb.vinyl)
                return;
            var cx = width / 2, cy = height / 2;
            var g;
            if (orb.orbStyle === "glass") {
                g = ctx.createRadialGradient(cx - r * 0.3, cy - r * 0.35, r * 0.1, cx, cy, r);
                g.addColorStop(0, "rgba(255,255,255,0.42)");
                g.addColorStop(0.45, orb.mix(orb.accent, 0.4, 0.22));
                g.addColorStop(1, orb.mix(orb.accent, -0.2, 0.38));
                ctx.fillStyle = g;
                ctx.beginPath(); ctx.arc(cx, cy, r - 0.5, 0, Math.PI * 2); ctx.fill();
                ctx.strokeStyle = "rgba(255,255,255,0.55)";
                ctx.lineWidth = 1;
                ctx.stroke();
                // highlight
                var hg = ctx.createLinearGradient(0, cy - r, 0, cy);
                hg.addColorStop(0, "rgba(255,255,255,0.5)");
                hg.addColorStop(1, "rgba(255,255,255,0)");
                ctx.fillStyle = hg;
                ctx.beginPath();
                ctx.ellipse(cx - r * 0.62, cy - r * 0.9, r * 1.24, r * 0.8);
                ctx.fill();
            } else if (orb.orbStyle === "neon") {
                ctx.fillStyle = "#0b0a0f";
                ctx.beginPath(); ctx.arc(cx, cy, r * 0.84, 0, Math.PI * 2); ctx.fill();
                for (var i = 3; i >= 1; i--) {
                    ctx.beginPath();
                    ctx.arc(cx, cy, r * 0.84, 0, Math.PI * 2);
                    ctx.strokeStyle = orb.mix(orb.accent, 0.1, i === 1 ? 1 : 0.18 / i);
                    ctx.lineWidth = i === 1 ? 2 : r * 0.12 * i;
                    ctx.stroke();
                }
            } else {
                g = ctx.createRadialGradient(cx, cy, 0, cx, cy, r);
                g.addColorStop(0, "#130e0d");
                g.addColorStop(0.5, orb.mix(orb.accent, -0.86));
                g.addColorStop(0.86, orb.mix(orb.accent, -0.55));
                g.addColorStop(1, orb.mix(orb.accent, -0.3));
                ctx.fillStyle = g;
                ctx.beginPath(); ctx.arc(cx, cy, r - 0.8, 0, Math.PI * 2); ctx.fill();
                ctx.strokeStyle = orb.mix(orb.accent2, 0, 0.95);
                ctx.lineWidth = Math.max(1, r * 0.018);
                ctx.stroke();
            }
        }
    }

    // ---- record ("vinyl") -------------------------------------------------
    // The disc (grooves + label with the cover) turns; the light reflections
    // stay still on top, like on a real turntable.
    Canvas {
        id: disc
        anchors.fill: parent
        visible: orb.vinyl
        antialiasing: true
        property real turn: 0
        rotation: orb.turnOverride >= 0 ? orb.turnOverride : turn
        onImageLoaded: requestPaint()
        Component.onCompleted: if (orb.art !== "") loadImage(orb.art)
        onVisibleChanged: if (visible) requestPaint()
        onWidthChanged: requestPaint()
        onPaint: {
            var ctx = getContext("2d");
            ctx.reset();
            var r = Math.min(width, height) / 2;
            if (r < 2)
                return;
            var cx = width / 2, cy = height / 2;
            // vinyl body
            var g = ctx.createRadialGradient(cx, cy, r * 0.3, cx, cy, r);
            g.addColorStop(0, "#1d1a19");
            g.addColorStop(0.7, "#141211");
            g.addColorStop(1, "#0b0a0a");
            ctx.fillStyle = g;
            ctx.beginPath(); ctx.arc(cx, cy, r - 0.5, 0, Math.PI * 2); ctx.fill();
            // grooves
            var n = Math.max(4, Math.min(28, Math.round(r / 4)));
            for (var i = 0; i < n; i++) {
                var rr = r * (0.42 + 0.54 * i / Math.max(1, n - 1));
                ctx.beginPath();
                ctx.arc(cx, cy, rr, 0, Math.PI * 2);
                ctx.lineWidth = Math.max(0.5, r * 0.006);
                ctx.strokeStyle = i % 5 === 4 ? orb.mix(orb.accent, 0.1, 0.28) : "rgba(255,255,255,0.08)";
                ctx.stroke();
            }
            // rim
            ctx.beginPath(); ctx.arc(cx, cy, r - 0.8, 0, Math.PI * 2);
            ctx.lineWidth = Math.max(1, r * 0.02);
            ctx.strokeStyle = "rgba(255,255,255,0.12)";
            ctx.stroke();
            // label: the cover if there is one, otherwise the accent colours
            var lr = r * 0.4;
            ctx.save();
            ctx.beginPath(); ctx.arc(cx, cy, lr, 0, Math.PI * 2); ctx.clip();
            if (orb.art !== "" && isImageLoaded(orb.art)) {
                ctx.drawImage(orb.art, cx - lr, cy - lr, lr * 2, lr * 2);
            } else {
                var lg = ctx.createLinearGradient(cx - lr, cy - lr, cx + lr, cy + lr);
                lg.addColorStop(0, orb.mix(orb.accent2, 0.1));
                lg.addColorStop(1, orb.mix(orb.accent, -0.15));
                ctx.fillStyle = lg;
                ctx.fillRect(cx - lr, cy - lr, lr * 2, lr * 2);
                // a little print on the label so the turning is visible
                ctx.fillStyle = "rgba(255,255,255,0.55)";
                ctx.fillRect(cx - lr * 0.55, cy - lr * 0.5, lr * 1.1, Math.max(1, lr * 0.09));
                ctx.fillRect(cx - lr * 0.35, cy - lr * 0.32, lr * 0.7, Math.max(1, lr * 0.07));
            }
            ctx.restore();
            ctx.beginPath(); ctx.arc(cx, cy, lr, 0, Math.PI * 2);
            ctx.lineWidth = Math.max(1, r * 0.02);
            ctx.strokeStyle = orb.mix(orb.accent, 0.2, 0.9);
            ctx.stroke();
            // spindle hole
            ctx.beginPath(); ctx.arc(cx, cy, Math.max(1, r * 0.035), 0, Math.PI * 2);
            ctx.fillStyle = "#d8d8d8";
            ctx.fill();
        }
        NumberAnimation on turn {
            from: 0; to: 360
            duration: 1800                 // 33 rpm
            loops: Animation.Infinite
            running: orb.vinyl && orb.spin && orb.visible
            paused: running && !orb.spinning  // stop where it is, no jump back
        }
    }

    // still reflections on top of the turning disc
    Canvas {
        id: sheen
        anchors.fill: parent
        visible: orb.vinyl
        onVisibleChanged: if (visible) requestPaint()
        onWidthChanged: requestPaint()
        onPaint: {
            var ctx = getContext("2d");
            ctx.reset();
            var r = Math.min(width, height) / 2;
            if (r < 2)
                return;
            var cx = width / 2, cy = height / 2;
            ctx.save();
            ctx.beginPath(); ctx.arc(cx, cy, r - 1, 0, Math.PI * 2);
            ctx.arc(cx, cy, r * 0.41, 0, Math.PI * 2, true);
            ctx.clip();
            ctx.globalCompositeOperation = "lighter";
            for (var k = 0; k < 2; k++) {
                var a0 = -Math.PI * 0.62 + k * Math.PI;
                ctx.beginPath();
                ctx.moveTo(cx, cy);
                ctx.arc(cx, cy, r, a0, a0 + Math.PI * 0.24);
                ctx.closePath();
                var sg = ctx.createRadialGradient(cx, cy, r * 0.41, cx, cy, r);
                sg.addColorStop(0, "rgba(255,255,255,0)");
                sg.addColorStop(0.55, "rgba(255,235,210," + (k ? 0.07 : 0.11) + ")");
                sg.addColorStop(1, "rgba(255,255,255,0.02)");
                ctx.fillStyle = sg;
                ctx.fill();
            }
            ctx.restore();
        }
    }

    // tone arm: on the record while playing, swung out while paused
    Item {
        id: toneArm
        visible: orb.vinyl && orb.arm && orb.radius >= 10
        x: orb.radius + orb.radius * 1.2
        y: orb.radius - orb.radius * 1.12
        width: 0
        height: 0
        property real angle: orb.playing ? 0 : -24
        Behavior on angle { NumberAnimation { duration: 600; easing.type: Easing.InOutQuad } }
        transform: Rotation { origin.x: 0; origin.y: 0; angle: isNaN(orb.armOverride) ? toneArm.angle : orb.armOverride }
        Canvas {
            id: armPaint
            readonly property real r: orb.radius
            x: -r * 0.6
            y: -r * 0.3
            width: r * 1.0
            height: r * 1.7
            onRChanged: requestPaint()
            onVisibleChanged: if (visible) requestPaint()
            onPaint: {
                var ctx = getContext("2d");
                ctx.reset();
                var r = armPaint.r;
                var px = r * 0.6, py = r * 0.3;          // pivot inside this canvas
                var hx = px - r * 0.44, hy = py + r * 1.24;  // headshell
                // shadow
                ctx.lineCap = "round";
                ctx.strokeStyle = "rgba(0,0,0,0.35)";
                ctx.lineWidth = Math.max(2, r * 0.07);
                ctx.beginPath(); ctx.moveTo(px + 2, py + 3); ctx.lineTo(hx + 2, hy + 3); ctx.stroke();
                // arm tube
                var tg = ctx.createLinearGradient(px - 3, 0, px + 3, 0);
                tg.addColorStop(0, "#9a9a9e");
                tg.addColorStop(0.5, "#f2f2f4");
                tg.addColorStop(1, "#8a8a8e");
                ctx.strokeStyle = tg;
                ctx.lineWidth = Math.max(1.5, r * 0.05);
                ctx.beginPath(); ctx.moveTo(px, py); ctx.lineTo(hx, hy); ctx.stroke();
                // headshell
                var ang = Math.atan2(hy - py, hx - px);
                ctx.save();
                ctx.translate(hx, hy);
                ctx.rotate(ang - Math.PI / 2);
                ctx.fillStyle = "#c9c9cd";
                var hw = Math.max(3, r * 0.12), hl = Math.max(4, r * 0.17);
                ctx.fillRect(-hw / 2, -hl * 0.2, hw, hl);
                ctx.fillStyle = "#6e6e72";
                ctx.fillRect(-hw / 2, hl * 0.62, hw, hl * 0.18);
                ctx.restore();
                // pivot knob
                var kr = Math.max(3, r * 0.13);
                var kg = ctx.createRadialGradient(px - kr * 0.35, py - kr * 0.35, kr * 0.1, px, py, kr);
                kg.addColorStop(0, "#ffffff");
                kg.addColorStop(0.6, "#c4c4c8");
                kg.addColorStop(1, "#7c7c80");
                ctx.fillStyle = kg;
                ctx.beginPath(); ctx.arc(px, py, kr, 0, Math.PI * 2); ctx.fill();
                ctx.fillStyle = "#5a5a5e";
                ctx.beginPath(); ctx.arc(px, py, kr * 0.32, 0, Math.PI * 2); ctx.fill();
            }
        }
    }

    // Play / pause symbol on a dark round backdrop, so it stands out on any
    // orb colour. "always": always visible, "hover": only under the mouse
    // (and while paused), "never": hidden.
    Canvas {
        id: glyph
        anchors.fill: parent
        opacity: (!orb.interactive && !orb.staticIcon) || orb.iconMode === "never" ? 0
               : (orb.hovered ? 1 : (orb.iconMode === "always" ? 0.92 : (orb.playing ? 0 : 0.85)))
        Behavior on opacity { NumberAnimation { duration: 160 } }
        visible: orb.radius >= 7 && opacity > 0
        property bool hot: orb.hovered
        property bool rec: orb.vinyl
        onRecChanged: requestPaint()
        onHotChanged: requestPaint()
        onPaint: {
            var ctx = getContext("2d");
            ctx.reset();
            var r = Math.min(width, height) / 2;
            var cx = width / 2, cy = height / 2;
            var br = orb.vinyl ? Math.max(6, Math.min(r * 0.17, 18))   // small, the cover stays visible
                               : Math.max(7, Math.min(r * 0.62, 34));    // backdrop radius
            // backdrop
            ctx.beginPath();
            ctx.arc(cx, cy, br, 0, Math.PI * 2);
            ctx.fillStyle = glyph.hot ? "rgba(0,0,0,0.62)" : (orb.vinyl ? "rgba(0,0,0,0.38)" : "rgba(0,0,0,0.48)");
            ctx.fill();
            ctx.lineWidth = Math.max(1, br * 0.06);
            ctx.strokeStyle = "rgba(255,255,255,0.35)";
            ctx.stroke();
            // symbol
            var s = br * 0.5;
            ctx.fillStyle = "rgba(255,255,255,0.97)";
            ctx.beginPath();
            if (orb.playing) {
                var bw = s * 0.42, gap = s * 0.38, rr = bw * 0.3;
                ctx.roundedRect(cx - gap / 2 - bw, cy - s * 0.9, bw, s * 1.8, rr, rr);
                ctx.roundedRect(cx + gap / 2, cy - s * 0.9, bw, s * 1.8, rr, rr);
            } else {
                ctx.moveTo(cx - s * 0.55, cy - s * 0.92);
                ctx.lineTo(cx + s * 0.95, cy);
                ctx.lineTo(cx - s * 0.55, cy + s * 0.92);
                ctx.closePath();
            }
            ctx.fill();
        }
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        enabled: orb.interactive
        hoverEnabled: true
        property bool inside: false
        cursorShape: inside ? Qt.PointingHandCursor : Qt.ArrowCursor
        function within(m) {
            var dx = m.x - width / 2, dy = m.y - height / 2;
            return dx * dx + dy * dy <= (width / 2) * (width / 2);
        }
        onPositionChanged: (m) => inside = within(m)
        onExited: inside = false
        onPressed: (m) => { m.accepted = within(m); }
        onClicked: orb.clicked()
    }
}
