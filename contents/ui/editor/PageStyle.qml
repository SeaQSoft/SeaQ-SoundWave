import QtQuick
import "../js/styles.js" as Styles

Column {
    id: pg
    spacing: 26

    // hero: big live preview of the current style
    Item {
        width: parent.width
        height: 270
        LivePreview {
            anchors.fill: parent
        }
        Column {
            anchors.left: parent.left
            anchors.bottom: parent.bottom
            anchors.margins: 18
            spacing: 2
            Text {
                text: i18n(editor.info.name)
                color: "white"
                font.pixelSize: 24
                font.weight: Font.Bold
                style: Text.Raised
                styleColor: Qt.rgba(0, 0, 0, 0.5)
            }
            Text {
                text: i18n(editor.info.desc) + "  ·  " + i18n(Styles.groupName(editor.info.group))
                color: "white"
                opacity: 0.8
                font.pixelSize: 13
            }
        }
        Row {
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            anchors.margins: 16
            spacing: 8
            EdButton {
                text: i18n("Random")
                onClicked: {
                    var all = Styles.STYLES, id = editor.cfg.vizStyle;
                    while (id === editor.cfg.vizStyle)
                        id = all[Math.floor(Math.random() * all.length)].id;
                    editor.cfg.vizStyle = id;
                }
            }
            EdButton {
                text: i18n("Adjust options") + "  ›"
                primary: true
                onClicked: editor.page = 1
            }
        }
    }

    Repeater {
        model: Styles.GROUPS
        delegate: EdSection {
            id: sec
            required property var modelData
            title: i18n(modelData.name)
            subtitle: i18n(modelData.desc)
            boxPadding: 16
            Flow {
                width: parent.width
                spacing: 16
                Repeater {
                    model: Styles.inGroup(sec.modelData.id)
                    delegate: StyleTile {
                        required property var modelData
                        info: modelData
                        width: Math.floor((sec.width - 32 - 3 * 16) / 4)
                        selected: editor.cfg.vizStyle === modelData.id
                        paletteStops: editor.cfg.palette
                        colorShift: editor.cfg.colorShift
                        onPicked: editor.cfg.vizStyle = modelData.id
                    }
                }
            }
        }
    }
}
