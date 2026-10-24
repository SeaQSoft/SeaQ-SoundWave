.pragma library

// Colour palettes for SeaQ SoundWave.
// A palette is a list of stops { c: "#rrggbb", p: 0..1 }.

var DEFAULT_STOPS = [
    { c: "#ff453a", p: 0.0 }, { c: "#ff9f0a", p: 0.143 }, { c: "#ffd60a", p: 0.286 },
    { c: "#32d74b", p: 0.429 }, { c: "#64d2ff", p: 0.571 }, { c: "#0a84ff", p: 0.714 },
    { c: "#bf5af2", p: 0.857 }, { c: "#ff375f", p: 1.0 }
];

// The colour collection shown in the editor (like the one in LizardTune).
// Colours are spread evenly unless a palette brings its own positions.
var COLLECTION = [
    { id: "macos",     cat: "Apple",   name: "macOS Rainbow", colors: ["#ff453a", "#ff9f0a", "#ffd60a", "#32d74b", "#64d2ff", "#0a84ff", "#bf5af2", "#ff375f"] },
    { id: "lizard",    cat: "Apple",   name: "Chameleon",        colors: ["#34c759", "#a3e635", "#ffd60a", "#ff9f0a", "#bf5af2", "#64d2ff"] },
    { id: "music",     cat: "Apple",   name: "Apple Music",      colors: ["#fa233b", "#fb5c74", "#ff9fb2", "#c86bfa"] },
    { id: "sonoma",    cat: "Apple",   name: "Sonoma",           colors: ["#ffb347", "#ff6f61", "#c2185b", "#5b2a86"] },
    { id: "sequoia",   cat: "Apple",   name: "Sequoia",          colors: ["#1e3a8a", "#2563eb", "#7c3aed", "#db2777", "#f97316"] },
    { id: "peach",     cat: "Gradient", name: "Peach Evening",   colors: ["#fff1bf", "#ec458d", "#474ed7"], pos: [0, 0.5, 1] },
    { id: "sunset",    cat: "Gradient", name: "Sunset",  colors: ["#ffd000", "#ff6a00", "#ee0979", "#7b0028"] },
    { id: "ocean",     cat: "Nature",   name: "Ocean",            colors: ["#00e5ff", "#00c6ff", "#0072ff", "#1e3c72"] },
    { id: "aurora",    cat: "Nature",   name: "Aurora",       colors: ["#00f5a0", "#00d9f5", "#7b2ff7", "#f107a3"] },
    { id: "warmlight", cat: "Nature",   name: "Light Strings",       colors: ["#1e90ff", "#00e5ff", "#7cfc00", "#ffd700", "#ff8c00"] },
    { id: "forest",    cat: "Nature",   name: "Forest",             colors: ["#d4fc79", "#96e6a1", "#2f9e44", "#0b6e4f"] },
    { id: "fire",      cat: "Nature",   name: "Fire",            colors: ["#fff200", "#ff8c00", "#ff2d00", "#9b0000"] },
    { id: "ice",       cat: "Nature",   name: "Glacier",        colors: ["#e0f7ff", "#8ae6ff", "#3aa0ff", "#2e5bff"] },
    { id: "neon",      cat: "Neon",    name: "Neon",             colors: ["#ff00e5", "#00e5ff", "#7cff00"] },
    { id: "cyber",     cat: "Neon",    name: "Cyberpunk",        colors: ["#f72585", "#7209b7", "#3a0ca3", "#4cc9f0"] },
    { id: "vapor",     cat: "Neon",    name: "Vaporwave",        colors: ["#ff71ce", "#01cdfe", "#05ffa1", "#b967ff", "#fffb96"] },
    { id: "synth",     cat: "Neon",    name: "Synthwave",        colors: ["#f9c80e", "#f86624", "#ea3546", "#662e9b", "#43bccd"] },
    { id: "laser",     cat: "Neon",    name: "Laser",            colors: ["#ff3b30", "#ff9500", "#af52de", "#5856d6", "#34c759"] },
    { id: "candy",     cat: "Pastel", name: "Cotton Candy",      colors: ["#ff9a9e", "#fad0c4", "#fbc2eb", "#a18cd1"] },
    { id: "pastel",    cat: "Pastel", name: "Pastel",          colors: ["#ffd6a5", "#fdffb6", "#caffbf", "#9bf6ff", "#a0c4ff", "#bdb2ff", "#ffc6ff"] },
    { id: "tropical",  cat: "Pastel", name: "Tropical",         colors: ["#f9f871", "#ffc75f", "#ff9671", "#ff6f91", "#d65db1", "#845ec2"] },
    { id: "mint",      cat: "Pastel", name: "Mint",            colors: ["#43e97b", "#38f9d7", "#a0f1ff"] },
    { id: "gold",      cat: "Precious",    name: "Gold",             colors: ["#fff3b0", "#ffd166", "#e09f3e", "#9e2a2b"] },
    { id: "silver",    cat: "Precious",    name: "Silver",           colors: ["#ffffff", "#cbd5e1", "#94a3b8", "#64748b"] },
    { id: "rose",      cat: "Precious",    name: "Rose Gold",         colors: ["#fde2e4", "#f4acb7", "#b5838d", "#6d6875"] },
    { id: "classic",   cat: "Precious",    name: "Classic Blue",   colors: ["#0a84ff", "#bf5af2"] }
];

