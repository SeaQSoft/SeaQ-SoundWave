import QtQuick
import "js/render.js" as R
import "js/palette.js" as Pal
import "js/styles.js" as Styles

// One visualizer surface: the canvas with the chosen style plus, for the
// styles that have one, the orb in the middle (click = pause / resume).
Item {
    id: viz

    // spectrum 0..1 per band; empty + demo = animated fake spectrum (previews)
    property var values: []
    property bool demo: false
    property bool running: true
    property int fps: 60
    property real quality: 1

    property string style: "macos-wave"
    property var optionsJson: "{}"
    property var paletteStops: ""
    property string colorMapping: "auto"
    property int gradientAngle: 90
    property bool colorShift: true
    property int colorShiftSpeed: 12
    property real opacityLevel: 1
    property real smoothing: 0.35

    // soft rounded ends above a floating panel
    property real softLeft: 0
    property real softRight: 0
    property real softBase: 8

    // true while nothing plays (set by the widget); together with "settled"
    // (everything has faded out) still pictures stop being redrawn
    property bool idle: false
    property bool settled: false

    // fixed time in seconds instead of the real clock (-1 = real clock);
    // used for recordings, where every frame is rendered at an exact time
    property real clock: -1
    onClockChanged: if (clock >= 0) canvas.requestPaint()
    property real orbTurn: -1            // recordings: fixed angle of the record
    property real orbArmAngle: NaN       // recordings: fixed angle of the tone arm

    property bool orbInteractive: true
    property bool orbStaticIcon: false     // previews: show the play/pause symbol without a click action
    property bool orbHover: false          // hover from a click target lying above (desktop)
    readonly property bool orbClickable: orbGeo.show && orbInteractive && opts.orbPlayPause !== false
    property bool mediaPlaying: true
    property bool mediaSpinning: mediaPlaying   // record orb: really playing right now
    property string mediaArt: ""                // record orb: cover of the current track
    property real iconRotation: 0      // keeps the play symbol upright when the strip is turned
    signal orbClicked()

    readonly property var info: Styles.byId(style)
    readonly property var opts: Styles.resolve(style, optionsJson)
    readonly property var pal: Pal.make(paletteStops)
    readonly property var orbGeo: R.orbGeometry(info.id, width, height, opts)
    property real bass: 0
    property var st: ({})
    readonly property double t0: Date.now()

    onStyleChanged: { st = ({}); canvas.requestPaint(); }
    onOptsChanged: canvas.requestPaint()
    onPalChanged: canvas.requestPaint()
    onValuesChanged: if (!demo && !(idle && settled)) canvas.requestPaint()
    onColorMappingChanged: canvas.requestPaint()
    onGradientAngleChanged: canvas.requestPaint()
    onVisibleChanged: if (visible) canvas.requestPaint()

    function frameValues(t) {
        if (demo && (!values || values.length === 0))
            return R.demoValues(48, t);
        if (!values || values.length === 0) {
            var z = [];
            for (var i = 0; i < 32; i++)
                z.push(0);
            return z;
        }
        return values;
    }

    Canvas {
        id: canvas
        anchors.fill: parent
        renderStrategy: Canvas.Cooperative

        onWidthChanged: requestPaint()
        onHeightChanged: requestPaint()

        onPaint: {
            var ctx = getContext("2d");
            if (!ctx)
                return;
            var t = viz.clock >= 0 ? viz.clock : (Date.now() - viz.t0) / 1000;
            var vals = viz.frameValues(t);
            var p = viz.pal;
            p.phase = viz.colorShift ? t * viz.colorShiftSpeed / 100 * 0.5 : 0;
            R.paint(ctx, {
                w: width, h: height, q: 1,
                values: vals, t: t,
                style: viz.info.id,
                o: viz.opts,
                pal: p,
                map: viz.colorMapping === "auto" ? "" : viz.colorMapping,
                angle: viz.gradientAngle,
                alpha: viz.opacityLevel,
                smoothing: viz.smoothing,
                soft: { left: viz.softLeft, right: viz.softRight, base: viz.softBase },
                S: viz.st
            });
            // bass level for the orb's pulse
            var sm = viz.st.sm || vals;
            var n = Math.max(1, Math.round(sm.length * 0.12)), b = 0;
            for (var i = 0; i < n && i < sm.length; i++)
                b += sm[i];
            viz.bass = b / n;
            var mx = 0;
            for (var j = 0; j < sm.length; j++)
                mx = Math.max(mx, sm[j]);
            viz.settled = mx < 0.003;
        }
    }

    // Animated styles (and demo previews) need frames even in silence.
    Timer {
        interval: Math.max(8, Math.round(1000 / Math.max(5, viz.fps)))
        repeat: true
        running: viz.running && viz.visible && viz.width > 2 && viz.height > 2
                 && viz.clock < 0
                 && (viz.demo || viz.info.animated
                     || ((viz.colorShift || viz.values.length === 0) && !(viz.idle && viz.settled)))
        onTriggered: canvas.requestPaint()
    }

    Orb {
        id: orb
        visible: viz.orbGeo.show
        radius: viz.orbGeo.r
        x: viz.orbGeo.x - radius
        y: viz.orbGeo.y - radius
        orbStyle: viz.opts.orbStyle || "dark"
        pulse: viz.opts.orbPulse !== false
        level: viz.bass
        readonly property bool ownColour: viz.opts.orbColorMode === "custom"
        accent: ownColour ? viz.opts.orbColor : viz.pal.hex(viz.info.round ? 0.42 : 0.55)
        accent2: ownColour ? Qt.lighter(viz.opts.orbColor, 1.35) : viz.pal.hex(viz.info.round ? 0.22 : 0.1)
        playing: viz.mediaPlaying
        interactive: viz.orbInteractive && viz.opts.orbPlayPause !== false
        iconMode: viz.opts.orbIcon || "always"
        staticIcon: viz.orbStaticIcon && viz.opts.orbPlayPause !== false
        externalHover: viz.orbHover
        spin: viz.opts.orbSpin !== false
        spinning: viz.mediaSpinning
        arm: viz.opts.orbArm !== false
        art: viz.opts.orbCover !== false ? viz.mediaArt : ""
        turnOverride: viz.orbTurn
        armOverride: viz.orbArmAngle
        rotation: viz.iconRotation
        onClicked: viz.orbClicked()
    }
}
