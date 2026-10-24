import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.kcmutils as KCM
import org.kde.plasma.plasmoid
import "js/styles.js" as Styles
import "js/palette.js" as Pal

// "Quick settings" in Plasma's own settings dialog: only the most
// important options (they apply immediately) and the button that opens
// the full settings editor.
KCM.SimpleKCM {
    id: page

    readonly property var cfg: Plasmoid.configuration

    readonly property var styleModel: Styles.STYLES.map(function (s) {
        return { text: i18n(Styles.groupName(s.group)) + "  ·  " + i18n(s.name), value: s.id };
    })
    readonly property var paletteModel: Pal.COLLECTION.map(function (p) {
        return { text: i18n(p.cat) + "  ·  " + i18n(p.name), value: p.id };
    })
    readonly property var placementModel: [
        { text: i18n("In the widget"), value: "widget" },
        { text: i18n("At the panel"), value: "panel" },
        { text: i18n("Fixed position on the screen"), value: "screen" },
        { text: i18n("Freely movable"), value: "free" }
    ]

    function indexOf(model, v) {
        for (var i = 0; i < model.length; i++)
            if (model[i].value === v)
                return i;
        return -1;
    }

    ColumnLayout {
        spacing: Kirigami.Units.largeSpacing * 2

        // Banner: a live "Colour waves" demo in macOS colours on a
        // Ventura-dark background, and the button to the settings editor in
        // the accent colour of the user's KDE theme.
        Rectangle {
            id: banner
            Layout.fillWidth: true
            Layout.preferredHeight: Kirigami.Units.gridUnit * 8
            radius: Kirigami.Units.cornerRadius * 2.5
            border.color: Qt.rgba(1, 1, 1, 0.08)
            clip: true

            gradient: Gradient {
                GradientStop { position: 0; color: "#2a2a2c" }
                GradientStop { position: 1; color: "#1c1c1e" }
            }

            Visualizer {
                anchors.fill: parent
                anchors.topMargin: parent.height * 0.2
                anchors.leftMargin: banner.radius
                anchors.rightMargin: banner.radius * 0.6
                anchors.bottomMargin: banner.radius * 0.35
                softRight: 46            // rounded end inside the card corner
                softBase: 6
                demo: true
                style: "macos-wave"
                paletteStops: ""          // empty = the built-in macOS palette
                colorShift: true
                colorShiftSpeed: 12
                orbInteractive: false
                fps: 30
            }

            // let the wave fade out behind the text
            Rectangle {
                anchors.fill: parent
                radius: banner.radius
                gradient: Gradient {
                    orientation: Gradient.Horizontal
                    GradientStop { position: 0.0; color: Qt.rgba(0.149, 0.149, 0.157, 1) }
                    GradientStop { position: 0.3; color: Qt.rgba(0.149, 0.149, 0.157, 0.9) }
                    GradientStop { position: 0.58; color: Qt.rgba(0.149, 0.149, 0.157, 0) }
                }
            }

            ColumnLayout {
                anchors.left: parent.left
                anchors.leftMargin: Kirigami.Units.gridUnit * 1.3
                anchors.verticalCenter: parent.verticalCenter
                spacing: Kirigami.Units.smallSpacing

                QQC2.Label {
                    text: "SeaQ SoundWave"
                    color: "white"
                    font.pointSize: Kirigami.Theme.defaultFont.pointSize * 1.7
                    font.weight: Font.Bold
                }
                QQC2.Label {
                    text: i18n("Quick settings · everything else in the settings editor")
                    color: "white"
                    opacity: 0.7
                }

                // accent-coloured button
                Rectangle {
                    id: openBtn
                    Layout.topMargin: Kirigami.Units.largeSpacing
                    implicitWidth: btnRow.implicitWidth + Kirigami.Units.gridUnit * 1.6
                    implicitHeight: Kirigami.Units.gridUnit * 2.1
                    radius: height / 2
                    readonly property color accent: Kirigami.Theme.highlightColor
                    color: btnMa.pressed ? Qt.darker(accent, 1.18) : (btnMa.containsMouse ? Qt.lighter(accent, 1.12) : accent)
                    border.color: Qt.lighter(accent, 1.35)
                    border.width: 1
                    scale: btnMa.pressed ? 0.97 : 1
                    Behavior on scale { NumberAnimation { duration: 90 } }
                    Behavior on color { ColorAnimation { duration: 120 } }

                    // soft glow in the accent colour
                    Rectangle {
                        z: -1
                        anchors.fill: parent
                        anchors.margins: -4
                        radius: height / 2
                        color: "transparent"
                        border.width: 4
                        border.color: Qt.rgba(openBtn.accent.r, openBtn.accent.g, openBtn.accent.b, btnMa.containsMouse ? 0.35 : 0.18)
                    }

                    RowLayout {
                        id: btnRow
                        anchors.centerIn: parent
                        spacing: Kirigami.Units.smallSpacing
                        Kirigami.Icon {
                            source: "configure"
                            color: Kirigami.Theme.highlightedTextColor
                            isMask: true
                            Layout.preferredWidth: Kirigami.Units.iconSizes.small
                            Layout.preferredHeight: Kirigami.Units.iconSizes.small
                        }
                        QQC2.Label {
                            text: i18n("Open settings editor…")
                            color: Kirigami.Theme.highlightedTextColor
                            font.weight: Font.DemiBold
                        }
                    }

                    MouseArea {
                        id: btnMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: page.cfg.editorRequest = String(Date.now())
                    }
                    Accessible.role: Accessible.Button
                    Accessible.name: i18n("Open settings editor…")
                }
            }
        }

        Kirigami.FormLayout {
            Layout.fillWidth: true

            QQC2.ComboBox {
                Kirigami.FormData.label: i18n("Style:")
                Layout.minimumWidth: Kirigami.Units.gridUnit * 16
                model: page.styleModel
                textRole: "text"
                valueRole: "value"
                currentIndex: page.indexOf(page.styleModel, page.cfg.vizStyle)
                onActivated: page.cfg.vizStyle = currentValue
            }

            QQC2.ComboBox {
                Kirigami.FormData.label: i18n("Colour palette:")
                Layout.minimumWidth: Kirigami.Units.gridUnit * 16
                model: page.paletteModel
                textRole: "text"
                valueRole: "value"
                currentIndex: page.indexOf(page.paletteModel, page.cfg.paletteName)
                displayText: currentIndex < 0 ? i18n("Custom colours") : currentText
                onActivated: {
                    page.cfg.palette = Pal.serialize(Pal.collectionStops(currentValue));
                    page.cfg.paletteName = currentValue;
                }
            }

            QQC2.CheckBox {
                text: i18n("Let the colours flow")
                checked: page.cfg.colorShift
                onToggled: page.cfg.colorShift = checked
            }

            Item { Kirigami.FormData.isSection: true }

            QQC2.ComboBox {
                Kirigami.FormData.label: i18n("Placement:")
                Layout.minimumWidth: Kirigami.Units.gridUnit * 16
                model: page.placementModel
                textRole: "text"
                valueRole: "value"
                currentIndex: page.indexOf(page.placementModel, page.cfg.placement)
                onActivated: page.cfg.placement = currentValue
            }

            QQC2.Label {
                Layout.maximumWidth: Kirigami.Units.gridUnit * 24
                wrapMode: Text.WordWrap
                opacity: 0.75
                text: i18n("Move freely, lock and unlock again: shortcut %1 (change it on the “Keyboard Shortcuts” page or in the settings editor).", page.cfg.shortcutText)
            }

            Item { Kirigami.FormData.isSection: true }

            RowLayout {
                Kirigami.FormData.label: i18n("Sensitivity:")
                QQC2.Slider {
                    id: sens
                    Layout.preferredWidth: Kirigami.Units.gridUnit * 12
                    from: 10
                    to: 300
                    stepSize: 5
                    value: page.cfg.sensitivity
                    onMoved: page.cfg.sensitivity = Math.round(value)
                }
                QQC2.Label { text: Math.round(sens.value) + " %" }
            }

            QQC2.ComboBox {
                Kirigami.FormData.label: i18n("Clicking the orb:")
                model: [{ text: i18n("Pause / resume audio and video"), value: "playpause" }, { text: i18n("Do nothing"), value: "none" }]
                textRole: "text"
                valueRole: "value"
                currentIndex: page.cfg.orbAction === "none" ? 1 : 0
                onActivated: page.cfg.orbAction = currentValue
            }
        }
    }
}
