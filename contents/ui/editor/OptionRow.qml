import QtQuick
import "../js/styles.js" as Styles

// Renders one style option (slider / switch / segment) from the registry.
EdRow {
    id: row
    property string key: ""
    property var opts: ({})
    property bool isFirst: false
    signal changed(string key, var value)

    readonly property var def: Styles.OPTS[key] || ({ label: key, type: "switch" })
    first: isFirst
    label: i18n(def.label)
    desc: def.desc ? i18n(def.desc) : ""
    enabledState: Styles.optEnabled(key, opts)

    EdSlider {
        visible: row.def.type === "slider"
        width: parent.width
        from: row.def.min !== undefined ? row.def.min : 0
        to: row.def.max !== undefined ? row.def.max : 100
        stepSize: row.def.step || 1
        unit: row.def.unit || ""
        value: Number(row.opts[row.key])
        enabledState: row.enabledState
        onMoved: (v) => row.changed(row.key, v)
    }
    EdSwitch {
        visible: row.def.type === "switch"
        anchors.right: parent.right
        checked: !!row.opts[row.key]
        enabledState: row.enabledState
        onToggled: (v) => row.changed(row.key, v)
    }
    ColorWell {
        visible: row.def.type === "color"
        anchors.right: parent.right
        value: row.opts[row.key] || "#ffffff"
        enabled: row.enabledState
        opacity: row.enabledState ? 1 : 0.4
        onPicked: (c) => row.changed(row.key, "#" + [c.r, c.g, c.b].map(function (v) {
            var h = Math.round(v * 255).toString(16);
            return h.length < 2 ? "0" + h : h;
        }).join(""))
    }
    EdSegmented {
        visible: row.def.type === "segment"
        anchors.right: parent.right
        model: row.def.choices || []
        current: row.opts[row.key]
        enabledState: row.enabledState
        onPicked: (v) => row.changed(row.key, v)
    }
}
