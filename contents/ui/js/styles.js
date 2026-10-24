.pragma library

// Registry of all visualizer styles and of the options they can offer.
// The editor builds its "Style options" page from this, so every style
// only shows the settings that actually change something for it.

var GROUPS = [
    { id: "classic", name: "Classic",        desc: "The proven spectrum shapes" },
    { id: "macos",   name: "macOS",          desc: "Colourful, in the style of macOS" },
    { id: "light",   name: "Lines & Light",  desc: "Light strings and beams – also full screen" },
    { id: "round",   name: "Round",          desc: "Circular, with a playback orb in the middle" }
];

// type: slider | switch | segment
var OPTS = {
    barSpacing:   { label: "Spacing",                  type: "slider", min: 0, max: 20, step: 1, unit: "px", def: 3 },
    barWidthAuto: { label: "Fill width automatically", type: "switch", def: true },
    barWidth:     { label: "Fixed bar width",       type: "slider", min: 1, max: 60, step: 1, unit: "px", def: 8, enabledIf: "!barWidthAuto" },
    cornerRadius: { label: "Corner radius",              type: "slider", min: 0, max: 20, step: 1, unit: "px", def: 2 },
    density:      { label: "Number of elements", desc: "How many bars, columns or rays are drawn", type: "slider", min: 12, max: 240, step: 2, unit: "", def: 64 },
    lineCount:    { label: "Lines per side",         type: "slider", min: 2, max: 40, step: 1, unit: "", def: 8 },
    lineWidth:    { label: "Line width",             type: "slider", min: 0.5, max: 12, step: 0.5, unit: "px", def: 2 },
    glow:         { label: "Glow",                 type: "slider", min: 0, max: 100, step: 1, unit: "%", def: 50 },
    amplitude:    { label: "Amplitude",                type: "slider", min: 10, max: 250, step: 5, unit: "%", def: 100 },
    speed:        { label: "Motion speed",           type: "slider", min: 0, max: 300, step: 5, unit: "%", def: 100 },
    edgeFade:     { label: "Fade out at the edges", type: "slider", min: 0, max: 50, step: 1, unit: "%", def: 12 },
    spread:       { label: "Spread",             type: "slider", min: 10, max: 100, step: 1, unit: "%", def: 80 },
    turns:        { label: "Turns",                type: "slider", min: 2, max: 30, step: 1, unit: "", def: 12 },
    rungs:        { label: "Rungs between the strands", type: "switch", def: true },
    waviness:     { label: "Waviness",               type: "slider", min: 0, max: 100, step: 1, unit: "%", def: 50 },
    centerGlow:   { label: "Light in the middle", desc: "A bright light where the lines meet – it breathes with the music", type: "switch", def: true },
    additive:     { label: "Light blending",   desc: "Overlaps shine brighter (additive)", type: "switch", def: true },
    orbEnabled:   { label: "Orb in the middle", type: "switch", def: false },
    orbSize:      { label: "Orb size",               type: "slider", min: 10, max: 260, step: 2, unit: "px", def: 46, enabledIf: "orbEnabled" },
    orbStyle:     { label: "Orb style",               type: "segment", choices: [["dark", "Dark"], ["glass", "Glass"], ["neon", "Neon"], ["vinyl", "Record"]], def: "dark", enabledIf: "orbEnabled" },
    orbSpin:      { label: "Record spins", desc: "Turns like on a turntable while music plays and stops on pause", type: "switch", def: true, enabledIf: "orbStyle=vinyl" },
    orbArm:       { label: "Tone arm", desc: "Swings onto the record when playing and away on pause", type: "switch", def: true, enabledIf: "orbStyle=vinyl" },
    orbCover:     { label: "Cover on the label", desc: "Shows the cover of the current song or video in the middle of the record", type: "switch", def: true, enabledIf: "orbStyle=vinyl" },
    orbPulse:     { label: "Orb pulses with the bass", type: "switch", def: true, enabledIf: "orbEnabled" },
    orbColorMode: { label: "Orb colour",               type: "segment", choices: [["palette", "From palette"], ["custom", "Own colour"]], def: "palette", enabledIf: "orbEnabled" },
    orbColor:     { label: "Colour of the orb",        type: "color", def: "#0a84ff", enabledIf: "orbColorMode=custom" },
    orbPlayPause: { label: "Play/pause on click",      desc: "Clicking the orb pauses or resumes audio and video", type: "switch", def: true, enabledIf: "orbEnabled" },
    orbIcon:      { label: "Show play/pause symbol",   type: "segment", choices: [["always", "Always"], ["hover", "On hover"], ["never", "Never"]], def: "always", enabledIf: "orbPlayPause" },
    innerRadius:  { label: "Inner radius",              type: "slider", min: 10, max: 80, step: 1, unit: "%", def: 32 },
    rayLength:    { label: "Ray length",            type: "slider", min: 10, max: 100, step: 1, unit: "%", def: 75 },
    rotation:     { label: "Rotation",         desc: "Negative = counter-clockwise", type: "slider", min: -100, max: 100, step: 1, unit: "%", def: 0 },
    segmentRows:  { label: "Rings",                    type: "slider", min: 3, max: 12, step: 1, unit: "", def: 7 },
    ledRows:      { label: "LED rows",               type: "slider", min: 6, max: 48, step: 1, unit: "", def: 24 },
    peakCaps:     { label: "Peak caps",            type: "switch", def: true },
    peakFall:     { label: "Fall speed",      type: "slider", min: 5, max: 100, step: 1, unit: "%", def: 35, enabledIf: "peakCaps" },
    reflection:   { label: "Reflection",               type: "switch", def: true },
    reflectionStrength: { label: "Reflection strength", type: "slider", min: 5, max: 100, step: 1, unit: "%", def: 40, enabledIf: "reflection" },
    windowsLit:   { label: "Lit windows",      type: "slider", min: 10, max: 100, step: 1, unit: "%", def: 85 },
    dimUnlit:     { label: "Hint inactive elements", type: "switch", def: true },
    symmetry:     { label: "Symmetry axes",         type: "slider", min: 3, max: 16, step: 1, unit: "", def: 8 },
    ringCount:    { label: "Pulse rings",                type: "slider", min: 2, max: 14, step: 1, unit: "", def: 6 },
    layers:       { label: "Layers",                   type: "slider", min: 1, max: 6, step: 1, unit: "", def: 3 }
};

