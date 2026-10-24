import QtQuick

// single line text field
Rectangle {
    id: f
    property alias text: input.text
    property string placeholder: ""
    property alias inputMask: input.inputMask
    property alias validator: input.validator
    signal edited(string text)
    signal accepted(string text)

    implicitWidth: 180
    implicitHeight: 30
    radius: 7
    color: editor.c.field
    border.color: input.activeFocus ? editor.c.accent : editor.c.border
    border.width: input.activeFocus ? 2 : 1

    TextInput {
        id: input
        anchors.fill: parent
        anchors.leftMargin: 10
        anchors.rightMargin: 10
        verticalAlignment: TextInput.AlignVCenter
        color: editor.c.text
        selectionColor: editor.c.accent
        font.pixelSize: 13
        clip: true
        selectByMouse: true
        onTextEdited: f.edited(text)
        onAccepted: f.accepted(text)
        Text {
            anchors.verticalCenter: parent.verticalCenter
            visible: !input.text && !input.activeFocus
            text: f.placeholder
            color: editor.c.sub
            font.pixelSize: 13
        }
    }
}