var CATEGORIES = ["Apple", "Gradient", "Nature", "Neon", "Pastel", "Precious"];

function stopsFromColors(colors, pos) {
    var out = [];
    var n = colors.length;
    for (var i = 0; i < n; i++)
        out.push({ c: colors[i], p: pos ? pos[i] : (n === 1 ? 0 : i / (n - 1)) });
    return out;
}

function collectionStops(id) {
    for (var i = 0; i < COLLECTION.length; i++)
        if (COLLECTION[i].id === id)
            return stopsFromColors(COLLECTION[i].colors, COLLECTION[i].pos);
    return DEFAULT_STOPS.slice();
}

function clamp(x, a, b) { return x < a ? a : (x > b ? b : x); }

function hexToRgb(h) {
    h = String(h || "").trim();
    if (h.charAt(0) === "#")
        h = h.substring(1);
    if (h.length === 3)
        h = h.charAt(0) + h.charAt(0) + h.charAt(1) + h.charAt(1) + h.charAt(2) + h.charAt(2);
    if (h.length === 8)          // #aarrggbb (Qt colour strings)
        h = h.substring(2);
    var n = parseInt(h, 16);
    if (isNaN(n) || h.length !== 6)
        return [255, 255, 255];
    return [(n >> 16) & 255, (n >> 8) & 255, n & 255];
}

function rgbToHex(c) {
    function hx(v) { var s = Math.round(clamp(v, 0, 255)).toString(16); return s.length < 2 ? "0" + s : s; }
    return "#" + hx(c[0]) + hx(c[1]) + hx(c[2]);
}

function parse(json) {
    var arr = null;
    if (Array.isArray(json))
        arr = json;
    else {
        try { arr = JSON.parse(json); } catch (e) { arr = null; }
    }
    if (!arr || !arr.length)
        arr = DEFAULT_STOPS;
    var out = [];
    for (var i = 0; i < arr.length; i++) {
        var s = arr[i];
        if (!s)
            continue;
        out.push({ c: String(s.c || "#ffffff"), p: clamp(Number(s.p) || 0, 0, 1) });
    }
    if (out.length === 0)
        out = DEFAULT_STOPS.slice();
    out.sort(function (a, b) { return a.p - b.p; });
    return out;
}

function serialize(stops) {
    var out = [];
    for (var i = 0; i < stops.length; i++)
        out.push({ c: String(stops[i].c), p: Math.round(stops[i].p * 1000) / 1000 });
    return JSON.stringify(out);
}

