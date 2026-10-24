import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Dialogs
import "../js/palette.js" as Pal
import ".." as SW

// Gradient builder (picture 12): colour stops on a bar, colour / position,
// rotation and gradient type on the left, a large preview on the right.
Item {
    id: ge

    property var cfg
    property var liveValues: []
    property string styleId: "macos-wave"

    property var stops: []
    property int sel: 0
    property bool previewViz: false
    property bool naming: false
    property bool internalWrite: false

    readonly property var selStop: stops.length ? stops[Math.min(sel, stops.length - 1)] : ({ c: "#ffffff", p: 0 })

    implicitHeight: 372
    width: parent ? parent.width : 700
    height: implicitHeight

    function load() {
        var json = cfg.palette && String(cfg.palette).length > 2 ? cfg.palette : Pal.DEFAULT_STOPS;
        stops = Pal.parse(json);
        sel = Math.min(sel, stops.length - 1);
        repaint();
    }

    function repaint() { bar.requestPaint(); prev.requestPaint(); }

    function commit() {
        internalWrite = true;
        cfg.palette = Pal.serialize(stops);
        cfg.paletteName = "";
        internalWrite = false;
        repaint();
    }

    function setStop(i, c, p) {
        var s = stops.slice();
        s[i] = { c: c !== undefined ? c : s[i].c, p: p !== undefined ? Math.max(0, Math.min(1, p)) : s[i].p };
        stops = s;
        repaint();
        commitTimer.restart();
    }

    function addStop(p) {
        var pal = Pal.make(stops);
        var s = stops.slice();
        s.push({ c: pal.hex(p), p: p });
        stops = s;
        sel = s.length - 1;
        commit();
    }

    function removeStop() {
        if (stops.length <= 2)
            return;
        var s = stops.slice();
        s.splice(sel, 1);
        stops = s;
        sel = Math.max(0, sel - 1);
        commit();
    }

    function colorToHex(c) {
        return Pal.rgbToHex([c.r * 255, c.g * 255, c.b * 255]);
    }

    function copyText(t) {
        clip.text = t;
        clip.selectAll();
        clip.copy();
        toast.show(i18n("Copied to the clipboard"));
    }

    function savePalette(name) {
        var list = [];
        try { list = JSON.parse(cfg.customPalettes || "[]"); } catch (e) { list = []; }
        name = String(name || "").trim() || i18n("My palette %1", list.length + 1);
        list.push({ name: name, stops: Pal.parse(stops) });
        cfg.customPalettes = JSON.stringify(list);
        cfg.paletteName = "custom:" + name;
        naming = false;
        toast.show(i18n("“%1” saved", name));
    }

    Component.onCompleted: load()
    Connections {
        target: ge.cfg
        function onPaletteChanged() { if (!ge.internalWrite) ge.load(); }
        function onColorMappingChanged() { prev.requestPaint(); }
        function onGradientAngleChanged() { prev.requestPaint(); }
    }
    Timer { id: commitTimer; interval: 60; onTriggered: ge.commit() }

    TextEdit { id: clip; visible: false }

    ColorDialog {
        id: dlg
        title: i18n("Choose a colour")
        onAccepted: ge.setStop(ge.sel, ge.colorToHex(selectedColor))
    }

    // ---------------- left: controls ----------------
    Rectangle {
        id: panel
        width: Math.min(420, parent.width * 0.48)
        height: parent.height
        radius: 14
        color: editor.c.card
        border.color: editor.c.cardBorder

        Column {
            anchors.fill: parent
            anchors.margins: 22
            spacing: 14

            // colour stop bar
            Item {
                id: barArea
                width: parent.width
                height: 34
                readonly property real pad: 15
                readonly property real span: width - pad * 2

                Canvas {
                    id: bar
                    x: barArea.pad - 6
                    width: barArea.span + 12
                    height: 12
                    anchors.verticalCenter: parent.verticalCenter
                    onPaint: {
                        var c = getContext("2d");
                        c.reset();
                        var g = c.createLinearGradient(6, 0, width - 6, 0);
                        for (var i = 0; i < ge.stops.length; i++)
                            g.addColorStop(ge.stops[i].p, ge.stops[i].c);
                        c.fillStyle = g;
                        var r = height / 2;
                        c.beginPath();
                        c.moveTo(r, 0); c.lineTo(width - r, 0); c.arc(width - r, r, r, -Math.PI / 2, Math.PI / 2);
                        c.lineTo(r, height); c.arc(r, r, r, Math.PI / 2, Math.PI * 1.5); c.closePath();
                        c.fill();
                    }
                }
                MouseArea {
                    anchors.fill: bar
                    anchors.margins: -6
                    cursorShape: Qt.CrossCursor
                    onClicked: (m) => ge.addStop(Math.max(0, Math.min(1, (m.x - 6 - 6) / barArea.span)))
                }
                Repeater {
                    model: ge.stops.length
                    delegate: Rectangle {
                        id: handle
                        required property int index
                        readonly property var stop: ge.stops[index] || ({ c: "#fff", p: 0 })
                        readonly property bool isSel: ge.sel === index
                        width: isSel ? 30 : 26
                        height: width
                        radius: width / 2
                        x: barArea.pad + stop.p * barArea.span - width / 2
                        anchors.verticalCenter: parent.verticalCenter
                        color: "white"
                        border.color: isSel ? editor.c.accent : Qt.rgba(0, 0, 0, 0.15)
                        border.width: isSel ? 2 : 1
                        z: isSel ? 3 : 2
                        Rectangle {
                            anchors.centerIn: parent
                            width: parent.width - 12
                            height: width
                            radius: width / 2
                            color: handle.stop.c
                        }
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.SizeHorCursor
                            preventStealing: true
                            onPressed: ge.sel = handle.index
                            onPositionChanged: (m) => {
                                if (!pressed)
                                    return;
                                var p = mapToItem(barArea, m.x, m.y);
                                ge.setStop(handle.index, undefined, (p.x - barArea.pad) / barArea.span);
                            }
                            onDoubleClicked: { dlg.selectedColor = handle.stop.c; dlg.open(); }
                        }
                    }
                }
            }

            // Colour | Position
            Row {
                width: parent.width
                spacing: 14
                readonly property real colW: (width - spacing) / 2
                Column {
                    width: parent.colW
                    spacing: 6
                    Item {
                        width: parent.width; height: 16
                        Text { text: i18n("Colour"); color: editor.c.text; font.pixelSize: 12; font.weight: Font.DemiBold }
                        Text {
                            anchors.right: parent.right
                            text: i18n("Remove")
                            color: ge.stops.length > 2 ? editor.c.accent : editor.c.sub
                            font.pixelSize: 12
                            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: ge.removeStop() }
                        }
                    }
                    Rectangle {
                        width: parent.width; height: 34; radius: 8
                        color: editor.c.field
                        border.color: hexIn.activeFocus ? editor.c.accent : editor.c.border
                        border.width: hexIn.activeFocus ? 2 : 1
                        TextInput {
                            id: hexIn
                            anchors.left: parent.left; anchors.leftMargin: 12
                            anchors.right: sw.left; anchors.rightMargin: 6
                            anchors.verticalCenter: parent.verticalCenter
                            text: String(ge.selStop.c).toUpperCase()
                            color: editor.c.text
                            font.pixelSize: 13
                            selectByMouse: true
                            maximumLength: 7
                            onEditingFinished: {
                                var t = text.trim();
                                if (t.charAt(0) !== "#") t = "#" + t;
                                if (/^#[0-9a-fA-F]{6}$/.test(t))
                                    ge.setStop(ge.sel, t.toLowerCase());
                                text = Qt.binding(function () { return String(ge.selStop.c).toUpperCase(); });
                            }
                        }
                        Rectangle {
                            id: sw
                            anchors.right: parent.right; anchors.rightMargin: 6
                            anchors.verticalCenter: parent.verticalCenter
                            width: 24; height: 24; radius: 6
                            color: ge.selStop.c
                            border.color: Qt.rgba(0, 0, 0, 0.15)
                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: { dlg.selectedColor = ge.selStop.c; dlg.open(); }
                            }
                        }
                    }
                }
                Column {
                    width: parent.colW
                    spacing: 6
                    Text { text: i18n("Position"); color: editor.c.text; font.pixelSize: 12; font.weight: Font.DemiBold; height: 16 }
                    EdSpin {
                        width: parent.width
                        from: 0; to: 100; step: 1; suffix: "%"
                        value: Math.round(ge.selStop.p * 100)
                        onChanged: (v) => ge.setStop(ge.sel, undefined, v / 100)
                    }
                }
            }

            // quick swatches
            Row {
                spacing: 6
                Repeater {
                    model: ["#ff453a", "#ff9f0a", "#ffd60a", "#32d74b", "#64d2ff", "#0a84ff", "#5e5ce6", "#bf5af2", "#ff375f", "#ffffff", "#8e8e93"]
                    delegate: Rectangle {
                        required property string modelData
                        width: 22; height: 22; radius: 11
                        color: modelData
                        border.color: Qt.rgba(0, 0, 0, 0.18)
                        scale: qm.containsMouse ? 1.15 : 1
                        Behavior on scale { NumberAnimation { duration: 90 } }
                        MouseArea { id: qm; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: ge.setStop(ge.sel, parent.modelData) }
                    }
                }
            }

            // Rotation | Type
            Row {
                width: parent.width
                spacing: 14
                Column {
                    width: 110
                    spacing: 6
                    Text { text: i18n("Rotation"); color: editor.c.text; font.pixelSize: 12; font.weight: Font.DemiBold; height: 16 }
                    EdSpin {
                        width: parent.width
                        from: 0; to: 359; step: 5; suffix: "°"; wrap: true
                        value: ge.cfg.gradientAngle
                        onChanged: (v) => ge.cfg.gradientAngle = Math.round(v)
                    }
                }
                Column {
                    width: parent.width - 110 - parent.spacing
                    spacing: 6
                    Text { text: i18n("Type"); color: editor.c.text; font.pixelSize: 12; font.weight: Font.DemiBold; height: 16 }
                    EdSegmented {
                        width: parent.width
                        height: 34
                        model: [["auto", "Auto"], ["linear", "Linear"], ["radial", "Radial"], ["conic", "Conic"]]
                        current: ge.cfg.colorMapping
                        onPicked: (v) => ge.cfg.colorMapping = v
                    }
                }
            }
            Text {
                width: parent.width
                wrapMode: Text.WordWrap
                color: editor.c.sub
                font.pixelSize: 11
                text: ge.cfg.colorMapping === "auto"
                      ? i18n("Auto: every visualizer lays out the colours itself (e.g. per line, all around or from bottom to top).")
                      : i18n("The gradient covers the whole visualizer – rotation and type apply as set above.")
            }

            // buttons
            Row {
                width: parent.width
                spacing: 10
                visible: !ge.naming
                EdButton {
                    width: (parent.width - parent.spacing) / 2
                    height: 40
                    text: i18n("Random")
                    onClicked: { ge.stops = Pal.randomStops(); ge.sel = 0; ge.commit(); }
                }
                Rectangle {
                    width: (parent.width - parent.spacing) / 2
                    height: 40
                    radius: 8
                    color: editor.c.accent
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        x: (parent.width - 34 - width) / 2
                        text: i18n("Save")
                        color: "white"; font.pixelSize: 13; font.weight: Font.DemiBold
                    }
                    MouseArea {
                        width: parent.width - 34; height: parent.height
                        cursorShape: Qt.PointingHandCursor
                        onClicked: { ge.naming = true; nameField.text = ""; nameField.forceInputFocus(); }
                    }
                    Rectangle { x: parent.width - 34; width: 1; height: parent.height; color: Qt.rgba(1, 1, 1, 0.35) }
                    Text {
                        x: parent.width - 34; width: 34; height: parent.height
                        horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter
                        text: "▾"; color: "white"; font.pixelSize: 14
                        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: menu.open() }
                    }
                    QQC2.Popup {
                        id: menu
                        y: parent.height + 6
                        x: parent.width - width
                        width: 230
                        padding: 6
                        background: Rectangle { radius: 10; color: editor.c.menu; border.color: editor.c.border }
                        contentItem: Column {
                            Repeater {
                                model: [["css", "Copy CSS"], ["hex", "Copy hex values"], ["rev", "Reverse colours"], ["even", "Spread evenly"]]
                                delegate: Rectangle {
                                    required property var modelData
                                    width: 218; height: 30; radius: 6
                                    color: mm.containsMouse ? editor.c.accent : "transparent"
                                    Text {
                                        anchors.verticalCenter: parent.verticalCenter
                                        x: 10
                                        text: parent.modelData[1]
                                        color: mm.containsMouse ? "white" : editor.c.text
                                        font.pixelSize: 13
                                    }
                                    MouseArea {
                                        id: mm
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        onClicked: {
                                            var k = parent.modelData[0];
                                            menu.close();
                                            if (k === "css")
                                                ge.copyText("background: " + Pal.cssGradient(Pal.parse(ge.stops), ge.cfg.colorMapping === "auto" ? "linear" : ge.cfg.colorMapping, ge.cfg.gradientAngle) + ";");
                                            else if (k === "hex")
                                                ge.copyText(Pal.parse(ge.stops).map(function (s) { return s.c.toUpperCase(); }).join(", "));
                                            else if (k === "rev") {
                                                ge.stops = ge.stops.map(function (s) { return { c: s.c, p: 1 - s.p }; });
                                                ge.commit();
                                            } else if (k === "even") {
                                                var st = Pal.parse(ge.stops);
                                                ge.stops = st.map(function (s, i) { return { c: s.c, p: st.length > 1 ? i / (st.length - 1) : 0 }; });
                                                ge.commit();
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
            Row {
                width: parent.width
                spacing: 8
                visible: ge.naming
                EdField {
                    id: nameField
                    width: parent.width - 2 * 92 - 2 * parent.spacing
                    height: 40
                    placeholder: i18n("Name of the palette")
                    function forceInputFocus() { children[0].forceActiveFocus(); }
                    onAccepted: (t) => ge.savePalette(t)
                }
                EdButton { width: 92; height: 40; text: i18n("Save"); primary: true; onClicked: ge.savePalette(nameField.text) }
                EdButton { width: 92; height: 40; text: i18n("Cancel"); onClicked: ge.naming = false }
            }
        }
    }

    // ---------------- right: preview ----------------
    Rectangle {
        id: prevFrame
        anchors.left: panel.right
        anchors.leftMargin: 18
        anchors.right: parent.right
        height: parent.height
        radius: 14
        color: "#14100f"
        border.color: editor.c.cardBorder
        clip: true

        Canvas {
            id: prev
            anchors.fill: parent
            visible: !ge.previewViz
            onPaint: {
                var c = getContext("2d");
                c.reset();
                var w = width, h = height, g;
                var type = ge.cfg.colorMapping === "auto" ? "linear" : ge.cfg.colorMapping;
                var ang = ge.cfg.gradientAngle * Math.PI / 180;
                if (type === "radial")
                    g = c.createRadialGradient(w / 2, h / 2, 0, w / 2, h / 2, Math.max(w, h) / 2);
                else if (type === "conic")
                    g = c.createConicalGradient(w / 2, h / 2, ang);
                else {
                    var dx = Math.sin(ang), dy = -Math.cos(ang);
                    var len = Math.abs(w * dx) + Math.abs(h * dy);
                    g = c.createLinearGradient(w / 2 - dx * len / 2, h / 2 - dy * len / 2, w / 2 + dx * len / 2, h / 2 + dy * len / 2);
                }
                for (var i = 0; i < ge.stops.length; i++)
                    g.addColorStop(ge.stops[i].p, ge.stops[i].c);
                c.fillStyle = g;
                c.fillRect(0, 0, w, h);
            }
        }

        SW.Visualizer {
            anchors.fill: parent
            anchors.margins: 14
            visible: ge.previewViz
            running: visible
            values: ge.liveValues
            demo: !ge.liveValues || ge.liveValues.length === 0
            style: ge.styleId
            optionsJson: ge.cfg.styleOptions
            paletteStops: ge.stops
            colorMapping: ge.cfg.colorMapping
            gradientAngle: ge.cfg.gradientAngle
            colorShift: ge.cfg.colorShift
            colorShiftSpeed: ge.cfg.colorShiftSpeed
            orbInteractive: false
        }

        Rectangle {
            anchors.top: parent.top
            anchors.right: parent.right
            anchors.margins: 12
            width: 30; height: 30; radius: 8
            color: em.containsMouse ? Qt.rgba(1, 1, 1, 0.32) : Qt.rgba(1, 1, 1, 0.2)
            Canvas {
                anchors.fill: parent
                anchors.margins: 8
                property bool viz: ge.previewViz
                onVizChanged: requestPaint()
                onPaint: {
                    var c = getContext("2d");
                    c.reset();
                    c.strokeStyle = "white"; c.lineWidth = 1.8; c.lineCap = "round";
                    var w = width, h = height;
                    c.beginPath();
                    if (!viz) {
                        c.moveTo(w * 0.6, 0); c.lineTo(w, 0); c.lineTo(w, h * 0.4);
                        c.moveTo(w, 0); c.lineTo(w * 0.6, h * 0.4);
                        c.moveTo(w * 0.4, h); c.lineTo(0, h); c.lineTo(0, h * 0.6);
                        c.moveTo(0, h); c.lineTo(w * 0.4, h * 0.6);
                    } else {
                        c.moveTo(0, h * 0.5);
                        for (var i = 1; i <= 8; i++) c.lineTo(i / 8 * w, h * 0.5 + Math.sin(i * 1.4) * h * 0.4);
                    }
                    c.stroke();
                }
            }
            MouseArea { id: em; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: ge.previewViz = !ge.previewViz }
        }
        Text {
            anchors.left: parent.left
            anchors.bottom: parent.bottom
            anchors.margins: 12
            text: ge.previewViz ? i18n("Preview with the current visualizer") : i18n("Gradient")
            color: "white"
            opacity: 0.75
            font.pixelSize: 11
        }
    }

    Rectangle {
        id: toast
        property string msg: ""
        function show(m) { msg = m; opacity = 1; toastTimer.restart(); }
        anchors.horizontalCenter: prevFrame.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 16
        width: tt.implicitWidth + 24; height: 30; radius: 15
        color: Qt.rgba(0, 0, 0, 0.75)
        opacity: 0
        Behavior on opacity { NumberAnimation { duration: 180 } }
        Text { id: tt; anchors.centerIn: parent; text: toast.msg; color: "white"; font.pixelSize: 12 }
        Timer { id: toastTimer; interval: 1800; onTriggered: toast.opacity = 0 }
    }
}
