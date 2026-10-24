import QtQuick

// number field with chevrons (like the gradient tool in picture 12)
Rectangle {
    id: sp
    property real value: 0
    property real from: 0
    property real to: 100
    property real step: 1
    property string suffix: ""
    property bool wrap: false
    signal changed(real value)

    implicitWidth: 120
    implicitHeight: 34
    radius: 8
    color: editor.c.field
    border.color: input.activeFocus ? editor.c.accent : editor.c.border
    border.width: input.activeFocus ? 2 : 1

    function emit(v) {
        if (wrap) {
            var span = to - from + step;
            while (v > to) v -= span;
            while (v < from) v += span;
        }
        sp.changed(Math.max(from, Math.min(to, v)));
    }

    TextInput {
        id: input
        anchors.left: parent.left
        anchors.right: chev.left
        anchors.verticalCenter: parent.verticalCenter
        anchors.leftMargin: 12
        text: Math.round(sp.value) + sp.suffix
        color: editor.c.text
        font.pixelSize: 13
        selectByMouse: true
        onEditingFinished: {
            var n = parseFloat(text);
            if (!isNaN(n)) sp.emit(n);
            text = Qt.binding(function () { return Math.round(sp.value) + sp.suffix; });
        }
    }
    Column {
        id: chev
        anchors.right: parent.right
        anchors.rightMargin: 4
        anchors.verticalCenter: parent.verticalCenter
        Repeater {
            model: [1, -1]
            delegate: Rectangle {
                required property int modelData
                width: 20; height: 13; radius: 4
                color: cm.containsMouse ? editor.c.hover : "transparent"
                Text {
                    anchors.centerIn: parent
                    text: parent.modelData > 0 ? "▴" : "▾"
                    color: editor.c.sub
                    font.pixelSize: 11
                }
                MouseArea {
                    id: cm
                    anchors.fill: parent
                    hoverEnabled: true
                    onClicked: sp.emit(sp.value + parent.modelData * sp.step)
                    onPressAndHold: rep.start()
                    onReleased: rep.stop()
                    Timer { id: rep; interval: 60; repeat: true; onTriggered: sp.emit(sp.value + cm.parent.modelData * sp.step) }
                }
            }
        }
    }
    MouseArea {
        anchors.fill: input
        acceptedButtons: Qt.NoButton
        onWheel: (w) => sp.emit(sp.value + (w.angleDelta.y > 0 ? sp.step : -sp.step))
    }
}
