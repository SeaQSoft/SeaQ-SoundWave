import QtQuick

// A titled, rounded group box (macOS System Settings style).
Column {
    id: sec
    property string title: ""
    property string subtitle: ""
    property alias trailing: trailingSlot.data
    default property alias rows: box.data
    property real boxPadding: 0
    width: parent ? parent.width : 400
    spacing: 8

    Item {
        width: parent.width
        height: Math.max(titleCol.height, trailingSlot.childrenRect.height)
        visible: sec.title !== ""
        Column {
            id: titleCol
            anchors.left: parent.left
            anchors.leftMargin: 4
            anchors.right: trailingSlot.left
            spacing: 2
            Text { text: sec.title; color: editor.c.text; font.pixelSize: 14; font.weight: Font.DemiBold }
            Text { visible: sec.subtitle !== ""; text: sec.subtitle; color: editor.c.sub; font.pixelSize: 12; wrapMode: Text.WordWrap; width: parent.width }
        }
        Item {
            id: trailingSlot
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            width: childrenRect.width
            height: childrenRect.height
        }
    }
    Rectangle {
        width: parent.width
        height: box.implicitHeight + sec.boxPadding * 2
        radius: 12
        color: editor.c.card
        border.color: editor.c.cardBorder
        Column {
            id: box
            x: sec.boxPadding
            y: sec.boxPadding
            width: parent.width - sec.boxPadding * 2
        }
    }
}
