import QtQuick

// macOS style slider with a value read-out
Item {
    id: sl
    property real from: 0
    property real to: 100
    property real stepSize: 1
    property real value: 0
    property string unit: ""
    property bool enabledState: true
    property bool showValue: true
    property int decimals: stepSize < 1 ? 1 : 0
    signal moved(real value)

    implicitWidth: 260
    implicitHeight: 26
    opacity: enabledState ? 1 : 0.4

    readonly property real frac: to > from ? Math.max(0, Math.min(1, (value - from) / (to - from))) : 0
    readonly property real trackW: width - (showValue ? valueText.width + 12 : 0)

    function valueAt(x) {
        var f = Math.max(0, Math.min(1, (x - 9) / Math.max(1, trackW - 18)));
        var v = from + f * (to - from);
        v = Math.round(v / stepSize) * stepSize;
        return Math.max(from, Math.min(to, Number(v.toFixed(3))));
    }

    Rectangle {
        id: track
        x: 9
        width: sl.trackW - 18
        height: 4
        radius: 2
        anchors.verticalCenter: parent.verticalCenter
        color: editor.c.track
        Rectangle {
            width: sl.frac * parent.width
            height: parent.height
            radius: 2
            color: editor.c.accent
        }
    }
    Rectangle {
        id: knob
        width: 18; height: 18; radius: 9
        anchors.verticalCenter: parent.verticalCenter
        x: sl.frac * (sl.trackW - 18)
        color: "white"
        border.color: Qt.rgba(0, 0, 0, 0.15)
        scale: drag.pressed ? 1.1 : 1
        Behavior on scale { NumberAnimation { duration: 90 } }
    }
    Text {
        id: valueText
        visible: sl.showValue
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        width: Math.max(implicitWidth, 46)
        horizontalAlignment: Text.AlignRight
        text: Number(sl.value).toFixed(sl.decimals) + (sl.unit ? " " + sl.unit : "")
        color: editor.c.sub
        font.pixelSize: 12
        font.features: { "tnum": 1 }
    }
    MouseArea {
        id: drag
        x: 0
        width: sl.trackW
        height: parent.height
        enabled: sl.enabledState
        cursorShape: Qt.PointingHandCursor
        preventStealing: true
        onPressed: (m) => sl.moved(sl.valueAt(m.x))
        onPositionChanged: (m) => { if (pressed) sl.moved(sl.valueAt(m.x)); }
    }
}
