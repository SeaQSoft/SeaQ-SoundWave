import QtQuick
import "../js/palette.js" as Pal

Column {
    id: pg
    spacing: 26
    property string cat: "all"

    readonly property var custom: {
        try {
            var l = JSON.parse(editor.cfg.customPalettes || "[]");
            return Array.isArray(l) ? l : [];
        } catch (e) {
            return [];
        }
    }

    function removeCustom(i) {
        var l = custom.slice();
        var gone = l.splice(i, 1);
        editor.cfg.customPalettes = JSON.stringify(l);
        if (gone.length && editor.cfg.paletteName === "custom:" + gone[0].name)
            editor.cfg.paletteName = "";
    }

    EdSection {
        title: i18n("Colour collection")
        subtitle: i18n("One click recolours the visualizer at once – save your own palettes in the gradient editor.")
        boxPadding: 18
        trailing: EdSegmented {
            model: [["all", "All"]].concat(Pal.CATEGORIES.map(function (c) { return [c, c]; })).concat([["mine", "Mine"]])
            current: pg.cat
            onPicked: (v) => pg.cat = v
        }

        Flow {
            width: parent.width
            spacing: 16
            Repeater {
                model: Pal.COLLECTION
                delegate: PaletteSwatch {
                    required property var modelData
                    visible: pg.cat === "all" || pg.cat === modelData.cat
                    width: Math.floor((parent.width - 4 * 16) / 5)
                    stops: Pal.collectionStops(modelData.id)
                    name: i18n(modelData.name)
                    selected: editor.cfg.paletteName === modelData.id
                    onPicked: {
                        editor.cfg.palette = Pal.serialize(Pal.collectionStops(modelData.id));
                        editor.cfg.paletteName = modelData.id;
                    }
                }
            }
            Repeater {
                model: pg.custom
                delegate: PaletteSwatch {
                    required property var modelData
                    required property int index
                    visible: pg.cat === "all" || pg.cat === "mine"
                    width: Math.floor((parent.width - 4 * 16) / 5)
                    stops: modelData.stops
                    name: modelData.name
                    removable: true
                    selected: editor.cfg.paletteName === "custom:" + modelData.name
                    onPicked: {
                        editor.cfg.palette = Pal.serialize(Pal.parse(modelData.stops));
                        editor.cfg.paletteName = "custom:" + modelData.name;
                    }
                    onRemoved: pg.removeCustom(index)
                }
            }
        }
        Text {
            visible: pg.cat === "mine" && pg.custom.length === 0
            width: parent.width
            topPadding: 6
            wrapMode: Text.WordWrap
            color: editor.c.sub
            font.pixelSize: 13
            text: i18n("No palettes of your own yet. Put colours together in the gradient editor below and click “Save”.")
        }
    }

    Column {
        width: parent.width
        spacing: 8
        Text {
            leftPadding: 4
            text: i18n("Gradient editor")
            color: editor.c.text
            font.pixelSize: 14
            font.weight: Font.DemiBold
        }
        Text {
            leftPadding: 4
            width: parent.width
            wrapMode: Text.WordWrap
            text: i18n("Drag the points on the colour bar, click the bar to add a colour. The preview on the right shows the gradient or – with the button at its top right – your visualizer.")
            color: editor.c.sub
            font.pixelSize: 12
        }
        GradientEditor {
            width: parent.width
            cfg: editor.cfg
            liveValues: editor.app && editor.hasSignal(editor.app.barValues) ? editor.app.barValues : []
            styleId: editor.cfg.vizStyle
        }
    }

    EdSection {
        title: i18n("Colour flow")
        trailing: EdButton { text: i18n("Reset colours"); onClicked: editor.resetGroup("colors") }
        EdRow {
            first: true
            label: i18n("Let the colours flow")
            desc: i18n("The palette slowly moves through the visualizer – like the macOS colour waves")
            EdSwitch {
                anchors.right: parent.right
                checked: editor.cfg.colorShift
                onToggled: (v) => editor.cfg.colorShift = v
            }
        }
        EdRow {
            label: i18n("Speed")
            enabledState: editor.cfg.colorShift
            EdSlider {
                width: parent.width
                from: 1; to: 100; unit: "%"
                value: editor.cfg.colorShiftSpeed
                enabledState: editor.cfg.colorShift
                onMoved: (v) => editor.cfg.colorShiftSpeed = Math.round(v)
            }
        }
    }
}