// Builds a sampler for a palette.
// at(f)  -> [r,g,b] for f in 0..1
// css(f) -> "rgb(r,g,b)"
// phase shifts the palette (used for the animated colour shift). While
// shifting it runs forward and back (ping-pong) so any palette loops
// without a hard seam.
function make(stopsOrJson) {
    var stops = parse(stopsOrJson);
    var rgb = [];
    for (var i = 0; i < stops.length; i++)
        rgb.push({ c: hexToRgb(stops[i].c), p: stops[i].p });

    var pal = {
        stops: stops,
        phase: 0,
        raw: function (f) {
            f = clamp(f, 0, 1);
            if (f <= rgb[0].p)
                return rgb[0].c;
            var last = rgb[rgb.length - 1];
            if (f >= last.p)
                return last.c;
            for (var k = 1; k < rgb.length; k++) {
                if (f <= rgb[k].p) {
                    var a = rgb[k - 1], b = rgb[k];
                    var t = (b.p - a.p) < 1e-6 ? 0 : (f - a.p) / (b.p - a.p);
                    return [a.c[0] + (b.c[0] - a.c[0]) * t,
                            a.c[1] + (b.c[1] - a.c[1]) * t,
                            a.c[2] + (b.c[2] - a.c[2]) * t];
                }
            }
            return last.c;
        },
        at: function (f) {
            if (this.phase !== 0) {
                var x = f * 0.5 + this.phase;
                x = x - Math.floor(x);
                f = 1 - Math.abs(1 - 2 * x);
            }
            return this.raw(f);
        },
        css: function (f) {
            var c = this.at(f);
            return "rgb(" + Math.round(c[0]) + "," + Math.round(c[1]) + "," + Math.round(c[2]) + ")";
        },
        rgba: function (f, a) {
            var c = this.at(f);
            return "rgba(" + Math.round(c[0]) + "," + Math.round(c[1]) + "," + Math.round(c[2]) + "," + a + ")";
        },
        // colour mixed towards white (k>0) or black (k<0)
        tint: function (f, k, a) {
            var c = this.at(f);
            var t = k >= 0 ? 255 : 0, m = Math.abs(k);
            return "rgba(" + Math.round(c[0] + (t - c[0]) * m) + "," + Math.round(c[1] + (t - c[1]) * m) + ","
                + Math.round(c[2] + (t - c[2]) * m) + "," + (a === undefined ? 1 : a) + ")";
        },
        hex: function (f) { return rgbToHex(this.at(f)); }
    };
    return pal;
}

// Adds `n` colour stops of the palette (from f0 to f1) to a canvas gradient.
function fillGradient(g, pal, f0, f1, n, alphaFn) {
    n = Math.max(2, n || 16);
    for (var i = 0; i < n; i++) {
        var s = i / (n - 1);
        var a = alphaFn ? alphaFn(s) : 1;
        g.addColorStop(s, pal.rgba(f0 + (f1 - f0) * s, a));
    }
    return g;
}

function randomStops() {
    var n = 2 + Math.floor(Math.random() * 3);
    var base = Math.random() * 360;
    var out = [];
    for (var i = 0; i < n; i++) {
        var h = (base + i * (40 + Math.random() * 80)) % 360;
        var s = 0.65 + Math.random() * 0.35, l = 0.5 + Math.random() * 0.2;
        out.push({ c: rgbToHex(hslToRgb(h / 360, s, l)), p: n === 1 ? 0 : i / (n - 1) });
    }
    return out;
}

function hslToRgb(h, s, l) {
    function f(n) {
        var k = (n + h * 12) % 12;
        var a = s * Math.min(l, 1 - l);
        return 255 * (l - a * Math.max(-1, Math.min(k - 3, 9 - k, 1)));
    }
    return [f(0), f(8), f(4)];
}

function cssGradient(stops, type, angle) {
    var parts = [];
    for (var i = 0; i < stops.length; i++)
        parts.push(String(stops[i].c).toUpperCase() + " " + Math.round(stops[i].p * 100) + "%");
    if (type === "radial")
        return "radial-gradient(circle, " + parts.join(", ") + ")";
    if (type === "conic")
        return "conic-gradient(from " + angle + "deg, " + parts.join(", ") + ")";
    return "linear-gradient(" + angle + "deg, " + parts.join(", ") + ")";
}