// Sections the options are grouped into on the editor page.
var SECTIONS = [
    { name: "Shape",       keys: ["density", "lineCount", "turns", "symmetry", "layers", "ringCount", "segmentRows", "ledRows",
                                 "barSpacing", "barWidthAuto", "barWidth", "cornerRadius", "lineWidth", "innerRadius", "rayLength",
                                 "spread", "waviness", "amplitude", "windowsLit"] },
    { name: "Motion",   keys: ["speed", "rotation", "peakCaps", "peakFall"] },
    { name: "Light & glow", keys: ["glow", "centerGlow", "additive", "edgeFade", "rungs", "dimUnlit", "reflection", "reflectionStrength"] },
    { name: "Orb",      keys: ["orbEnabled", "orbSize", "orbStyle", "orbSpin", "orbArm", "orbCover", "orbColorMode", "orbColor", "orbPulse", "orbPlayPause", "orbIcon"] }
];

var ORB = ["orbEnabled", "orbSize", "orbStyle", "orbSpin", "orbArm", "orbCover", "orbColorMode", "orbColor", "orbPulse", "orbPlayPause", "orbIcon"];
var ORB_ROUND = ["orbEnabled", "orbStyle", "orbSpin", "orbArm", "orbCover", "orbColorMode", "orbColor", "orbPulse", "orbPlayPause", "orbIcon"];

// Orb settings shared by every style: switching the orb on or off (or
// changing its look) applies to all styles at once. Only the size stays
// per style, because the styles need very different sizes.
// Stored in the style options under the "_orb" entry.
var GLOBAL_ORB = ["orbEnabled", "orbStyle", "orbSpin", "orbArm", "orbCover", "orbColorMode", "orbColor", "orbPulse", "orbPlayPause", "orbIcon"];
var GLOBAL_KEY = "_orb";
function isGlobal(key) { return GLOBAL_ORB.indexOf(key) >= 0; }   // size follows the inner radius

