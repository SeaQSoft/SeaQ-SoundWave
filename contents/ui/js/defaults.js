.pragma library

// Factory defaults of every setting (generated from config/main.xml).
// Colours are written as "color:r,g,b,a".
var DEFAULTS = {
    vizStyle: "macos-wave",
    styleOptions: "{}",
    palette: "",
    paletteName: "macos",
    customPalettes: "[]",
    colorMapping: "auto",
    gradientAngle: 90,
    colorShift: true,
    colorShiftSpeed: 12,
    opacity: 100,
    smoothing: 35,
    backgroundEnabled: false,
    backgroundColor: "color:20,20,20,89",
    backgroundRadius: 14,
    barCount: 64,
    sensitivity: 100,
    framerate: 60,
    engine: "auto",
    inputMethod: "pulse",
    inputSource: "auto",
    placement: "widget",
    attachEdge: "auto",
    attachThickness: 96,
    attachGap: 1,
    attachOffset: 0,
    attachLengthMode: "panel",
    attachLength: 900,
    attachEndInset: 8,
    attachSoftEnds: 32,
    attachSoftBase: 8,
    screenAnchor: "bottom",
    screenMarginX: 0,
    screenMarginY: 24,
    screenWidth: 60,
    screenHeight: 260,
    freeX: -1,
    freeY: -1,
    freeW: -1,
    freeH: -1,
    freeEdge: "bottom",
    showMiniCard: true,
    widgetSize: "",
    audioGuard: "notify",
    audioGuardIgnore: "",
    taskbarIcon: true,
    orbAction: "playpause",
    editorTheme: "auto",
    editorRequest: "",
    editorPage: 0,
    shortcutInit: false,
    shortcutText: "Meta+Alt+V"
};

// never touched by a reset
var KEEP = ["widgetSize", "editorRequest", "shortcutInit", "shortcutText", "customPalettes", "editorPage"];

var GROUPS = {
    colors:   ["palette", "paletteName", "colorMapping", "gradientAngle", "colorShift", "colorShiftSpeed"],
    general:  ["opacity", "smoothing", "backgroundEnabled", "backgroundColor", "backgroundRadius"],
    position: ["attachEdge", "attachThickness", "attachGap", "attachOffset", "attachLengthMode", "attachLength",
               "attachEndInset", "attachSoftEnds", "attachSoftBase", "screenAnchor", "screenMarginX", "screenMarginY",
               "screenWidth", "screenHeight", "freeX", "freeY", "freeW", "freeH", "freeEdge", "showMiniCard"],
    audio:    ["audioGuard", "audioGuardIgnore", "barCount", "sensitivity", "framerate", "engine", "inputMethod", "inputSource", "smoothing"],
    orb:      ["orbAction"]
};

function valueFor(key) {
    var v = DEFAULTS[key];
    if (typeof v === "string" && v.indexOf("color:") === 0) {
        var a = v.substring(6).split(",").map(Number);
        return Qt.rgba(a[0] / 255, a[1] / 255, a[2] / 255, (a.length > 3 ? a[3] : 255) / 255);
    }
    return v;
}

function resetKeys(cfg, keys) {
    for (var i = 0; i < keys.length; i++)
        if (DEFAULTS[keys[i]] !== undefined)
            cfg[keys[i]] = valueFor(keys[i]);
}

function resetAll(cfg) {
    var keys = [];
    for (var k in DEFAULTS)
        if (KEEP.indexOf(k) < 0)
            keys.push(k);
    resetKeys(cfg, keys);
}
