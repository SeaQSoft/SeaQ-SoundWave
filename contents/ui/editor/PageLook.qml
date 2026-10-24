import QtQuick
import "../js/styles.js" as Styles

Column {
    id: pg
    spacing: 26

    LivePreview {
        width: parent.width
        height: 180
    }

    Text {
        width: parent.width
        wrapMode: Text.WordWrap
        color: editor.c.sub
        font.pixelSize: 13
        text: i18n("This page adapts itself: you only see the settings that the style “%1” really uses. Every style remembers its own values.", i18n(editor.info.name))
    }

    Repeater {
        model: editor.sectionsForStyle()
        delegate: EdSection {
            id: sec
            required property var modelData
            required property int index
            title: i18n(modelData.name)
            trailing: EdButton {
                visible: sec.index === 0
                text: i18n("Defaults")
                onClicked: editor.cfg.styleOptions = Styles.resetStyle(editor.cfg.styleOptions, editor.cfg.vizStyle)
            }
            Repeater {
                model: sec.modelData.keys
                delegate: OptionRow {
                    required property string modelData
                    required property int index
                    key: modelData
                    isFirst: index === 0
                    opts: editor.opts
                    onChanged: (k, v) => editor.setOpt(k, v)
                }
            }
        }
    }

    EdSection {
        visible: editor.sectionsForStyle().length === 0
        title: i18n("No options of its own")
        EdRow {
            first: true
            label: i18n("“%1” has no additional shape settings.", i18n(editor.info.name))
            desc: i18n("Set colours and colour flow on the “Colours” page, opacity further down.")
        }
    }

    EdSection {
        title: i18n("For all styles")
        trailing: EdButton { text: i18n("Reset"); onClicked: editor.resetGroup("general") }
        EdRow {
            first: true
            label: i18n("Opacity")
            EdSlider {
                width: parent.width
                from: 10; to: 100; unit: "%"
                value: editor.cfg.opacity
                onMoved: (v) => editor.cfg.opacity = Math.round(v)
            }
        }
        EdRow {
            label: i18n("Smoothing")
            desc: i18n("How softly the motion follows the music")
            EdSlider {
                width: parent.width
                from: 0; to: 90; unit: "%"
                value: editor.cfg.smoothing
                onMoved: (v) => editor.cfg.smoothing = Math.round(v)
            }
        }
        EdRow {
            label: i18n("Background plate")
            desc: editor.info.anchored
                  ? i18n("Square at the bottom so that “%1” sits flush – rounded at the top", i18n(editor.info.name))
                  : i18n("Rounded all around, because “%1” floats freely in the middle", i18n(editor.info.name))
            Row {
                anchors.right: parent.right
                spacing: 12
                ColorWell {
                    anchors.verticalCenter: parent.verticalCenter
                    value: editor.cfg.backgroundColor
                    alpha: true
                    enabled: editor.cfg.backgroundEnabled
                    opacity: enabled ? 1 : 0.4
                    onPicked: (c) => editor.cfg.backgroundColor = c
                }
                EdSwitch {
                    anchors.verticalCenter: parent.verticalCenter
                    checked: editor.cfg.backgroundEnabled
                    onToggled: (v) => editor.cfg.backgroundEnabled = v
                }
            }
        }
        EdRow {
            label: i18n("Corner radius of the plate")
            enabledState: editor.cfg.backgroundEnabled
            EdSlider {
                width: parent.width
                from: 0; to: 60; unit: "px"
                value: editor.cfg.backgroundRadius
                enabledState: editor.cfg.backgroundEnabled
                onMoved: (v) => editor.cfg.backgroundRadius = Math.round(v)
            }
        }
    }
}
