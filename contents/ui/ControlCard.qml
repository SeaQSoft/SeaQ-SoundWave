import QtQuick
import QtQuick.Layouts
import org.kde.plasma.components as PlasmaComponents3
import org.kde.kirigami as Kirigami
import "js/styles.js" as Styles

// The small card the widget shrinks to while the visualizer floats on
// the desktop: a live mini preview plus the most important controls.
Rectangle {
    id: card

    property var host

    readonly property bool narrow: width < Kirigami.Units.gridUnit * 10
    readonly property var placementNames: ({
        "panel": i18n("At the panel"), "screen": i18n("Fixed position"), "free": i18n("Placed freely"), "widget": i18n("In the widget")
    })

    radius: 14
    color: Qt.rgba(Kirigami.Theme.backgroundColor.r, Kirigami.Theme.backgroundColor.g, Kirigami.Theme.backgroundColor.b, 0.86)
    border.width: 1
    border.color: Qt.rgba(Kirigami.Theme.textColor.r, Kirigami.Theme.textColor.g, Kirigami.Theme.textColor.b, 0.12)

    RowLayout {
        anchors.fill: parent
        anchors.margins: Kirigami.Units.smallSpacing * 2
        spacing: Kirigami.Units.smallSpacing * 2

        Rectangle {
            Layout.preferredWidth: Math.min(card.height - Kirigami.Units.smallSpacing * 4, Kirigami.Units.gridUnit * 3) * 1.4
            Layout.preferredHeight: Math.min(card.height - Kirigami.Units.smallSpacing * 4, Kirigami.Units.gridUnit * 3)
            Layout.alignment: Qt.AlignVCenter
            radius: 9
            color: "#14100f"
            clip: true
            visible: !card.narrow || card.width > Kirigami.Units.gridUnit * 6

            Visualizer {
                anchors.fill: parent
                anchors.margins: 3
                values: card.host.barValues
                style: card.host.cfg.vizStyle
                optionsJson: card.host.cfg.styleOptions
                paletteStops: card.host.paletteJson
                colorShift: card.host.cfg.colorShift
                colorShiftSpeed: card.host.cfg.colorShiftSpeed
                fps: 24
                orbInteractive: false
                mediaPlaying: card.host.mediaPlaying
                mediaArt: card.host.mediaArt || ""
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignVCenter
            spacing: 0
            visible: !card.narrow

            PlasmaComponents3.Label {
                Layout.fillWidth: true
                text: "SeaQ SoundWave"
                font.weight: Font.DemiBold
                elide: Text.ElideRight
            }
            PlasmaComponents3.Label {
                Layout.fillWidth: true
                text: i18n(Styles.byId(card.host.cfg.vizStyle).name) + " · "
                      + (card.host.unlocked ? i18n("Moving active") : (card.placementNames[card.host.placement] || ""))
                opacity: 0.7
                font.pointSize: Kirigami.Theme.smallFont.pointSize
                elide: Text.ElideRight
            }
        }

        // Play / pause: a round button in the accent colour of the KDE theme,
        // with its own drawn symbol so it is always clearly visible.
        Rectangle {
            id: ppButton
            Layout.alignment: Qt.AlignVCenter
            Layout.preferredWidth: Kirigami.Units.gridUnit * 2
            Layout.preferredHeight: Kirigami.Units.gridUnit * 2
            radius: width / 2
            readonly property color accent: Kirigami.Theme.highlightColor
            color: ppMa.pressed ? Qt.darker(accent, 1.2) : (ppMa.containsMouse ? Qt.lighter(accent, 1.15) : accent)
            border.color: Qt.lighter(accent, 1.4)
            border.width: 1
            scale: ppMa.pressed ? 0.94 : 1
            Behavior on scale { NumberAnimation { duration: 90 } }

            Canvas {
                id: ppGlyph
                anchors.fill: parent
                property bool playing: card.host.mediaPlaying
                property color ink: Kirigami.Theme.highlightedTextColor
                onPlayingChanged: requestPaint()
                onInkChanged: requestPaint()
                onPaint: {
                    var c = getContext("2d");
                    c.reset();
                    c.fillStyle = ink;
                    var cx = width / 2, cy = height / 2, s = width * 0.26;
                    if (playing) {
                        var bw = s * 0.62, gap = s * 0.42;
                        c.beginPath();
                        c.roundedRect(cx - gap / 2 - bw, cy - s, bw, s * 2, bw * 0.35, bw * 0.35);
                        c.roundedRect(cx + gap / 2, cy - s, bw, s * 2, bw * 0.35, bw * 0.35);
                        c.fill();
                    } else {
                        c.beginPath();
                        c.moveTo(cx - s * 0.7, cy - s);
                        c.lineTo(cx + s * 1.05, cy);
                        c.lineTo(cx - s * 0.7, cy + s);
                        c.closePath();
                        c.fill();
                    }
                }
            }

            MouseArea {
                id: ppMa
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: card.host.mediaToggle()
            }
            PlasmaComponents3.ToolTip.text: card.host.mediaPlaying ? i18n("Pause") : i18n("Resume")
            PlasmaComponents3.ToolTip.visible: ppMa.containsMouse
            Accessible.role: Accessible.Button
            Accessible.name: card.host.mediaPlaying ? i18n("Pause") : i18n("Resume")
        }
        PlasmaComponents3.ToolButton {
            icon.name: card.host.unlocked ? "object-unlocked" : (card.host.placement === "free" ? "object-locked" : "transform-move")
            checkable: false
            highlighted: card.host.unlocked
            onClicked: { card.host.popupOpen = false; card.host.toggleLock(); }
            PlasmaComponents3.ToolTip.text: card.host.unlocked ? i18n("Lock position (%1)", card.host.shortcutText)
                                                               : i18n("Move freely (%1)", card.host.shortcutText)
            PlasmaComponents3.ToolTip.visible: hovered
        }
        PlasmaComponents3.ToolButton {
            icon.name: "configure"
            onClicked: { card.host.popupOpen = false; card.host.openEditor(); }
            PlasmaComponents3.ToolTip.text: i18n("Settings editor")
            PlasmaComponents3.ToolTip.visible: hovered
        }
    }
}
