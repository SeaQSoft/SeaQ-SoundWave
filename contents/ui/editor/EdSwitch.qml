import QtQuick

// macOS style toggle
Item {
    id: sw
    property bool checked: false
    property bool enabledState: true
    signal toggled(bool value)

    implicitWidth: 40
    implicitHeight: 24
    opacity: enabledState ? 1 : 0.4

    Rectangle {
        anchors.fill: parent
        radius: height / 2
        color: sw.checked ? editor.c.green : editor.c.track
        Behavior on color { ColorAnimation { duration: 140 } }
        Rectangle {
            width: parent.height - 4
            height: width
            radius: width / 2
            y: 2
            x: sw.checked ? parent.width - width - 2 : 2
            color: "white"
            border.color: Qt.rgba(0, 0, 0, 0.08)
            Behavior on x { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }
        }
    }
    MouseArea {
        anchors.fill: parent
        enabled: sw.enabledState
        cursorShape: Qt.PointingHandCursor
        onClicked: sw.toggled(!sw.checked)
    }
}
