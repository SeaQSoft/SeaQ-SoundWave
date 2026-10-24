import QtQuick
import "../js/palette.js" as Pal
import ".." as SW

Column {
    id: pg
    spacing: 26
    property bool confirm: false

    // hero: the app icon over flowing macOS rainbow colour waves
    Rectangle {
        id: hero
        width: parent.width
        height: 260
        radius: 16
        border.color: editor.c.cardBorder
        clip: true
        gradient: Gradient {
            GradientStop { position: 0; color: "#2a2a2c" }
            GradientStop { position: 1; color: "#161618" }
        }

        SW.Visualizer {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            anchors.leftMargin: hero.radius * 0.6
            anchors.rightMargin: hero.radius * 0.6
            height: parent.height * 0.52
            demo: true
            style: "macos-wave"
            paletteStops: ""             // the built-in macOS rainbow
            colorShift: true
            colorShiftSpeed: 12
            softLeft: 60
            softRight: 60
            softBase: 6
            opacityLevel: 0.9
            orbInteractive: false
            fps: 40
        }
        // colour streams flowing into the logo (the logo lies on top as the orb)
        SW.Visualizer {
            anchors.left: parent.left
            anchors.right: parent.right
            y: 26 + 55 - height / 2          // centre = centre of the logo
            height: 176
            demo: true
            style: "ribbons"
            paletteStops: ""
            colorShift: true
            colorShiftSpeed: 12
            optionsJson: '{"_orb":{"orbEnabled":false},"ribbons":{"spread":64,"lineCount":9,"glow":60,"waviness":55,"centerGlow":true}}'
            orbInteractive: false
            fps: 40
        }

        // darken the waves behind the text a little
        Rectangle {
            anchors.fill: parent
            radius: hero.radius
            gradient: Gradient {
                GradientStop { position: 0.35; color: Qt.rgba(0.09, 0.09, 0.1, 0.0) }
                GradientStop { position: 0.75; color: Qt.rgba(0.09, 0.09, 0.1, 0.45) }
                GradientStop { position: 1.0; color: Qt.rgba(0.09, 0.09, 0.1, 0.1) }
            }
        }

        Column {
            anchors.horizontalCenter: parent.horizontalCenter
            y: 26
            spacing: 8
            Item {
                anchors.horizontalCenter: parent.horizontalCenter
                width: 110
                height: 110
                // soft glow behind the icon
                Rectangle {
                    anchors.centerIn: parent
                    width: 128
                    height: 128
                    radius: 64
                    color: "transparent"
                    border.width: 16
                    border.color: Qt.rgba(0.75, 0.35, 0.95, 0.0)
                }
                Image {
                    anchors.fill: parent
                    source: Qt.resolvedUrl("../../icons/seaq-soundwave-256.png")
                    sourceSize: Qt.size(220, 220)
                    smooth: true
                    mipmap: true
                }
            }
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: "SeaQ SoundWave"
                color: "white"
                font.pixelSize: 28
                font.weight: Font.Bold
                style: Text.Raised
                styleColor: Qt.rgba(0, 0, 0, 0.45)
            }
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: i18n("Version %1 · by %2", "2.5.0", "SeaQ")
                color: "white"
                opacity: 0.8
                font.pixelSize: 13
            }
        }
    }

    // support / donations
    component DonateButton: Rectangle {
        id: db
        property string label
        property string sub
        property string url
        property color fill
        property color ink: "white"
        property string glyph: ""
        width: (parent.width - 14) / 2
        height: 58
        radius: 12
        color: dbMa.pressed ? Qt.darker(fill, 1.15) : (dbMa.containsMouse ? Qt.lighter(fill, 1.08) : fill)
        scale: dbMa.pressed ? 0.98 : 1
        Behavior on scale { NumberAnimation { duration: 90 } }
        Row {
            anchors.centerIn: parent
            spacing: 12
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: db.glyph
                font.pixelSize: 24
                color: db.ink
            }
            Column {
                anchors.verticalCenter: parent.verticalCenter
                spacing: 1
                Text { text: db.label; color: db.ink; font.pixelSize: 15; font.weight: Font.Bold }
                Text { text: db.sub; color: db.ink; opacity: 0.75; font.pixelSize: 11 }
            }
        }
        MouseArea {
            id: dbMa
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: Qt.openUrlExternally(db.url)
        }
        Accessible.role: Accessible.Link
        Accessible.name: db.label
    }

    EdSection {
        title: i18n("Support SeaQ SoundWave")
        subtitle: i18n("If you like the widget, you can support its development – thank you!")
        boxPadding: 14
        Row {
            width: parent.width
            spacing: 14
            DonateButton {
                label: i18n("Donate with PayPal")
                sub: "paypal.me/SeaQSoft"
                url: "https://paypal.me/SeaQSoft"
                fill: "#0070ba"
                glyph: "♥"
            }
            DonateButton {
                label: i18n("Buy me a coffee")
                sub: "buymeacoffee.com/seaq"
                url: "https://buymeacoffee.com/seaq"
                fill: "#ffdd00"
                ink: "#1d1d1f"
                glyph: "☕"
            }
        }
    }

    EdSection {
        title: i18n("About")
        EdRow {
            first: true
            label: i18n("Audio visualizer for KDE Plasma 6")
            desc: i18n("19 styles in four groups, colour collection with gradient editor, orb with play/pause, panel attachment, fixed or free position on the desktop.")
        }
        EdRow { label: i18n("Author"); desc: "SeaQ" }
        EdRow { label: i18n("License"); desc: "GPL-3.0-or-later" }
    }

    EdSection {
        title: "Editor"
        EdRow {
            first: true
            label: i18n("Appearance")
            EdSegmented {
                anchors.right: parent.right
                model: [["auto", "Automatic"], ["light", "Light"], ["dark", "Dark"]]
                current: editor.cfg.editorTheme
                onPicked: (v) => editor.cfg.editorTheme = v
            }
        }
        EdRow {
            label: i18n("Logo in the taskbar")
            desc: i18n("Shows the SeaQ SoundWave logo instead of the Plasma logo while a settings window is open. Adds a hidden desktop file and a KWin window rule – switching it off removes both again.")
            EdSwitch {
                anchors.right: parent.right
                checked: editor.cfg.taskbarIcon
                onToggled: (v) => editor.cfg.taskbarIcon = v
            }
        }
    }

    property bool confirmAll: false

    EdSection {
        title: i18n("Reset")
        EdRow {
            first: true
            label: i18n("Everything to factory settings")
            desc: i18n("Style, style options, colours, position, orb, audio and editor – everything like right after installing. Your own palettes are kept.")
            EdButton {
                anchors.right: parent.right
                danger: true
                primary: pg.confirmAll
                text: pg.confirmAll ? i18n("Yes, reset everything") : i18n("Factory settings")
                onClicked: {
                    if (!pg.confirmAll) { pg.confirmAll = true; allTimer.restart(); return; }
                    editor.factoryReset();
                    pg.confirmAll = false;
                }
                Timer { id: allTimer; interval: 4000; onTriggered: pg.confirmAll = false }
            }
        }
        EdRow {
            label: i18n("Reset the options of all styles")
            desc: i18n("Sets the shape settings of every style back to the defaults")
            EdButton {
                anchors.right: parent.right
                danger: true
                text: pg.confirm ? i18n("Really?") : i18n("Reset")
                onClicked: {
                    if (!pg.confirm) { pg.confirm = true; confirmTimer.restart(); return; }
                    editor.cfg.styleOptions = "{}";
                    pg.confirm = false;
                }
                Timer { id: confirmTimer; interval: 3000; onTriggered: pg.confirm = false }
            }
        }
        EdRow {
            label: i18n("Reset colours")
            desc: i18n("macOS rainbow, colour flow on")
            EdButton {
                anchors.right: parent.right
                text: i18n("Reset")
                onClicked: editor.resetGroup("colors")
            }
        }
    }
}