// map: natural colour mapping ("vertical", "horizontal", "line", "angle", "radius")
// strip: drawn as a strip that can be laid along a panel (rotated for side panels)
// soft: supports the soft rounded ends above a floating panel
// round: square, centred content (never rotated)
// fullscreen: may cover the whole screen
var STYLES = [
    { id: "bars",      group: "classic", name: "Bars",            desc: "Classic spectrum bars",
      strip: true, soft: true, map: "vertical",
      opts: ["barSpacing", "barWidthAuto", "barWidth", "cornerRadius", "peakCaps", "peakFall", "reflection", "reflectionStrength"],
      defaults: { peakCaps: false, reflection: false } },
    { id: "spine",     group: "classic", name: "Mirror axis",     desc: "Bars mirrored around the centre line",
      strip: true, soft: true, map: "vertical",
      opts: ["barSpacing", "barWidthAuto", "barWidth", "cornerRadius"] },
    { id: "wave",      group: "classic", name: "Wave",            desc: "A soft, filled curve",
      strip: true, soft: true, map: "vertical", opts: [] },
    { id: "dots",      group: "classic", name: "Dots",            desc: "Floating dots",
      strip: true, map: "vertical", opts: ["barSpacing", "barWidthAuto", "barWidth"] },
    { id: "particles", group: "classic", name: "Particles",       desc: "Floating capsules",
      strip: true, map: "vertical", opts: ["barSpacing", "barWidthAuto", "barWidth", "cornerRadius"] },

    { id: "macos-wave",    group: "macos", name: "Colour waves",    desc: "Flowing macOS colours (the original)",
      strip: true, soft: true, map: "horizontal", animated: true, forceShift: true, fullscreen: true, opts: [] },
    { id: "macos-led",     group: "macos", name: "LED matrix",      desc: "Glowing dots in rows and columns",
      strip: true, map: "vertical", fullscreen: true,
      opts: ["density", "ledRows", "barSpacing", "glow", "peakCaps", "peakFall", "dimUnlit"],
      defaults: { density: 70, barSpacing: 4, glow: 35 } },
    { id: "macos-skyline", group: "macos", name: "Skyline",         desc: "A city that grows with the music",
      strip: true, map: "horizontal", fullscreen: true,
      opts: ["density", "barSpacing", "windowsLit", "glow", "reflection", "reflectionStrength"],
      defaults: { density: 52, barSpacing: 5, glow: 20 } },
    { id: "macos-bars",    group: "macos", name: "Rainbow bars",    desc: "Rounded bars with peaks and reflection",
      strip: true, map: "horizontal", fullscreen: true,
      opts: ["density", "barSpacing", "cornerRadius", "peakCaps", "peakFall", "reflection", "reflectionStrength"],
      defaults: { density: 96, barSpacing: 3, cornerRadius: 6, reflectionStrength: 30 } },

    { id: "helix",   group: "light", name: "Double helix", desc: "Two glowing strands winding around each other",
      strip: true, map: "line", animated: true, fullscreen: true, orb: true,
      opts: ["centerGlow", "turns", "amplitude", "lineWidth", "glow", "speed", "rungs", "edgeFade", "additive"].concat(ORB),
      defaults: { lineWidth: 2.5, glow: 40, edgeFade: 10, additive: false, orbEnabled: true, orbSize: 40 } },
    { id: "beams",   group: "light", name: "Laser fan",    desc: "Beams of light meeting in the middle",
      strip: true, map: "line", animated: true, fullscreen: true, orb: true,
      opts: ["centerGlow", "lineCount", "spread", "lineWidth", "glow", "speed", "edgeFade", "additive"].concat(ORB),
      defaults: { lineCount: 14, lineWidth: 3, glow: 45, edgeFade: 14, orbEnabled: true, orbSize: 40 } },
    { id: "strings", group: "light", name: "Light strings", desc: "Fine strings bundled into a point of light",
      strip: true, map: "line", animated: true, fullscreen: true, orb: true,
      opts: ["centerGlow", "lineCount", "spread", "waviness", "lineWidth", "glow", "speed", "edgeFade", "additive"].concat(ORB),
      defaults: { lineCount: 22, lineWidth: 1, glow: 30, edgeFade: 10, waviness: 60, orbEnabled: true, orbSize: 40 } },
    { id: "ribbons", group: "light", name: "Colour streams", desc: "Coloured lines flowing into a small orb",
      strip: true, map: "line", animated: true, fullscreen: true, orb: true,
      opts: ["centerGlow", "lineCount", "spread", "waviness", "lineWidth", "glow", "speed", "edgeFade", "additive"].concat(ORB),
      defaults: { lineCount: 7, lineWidth: 1.5, glow: 40, edgeFade: 8, orbEnabled: true, orbSize: 34, additive: false } },
    { id: "silk",    group: "light", name: "Silk waves",   desc: "Layered, swinging bands of light",
      strip: true, map: "line", animated: true, fullscreen: true,
      opts: ["lineCount", "amplitude", "lineWidth", "glow", "speed", "edgeFade", "additive"],
      defaults: { lineCount: 7, lineWidth: 2, glow: 55, edgeFade: 6 } },

    { id: "ring",     group: "round", name: "Ring spectrum", desc: "Rays all around the orb",
      round: true, map: "angle", fullscreen: true, orb: true, animated: true,
      opts: ["density", "innerRadius", "rayLength", "lineWidth", "rotation", "glow"].concat(ORB_ROUND),
      defaults: { density: 160, lineWidth: 3, glow: 20, orbEnabled: true } },
    { id: "segments", group: "round", name: "Segment ring",  desc: "Concentric glowing segments",
      round: true, map: "radius", fullscreen: true, orb: true, animated: true,
      opts: ["density", "segmentRows", "innerRadius", "barSpacing", "rotation", "dimUnlit"].concat(ORB_ROUND),
      defaults: { density: 64, barSpacing: 5, innerRadius: 30, orbEnabled: true } },
    { id: "pulse",    group: "round", name: "Pulse rings",   desc: "Rings that travel outwards with the bass",
      round: true, map: "radius", fullscreen: true, orb: true, animated: true,
      opts: ["ringCount", "innerRadius", "lineWidth", "glow", "speed"].concat(ORB_ROUND),
      defaults: { lineWidth: 2, glow: 45, innerRadius: 24, orbEnabled: true } },
    { id: "blob",     group: "round", name: "Liquid orb",    desc: "Soft shapes flowing around the orb",
      round: true, map: "line", fullscreen: true, orb: true, animated: true,
      opts: ["layers", "innerRadius", "amplitude", "glow", "speed", "additive"].concat(ORB_ROUND),
      defaults: { innerRadius: 30, glow: 35, orbEnabled: true } },
    { id: "kaleido",  group: "round", name: "Kaleidoscope",  desc: "A fractal-like bloom of light petals",
      round: true, map: "line", fullscreen: true, orb: true, animated: true,
      opts: ["symmetry", "layers", "amplitude", "lineWidth", "glow", "speed", "rotation", "additive"].concat(ORB),
      defaults: { lineWidth: 1.5, glow: 40, rotation: 15, innerRadius: 14, orbEnabled: true, orbSize: 40 } }
];

