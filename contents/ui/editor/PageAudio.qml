import QtQuick

Column {
    id: pg
    spacing: 26

    component SliderRow: EdRow {
        id: sr
        property string cfgKey
        property real from: 0
        property real to: 100
        property real step: 1
        property string unit: ""
        EdSlider {
            width: parent.width
            from: sr.from
            to: sr.to
            stepSize: sr.step
            unit: sr.unit
            value: Number(editor.cfg[sr.cfgKey])
            onMoved: (v) => editor.cfg[sr.cfgKey] = Math.round(v)
        }
    }

    EdSection {
        title: i18n("Analysis")
        trailing: EdButton { text: i18n("Reset"); onClicked: editor.resetGroup("audio") }
        SliderRow { first: true; label: i18n("Frequency bands"); desc: i18n("Detail of the spectrum"); cfgKey: "barCount"; from: 8; to: 128 }
        SliderRow { label: i18n("Sensitivity"); cfgKey: "sensitivity"; from: 10; to: 300; step: 5; unit: "%" }
        SliderRow { label: i18n("Frame rate"); desc: i18n("Fewer frames per second save power"); cfgKey: "framerate"; from: 15; to: 144; unit: "fps" }
        SliderRow { label: i18n("Smoothing"); cfgKey: "smoothing"; from: 0; to: 90; unit: "%" }
    }

    EdSection {
        title: i18n("Audio source")
        EdRow {
            first: true
            label: i18n("Audio engine")
            desc: i18n("Automatic uses cava when it is installed – otherwise the built-in analysis (needs only parec or pw-record).")
            controlWidth: 330
            EdSegmented {
                anchors.right: parent.right
                model: [["auto", "Automatic"], ["builtin", "Built-in"], ["cava", "cava"]]
                current: editor.cfg.engine
                onPicked: (v) => editor.cfg.engine = v
            }
        }
        EdRow {
            label: i18n("Input method (cava only)")
            enabledState: editor.cfg.engine !== "builtin"
            controlWidth: 330
            EdSegmented {
                anchors.right: parent.right
                enabledState: editor.cfg.engine !== "builtin"
                model: [["pulse", "Pulse"], ["pipewire", "PipeWire"], ["alsa", "ALSA"], ["jack", "JACK"]]
                current: editor.cfg.inputMethod
                onPicked: (v) => editor.cfg.inputMethod = v
            }
        }
        EdRow {
            label: i18n("Source")
            desc: i18n("“auto” shows whatever is playing. Find other sources with “pactl list short sources”.")
            EdField {
                anchors.right: parent.right
                width: 240
                text: editor.cfg.inputSource
                placeholder: "auto"
                onAccepted: (t) => editor.cfg.inputSource = t.trim() === "" ? "auto" : t.trim()
                onEdited: srcTimer.restart()
                Timer {
                    id: srcTimer
                    interval: 1200
                    onTriggered: editor.cfg.inputSource = parent.text.trim() === "" ? "auto" : parent.text.trim()
                }
            }
        }
    }

    EdSection {
        title: i18n("Audio protection")
        subtitle: i18n("SoundWave keeps its own recording stream out of the audio memory. If an app ends up muted or at 0 % anyway (as remembered by the system), it can be repaired here.") + " "
                  + i18n("Repairing only unmutes and only raises a volume that is at 0 % (to the normal 100 %). Cleaning the remembered settings briefly restarts the audio service.")
        EdRow {
            first: true
            label: i18n("When a muted app is found")
            controlWidth: 360
            EdSegmented {
                anchors.right: parent.right
                model: [["notify", "Notify"], ["auto", "Repair automatically"], ["off", "Off"]]
                current: editor.cfg.audioGuard
                onPicked: (v) => editor.cfg.audioGuard = v
            }
        }
        EdRow {
            readonly property var issue: editor.app ? editor.app.audioIssue : []
            label: issue.length ? i18n("Muted or silent: %1", issue.join(", ")) : i18n("All apps can be heard")
            Row {
                anchors.right: parent.right
                spacing: 8
                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    width: 10
                    height: 10
                    radius: 5
                    color: editor.app && editor.app.audioIssue.length ? editor.c.orange : editor.c.green
                }
                EdButton {
                    visible: !!editor.app && editor.app.audioIssue.length > 0
                    text: i18n("Don't report again")
                    onClicked: editor.app.ignoreApps(editor.app.audioIssue.join(", "))
                }
                EdButton {
                    text: i18n("Check now")
                    onClicked: if (editor.app) editor.app.checkAudio()
                }
                EdButton {
                    primary: true
                    enabledState: !!editor.app && !editor.app.audioFixing
                    text: i18n("Repair now")
                    onClicked: if (editor.app) editor.app.fixAudio(true)
                }
            }
        }
        EdRow {
            readonly property var ignored: String(editor.cfg.audioGuardIgnore || "").split("\n").filter(function (x) { return x !== ""; })
            visible: ignored.length > 0
            label: i18n("Not reported: %1", ignored.join(", "))
            desc: i18n("Apps you muted on purpose")
            EdButton {
                anchors.right: parent.right
                text: i18n("Clear list")
                onClicked: editor.cfg.audioGuardIgnore = ""
            }
        }
    }
}
