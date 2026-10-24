import QtQuick

// One row in a section: label (+ description) on the left, control on the right.
Item {
    id: r
    property string label: ""
    property string desc: ""
    property bool first: false
    property bool enabledState: true
    property real controlWidth: 280
    default property alias control: slot.data

    width: parent ? parent.width : 400
    implicitHeight: Math.max(48, textCol.implicitHeight + 22, slot.childrenRect.height + 18)
    height: implicitHeight

    Rectangle {
        visible: !r.first
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.leftMargin: 14
        anchors.rightMargin: 14
        height: 1
        color: editor.c.sep
    }
    Column {
        id: textCol
        anchors.left: parent.left
        anchors.leftMargin: 16
        anchors.right: slot.left
        anchors.rightMargin: 16
        anchors.verticalCenter: parent.verticalCenter
        spacing: 2
        opacity: r.enabledState ? 1 : 0.45
        Text { width: parent.width; text: r.label; color: editor.c.text; font.pixelSize: 13; wrapMode: Text.WordWrap }
        Text { width: parent.width; visible: r.desc !== ""; text: r.desc; color: editor.c.sub; font.pixelSize: 11; wrapMode: Text.WordWrap }
    }
    Item {
        id: slot
        anchors.right: parent.right
        anchors.rightMargin: 16
        anchors.verticalCenter: parent.verticalCenter
        width: Math.min(r.controlWidth, r.width * 0.55)
        height: childrenRect.height
    }
}
