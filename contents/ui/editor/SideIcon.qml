import QtQuick

// Rounded, coloured icon tile like in macOS System Settings.
Rectangle {
    id: ic
    property string kind: "wave"
    property color tint: "#0a84ff"
    property real size: 24
    width: size
    height: size
    radius: size * 0.26
    gradient: Gradient {
        GradientStop { position: 0; color: Qt.lighter(ic.tint, 1.18) }
        GradientStop { position: 1; color: ic.tint }
    }
    onKindChanged: cv.requestPaint()
    Canvas {
        id: cv
        anchors.fill: parent
        anchors.margins: ic.size * 0.18
        onPaint: {
            var c = getContext("2d");
            c.reset();
            var w = width, h = height;
            c.strokeStyle = "white"; c.fillStyle = "white";
            c.lineWidth = Math.max(1.4, w / 9); c.lineCap = "round"; c.lineJoin = "round";
            var k = ic.kind;
            c.beginPath();
            if (k === "wave") {
                for (var i = 0; i <= 20; i++) {
                    var x = i / 20 * w, y = h / 2 + Math.sin(i / 20 * Math.PI * 3) * h * 0.32 * Math.sin(i / 20 * Math.PI);
                    if (i === 0) c.moveTo(x, y); else c.lineTo(x, y);
                }
                c.stroke();
            } else if (k === "grid") {
                var s = w * 0.42;
                c.rect(0, 0, s, s); c.rect(w - s, 0, s, s); c.rect(0, h - s, s, s); c.rect(w - s, h - s, s, s);
                c.lineWidth = Math.max(1.2, w / 11); c.stroke();
            } else if (k === "sliders") {
                for (var j = 0; j < 3; j++) {
                    var yy = h * (0.18 + j * 0.32);
                    c.moveTo(0, yy); c.lineTo(w, yy);
                }
                c.stroke();
                [0.7, 0.3, 0.55].forEach(function (f, n) {
                    c.beginPath(); c.arc(w * f, h * (0.18 + n * 0.32), w * 0.13, 0, Math.PI * 2); c.fill();
                });
            } else if (k === "palette") {
                c.arc(w / 2, h / 2, w * 0.46, 0, Math.PI * 2); c.stroke();
                [[0.32, 0.34], [0.62, 0.3], [0.72, 0.58], [0.38, 0.66]].forEach(function (p) {
                    c.beginPath(); c.arc(w * p[0], h * p[1], w * 0.09, 0, Math.PI * 2); c.fill();
                });
            } else if (k === "place") {
                c.rect(w * 0.04, h * 0.12, w * 0.92, h * 0.64); c.stroke();
                c.beginPath(); c.moveTo(w * 0.3, h * 0.94); c.lineTo(w * 0.7, h * 0.94); c.stroke();
                c.beginPath(); c.rect(w * 0.22, h * 0.48, w * 0.56, h * 0.14); c.fill();
            } else if (k === "orb") {
                c.arc(w / 2, h / 2, w * 0.46, 0, Math.PI * 2); c.stroke();
                c.beginPath(); c.moveTo(w * 0.4, h * 0.3); c.lineTo(w * 0.72, h * 0.5); c.lineTo(w * 0.4, h * 0.7); c.closePath(); c.fill();
            } else if (k === "audio") {
                c.moveTo(w * 0.05, h * 0.36); c.lineTo(w * 0.25, h * 0.36); c.lineTo(w * 0.5, h * 0.12);
                c.lineTo(w * 0.5, h * 0.88); c.lineTo(w * 0.25, h * 0.64); c.lineTo(w * 0.05, h * 0.64); c.closePath(); c.fill();
                c.beginPath(); c.arc(w * 0.5, h / 2, w * 0.28, -0.8, 0.8); c.stroke();
                c.beginPath(); c.arc(w * 0.5, h / 2, w * 0.46, -0.85, 0.85); c.stroke();
            } else if (k === "info") {
                c.arc(w / 2, h * 0.16, w * 0.1, 0, Math.PI * 2); c.fill();
                c.beginPath(); c.moveTo(w / 2, h * 0.4); c.lineTo(w / 2, h * 0.92); c.lineWidth = w / 6; c.stroke();
            } else if (k === "light") {
                for (var r = 0; r < 5; r++) {
                    c.moveTo(0, h * (0.1 + r * 0.2)); c.quadraticCurveTo(w * 0.35, h / 2, w / 2, h / 2);
                    c.moveTo(w, h * (0.1 + r * 0.2)); c.quadraticCurveTo(w * 0.65, h / 2, w / 2, h / 2);
                }
                c.lineWidth = Math.max(1, w / 14); c.stroke();
            }
        }
    }
}
