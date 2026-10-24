import QtQuick

Rectangle {
    id: b
    property string text: ""
    property bool primary: false
    property bool danger: false
    property bool enabledState: true
    signal clicked()

    implicitWidth: Math.max(80, t.implicitWidth + 28)
    implicitHeight: 30
    radius: 8
    opacity: enabledState ? 1 : 0.45
    readonly property color fill: danger ? editor.c.red : editor.c.accent
    color: primary ? (ma.pressed ? Qt.darker(fill, 1.15) : fill)
                   : (ma.pressed ? editor.c.pressed : (ma.containsMouse ? editor.c.btnHover : editor.c.btn))
    border.color: primary ? "transparent" : editor.c.border
    Text {
        id: t
        anchors.centerIn: parent
        text: b.text
        color: b.primary ? "white" : (b.danger ? editor.c.red : editor.c.text)
        font.pixelSize: 13
        font.weight: Font.Medium
    }
    MouseArea {
        id: ma
        anchors.fill: parent
        hoverEnabled: true
        enabled: b.enabledState
        cursorShape: Qt.PointingHandCursor
        onClicked: b.clicked()
    }
}
