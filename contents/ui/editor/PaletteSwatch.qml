import QtQuick
import "../js/palette.js" as Pal

// Gradient swatch of a palette (used by the colour collection).
Item {
    id: sw
    property var stops: []
    property string name: ""
    property bool selected: false
    property bool removable: false
    signal picked()
    signal removed()

    width: 150
    height: 92

    onStopsChanged: cv.requestPaint()

    Rectangle {
        id: frame
        width: parent.width
        height: parent.height - 22
        radius: 12
        color: "transparent"
        border.width: sw.selected ? 2.5 : 1
        border.color: sw.selected ? editor.c.accent : editor.c.cardBorder
        scale: ma.pressed ? 0.97 : (ma.containsMouse ? 1.02 : 1)
        Behavior on scale { NumberAnimation { duration: 110 } }
        Canvas {
            id: cv
            anchors.fill: parent
            anchors.margins: sw.selected ? 4 : 2
            onPaint: {
                var c = getContext("2d");
                c.reset();
                var st = Pal.parse(sw.stops);
                var g = c.createLinearGradient(0, 0, width, 0);
                for (var i = 0; i < st.length; i++)
                    g.addColorStop(st[i].p, st[i].c);
                c.fillStyle = g;
                var r = 9;
                c.beginPath();
                c.moveTo(r, 0); c.arcTo(width, 0, width, height, r); c.arcTo(width, height, 0, height, r);
                c.arcTo(0, height, 0, 0, r); c.arcTo(0, 0, width, 0, r); c.closePath();
                c.fill();
            }
        }
        Rectangle {
            visible: sw.selected
            width: 20; height: 20; radius: 10
            anchors.right: parent.right; anchors.top: parent.top; anchors.margins: 7
            color: editor.c.accent
            border.color: "white"; border.width: 2
            Text { anchors.centerIn: parent; text: "✓"; color: "white"; font.pixelSize: 11; font.bold: true }
        }
        Rectangle {
            visible: sw.removable && ma.containsMouse
            width: 20; height: 20; radius: 10
            anchors.left: parent.left; anchors.top: parent.top; anchors.margins: 7
            color: Qt.rgba(0, 0, 0, 0.6)
            Text { anchors.centerIn: parent; text: "✕"; color: "white"; font.pixelSize: 10 }
            MouseArea { anchors.fill: parent; onClicked: sw.removed() }
            z: 2
        }
    }
    Text {
        anchors.bottom: parent.bottom
        width: parent.width
        horizontalAlignment: Text.AlignHCenter
        text: sw.name
        color: sw.selected ? editor.c.text : editor.c.sub
        font.pixelSize: 12
        font.weight: sw.selected ? Font.DemiBold : Font.Normal
        elide: Text.ElideRight
    }
    MouseArea {
        id: ma
        anchors.fill: frame
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: sw.picked()
    }
}
