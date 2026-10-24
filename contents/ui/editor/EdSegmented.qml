import QtQuick

// macOS segmented control. model: [[value, label], ...]
Rectangle {
    id: seg
    property var model: []
    property var current
    property bool enabledState: true
    signal picked(var value)

    implicitWidth: Math.max(120, row.implicitWidth + 4)
    implicitHeight: 28
    radius: 8
    color: editor.c.segBg
    opacity: enabledState ? 1 : 0.4

    Row {
        id: row
        anchors.fill: parent
        anchors.margins: 2
        Repeater {
            model: seg.model
            delegate: Rectangle {
                required property var modelData
                required property int index
                readonly property bool sel: String(seg.current) === String(modelData[0])
                width: Math.max(lbl.implicitWidth + 22, (seg.width - 4) / Math.max(1, seg.model.length))
                height: row.height
                radius: 6
                color: sel ? editor.c.segSel : (ma.containsMouse ? editor.c.hover : "transparent")
                border.color: sel ? editor.c.border : "transparent"
                Text {
                    id: lbl
                    anchors.centerIn: parent
                    text: i18n(modelData[1])
                    color: editor.c.text
                    font.pixelSize: 12
                    font.weight: parent.sel ? Font.DemiBold : Font.Normal
                }
                MouseArea {
                    id: ma
                    anchors.fill: parent
                    hoverEnabled: true
                    enabled: seg.enabledState
                    cursorShape: Qt.PointingHandCursor
                    onClicked: seg.picked(parent.modelData[0])
                }
            }
        }
    }
}
