import QtQuick
import "../js/styles.js" as Styles

Column {
    id: pg
    spacing: 26

    readonly property string mode: editor.cfg.placement || "widget"
    readonly property bool round: !!editor.info.round
    readonly property var app: editor.app

    // ---- small illustration of a screen for the placement cards -------------
    component PlacementCard: Rectangle {
        id: pc
        property string mode
        property string title
        property string desc
        readonly property bool sel: pg.mode === mode
        width: (parent.width - 3 * 14) / 4
        height: 196
        radius: 12
        color: editor.c.card
        border.width: sel ? 2.5 : 1
        border.color: sel ? editor.c.accent : editor.c.cardBorder
        scale: pcMa.pressed ? 0.98 : 1
        Behavior on scale { NumberAnimation { duration: 100 } }

        Canvas {
            id: art
            x: 12
            y: 12
            width: parent.width - 24
            height: 96
            property bool dark: editor.dark
            property bool active: pc.sel
            onDarkChanged: requestPaint()
            onActiveChanged: requestPaint()
            onPaint: {
                var c = getContext("2d");
                c.reset();
                var w = width, h = height;
                // monitor
                c.fillStyle = "#1a1530";
                var g = c.createLinearGradient(0, 0, w, h);
                g.addColorStop(0, "#2b2350");
                g.addColorStop(1, "#5a2b4a");
                c.fillStyle = g;
                c.beginPath();
                c.roundedRect(0, 0, w, h, 8, 8);
                c.fill();
                // panel
                c.fillStyle = "rgba(255,255,255,0.22)";
                c.beginPath();
                c.roundedRect(w * 0.18, h - 13, w * 0.64, 8, 4, 4);
                c.fill();
                var acc = "#0a84ff";
                function bars(x, y, bw, bh) {
                    var n = 9;
                    for (var i = 0; i < n; i++) {
                        var f = i / (n - 1);
                        var hh = bh * (0.35 + 0.65 * Math.abs(Math.sin(i * 1.3 + 0.6)));
                        c.fillStyle = "hsl(" + Math.round(f * 300) + ",90%,62%)";
                        c.fillRect(x + i * bw / n + 0.5, y + bh - hh, bw / n - 1.5, hh);
                    }
                }
                if (pc.mode === "widget") {
                    c.fillStyle = "rgba(255,255,255,0.12)";
                    c.strokeStyle = "rgba(255,255,255,0.45)";
                    c.beginPath();
                    c.roundedRect(w * 0.1, h * 0.14, w * 0.42, h * 0.38, 5, 5);
                    c.fill();
                    c.stroke();
                    bars(w * 0.14, h * 0.22, w * 0.34, h * 0.26);
                } else if (pc.mode === "panel") {
                    bars(w * 0.22, h - 34, w * 0.56, 19);
                } else if (pc.mode === "screen") {
                    for (var r = 0; r < 3; r++)
                        for (var q = 0; q < 3; q++) {
                            c.fillStyle = (r === 2 && q === 1) ? acc : "rgba(255,255,255,0.35)";
                            c.beginPath();
                            c.arc(w * (0.15 + q * 0.35), h * (0.15 + r * 0.29), (r === 2 && q === 1) ? 4.5 : 3, 0, Math.PI * 2);
                            c.fill();
                        }
                    bars(w * 0.34, h * 0.48, w * 0.32, h * 0.2);
                } else {
                    c.strokeStyle = acc;
                    c.lineWidth = 1.5;
                    c.setLineDash ? c.setLineDash([4, 3]) : 0;
                    c.beginPath();
                    c.roundedRect(w * 0.4, h * 0.16, w * 0.46, h * 0.4, 5, 5);
                    c.stroke();
                    bars(w * 0.44, h * 0.22, w * 0.38, h * 0.28);
                    // move arrows
                    c.strokeStyle = "white";
                    c.lineWidth = 1.6;
                    c.lineCap = "round";
                    var mx = w * 0.22, my = h * 0.42, a = 9;
                    c.beginPath();
                    c.moveTo(mx - a, my); c.lineTo(mx + a, my);
                    c.moveTo(mx, my - a); c.lineTo(mx, my + a);
                    c.moveTo(mx - a + 3, my - 3); c.lineTo(mx - a, my); c.lineTo(mx - a + 3, my + 3);
                    c.moveTo(mx + a - 3, my - 3); c.lineTo(mx + a, my); c.lineTo(mx + a - 3, my + 3);
                    c.moveTo(mx - 3, my - a + 3); c.lineTo(mx, my - a); c.lineTo(mx + 3, my - a + 3);
                    c.moveTo(mx - 3, my + a - 3); c.lineTo(mx, my + a); c.lineTo(mx + 3, my + a - 3);
                    c.stroke();
                }
            }
        }
        Column {
            anchors.top: art.bottom
            anchors.topMargin: 10
            x: 12
            width: parent.width - 24
            spacing: 3
            Text { text: pc.title; color: editor.c.text; font.pixelSize: 13; font.weight: Font.DemiBold }
            Text { width: parent.width; text: pc.desc; color: editor.c.sub; font.pixelSize: 11; wrapMode: Text.WordWrap; maximumLineCount: 3; elide: Text.ElideRight }
        }
        Rectangle {
            visible: pc.sel
            width: 20; height: 20; radius: 10
            anchors.right: parent.right; anchors.top: parent.top; anchors.margins: 6
            color: editor.c.accent
            border.color: "white"; border.width: 2
            Text { anchors.centerIn: parent; text: "✓"; color: "white"; font.pixelSize: 11; font.bold: true }
        }
        MouseArea {
            id: pcMa
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            enabled: pc.mode === "widget" || (pg.app && pg.app.canPlace)
            onClicked: {
                if (pc.mode === "free" && editor.cfg.placement !== "free" && pg.app) {
                    pg.app.toggleLock();      // start free positioning where the visualizer is now
                } else {
                    editor.cfg.placement = pc.mode;
                }
            }
        }
        opacity: pcMa.enabled ? 1 : 0.45
    }

    // ---- 3 x 3 anchor picker on a little screen ----------------------------
    component AnchorGrid: Rectangle {
        id: ag
        width: 228
        height: 140
        radius: 10
        gradient: Gradient {
            orientation: Gradient.Horizontal
            GradientStop { position: 0; color: "#2b2350" }
            GradientStop { position: 1; color: "#5a2b4a" }
        }
        border.color: editor.c.cardBorder
        Grid {
            anchors.fill: parent
            anchors.margins: 8
            columns: 3
            Repeater {
                model: Styles.ANCHORS
                delegate: Item {
                    required property string modelData
                    width: (ag.width - 16) / 3
                    height: (ag.height - 16) / 3
                    readonly property bool sel: editor.cfg.screenAnchor === modelData
                    Rectangle {
                        anchors.centerIn: parent
                        width: parent.sel ? 30 : (cellMa.containsMouse ? 18 : 12)
                        height: parent.sel ? 16 : (cellMa.containsMouse ? 18 : 12)
                        radius: height / 2
                        color: parent.sel ? editor.c.accent : Qt.rgba(1, 1, 1, cellMa.containsMouse ? 0.6 : 0.35)
                        border.color: parent.sel ? "white" : "transparent"
                        border.width: 2
                        Behavior on width { NumberAnimation { duration: 120 } }
                    }
                    MouseArea {
                        id: cellMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: editor.cfg.screenAnchor = parent.modelData
                    }
                }
            }
        }
    }

    component SliderRow: EdRow {
        id: sr
        property string cfgKey
        property real from: 0
        property real to: 100
        property real step: 1
        property string unit: "px"
        EdSlider {
            width: parent.width
            from: sr.from
            to: sr.to
            stepSize: sr.step
            unit: sr.unit
            value: Number(editor.cfg[sr.cfgKey])
            enabledState: sr.enabledState
            onMoved: (v) => editor.cfg[sr.cfgKey] = Math.round(v)
        }
    }

    // ---------------------------------------------------------------------------

    Rectangle {
        visible: !(pg.app && pg.app.canPlace)
        width: parent.width
        height: warn.implicitHeight + 24
        radius: 12
        color: Qt.rgba(1, 0.62, 0.04, 0.14)
        border.color: Qt.rgba(1, 0.62, 0.04, 0.5)
        Text {
            id: warn
            x: 14
            width: parent.width - 28
            anchors.verticalCenter: parent.verticalCenter
            wrapMode: Text.WordWrap
            color: editor.c.text
            font.pixelSize: 13
            text: i18n("The widget is not on the desktop right now (e.g. in a panel). Panel, fixed and free placement only work for widgets on the desktop – put SeaQ SoundWave on the desktop for that.")
        }
    }

    EdSection {
        title: i18n("Where should the visualizer appear?")
        subtitle: i18n("Outside the widget the visualizer floats on the desktop behind all windows – the widget itself becomes invisible (in the desktop’s edit mode you see a small icon).")
        boxPadding: 14
        Row {
            width: parent.width
            spacing: 14
            PlacementCard { mode: "widget"; title: i18n("In the widget"); desc: i18n("Classic, inside the widget frame, sized like any widget") }
            PlacementCard { mode: "panel"; title: i18n("At the panel"); desc: i18n("Centred at a panel at the top, bottom, left or right") }
            PlacementCard { mode: "screen"; title: i18n("Fixed position"); desc: i18n("At one of nine points of the screen") }
            PlacementCard { mode: "free"; title: i18n("Free"); desc: i18n("Drag it with the mouse, lock it with a shortcut") }
        }
    }

    // ---- panel ---------------------------------------------------------------
    EdSection {
        visible: pg.mode === "panel"
        title: i18n("At the panel")
        subtitle: pg.app && pg.app.attachEdge !== ""
                  ? ({ bottom: i18n("Found: panel at the bottom."), top: i18n("Found: panel at the top."), left: i18n("Found: panel on the left."), right: i18n("Found: panel on the right.") })[pg.app.attachEdge]
                    + " " + (pg.round ? i18n("Round styles sit centred above the panel.") : i18n("The base of the visualizer always points to the panel."))
                  : i18n("There is no panel on this edge – until there is one, the visualizer sits at the bottom of the screen.")
        EdRow {
            first: true
            label: i18n("Edge")
            EdSegmented {
                anchors.right: parent.right
                model: [["auto", "Auto"], ["bottom", "Bottom"], ["top", "Top"], ["left", "Left"], ["right", "Right"]]
                current: editor.cfg.attachEdge
                onPicked: (v) => editor.cfg.attachEdge = v
            }
        }
        SliderRow { label: i18n("Height"); desc: i18n("How far the visualizer rises from the panel"); cfgKey: "attachThickness"; from: 24; to: 900; step: 2 }
        SliderRow { label: i18n("Gap to the panel"); desc: i18n("Small gap between panel and visualizer"); cfgKey: "attachGap"; from: -60; to: 300 }
        EdRow {
            label: i18n("Offset along the panel")
            desc: i18n("0 = exactly centred")
            controlWidth: 340
            Row {
                width: parent.width
                spacing: 10
                EdSlider {
                    width: parent.width - centerBtn.width - 10
                    from: -1600; to: 1600; unit: "px"
                    value: editor.cfg.attachOffset
                    onMoved: (v) => editor.cfg.attachOffset = Math.round(v / 2) * 2
                }
                EdButton { id: centerBtn; text: i18n("Centre"); implicitWidth: 72; onClicked: editor.cfg.attachOffset = 0 }
            }
        }
        EdRow {
            label: i18n("Length")
            EdSegmented {
                anchors.right: parent.right
                model: [["panel", "Like the panel"], ["screen", "Whole edge"], ["custom", "Fixed length"]]
                current: editor.cfg.attachLengthMode
                onPicked: (v) => editor.cfg.attachLengthMode = v
            }
        }
        SliderRow { visible: editor.cfg.attachLengthMode === "custom"; label: i18n("Fixed length"); cfgKey: "attachLength"; from: 100; to: 4000; step: 10 }
        SliderRow {
            visible: editor.cfg.attachLengthMode === "panel"
            label: i18n("Stop before the panel corners")
            desc: i18n("So the visualizer does not reach into the rounding of a floating panel")
            cfgKey: "attachEndInset"; from: 0; to: 100
        }
        SliderRow {
            visible: !!editor.info.soft
            label: i18n("Rounded ends")
            desc: i18n("Soft curve at the ends above a floating panel (0 = straight edge)")
            cfgKey: "attachSoftEnds"; from: 0; to: 300; step: 2
        }
        SliderRow {
            visible: !!editor.info.soft && editor.cfg.attachSoftEnds > 0
            label: i18n("Flare at the base")
            cfgKey: "attachSoftBase"; from: 0; to: 100
        }
    }

    // ---- fixed screen position ----------------------------------------------
    EdSection {
        visible: pg.mode === "screen"
        title: i18n("Fixed position")
        subtitle: i18n("Choose an anchor point. Left and right in the middle turn strip styles sideways.")
        EdRow {
            first: true
            label: i18n("Anchor point")
            desc: ({ "top-left": i18n("Top left"), "top": i18n("Top centre"), "top-right": i18n("Top right"), "left": i18n("Left centre"),
                     "center": i18n("Screen centre"), "right": i18n("Right centre"), "bottom-left": i18n("Bottom left"), "bottom": i18n("Bottom centre"),
                     "bottom-right": i18n("Bottom right") })[editor.cfg.screenAnchor] || ""
            height: 164
            AnchorGrid { anchors.right: parent.right }
        }
        SliderRow { label: i18n("Horizontal margin"); cfgKey: "screenMarginX"; from: -1500; to: 1500; step: 2 }
        SliderRow { label: i18n("Vertical margin"); cfgKey: "screenMarginY"; from: -1000; to: 1000; step: 2 }
        SliderRow { visible: !pg.round; label: i18n("Length"); desc: i18n("Share of the screen width (or height)"); cfgKey: "screenWidth"; from: 5; to: 100; unit: "%" }
        SliderRow { label: pg.round ? i18n("Size") : i18n("Height"); cfgKey: "screenHeight"; from: 40; to: 2000; step: 4 }
    }

    // ---- free -----------------------------------------------------------------
    EdSection {
        visible: pg.mode === "free"
        title: i18n("Free positioning")
        EdRow {
            first: true
            label: pg.app && pg.app.unlocked ? i18n("Moving is active") : i18n("Position is locked")
            desc: pg.app && pg.app.unlocked
                  ? i18n("Drag the blue frame on the desktop. Lock with %1, Enter or a double click.", pg.app.shortcutText)
                  : i18n("Unlock with %1 – or here:", pg.app ? pg.app.shortcutText : "")
            EdButton {
                anchors.right: parent.right
                primary: true
                text: pg.app && pg.app.unlocked ? i18n("Lock") : i18n("Move now")
                onClicked: if (pg.app) pg.app.toggleLock()
            }
        }
        EdRow {
            visible: !pg.round
            label: i18n("Orientation")
            desc: i18n("On which side the “base” of the visualizer lies")
            EdSegmented {
                anchors.right: parent.right
                model: [["bottom", "Bottom"], ["top", "Top"], ["left", "Left"], ["right", "Right"]]
                current: editor.cfg.freeEdge
                onPicked: (v) => editor.cfg.freeEdge = v
            }
        }
        EdRow {
            label: i18n("Width")
            EdSlider {
                width: parent.width
                from: 80; to: 5120; stepSize: 2; unit: "px"
                value: pg.app && pg.app.stageGeo ? pg.app.stageGeo.width : 0
                onMoved: (v) => {
                    var g = pg.app.stageGeo;
                    pg.app.commitFree({ x: g.x + (g.width - v) / 2, y: g.y, width: v, height: pg.round ? v : g.height });
                }
            }
        }
        EdRow {
            visible: !pg.round
            label: i18n("Height")
            EdSlider {
                width: parent.width
                from: 40; to: 2880; stepSize: 2; unit: "px"
                value: pg.app && pg.app.stageGeo ? pg.app.stageGeo.height : 0
                onMoved: (v) => {
                    var g = pg.app.stageGeo;
                    pg.app.commitFree({ x: g.x, y: g.y + (g.height - v) / 2, width: g.width, height: v });
                }
            }
        }
        EdRow {
            label: i18n("Quick placement")
            Row {
                anchors.right: parent.right
                spacing: 8
                EdButton { text: i18n("Centre"); onClicked: pg.app.centerFree() }
                EdButton { text: i18n("Reset"); onClicked: pg.app.resetFree() }
            }
        }
    }

    // ---- inside the widget --------------------------------------------------
    EdSection {
        visible: pg.mode === "widget"
        title: i18n("In the widget")
        EdRow {
            first: true
            label: i18n("The visualizer fills the widget frame.")
            desc: i18n("Change size and place like any desktop widget (edit mode). A background plate is on the “Style options” page.")
        }
    }

    EdSection {
        title: i18n("Right click on the visualizer")
        trailing: EdButton { text: i18n("Reset position values"); onClicked: editor.resetGroup("position") }
        EdRow {
            first: true
            label: i18n("Show pop-up card")
            desc: editor.cfg.showMiniCard
                  ? i18n("A right click on the visualizer (not on the orb) opens a small card with preview, pause, lock and settings. A click on an empty spot closes it.")
                  : i18n("Off: a right click opens the widget’s menu (settings editor, move freely, pause, configure).")
            EdSwitch {
                anchors.right: parent.right
                checked: editor.cfg.showMiniCard
                onToggled: (v) => editor.cfg.showMiniCard = v
            }
        }
    }
}
