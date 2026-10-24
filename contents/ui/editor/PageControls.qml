import QtQuick

Column {
    id: pg
    spacing: 26
    readonly property var app: editor.app

    component Step: Item {
        id: st
        property int n
        property string title
        property string text
        width: parent.width
        height: Math.max(40, stepCol.implicitHeight + 14)
        Rectangle {
            id: num
            x: 16
            y: 8
            width: 24
            height: 24
            radius: 12
            color: editor.c.accent
            Text { anchors.centerIn: parent; text: st.n; color: "white"; font.pixelSize: 12; font.weight: Font.Bold }
        }
        Column {
            id: stepCol
            anchors.left: num.right
            anchors.leftMargin: 12
            anchors.right: parent.right
            anchors.rightMargin: 16
            y: 8
            spacing: 2
            Text { width: parent.width; text: st.title; color: editor.c.text; font.pixelSize: 13; font.weight: Font.DemiBold; wrapMode: Text.WordWrap }
            Text { width: parent.width; text: st.text; color: editor.c.sub; font.pixelSize: 12; wrapMode: Text.WordWrap }
        }
    }

    component KeyCap: Rectangle {
        property string label
        height: 24
        width: capText.implicitWidth + 16
        radius: 6
        color: editor.c.btn
        border.color: editor.c.border
        Rectangle { anchors.bottom: parent.bottom; width: parent.width; height: 2; radius: 1; color: editor.c.border }
        Text { id: capText; anchors.centerIn: parent; text: parent.label; color: editor.c.text; font.pixelSize: 12; font.family: "monospace" }
    }

    EdSection {
        title: i18n("Keyboard shortcut")
        subtitle: i18n("A global shortcut for free positioning – it works everywhere, even when a window is in front.")
        EdRow {
            first: true
            label: i18n("Move freely / lock / unlock")
            desc: i18n("Current: %1. Click the field and press the new combination.", pg.app ? pg.app.shortcutText : "")
            controlWidth: 300
            Loader {
                id: ksLoader
                anchors.right: parent.right
                source: "ShortcutField.qml"
                onLoaded: item.app = pg.app
            }
            Text {
                anchors.right: parent.right
                visible: ksLoader.status === Loader.Error
                text: i18n("Change it via right click → Configure → Keyboard Shortcuts")
                color: editor.c.sub
                font.pixelSize: 11
            }
        }
    }

    EdSection {
        title: i18n("How free positioning works")
        boxPadding: 6
        Step { n: 1; title: i18n("Unlock"); text: i18n("Press %1 (or choose “Position” → “Free”, or the lock on the pop-up card). A blue frame appears around the visualizer.", pg.app ? pg.app.shortcutText : "") }
        Step { n: 2; title: i18n("Move & resize"); text: i18n("Drag the frame with the mouse. The handles on every edge and corner change the size, the mouse wheel zooms, arrow keys move by 1 px (with Shift 10 px), + and − scale. It snaps to the centre of the screen.") }
        Step { n: 3; title: i18n("Lock"); text: i18n("%1 again, Enter, Esc, a double click or the “Lock” button. Afterwards the visualizer lies behind all windows again and lets clicks through to the desktop.", pg.app ? pg.app.shortcutText : "") }
        Step { n: 4; title: i18n("Unlock again"); text: i18n("Any time with the same shortcut – the widget itself stays where it is.") }
    }

    EdSection {
        title: i18n("Mouse & menus")
        EdRow {
            first: true
            label: i18n("Click on the orb")
            desc: i18n("Pauses or resumes audio and video (see “Orb & playback”)")
            Row { anchors.right: parent.right; spacing: 6; KeyCap { label: i18n("Click") } }
        }
        EdRow {
            label: i18n("Right click on the visualizer")
            desc: i18n("Opens the pop-up card – or, with the card switched off, the menu")
            Row { anchors.right: parent.right; spacing: 6; KeyCap { label: i18n("Right click") } }
        }
        EdRow {
            label: i18n("Quick settings")
            desc: i18n("“Configure SeaQ SoundWave…” shows the most important options and the button to this editor")
        }
        EdRow {
            label: i18n("Close the editor")
            Row { anchors.right: parent.right; spacing: 6; KeyCap { label: "Esc" } }
        }
    }
}
