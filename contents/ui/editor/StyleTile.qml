import QtQuick
import ".." as SW

// A live, animated thumbnail of one visualizer style.
Item {
    id: tile
    property var info
    property bool selected: false
    property bool running: tile.selected || ma.containsMouse
    property var paletteStops
    property bool colorShift: false
    signal picked()

    width: 212
    height: 156

    Rectangle {
        id: frame
        width: parent.width
        height: 118
        radius: 12
        color: "#15100f"
        border.width: tile.selected ? 2.5 : 1
        border.color: tile.selected ? editor.c.accent : editor.c.cardBorder
        clip: true
        scale: ma.pressed ? 0.97 : (ma.containsMouse ? 1.02 : 1)
        Behavior on scale { NumberAnimation { duration: 110 } }

        SW.Visualizer {
            anchors.fill: parent
            anchors.margins: tile.info.round ? 6 : 8
            demo: true
            running: tile.running
            fps: 24
            quality: 0.8
            style: tile.info.id
            paletteStops: tile.paletteStops
            colorShift: tile.colorShift
            orbInteractive: false
            orbStaticIcon: true
            optionsJson: editor.cfg.styleOptions      // the tile shows the orb only when it is switched on
        }
        Row {
            anchors.left: parent.left
            anchors.bottom: parent.bottom
            anchors.margins: 7
            spacing: 4
            Repeater {
                model: (tile.info.fullscreen ? ["Full screen"] : []).concat(tile.info.orb ? ["Orb"] : [])
                delegate: Rectangle {
                    required property string modelData
                    height: 16; width: bt.implicitWidth + 10; radius: 8
                    color: Qt.rgba(0, 0, 0, 0.55)
                    Text { id: bt; anchors.centerIn: parent; text: i18n(parent.modelData); color: "white"; font.pixelSize: 10 }
                }
            }
        }
        Rectangle {
            visible: tile.selected
            width: 22; height: 22; radius: 11
            anchors.right: parent.right; anchors.top: parent.top; anchors.margins: 7
            color: editor.c.accent
            border.color: "white"; border.width: 2
            Text { anchors.centerIn: parent; text: "✓"; color: "white"; font.pixelSize: 12; font.bold: true }
        }
    }
    Column {
        anchors.top: frame.bottom
        anchors.topMargin: 6
        width: parent.width
        spacing: 1
        Text {
            width: parent.width
            text: i18n(tile.info.name)
            color: editor.c.text
            font.pixelSize: 13
            font.weight: tile.selected ? Font.DemiBold : Font.Medium
            elide: Text.ElideRight
        }
        Text {
            width: parent.width
            text: i18n(tile.info.desc)
            color: editor.c.sub
            font.pixelSize: 11
            elide: Text.ElideRight
        }
    }
    MouseArea {
        id: ma
        anchors.fill: frame
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: tile.picked()
    }
}
