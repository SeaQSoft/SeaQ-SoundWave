import QtQuick
import QtQuick.Dialogs

// macOS-like colour well; opens the colour dialog.
Rectangle {
    id: well
    property bool alpha: false
    property color value: "white"
    signal picked(color c)

    width: 44
    height: 24
    radius: 6
    color: editor.c.field
    border.color: editor.c.border
    border.width: 1
    Rectangle {
        anchors.fill: parent
        anchors.margins: 3
        radius: 4
        color: well.value
        border.color: Qt.rgba(0, 0, 0, 0.15)
    }
    MouseArea {
        anchors.fill: parent
        enabled: well.enabled
        cursorShape: Qt.PointingHandCursor
        onClicked: dlg.open()
    }
    ColorDialog {
        id: dlg
        title: i18n("Choose a colour")
        selectedColor: well.value
        options: well.alpha ? ColorDialog.ShowAlphaChannel : 0
        onAccepted: well.picked(selectedColor)
    }
}
