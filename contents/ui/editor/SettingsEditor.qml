import QtQuick
import QtQuick.Window
import QtQuick.Controls as QQC2
import org.kde.kirigami as Kirigami
import "../js/styles.js" as Styles
import "../js/palette.js" as Pal
import "../js/defaults.js" as Defaults

// The big settings editor, styled like the macOS System Settings: a
// sidebar with coloured icon tiles and rounded, grouped cards. It is a normal
// window, so KWin draws the KDE title bar and borders. All changes apply live.
Window {
    id: editor

    property var app
    readonly property var cfg: app ? app.cfg : ({})
    property int page: 0
    property string search: ""

    readonly property var info: Styles.byId(cfg.vizStyle)
    readonly property var opts: Styles.resolve(cfg.vizStyle, cfg.styleOptions)

    function resetGroup(name) {
        Defaults.resetKeys(cfg, Defaults.GROUPS[name]);
    }

    function resetOrb() {
        Defaults.resetKeys(cfg, Defaults.GROUPS.orb);
        // the shared orb settings apply to all styles; the size of this style too
        var all = Styles.parseAll(cfg.styleOptions);
        delete all[Styles.GLOBAL_KEY];
        var mine = all[cfg.vizStyle];
        if (mine)
            for (var k in mine)
                if (k.indexOf("orb") === 0)
                    delete mine[k];
        cfg.styleOptions = JSON.stringify(all);
    }

    function factoryReset() {
        Defaults.resetAll(cfg);
        if (app && app.unlocked)
            app.toggleLock();
    }

    function setOpt(key, value) {
        cfg.styleOptions = Styles.withValue(cfg.styleOptions, cfg.vizStyle, key, value);
    }

    // style option sections that the current style really uses (orb keys live on their own page)
    function sectionsForStyle() {
        var out = [];
        for (var i = 0; i < Styles.SECTIONS.length; i++) {
            var sec = Styles.SECTIONS[i];
            if (sec.name === "Orb")
                continue;
            var keys = [];
            for (var k = 0; k < sec.keys.length; k++)
                if (info.opts.indexOf(sec.keys[k]) >= 0)
                    keys.push(sec.keys[k]);
            if (keys.length)
                out.push({ name: sec.name, keys: keys });
        }
        return out;
    }

    function orbKeys() {
        var out = [];
        for (var i = 0; i < info.opts.length; i++)
            if (String(info.opts[i]).indexOf("orb") === 0)
                out.push(info.opts[i]);
        return out;
    }

    function hasSignal(v) {
        if (!v)
            return false;
        for (var i = 0; i < v.length; i++)
            if (v[i] > 0.03)
                return true;
        return false;
    }

    Component.onCompleted: page = Math.max(0, Math.min(pages.length - 1, Number(cfg.editorPage) || 0))
    onPageChanged: if (app) cfg.editorPage = page

    readonly property bool dark: cfg.editorTheme === "dark"
        || (cfg.editorTheme !== "light" && Kirigami.Theme.backgroundColor.hslLightness < 0.5)

    readonly property QtObject c: QtObject {
        readonly property color bg:         editor.dark ? "#1e1e20" : "#f3f2f7"
        readonly property color side:       editor.dark ? "#28282b" : "#e6e5ea"
        readonly property color card:       editor.dark ? "#2b2b2e" : "#ffffff"
        readonly property color cardBorder: editor.dark ? "#3a3a3d" : "#dedde3"
        readonly property color sep:        editor.dark ? "#3a3a3d" : "#e6e6eb"
        readonly property color text:       editor.dark ? "#f5f5f7" : "#1d1d1f"
        readonly property color sub:        editor.dark ? "#9a9aa0" : "#6e6e73"
        readonly property color accent:     editor.dark ? "#0a84ff" : "#007aff"
        readonly property color field:      editor.dark ? "#1c1c1e" : "#ffffff"
        readonly property color border:     editor.dark ? "#48484b" : "#d1d1d6"
        readonly property color btn:        editor.dark ? "#3a3a3d" : "#ffffff"
        readonly property color btnHover:   editor.dark ? "#47474b" : "#f2f2f5"
        readonly property color pressed:    editor.dark ? "#545458" : "#e5e5ea"
        readonly property color red:        editor.dark ? "#ff453a" : "#ff3b30"
        readonly property color green:      editor.dark ? "#30d158" : "#34c759"
        readonly property color orange:     editor.dark ? "#ff9f0a" : "#ff9500"
        readonly property color track:      editor.dark ? "#4a4a4e" : "#d1d1d6"
        readonly property color segBg:      editor.dark ? "#1f1f22" : "#e4e4e9"
        readonly property color segSel:     editor.dark ? "#5b5b60" : "#ffffff"
        readonly property color hover:      editor.dark ? Qt.rgba(1, 1, 1, 0.06) : Qt.rgba(0, 0, 0, 0.05)
        readonly property color menu:       editor.dark ? "#2c2c2f" : "#ffffff"
        readonly property color frame:      editor.dark ? Qt.rgba(1, 1, 1, 0.13) : Qt.rgba(0, 0, 0, 0.16)
    }

    readonly property var pages: [
        { title: "Style",              sub: "Choose how your music looks",                  kind: "wave",    tint: "#bf5af2", file: "PageStyle.qml",    sec: "Appearance",
          kw: "style visualizer bars wave helix laser strings ring led skyline rainbow kaleidoscope" },
        { title: "Style options",      sub: "Adapts to the selected style",                 kind: "sliders", tint: "#0a84ff", file: "PageLook.qml",     sec: "Appearance",
          kw: "options lines width glow spacing radius opacity smoothing background" },
        { title: "Colours",            sub: "Colour collection and gradient editor",        kind: "palette", tint: "#ff375f", file: "PageColors.qml",   sec: "Appearance",
          kw: "colours colors palette gradient collection flow" },
        { title: "Position",           sub: "In the widget, at the panel, fixed or free",   kind: "place",   tint: "#30d158", file: "PagePosition.qml", sec: "Behaviour",
          kw: "position taskbar panel free move attach screen gap corner popup" },
        { title: "Orb & playback",     sub: "The orb in the middle – a click pauses",       kind: "orb",     tint: "#ff9f0a", file: "PageOrb.qml",      sec: "Behaviour",
          kw: "orb pause play playback video audio mpris" },
        { title: "Audio",              sub: "Source, sensitivity and frame rate",           kind: "audio",   tint: "#ff453a", file: "PageAudio.qml",    sec: "System",
          kw: "audio source cava pipewire pulse sensitivity frame rate fps bands" },
        { title: "Controls & shortcuts", sub: "Keyboard shortcuts and mouse gestures",      kind: "grid",    tint: "#8e8e93", file: "PageControls.qml", sec: "System",
          kw: "shortcut keyboard lock unlock controls mouse help" },
        { title: "About",              sub: "SeaQ SoundWave",                               kind: "info",    tint: "#636366", file: "PageAbout.qml",    sec: "System",
          kw: "about version author reset factory design light dark" }
    ]

    function matches(i) {
        var q = search.trim().toLowerCase();
        if (q === "")
            return true;
        var p = pages[i];
        return (i18n(p.title) + " " + i18n(p.sub) + " " + p.title + " " + p.kw).toLowerCase().indexOf(q) >= 0;
    }

    title: i18n("SeaQ SoundWave – Settings")
    width: 1100
    height: 760
    minimumWidth: 900
    minimumHeight: 580
    // a normal window: KWin draws its title bar, buttons and borders in the
    // decoration chosen in the KDE settings (resizable everywhere)
    flags: Qt.Window | Qt.WindowTitleHint | Qt.WindowSystemMenuHint
           | Qt.WindowMinMaxButtonsHint | Qt.WindowCloseButtonHint
    color: editor.c.bg
    transientParent: null

    Shortcut { sequences: [StandardKey.Close, "Esc"]; onActivated: editor.close() }
    Shortcut { sequences: [StandardKey.Find]; onActivated: searchInput.forceActiveFocus() }

    Rectangle {
        id: frame
        anchors.fill: parent
        color: editor.c.bg

        // ---------------- sidebar ----------------
        Rectangle {
            id: sidebar
            width: 248
            height: parent.height
            color: editor.c.side

            // search field
            Rectangle {
                id: searchBox
                x: 12
                y: 14
                width: parent.width - 24
                height: 30
                radius: 8
                color: editor.dark ? Qt.rgba(1, 1, 1, 0.07) : Qt.rgba(0, 0, 0, 0.06)
                border.color: searchInput.activeFocus ? editor.c.accent : "transparent"
                border.width: 2
                Text {
                    x: 10
                    anchors.verticalCenter: parent.verticalCenter
                    text: "⌕"
                    color: editor.c.sub
                    font.pixelSize: 16
                }
                TextInput {
                    id: searchInput
                    anchors.fill: parent
                    anchors.leftMargin: 30
                    anchors.rightMargin: 10
                    verticalAlignment: TextInput.AlignVCenter
                    color: editor.c.text
                    font.pixelSize: 13
                    clip: true
                    selectByMouse: true
                    onTextChanged: editor.search = text
                    onAccepted: {
                        for (var i = 0; i < editor.pages.length; i++)
                            if (editor.matches(i)) { editor.page = i; break; }
                    }
                    Keys.onEscapePressed: { text = ""; focus = false; }
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        visible: !parent.text && !parent.activeFocus
                        text: i18n("Search")
                        color: editor.c.sub
                        font.pixelSize: 13
                    }
                }
            }

            Flickable {
                anchors.top: searchBox.bottom
                anchors.topMargin: 12
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: statusCard.top
                anchors.bottomMargin: 8
                contentHeight: sideCol.implicitHeight
                clip: true
                boundsBehavior: Flickable.StopAtBounds

                Column {
                    id: sideCol
                    width: parent.width
                    spacing: 2

                    // app card
                    Item {
                        width: parent.width
                        height: 64
                        visible: editor.search === ""
                        Image {
                            id: appIcon
                            x: 12
                            anchors.verticalCenter: parent.verticalCenter
                            width: 46
                            height: 46
                            source: Qt.resolvedUrl("../../icons/seaq-soundwave-128.png")
                            sourceSize: Qt.size(92, 92)
                            smooth: true
                            mipmap: true
                        }
                        Column {
                            anchors.left: appIcon.right
                            anchors.leftMargin: 10
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 1
                            Text { text: "SeaQ SoundWave"; color: editor.c.text; font.pixelSize: 14; font.weight: Font.DemiBold }
                            Text { text: i18n(editor.info.name) + " · " + i18n(Styles.groupName(editor.info.group)); color: editor.c.sub; font.pixelSize: 11; elide: Text.ElideRight; width: parent.width - 8 }
                        }
                    }

                    Repeater {
                        model: editor.pages
                        delegate: Column {
                            id: entry
                            required property var modelData
                            required property int index
                            width: sideCol.width
                            visible: editor.matches(index)
                            readonly property bool newSection: index === 0 || editor.pages[index - 1].sec !== modelData.sec

                            Text {
                                visible: entry.newSection && editor.search === ""
                                leftPadding: 20
                                topPadding: entry.index === 0 ? 4 : 12
                                bottomPadding: 4
                                text: i18n(entry.modelData.sec)
                                color: editor.c.sub
                                font.pixelSize: 11
                                font.weight: Font.DemiBold
                            }
                            Rectangle {
                                x: 10
                                width: parent.width - 20
                                height: 34
                                radius: 7
                                readonly property bool sel: editor.page === entry.index
                                color: sel ? editor.c.accent : (rowMa.containsMouse ? editor.c.hover : "transparent")
                                SideIcon {
                                    x: 8
                                    anchors.verticalCenter: parent.verticalCenter
                                    size: 22
                                    kind: entry.modelData.kind
                                    tint: entry.modelData.tint
                                }
                                Text {
                                    x: 40
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: i18n(entry.modelData.title)
                                    color: parent.sel ? "white" : editor.c.text
                                    font.pixelSize: 13
                                }
                                MouseArea {
                                    id: rowMa
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    onClicked: editor.page = entry.index
                                }
                            }
                        }
                    }
                }
            }

            // live status at the bottom of the sidebar
            Rectangle {
                id: statusCard
                x: 12
                width: parent.width - 24
                anchors.bottom: parent.bottom
                anchors.bottomMargin: 12
                height: 54
                radius: 10
                color: editor.dark ? Qt.rgba(1, 1, 1, 0.05) : Qt.rgba(0, 0, 0, 0.04)
                Rectangle {
                    id: dot
                    x: 12
                    anchors.verticalCenter: parent.verticalCenter
                    width: 8
                    height: 8
                    radius: 4
                    color: !editor.app ? editor.c.sub
                         : (editor.app.errorText !== "" ? editor.c.red
                         : (editor.hasSignal(editor.app.barValues) ? editor.c.green : editor.c.orange))
                }
                Column {
                    anchors.left: dot.right
                    anchors.leftMargin: 10
                    anchors.right: ppBtn.left
                    anchors.rightMargin: 6
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 1
                    Text {
                        width: parent.width
                        elide: Text.ElideRight
                        text: !editor.app ? "" : (editor.app.errorText !== "" ? i18n("Audio engine stopped")
                              : (editor.hasSignal(editor.app.barValues) ? i18n("Music detected") : i18n("Waiting for sound…")))
                        color: editor.c.text
                        font.pixelSize: 12
                        font.weight: Font.Medium
                    }
                    Text {
                        width: parent.width
                        elide: Text.ElideRight
                        text: editor.app && editor.app.mediaPlayer !== ""
                              ? editor.app.mediaPlayer + " · " + (editor.app.mediaPlaying ? i18n("playing") : i18n("paused"))
                              : i18n("No player found")
                        color: editor.c.sub
                        font.pixelSize: 11
                    }
                }
                Rectangle {
                    id: ppBtn
                    anchors.right: parent.right
                    anchors.rightMargin: 10
                    anchors.verticalCenter: parent.verticalCenter
                    width: 30
                    height: 30
                    radius: 15
                    color: ppMa.pressed ? editor.c.pressed : (ppMa.containsMouse ? editor.c.btnHover : editor.c.btn)
                    border.color: editor.c.border
                    Canvas {
                        anchors.fill: parent
                        property bool playing: editor.app ? editor.app.mediaPlaying : true
                        property color ink: editor.c.text
                        onPlayingChanged: requestPaint()
                        onInkChanged: requestPaint()
                        onPaint: {
                            var g = getContext("2d");
                            g.reset();
                            g.fillStyle = ink;
                            var cx = width / 2, cy = height / 2;
                            if (playing) {
                                g.fillRect(cx - 5, cy - 6, 3.5, 12);
                                g.fillRect(cx + 1.5, cy - 6, 3.5, 12);
                            } else {
                                g.beginPath();
                                g.moveTo(cx - 3.5, cy - 6.5);
                                g.lineTo(cx + 6, cy);
                                g.lineTo(cx - 3.5, cy + 6.5);
                                g.closePath();
                                g.fill();
                            }
                        }
                    }
                    MouseArea {
                        id: ppMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: if (editor.app) editor.app.mediaToggle()
                    }
                }
            }
        }

        Rectangle {
            x: sidebar.x + sidebar.width
            y: 1
            width: 1
            height: parent.height - 2
            color: editor.c.sep
        }

        // ---------------- content ----------------
        Item {
            id: content
            anchors.left: sidebar.right
            anchors.leftMargin: 1
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            anchors.margins: 0

            Item {
                id: header
                width: parent.width
                height: 58
                Row {
                    x: 20
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 6
                    Repeater {
                        model: [-1, 1]
                        delegate: Rectangle {
                            required property int modelData
                            readonly property bool can: modelData < 0 ? editor.page > 0 : editor.page < editor.pages.length - 1
                            width: 26
                            height: 26
                            radius: 6
                            color: navMa.containsMouse && can ? editor.c.hover : "transparent"
                            Text {
                                anchors.centerIn: parent
                                text: parent.modelData < 0 ? "‹" : "›"
                                font.pixelSize: 22
                                color: parent.can ? editor.c.text : editor.c.sub
                                opacity: parent.can ? 0.9 : 0.4
                            }
                            MouseArea {
                                id: navMa
                                anchors.fill: parent
                                hoverEnabled: true
                                onClicked: if (parent.can) editor.page += parent.modelData
                            }
                        }
                    }
                    Item { width: 6; height: 1 }
                    Column {
                        anchors.verticalCenter: parent.verticalCenter
                        Text {
                            text: i18n(editor.pages[editor.page].title)
                            color: editor.c.text
                            font.pixelSize: 17
                            font.weight: Font.Bold
                        }
                        Text {
                            text: i18n(editor.pages[editor.page].sub)
                            color: editor.c.sub
                            font.pixelSize: 11
                        }
                    }
                }
            }
            Rectangle {
                anchors.top: header.bottom
                width: parent.width
                height: 1
                color: editor.c.sep
                opacity: flick.contentY > 2 ? 1 : 0
                Behavior on opacity { NumberAnimation { duration: 120 } }
            }

            Flickable {
                id: flick
                anchors.top: header.bottom
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                contentWidth: width
                contentHeight: pageLoader.item ? pageLoader.item.implicitHeight + 56 : 0
                clip: true
                boundsBehavior: Flickable.StopAtBounds
                QQC2.ScrollBar.vertical: QQC2.ScrollBar { policy: QQC2.ScrollBar.AsNeeded }

                Loader {
                    id: pageLoader
                    x: 28
                    y: 18
                    width: Math.min(flick.width - 56, 980)
                    source: editor.pages[editor.page].file
                    onSourceChanged: flick.contentY = 0
                    onStatusChanged: if (status === Loader.Error) console.warn("SeaQ SoundWave: page failed: " + source)
                }
            }
        }
    }
}
