import QtQuick
import ".." as SW

// Live preview of the current style (real audio, or a demo while nothing plays).
Rectangle {
    id: lp
    property string styleId: editor.cfg.vizStyle
    property bool showLabel: true
    readonly property bool live: editor.app ? editor.hasSignal(editor.app.barValues) : false

    radius: 14
    color: "#14100f"
    border.color: editor.c.cardBorder
    clip: true

    SW.Visualizer {
        anchors.fill: parent
        anchors.margins: 10
        values: lp.live ? editor.app.barValues : []
        demo: !lp.live
        style: lp.styleId
        optionsJson: editor.cfg.styleOptions
        paletteStops: editor.cfg.palette
        colorMapping: editor.cfg.colorMapping
        gradientAngle: editor.cfg.gradientAngle
        colorShift: editor.cfg.colorShift
        colorShiftSpeed: editor.cfg.colorShiftSpeed
        opacityLevel: editor.cfg.opacity / 100
        smoothing: editor.cfg.smoothing / 100
        fps: 45
        mediaPlaying: editor.app ? editor.app.mediaPlaying : true
        mediaArt: editor.app ? editor.app.mediaArt : ""
        orbInteractive: true
        onOrbClicked: if (editor.app) editor.app.orbClicked()
    }

    Rectangle {
        visible: lp.showLabel
        x: 12
        y: 12
        height: 22
        width: lbl.implicitWidth + 22
        radius: 11
        color: Qt.rgba(0, 0, 0, 0.55)
        Rectangle {
            x: 9
            anchors.verticalCenter: parent.verticalCenter
            width: 6
            height: 6
            radius: 3
            color: lp.live ? "#30d158" : "#ff9f0a"
        }
        Text {
            id: lbl
            x: 19
            anchors.verticalCenter: parent.verticalCenter
            text: lp.live ? i18n("Live") : i18n("Demo · nothing is playing right now")
            color: "white"
            font.pixelSize: 11
        }
    }
}