function byId(id) {
    for (var i = 0; i < STYLES.length; i++)
        if (STYLES[i].id === id)
            return STYLES[i];
    return STYLES[5];   // macos-wave
}

function inGroup(g) {
    var out = [];
    for (var i = 0; i < STYLES.length; i++)
        if (STYLES[i].group === g)
            out.push(STYLES[i]);
    return out;
}

function groupName(g) {
    for (var i = 0; i < GROUPS.length; i++)
        if (GROUPS[i].id === g)
            return GROUPS[i].name;
    return g;
}

function hasOpt(style, key) {
    return byId(style).opts.indexOf(key) >= 0;
}

function defaultValue(style, key) {
    var s = byId(style);
    if (s.defaults && s.defaults[key] !== undefined)
        return s.defaults[key];
    return OPTS[key] ? OPTS[key].def : undefined;
}

function parseAll(json) {
    try {
        var o = JSON.parse(json || "{}");
        return (o && typeof o === "object") ? o : {};
    } catch (e) {
        return {};
    }
}

// Effective options for a style: option defaults < style defaults < saved values.
function resolve(style, json) {
    var s = byId(style);
    var all = (typeof json === "object" && json) ? json : parseAll(json);
    var saved = all[s.id] || {};
    var out = {};
    for (var k in OPTS)
        out[k] = OPTS[k].def;
    if (s.defaults)
        for (var d in s.defaults)
            out[d] = s.defaults[d];
    for (var v in saved)
        if (OPTS[v] !== undefined && !isGlobal(v))
            out[v] = saved[v];
    if (s.orb) {
        // shared orb settings; the orb is on for every style unless switched off
        var g = all[GLOBAL_KEY] || {};
        out.orbEnabled = true;
        for (var gk in g)
            if (isGlobal(gk))
                out[gk] = g[gk];
    }
    return out;
}

function withValue(json, style, key, value) {
    var all = parseAll(json);
    if (isGlobal(key))
        style = GLOBAL_KEY;
    if (!all[style])
        all[style] = {};
    all[style][key] = value;
    return JSON.stringify(all);
}

function resetStyle(json, style) {
    var all = parseAll(json);
    delete all[style];
    return JSON.stringify(all);
}

function optEnabled(key, opts) {
    var o = OPTS[key];
    if (!o || !o.enabledIf)
        return true;
    if (o.enabledIf.indexOf("=") > 0) {      // "key=value"
        var kv = o.enabledIf.split("=");
        return String(opts[kv[0]]) === kv[1] && optEnabled(kv[0], opts);
    }
    var neg = o.enabledIf.charAt(0) === "!";
    var k = neg ? o.enabledIf.substring(1) : o.enabledIf;
    return neg ? !opts[k] : !!opts[k];
}

// Anchor points for a fixed position on the screen.
var ANCHORS = ["top-left", "top", "top-right", "left", "center", "right", "bottom-left", "bottom", "bottom-right"];

// Styles whose shapes stand on the bottom edge (bars, waves, LEDs ...).
// A background plate keeps square corners on that side so the
// visualizer sits flush; all other styles get four rounded corners.
var ANCHORED = ["bars", "wave", "dots", "particles", "macos-wave", "macos-led", "macos-skyline", "macos-bars"];
for (var _i = 0; _i < STYLES.length; _i++)
    STYLES[_i].anchored = ANCHORED.indexOf(STYLES[_i].id) >= 0;
