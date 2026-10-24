import QtQuick
import "../js/styles.js" as Styles

Column {
    id: pg
    spacing: 26
    readonly property var app: editor.app
    readonly property var orbStyles: Styles.STYLES.filter(function (s) { return !!s.orb; })

    LivePreview {
        width: parent.width
        height: 200
    }

    EdSection {
        visible: !editor.info.orb
        title: i18n("“%1” has no orb", i18n(editor.info.name))
        subtitle: i18n("The orb exists for the line, light and round styles. Pick one of them:")
        boxPadding: 14
        Flow {
            width: parent.width
            spacing: 8
            Repeater {
                model: pg.orbStyles
                delegate: EdButton {
                    required property var modelData
                    text: i18n(modelData.name)
                    onClicked: editor.cfg.vizStyle = modelData.id
                }
            }
        }
    }

    EdSection {
        visible: !!editor.info.orb
        title: i18n("Orb – for all styles")
        subtitle: editor.info.round ? i18n("On/off, look and play/pause apply to every style at once. For round styles the orb is the circle in the middle – its size follows the inner radius.")
                                    : i18n("On/off, look and play/pause apply to every style at once – only the size is set for each style.")
        Repeater {
            model: editor.orbKeys()
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

    EdSection {
        title: i18n("Clicking the orb")
        trailing: EdButton { text: i18n("Reset orb"); onClicked: editor.resetOrb() }
        EdRow {
            first: true
            label: i18n("Action")
            desc: i18n("Pauses audio and video of every player that is playing (browser with YouTube/Udemy, VLC, Spotify, Elisa, LizardTune…) – a second click resumes them.")
            EdSegmented {
                anchors.right: parent.right
                model: [["playpause", "Pause / resume"], ["none", "Nothing"]]
                current: editor.cfg.orbAction
                onPicked: (v) => editor.cfg.orbAction = v
            }
        }
        EdRow {
            label: pg.app && pg.app.mediaPlayer !== "" ? pg.app.mediaPlayer : i18n("No player found")
            desc: !pg.app ? "" : ({ Playing: i18n("Playing right now"), Paused: i18n("Paused"), Stopped: i18n("Stopped"), None: i18n("Start music or a video so the orb has something to control.") })[pg.app.mediaStatus] || pg.app.mediaStatus
            EdButton {
                anchors.right: parent.right
                text: pg.app && pg.app.mediaPlaying ? i18n("Pause now") : i18n("Resume")
                onClicked: if (pg.app) pg.app.mediaToggle()
            }
        }
    }
}
