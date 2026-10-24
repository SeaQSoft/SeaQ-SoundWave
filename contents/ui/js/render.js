.pragma library
.import "styles.js" as Styles

// All visualizer renderers of SeaQ SoundWave. Everything is drawn on a
// QtQuick Canvas 2D context. paint() gets one frame description:
//   { w, h, q, values, t, style, o, pal, map, angle, alpha, smoothing,
//     soft: { left, right, base }, S }
// S is a per-visualizer state object (smoothing, peaks, pulse rings ...).

var TAU = Math.PI * 2;

function clamp(x, a, b) { return x < a ? a : (x > b ? b : x); }
function lerp(a, b, t) { return a + (b - a) * t; }
function smooth01(t) { t = clamp(t, 0, 1); return t * t * (3 - 2 * t); }

// value at position f (0..1) of an array, linearly interpolated
function sample(v, f) {
    var n = v.length;
    if (!n)
        return 0;
    var x = clamp(f, 0, 1) * (n - 1);
    var i = Math.floor(x);
    if (i >= n - 1)
        return v[n - 1];
    var fr = x - i;
    return v[i] * (1 - fr) + v[i + 1] * fr;
}

// around a circle: 0 -> bass, 0.5 -> treble, 1 -> bass again (no seam)
function mirrorSample(v, f) {
    f = f - Math.floor(f);
    return sample(v, f < 0.5 ? f * 2 : (1 - f) * 2);
}

function bandAvg(v, f0, f1) {
    var n = v.length;
    if (!n)
        return 0;
    var a = Math.floor(f0 * n), b = Math.max(a + 1, Math.ceil(f1 * n));
    var s = 0;
    for (var i = a; i < b && i < n; i++)
        s += v[i];
    return s / Math.max(1, Math.min(b, n) - a);
}

function energy(v) {
    return { bass: bandAvg(v, 0, 0.12), mid: bandAvg(v, 0.12, 0.5), high: bandAvg(v, 0.5, 1), avg: bandAvg(v, 0, 1) };
}

// Fake but lively spectrum for previews.
function demoValues(n, t) {
    var out = [];
    var beat = Math.pow(0.5 + 0.5 * Math.sin(t * TAU * 1.9), 8);
    for (var i = 0; i < n; i++) {
        var f = n === 1 ? 0 : i / (n - 1);
        var base = 0.72 * Math.exp(-f * 2.0) + 0.2;
        var wob = 0.5 + 0.5 * Math.sin(t * 3.1 + f * 9.0) * Math.cos(t * 1.7 + f * 4.3);
        var sp = 0.5 + 0.5 * Math.sin(t * 7.3 + i * 1.7) * Math.sin(t * 2.1 + i * 0.37);
        var v = base * (0.35 + 0.45 * wob + 0.2 * sp) + beat * (1 - f) * 0.35;
        out.push(clamp(v, 0, 1));
    }
    return out;
}

// ---- colour helpers ------------------------------------------------------

// A gradient across the whole canvas when the user picked an explicit
// gradient type (linear with angle, radial, conic). null = per-style colours.
function globalGradient(ctx, L, mode, angle) {
    var w = L.w, h = L.h, g;
    if (mode === "radial") {
        g = ctx.createRadialGradient(w / 2, h / 2, 0, w / 2, h / 2, Math.max(w, h) / 2);
    } else if (mode === "conic") {
        g = ctx.createConicalGradient(w / 2, h / 2, (angle || 0) * Math.PI / 180);
    } else if (mode === "linear") {
        // CSS convention: 0deg = bottom->top, 90deg = left->right
        var a = (angle || 0) * Math.PI / 180;
        var dx = Math.sin(a), dy = -Math.cos(a);
        var len = Math.abs(w * dx) + Math.abs(h * dy);
        g = ctx.createLinearGradient(w / 2 - dx * len / 2, h / 2 - dy * len / 2, w / 2 + dx * len / 2, h / 2 + dy * len / 2);
    } else {
        return null;
    }
    for (var i = 0; i < 24; i++) {
        var s = i / 23;
        g.addColorStop(s, L.pal.css(s));
    }
    return g;
}

// colour for an element at palette position f (falls back to the global gradient)
function col(L, f) {
    return L.grad ? L.grad : L.pal.css(f);
}

function linGrad(ctx, L, x0, y0, x1, y1, f0, f1, n) {
    if (L.grad)
        return L.grad;
    var g = ctx.createLinearGradient(x0, y0, x1, y1);
    n = n || 12;
    for (var i = 0; i < n; i++) {
        var s = i / (n - 1);
        g.addColorStop(s, L.pal.css(f0 + (f1 - f0) * s));
    }
    return g;
}

// Strokes the current path with a soft glow (wide translucent passes first).
function glowStroke(ctx, L, lw, a) {
    var g = L.o.glow / 100;
    var base = L.alpha * a;
    if (g > 0.02) {
        ctx.lineWidth = lw + 10 * g * Math.max(1, lw * 0.6);
        ctx.globalAlpha = base * 0.07 * g;
        ctx.stroke();
        ctx.lineWidth = lw + 4 * g * Math.max(1, lw * 0.5);
        ctx.globalAlpha = base * 0.18 * g;
        ctx.stroke();
    }
    ctx.lineWidth = lw;
    ctx.globalAlpha = base;
    ctx.stroke();
}

function fadeEdges(ctx, L, pct) {
    var f = pct / 100 * L.w;
    if (f < 1)
        return;
    ctx.save();
    ctx.globalCompositeOperation = "destination-out";
    ctx.globalAlpha = 1;
    var g = ctx.createLinearGradient(0, 0, f, 0);
    g.addColorStop(0, "rgba(0,0,0,1)");
    g.addColorStop(0.45, "rgba(0,0,0,0.55)");
    g.addColorStop(1, "rgba(0,0,0,0)");
    ctx.fillStyle = g;
    ctx.fillRect(0, 0, f + 0.5, L.h);
    var g2 = ctx.createLinearGradient(L.w - f, 0, L.w, 0);
    g2.addColorStop(0, "rgba(0,0,0,0)");
    g2.addColorStop(0.55, "rgba(0,0,0,0.55)");
    g2.addColorStop(1, "rgba(0,0,0,1)");
    ctx.fillStyle = g2;
    ctx.fillRect(L.w - f - 0.5, 0, f + 1, L.h);
    ctx.restore();
}

function fadeVertical(ctx, L, y0, y1) {
    ctx.save();
    ctx.globalCompositeOperation = "destination-out";
    ctx.globalAlpha = 1;
    var g = ctx.createLinearGradient(0, y0, 0, y1);
    g.addColorStop(0, "rgba(0,0,0,0.25)");
    g.addColorStop(1, "rgba(0,0,0,1)");
    ctx.fillStyle = g;
    ctx.fillRect(0, y0, L.w, y1 - y0);
    ctx.restore();
}

// Lets lines melt into the orb instead of ending hard at its rim.
function orbHole(ctx, L, cx, cy, r) {
    ctx.save();
    ctx.globalCompositeOperation = "destination-out";
    ctx.globalAlpha = 1;
    var g = ctx.createRadialGradient(cx, cy, r * 0.7, cx, cy, r * 1.9);
    g.addColorStop(0, "rgba(0,0,0,1)");
    g.addColorStop(1, "rgba(0,0,0,0)");
    ctx.fillStyle = g;
    ctx.fillRect(cx - r * 2, cy - r * 2, r * 4, r * 4);
    ctx.restore();
}

// Where the orb sits for a style (also used by Visualizer.qml).
function orbGeometry(styleId, w, h, o) {
    var s = Styles.byId(styleId);
    if (!s.orb || !o || !o.orbEnabled || w <= 0 || h <= 0)
        return { show: false, x: w / 2, y: h / 2, r: 0 };
    var r;
    if (s.round && styleId !== "kaleido") {
        var R = Math.min(w, h) / 2 * 0.96;
        r = R * o.innerRadius / 100 * (styleId === "segments" ? 0.78 : 0.9);
    } else {
        r = Math.min(o.orbSize / 2, Math.min(w, h) * 0.45);
    }
    return { show: r > 3, x: w / 2, y: h / 2, r: Math.max(0, r) };
}

// ---- classic (ported from Audio Visualizer 1.6) -------------------------

function endProfile(d, rb, rt) {
    var eb = 0.14, et = 0.5;
    if (d <= 0)
        return 0;
    if (d < rb) {
        var u = d / rb;
        return eb * (1 - Math.sqrt(1 - u * u));
    }
    var x = d - rb;
    if (x < rt) {
        var w = 1 - x / rt;
        return (1 - et) + et * Math.sqrt(Math.max(0, 1 - w * w));
    }
    return 1;
}

function endZone(soft, base, C) {
    if (soft <= 0.5)
        return { rb: 0, rt: 0, len: 0 };
    var rb = Math.min(base, soft);
    var sc = Math.min(1, (C.rowWidth / 2) / (soft + rb));
    return { rb: rb * sc, rt: soft * sc, len: (soft + rb) * sc };
}

function envelope(x, C) {
    var e = 1;
    if (C.zl.len > 0)
        e *= endProfile(x - C.rowStartX, C.zl.rb, C.zl.rt);
    if (C.zr.len > 0)
        e *= endProfile(C.rowStartX + C.rowWidth - x, C.zr.rb, C.zr.rt);
    return e;
}

function topRoundedPath(ctx, x, y, w, bottom, r) {
    ctx.beginPath();
    if (r > 0.5) {
        ctx.moveTo(x, bottom);
        ctx.lineTo(x, y + r);
        ctx.arc(x + r, y + r, r, Math.PI, 1.5 * Math.PI);
        ctx.arc(x + w - r, y + r, r, 1.5 * Math.PI, 2 * Math.PI);
        ctx.lineTo(x + w, bottom);
        ctx.closePath();
    } else {
        ctx.rect(x, y, w, bottom - y);
    }
}

function roundedPath(ctx, x, top, w, bottom, r, keepPath) {
    if (!keepPath)
        ctx.beginPath();
    r = Math.max(0, Math.min(r, w / 2, (bottom - top) / 2));
    if (r > 0.5) {
        ctx.moveTo(x, top + r);
        ctx.arc(x + r, top + r, r, Math.PI, 1.5 * Math.PI);
        ctx.arc(x + w - r, top + r, r, 1.5 * Math.PI, 2 * Math.PI);
        ctx.arc(x + w - r, bottom - r, r, 0, 0.5 * Math.PI);
        ctx.arc(x + r, bottom - r, r, 0.5 * Math.PI, Math.PI);
        ctx.closePath();
    } else {
        ctx.rect(x, top, w, bottom - top);
    }
}

function classicLayout(L, soft, base) {
    var v = L.v, n = v.length, o = L.o;
    var totalSpacing = o.barSpacing * (n - 1);
    var auto = o.barWidthAuto !== false;
    var barWidth = auto ? Math.max(1, (L.w - totalSpacing) / n) : Math.max(1, o.barWidth);
    var rowWidth = n * barWidth + totalSpacing;
    var C = { n: n, h: base, barWidth: barWidth, spacing: o.barSpacing, rowWidth: rowWidth,
              rowStartX: auto ? 0 : Math.round((L.w - rowWidth) / 2) };
    C.zl = endZone(soft ? L.soft.left : 0, L.soft.base, C);
    C.zr = endZone(soft ? L.soft.right : 0, L.soft.base, C);
    return C;
}

function verticalFill(ctx, L, top, bottom) {
    return linGrad(ctx, L, 0, bottom, 0, top, 0, 1, 10);
}

function updatePeaks(L, key, vals) {
    var S = L.S;
    if (!S[key] || S[key].length !== vals.length)
        S[key] = vals.slice();
    var fall = (0.08 + L.o.peakFall / 100 * 1.4) * L.dt;
    var p = S[key];
    for (var i = 0; i < vals.length; i++)
        p[i] = vals[i] >= p[i] ? vals[i] : Math.max(vals[i], p[i] - fall);
    return p;
}

function drawBars(ctx, L) {
    var o = L.o;
    var refl = o.reflection;
    var base = refl ? L.h * 0.8 : L.h;
    var C = classicLayout(L, true, base);
    var v = L.v;
    var radius = Math.max(0, Math.min(o.cornerRadius, C.barWidth / 2, base / 2));
    ctx.fillStyle = verticalFill(ctx, L, 0, base);
    ctx.globalAlpha = L.alpha;
    var heights = [];
    for (var i = 0; i < C.n; i++) {
        var x = C.rowStartX + i * (C.barWidth + C.spacing);
        var e = envelope(x + C.barWidth / 2, C);
        var barH = v[i] * base * (o.peakCaps ? 0.94 : 1) * e;
        if (e > 0.999)
            barH = Math.max(2, barH);
        heights.push(barH);
        if (barH < 0.5)
            continue;
        topRoundedPath(ctx, x, base - barH, C.barWidth, base, Math.min(radius, barH / 2));
        ctx.fill();
    }
    if (o.peakCaps) {
        var p = updatePeaks(L, "barPeaks", v);
        ctx.beginPath();
        for (var k = 0; k < C.n; k++) {
            var px = C.rowStartX + k * (C.barWidth + C.spacing);
            var py = base - p[k] * base * 0.94 - 5;
            ctx.rect(px, py, C.barWidth, Math.max(2, Math.min(4, C.barWidth * 0.4)));
        }
        ctx.fill();
    }
    if (refl) {
        ctx.globalAlpha = L.alpha * o.reflectionStrength / 100 * 0.6;
        for (var j = 0; j < C.n; j++) {
            if (heights[j] < 0.5)
                continue;
            var rx = C.rowStartX + j * (C.barWidth + C.spacing);
            ctx.fillRect(rx, base + 1, C.barWidth, Math.min(L.h - base, heights[j] * 0.35));
        }
        fadeVertical(ctx, L, base, L.h);
    }
}

function drawSpine(ctx, L) {
    var C = classicLayout(L, true, L.h);
    var o = L.o, v = L.v;
    var midY = L.h / 2;
    var radius = Math.max(0, Math.min(o.cornerRadius, C.barWidth / 2, midY));
    ctx.globalAlpha = L.alpha;
    for (var i = 0; i < C.n; i++) {
        var x = C.rowStartX + i * (C.barWidth + C.spacing);
        var e = envelope(x + C.barWidth / 2, C);
        var halfH = v[i] * midY * e;
        if (e > 0.999)
            halfH = Math.max(1, halfH);
        if (halfH < 0.5)
            continue;
        roundedPath(ctx, x, midY - halfH, C.barWidth, midY + halfH, Math.min(radius, halfH));
        ctx.fillStyle = L.grad ? L.grad : linGrad(ctx, L, 0, midY + halfH, 0, midY - halfH, 0, 1, 6);
        ctx.fill();
    }
}

function sampleOutline(cx, cy, x) {
    var lo = 0, hi = cx.length - 1;
    if (x <= cx[0])
        return cy[0];
    if (x >= cx[hi])
        return cy[hi];
    while (hi - lo > 1) {
        var m = (lo + hi) >> 1;
        if (cx[m] <= x)
            lo = m;
        else
            hi = m;
    }
    var f = (x - cx[lo]) / (cx[hi] - cx[lo]);
    return cy[lo] + (cy[hi] - cy[lo]) * f;
}

function waveSilhouette(ctx, L) {
    var C = classicLayout(L, true, L.h);
    C.rowStartX = 0;
    C.rowWidth = L.w;
    C.zl = endZone(L.soft.left, L.soft.base, C);
    C.zr = endZone(L.soft.right, L.soft.base, C);
    var n = C.n, v = L.v, h = L.h;
    var px = [], py = [];
    for (var i = 0; i < n; i++) {
        px.push((n === 1) ? 0 : (i / (n - 1)) * L.w);
        py.push(h - Math.max(1, v[i] * h));
    }
    var cx = [px[0]], cy = [py[0]];
    var seg = 10;
    for (var j = 1; j < n; j++) {
        var mx = (px[j - 1] + px[j]) / 2;
        for (var k = 1; k <= seg; k++) {
            var t = k / seg, u = 1 - t;
            cx.push(u * u * u * px[j - 1] + 3 * u * u * t * mx + 3 * u * t * t * mx + t * t * t * px[j]);
            cy.push(py[j - 1] * (u * u * u + 3 * u * u * t) + py[j] * (3 * u * t * t + t * t * t));
        }
    }
    var xs = [];
    var x0 = 0, x1 = L.w;
    var lo = x0 + C.zl.len, hi = x1 - C.zr.len;
    var x;
    if (C.zl.len > 0)
        for (x = x0; x < lo; x += 0.5)
            xs.push(x);
    for (var q = 0; q < cx.length; q++)
        if (cx[q] >= lo && cx[q] <= hi)
            xs.push(cx[q]);
    if (C.zr.len > 0) {
        for (x = hi + 0.5; x < x1; x += 0.5)
            xs.push(x);
        xs.push(x1);
    }
    var minY = h;
    ctx.beginPath();
    ctx.moveTo(xs[0], h);
    for (var m = 0; m < xs.length; m++) {
        var y0 = sampleOutline(cx, cy, xs[m]);
        var y = h - (h - y0) * envelope(xs[m], C);
        if (y < minY)
            minY = y;
        ctx.lineTo(xs[m], y);
    }
    ctx.lineTo(xs[xs.length - 1], h);
    ctx.closePath();
    return minY;
}

function drawWave(ctx, L) {
    var minY = waveSilhouette(ctx, L);
    ctx.fillStyle = verticalFill(ctx, L, minY, L.h);
    ctx.globalAlpha = L.alpha;
    ctx.fill();
}

function drawMacosWave(ctx, L) {
    waveSilhouette(ctx, L);
    ctx.fillStyle = linGrad(ctx, L, 0, 0, Math.max(1, L.w), 0, 0, 1, 48);
    ctx.globalAlpha = L.alpha;
    ctx.fill();
}

function drawDots(ctx, L) {
    var C = classicLayout(L, false, L.h);
    var v = L.v;
    var radius = Math.max(2, Math.min(C.barWidth, L.h / 2) * 0.45);
    ctx.fillStyle = verticalFill(ctx, L, 0, L.h);
    ctx.globalAlpha = L.alpha;
    ctx.beginPath();
    for (var i = 0; i < C.n; i++) {
        var cx = C.rowStartX + i * (C.barWidth + C.spacing) + C.barWidth / 2;
        var cy = L.h - Math.max(radius, v[i] * L.h);
        ctx.moveTo(cx + radius, cy);
        ctx.arc(cx, cy, radius, 0, TAU);
    }
    ctx.fill();
}

function drawParticles(ctx, L) {
    var C = classicLayout(L, false, L.h);
    var v = L.v;
    var ph = Math.max(10, Math.min(L.h * 0.45, C.barWidth * 4));
    var radius = Math.max(0, Math.min(L.o.cornerRadius, C.barWidth / 2, ph / 2));
    ctx.fillStyle = verticalFill(ctx, L, 0, L.h);
    ctx.globalAlpha = L.alpha;
    for (var i = 0; i < C.n; i++) {
        var centerY = L.h - v[i] * L.h;
        var top = centerY - ph / 2;
        var bottom = top + ph;
        if (top < 0) { top = 0; bottom = ph; }
        if (bottom > L.h) { bottom = L.h; top = L.h - ph; }
        var x = C.rowStartX + i * (C.barWidth + C.spacing);
        roundedPath(ctx, x, top, C.barWidth, bottom, radius);
        ctx.fill();
    }
}

// ---- macOS group --------------------------------------------------------

// Reference picture 7: LED dot matrix
function drawLed(ctx, L) {
    var o = L.o;
    var cols = Math.max(4, Math.round(o.density));
    var rows = Math.max(3, Math.round(o.ledRows));
    var cw = L.w / cols, ch = L.h / rows;
    var gap = clamp(o.barSpacing / 20, 0, 1) * 0.6;
    var r = Math.max(0.8, Math.min(cw, ch) * 0.5 * (1 - gap));
    var lit = [];
    for (var c = 0; c < cols; c++)
        lit.push(Math.round(sample(L.v, c / Math.max(1, cols - 1)) * rows));
    var peaks = o.peakCaps ? updatePeaks(L, "ledPeaks", lit.map(function (x) { return x / rows; })) : null;
    var g = o.glow / 100;

    if (o.dimUnlit) {
        ctx.beginPath();
        for (var c0 = 0; c0 < cols; c0++) {
            var x0 = (c0 + 0.5) * cw;
            for (var r0 = lit[c0]; r0 < rows; r0++) {
                var y0 = L.h - (r0 + 0.5) * ch;
                ctx.moveTo(x0 + r, y0);
                ctx.arc(x0, y0, r, 0, TAU);
            }
        }
        ctx.fillStyle = "rgba(255,255,255,1)";
        ctx.globalAlpha = 0.035 * L.alpha;
        ctx.fill();
    }

    for (var row = 0; row < rows; row++) {
        var y = L.h - (row + 0.5) * ch;
        var f = rows === 1 ? 0 : row / (rows - 1);
        var color = L.grad ? L.grad : L.pal.css(f);
        var any = false;
        ctx.beginPath();
        for (var cc = 0; cc < cols; cc++) {
            var on = row < lit[cc];
            if (!on && peaks) {
                var pr = Math.round(peaks[cc] * rows) - 1;
                on = pr === row && pr >= lit[cc];
            }
            if (!on)
                continue;
            var x = (cc + 0.5) * cw;
            ctx.moveTo(x + r, y);
            ctx.arc(x, y, r, 0, TAU);
            any = true;
        }
        if (!any)
            continue;
        ctx.fillStyle = color;
        if (g > 0.02) {
            ctx.globalAlpha = 0.22 * g * L.alpha;
            ctx.strokeStyle = color;
            ctx.lineWidth = r * 1.4 * g + 1;
            ctx.stroke();
        }
        ctx.globalAlpha = L.alpha;
        ctx.fill();
    }
}

function hash3(a, b, c) {
    var x = Math.sin(a * 127.1 + b * 311.7 + c * 74.7) * 43758.5453;
    return x - Math.floor(x);
}

// Reference picture 8: skyline
function drawSkyline(ctx, L) {
    var o = L.o;
    var k = Math.max(4, Math.round(o.density));
    var gap = o.barSpacing;
    var bw = Math.max(2, (L.w - gap * (k - 1)) / k);
    var base = o.reflection ? L.h * 0.88 : L.h;
    var g = o.glow / 100;
    var win = Math.max(2, Math.min(5, bw / 6));
    var wgap = Math.max(1.2, win * 0.55);
    var slow = Math.floor(L.t * 0.25);
    for (var i = 0; i < k; i++) {
        var f = k === 1 ? 0 : i / (k - 1);
        var val = sample(L.v, f);
        var hb = Math.max(win * 4, (0.1 + 0.9 * val) * base * 0.96);
        var x = i * (bw + gap), top = base - hb;
        var color = col(L, f);
        // body
        ctx.fillStyle = L.grad ? L.grad : L.pal.tint(f, -0.72);
        ctx.globalAlpha = L.alpha;
        ctx.fillRect(x, top, bw, hb);
        // outline
        ctx.strokeStyle = color;
        ctx.lineWidth = 1.2;
        ctx.globalAlpha = L.alpha * (0.75 + 0.25 * g);
        ctx.strokeRect(x + 0.6, top + 0.6, bw - 1.2, hb - 0.6);
        // windows
        var colsW = Math.max(1, Math.floor((bw - wgap) / (win + wgap)));
        var rowsW = Math.max(1, Math.floor((hb - wgap * 2) / (win + wgap)));
        var offx = x + (bw - (colsW * (win + wgap) - wgap)) / 2;
        ctx.beginPath();
        for (var ry = 0; ry < rowsW; ry++) {
            for (var cx = 0; cx < colsW; cx++) {
                if (hash3(i, ry, cx + slow * 0.13) > o.windowsLit / 100)
                    continue;
                ctx.rect(offx + cx * (win + wgap), top + wgap * 1.5 + ry * (win + wgap), win, win);
            }
        }
        ctx.fillStyle = L.grad ? L.grad : L.pal.tint(f, 0.15);
        ctx.globalAlpha = L.alpha * (0.55 + 0.45 * Math.min(1, val * 1.6));
        ctx.fill();
        if (g > 0.02) {
            ctx.globalAlpha = L.alpha * 0.12 * g;
            ctx.lineWidth = 6 * g + 1;
            ctx.strokeRect(x, top, bw, hb);
        }
        // ground / reflection
        if (o.reflection) {
            ctx.fillStyle = color;
            ctx.globalAlpha = L.alpha * o.reflectionStrength / 100 * 0.55;
            ctx.fillRect(x, base + 1, bw, L.h - base);
        }
    }
    if (o.reflection)
        fadeVertical(ctx, L, base, L.h);
}

// Reference picture 9: rounded rainbow bars with peak caps and reflection
function drawMacBars(ctx, L) {
    var o = L.o;
    var k = Math.max(4, Math.round(o.density));
    var gap = o.barSpacing;
    var bw = Math.max(1.5, (L.w - gap * (k - 1)) / k);
    var base = o.reflection ? L.h * 0.88 : L.h;
    var top0 = o.peakCaps ? 10 : 2;
    var r = Math.min(o.cornerRadius, bw / 2);
    var vals = [];
    for (var i = 0; i < k; i++)
        vals.push(sample(L.v, k === 1 ? 0 : i / (k - 1)));
    var peaks = o.peakCaps ? updatePeaks(L, "macPeaks", vals) : null;
    var avail = base - top0;
    for (var j = 0; j < k; j++) {
        var f = k === 1 ? 0 : j / (k - 1);
        var hb = Math.max(r * 2 + 2, vals[j] * avail * 0.92 + 4);
        var x = j * (bw + gap);
        if (L.grad) {
            ctx.fillStyle = L.grad;
        } else {
            var gr = ctx.createLinearGradient(0, base, 0, base - hb);
            gr.addColorStop(0, L.pal.css(f));
            gr.addColorStop(1, L.pal.tint(clamp(f + 0.1, 0, 1), 0.18));
            ctx.fillStyle = gr;
        }
        ctx.globalAlpha = L.alpha;
        roundedPath(ctx, x, base - hb, bw, base, r);
        ctx.fill();
        if (peaks) {
            var py = base - Math.max(peaks[j] * avail * 0.92 + 4, hb) - 7;
            ctx.fillStyle = L.grad ? L.grad : L.pal.tint(f, 0.3);
            ctx.globalAlpha = L.alpha * 0.9;
            roundedPath(ctx, x, py, bw, py + 2.5, 1.2);
            ctx.fill();
        }
        if (o.reflection) {
            ctx.fillStyle = L.grad ? L.grad : L.pal.css(f);
            ctx.globalAlpha = L.alpha * o.reflectionStrength / 100 * 0.7;
            roundedPath(ctx, x, base + 2, bw, base + 2 + Math.min(L.h - base - 2, hb * 0.3), r);
            ctx.fill();
        }
    }
    if (o.reflection)
        fadeVertical(ctx, L, base, L.h);
}

// ---- lines & light ------------------------------------------------------

function speedOf(L) { return L.o.speed / 100; }

// The bright light where the lines meet (from reference picture 3). It
// breathes with the music; with an orb it becomes a halo around the orb.
function centerGlow(ctx, L, cx, cy, orb) {
    if (L.o.centerGlow === false)
        return;
    var e = L.en.avg, b = L.en.bass;
    var inner = orb.show ? orb.r * 0.85 : 0;
    var rr = (orb.show ? orb.r * 0.75 : 0) + Math.min(L.h, L.w) * (0.04 + 0.11 * b) + 3;
    var k = orb.show ? 0.6 : 1;          // a softer halo around the orb
    ctx.save();
    ctx.globalCompositeOperation = "lighter";
    ctx.globalAlpha = L.alpha;
    // never wider than the surface, so the halo is not cut off at an edge
    var R = Math.max(inner + 4, Math.min(rr * 2.2, Math.min(L.h, L.w) * 0.5));
    var g = ctx.createRadialGradient(cx, cy, inner, cx, cy, R);
    g.addColorStop(0, "rgba(255,255,255," + k * (0.5 + 0.45 * e) + ")");
    g.addColorStop(0.22, "rgba(255,248,232," + k * (0.22 + 0.3 * e) + ")");
    g.addColorStop(1, "rgba(255,255,255,0)");
    ctx.fillStyle = g;
    ctx.fillRect(cx - R, cy - R, R * 2, R * 2);
    if (!orb.show) {
        // the thin bright line through the meeting point
        var half = L.w * (0.03 + 0.04 * e);
        var lg = ctx.createLinearGradient(cx - half, 0, cx + half, 0);
        lg.addColorStop(0, "rgba(255,255,255,0)");
        lg.addColorStop(0.5, "rgba(255,255,255," + (0.65 + 0.35 * e) + ")");
        lg.addColorStop(1, "rgba(255,255,255,0)");
        ctx.fillStyle = lg;
        ctx.fillRect(cx - half, cy - 0.8, half * 2, 1.6);
    }
    ctx.restore();
}

// A phase that runs faster with louder music (accumulated, so it never jumps).
function musicPhase(L, key, base) {
    var p = (L.S[key] || 0) + L.dt * base * (0.55 + 1.8 * L.en.avg);
    L.S[key] = p;
    return p;
}

// Reference picture 1: double helix
function drawHelix(ctx, L) {
    var o = L.o, w = L.w, h = L.h, cx = w / 2, cy = h / 2;
    var sp = speedOf(L);
    var phase = musicPhase(L, "helixPhase", 2.2 * sp);
    var k = TAU * (o.turns / 2) / w;
    var lw = o.lineWidth;
    var amax = (h / 2 - lw * 3 - 2);
    var amp = o.amplitude / 100;
    var step = Math.max(2, w / 500);
    var orb = orbGeometry(L.styleId, w, h, o);
    var pump = 0.7 + 0.6 * L.en.bass;
    var p1 = [], p2 = [];
    for (var x = 0; x <= w + 0.1; x += step) {
        var d = Math.abs(x - cx) / (w / 2);
        var prof = 0.03 + 0.97 * Math.pow(d, 1.05);
        var audio = 0.12 + 1.3 * sample(L.v, d);
        var A = Math.min(amax, amax * prof * audio * amp * pump);
        var th = k * Math.abs(x - cx) - phase;
        var sn = Math.sin(th);
        p1.push(x, cy + A * sn);
        p2.push(x, cy - A * sn);
    }
    ctx.lineJoin = "round";
    ctx.lineCap = "round";
    if (o.additive)
        ctx.globalCompositeOperation = "lighter";

    if (o.rungs) {
        ctx.beginPath();
        var every = Math.max(2, Math.round((Math.PI / k) / 4 / step));
        for (var i = 0; i < p1.length; i += 2 * every) {
            ctx.moveTo(p1[i], p1[i + 1]);
            ctx.lineTo(p2[i], p2[i + 1]);
        }
        ctx.strokeStyle = linGrad(ctx, L, 0, 0, w, 0, 0, 1, 16);
        ctx.lineWidth = 1;
        ctx.globalAlpha = (0.07 + 0.1 * L.en.avg) * L.alpha;
        ctx.stroke();
    }

    var strands = [[p1, 0.0], [p2, 0.5]];
    for (var sIdx = 0; sIdx < 2; sIdx++) {
        var pts = strands[sIdx][0], off = strands[sIdx][1];
        ctx.beginPath();
        ctx.moveTo(pts[0], pts[1]);
        for (var j = 2; j < pts.length; j += 2)
            ctx.lineTo(pts[j], pts[j + 1]);
        if (L.grad) {
            ctx.strokeStyle = L.grad;
        } else {
            var g = ctx.createLinearGradient(0, 0, w, 0);
            for (var q = 0; q <= 32; q++) {
                var s2 = q / 32;
                var dd = Math.abs(s2 - 0.5) * 2;
                g.addColorStop(s2, L.pal.css((dd * 0.5 + off) % 1));
            }
            ctx.strokeStyle = g;
        }
        glowStroke(ctx, L, lw * (0.9 + 0.5 * L.en.avg), 1);
    }
    ctx.globalCompositeOperation = "source-over";
    if (orb.show)
        orbHole(ctx, L, orb.x, orb.y, orb.r);
    fadeEdges(ctx, L, o.edgeFade);
    centerGlow(ctx, L, cx, cy, orb);
}

// Reference picture 2: laser fan
function drawBeams(ctx, L) {
    var o = L.o, w = L.w, h = L.h, cx = w / 2, cy = h / 2;
    var n = Math.max(2, Math.round(o.lineCount));
    var orb = orbGeometry(L.styleId, w, h, o);
    var gap = orb.show ? orb.r + 2 : 0;          // without an orb the rays meet in one point
    var sp = speedOf(L);
    var t = musicPhase(L, "beamPhase", 1.3 * sp);
    var spread = o.spread / 100 * h * 0.5 * (0.5 + 0.75 * L.en.bass);
    var g = o.glow / 100;
    if (o.additive)
        ctx.globalCompositeOperation = "lighter";
    for (var side = 0; side < 2; side++) {
        var dir = side === 0 ? 1 : -1;
        var x0 = side === 0 ? 0 : w;
        var xc = cx - dir * gap;
        for (var i = 0; i < n; i++) {
            var u = n === 1 ? 0 : (i / (n - 1)) * 2 - 1;
            var au = Math.abs(u);
            var val = sample(L.v, side === 0 ? au : 1 - au);
            var sway = Math.sin(t + i * 1.1 + side * 2) * h * 0.012 * (1 + 3 * L.en.mid);
            var ye = cy + u * spread * (0.8 + 0.4 * val) + sway;
            var tw = o.lineWidth * (0.6 + 3.6 * val);
            var f = side === 0 ? au * 0.5 : 0.5 + au * 0.5;
            var a = 0.2 + 0.8 * val;
            var gr;
            if (L.grad) {
                gr = L.grad;
            } else {
                gr = ctx.createLinearGradient(x0, 0, xc, 0);
                gr.addColorStop(0, L.pal.rgba(f, 0.9));
                gr.addColorStop(0.55, L.pal.rgba(f, 0.75));
                gr.addColorStop(1, L.pal.tint(f, 0.35, 0.95));
            }
            ctx.fillStyle = gr;
            if (g > 0.02) {
                ctx.beginPath();
                ctx.moveTo(x0, ye - tw * (1 + 2.5 * g));
                ctx.lineTo(x0, ye + tw * (1 + 2.5 * g));
                ctx.lineTo(xc, cy);
                ctx.closePath();
                ctx.globalAlpha = L.alpha * a * 0.16 * g;
                ctx.fill();
            }
            ctx.beginPath();
            ctx.moveTo(x0, ye - tw / 2);
            ctx.lineTo(x0, ye + tw / 2);
            ctx.lineTo(xc, cy + 0.4);
            ctx.lineTo(xc, cy - 0.4);
            ctx.closePath();
            ctx.globalAlpha = L.alpha * a;
            ctx.fill();
        }
    }
    ctx.globalCompositeOperation = "source-over";
    if (orb.show)
        orbHole(ctx, L, orb.x, orb.y, orb.r);
    fadeEdges(ctx, L, o.edgeFade);
    centerGlow(ctx, L, cx, cy, orb);
}

function convergeGap(L, orb) {
    return orb.show ? orb.r + 2 : 0;
}

// Reference picture 3: light strings bundled into a bright point
function drawStrings(ctx, L) {
    var o = L.o, w = L.w, h = L.h, cx = w / 2, cy = h / 2;
    var n = Math.max(2, Math.round(o.lineCount));
    var orb = orbGeometry(L.styleId, w, h, o);
    var gap = orb.show ? orb.r + 1 : 0;
    var sp = speedOf(L);
    var wav = o.waviness / 100;
    var t = musicPhase(L, "stringPhase", sp);
    ctx.lineCap = "round";
    if (o.additive)
        ctx.globalCompositeOperation = "lighter";
    for (var side = 0; side < 2; side++) {
        for (var i = 0; i < n; i++) {
            var u = n === 1 ? 0 : (i / (n - 1)) * 2 - 1;
            var val = sample(L.v, Math.abs(u));
            var y0 = cy + u * h * 0.52 * (o.spread / 100) * 1.15 * (0.55 + 0.6 * val);
            var wob = wav * h * 0.22 * (0.2 + 1.3 * val);
            var c1y = y0 + wob * Math.sin(t * 0.9 + i * 1.37 + side);
            var c2y = cy + u * h * 0.05 + wob * 0.55 * Math.sin(t * 1.3 + i * 2.1 + side * 3);
            var X = function (x) { return side === 0 ? x : w - x; };
            ctx.beginPath();
            ctx.moveTo(X(0), y0 + wob * 0.3 * Math.sin(t * 0.7 + i));
            ctx.bezierCurveTo(X(w * 0.2), c1y, X(cx - w * 0.16), c2y, X(cx - gap), cy);
            ctx.strokeStyle = col(L, (u + 1) / 2);
            glowStroke(ctx, L, o.lineWidth * (0.8 + 0.8 * val), 0.4 + 0.55 * val);
        }
    }
    ctx.globalCompositeOperation = "source-over";
    if (orb.show)
        orbHole(ctx, L, orb.x, orb.y, orb.r);
    fadeEdges(ctx, L, o.edgeFade);
    centerGlow(ctx, L, cx, cy, orb);
}

// Reference picture 4/5: colour streams flowing into the orb
function drawRibbons(ctx, L) {
    var o = L.o, w = L.w, h = L.h, cx = w / 2, cy = h / 2;
    var n = Math.max(2, Math.round(o.lineCount));
    var orb = orbGeometry(L.styleId, w, h, o);
    var gap = orb.show ? orb.r * 0.95 : 0;       // without an orb the streams meet in the middle
    var sp = speedOf(L);
    var wav = o.waviness / 100;
    var t = musicPhase(L, "ribbonPhase", 1.6 * sp);
    var steps = Math.max(40, Math.round(w / 12));
    ctx.lineJoin = "round";
    ctx.lineCap = "round";
    if (o.additive)
        ctx.globalCompositeOperation = "lighter";
    for (var side = 0; side < 2; side++) {
        for (var i = 0; i < n; i++) {
            var u = n === 1 ? 0 : (i / (n - 1)) * 2 - 1;
            var val = sample(L.v, Math.abs(u) * 0.85 + (side ? 0.1 : 0));
            var yEdge = cy + u * h * 0.47 * (o.spread / 100) * (0.55 + 0.6 * val);
            var yEnd = orb.show ? cy + u * Math.max(2, gap * 0.12) : cy;
            var xEnd = cx - gap;
            ctx.beginPath();
            for (var k = 0; k <= steps; k++) {
                var s = k / steps;
                var e = smooth01((s - 0.12) / 0.88);
                e = Math.pow(e, 1.25);
                var x = s * xEnd;
                var wig = wav * h * 0.055 * (0.25 + 2.2 * val)
                    * Math.sin(TAU * s * 1.6 - t + i * 0.8 + side * 1.9)
                    * Math.pow(1 - s, 0.7);
                var y = yEdge + (yEnd - yEdge) * e + wig;
                var X = side === 0 ? x : w - x;
                if (k === 0)
                    ctx.moveTo(X, y);
                else
                    ctx.lineTo(X, y);
            }
            ctx.strokeStyle = col(L, (u + 1) / 2);
            glowStroke(ctx, L, o.lineWidth * (0.8 + 0.9 * val), 0.95);
        }
    }
    ctx.globalCompositeOperation = "source-over";
    if (orb.show)
        orbHole(ctx, L, orb.x, orb.y, orb.r * 0.9);
    fadeEdges(ctx, L, o.edgeFade);
    centerGlow(ctx, L, cx, cy, orb);
}

// Reference picture 6: layered silk waves
function drawSilk(ctx, L) {
    var o = L.o, w = L.w, h = L.h, cy = h / 2;
    var n = Math.max(1, Math.round(o.lineCount));
    var sp = speedOf(L);
    var amp = o.amplitude / 100;
    var steps = Math.max(60, Math.round(w / 6));
    var silkT = musicPhase(L, "silkPhase", sp);
    ctx.lineJoin = "round";
    if (o.additive)
        ctx.globalCompositeOperation = "lighter";
    for (var i = 0; i < n; i++) {
        var f = n === 1 ? 0 : i / (n - 1);
        var band = bandAvg(L.v, i / n, (i + 1) / n);
        var A = h * 0.44 * amp * (0.12 + 1.3 * band);
        var freq = 1.1 + i * 0.22;
        var ph = silkT * (0.9 + 0.17 * i) + i * 1.7;
        var c = 0.5 + 0.16 * Math.sin(L.t * 0.35 * sp + i * 1.3);
        var sig = 0.2 + 0.04 * Math.sin(i * 2.1);
        ctx.beginPath();
        for (var k = 0; k <= steps; k++) {
            var s = k / steps;
            var env = Math.exp(-Math.pow((s - c) / sig, 2)) * Math.pow(Math.sin(Math.PI * s), 1.4);
            var y = cy + A * env * Math.sin(TAU * freq * s * 2 - ph);
            if (k === 0)
                ctx.moveTo(s * w, y);
            else
                ctx.lineTo(s * w, y);
        }
        ctx.strokeStyle = col(L, f);
        glowStroke(ctx, L, o.lineWidth, 0.85);
    }
    ctx.globalCompositeOperation = "source-over";
    fadeEdges(ctx, L, o.edgeFade);
}

// ---- round --------------------------------------------------------------

function roundFrame(L) {
    var R = Math.min(L.w, L.h) / 2 * 0.96;
    var rot = L.S.rot || 0;
    rot += (L.o.rotation / 100) * 0.9 * L.dt;
    L.S.rot = rot;
    return { cx: L.w / 2, cy: L.h / 2, R: R, r0: R * L.o.innerRadius / 100, rot: rot };
}

// Reference picture 10: ring spectrum
function drawRing(ctx, L) {
    var o = L.o, F = roundFrame(L);
    var m = Math.max(12, Math.round(o.density));
    var orb = orbGeometry(L.styleId, L.w, L.h, o);
    var start = F.r0 + Math.max(3, o.lineWidth * 1.5);
    var maxLen = (F.R - start) * o.rayLength / 100;
    ctx.lineCap = "round";
    for (var j = 0; j < m; j++) {
        var f = j / m;
        var a = -Math.PI / 2 + f * TAU + F.rot;
        var val = mirrorSample(L.v, f);
        var len = maxLen * (0.1 + 0.9 * val);
        var ca = Math.cos(a), sa = Math.sin(a);
        ctx.beginPath();
        ctx.moveTo(F.cx + ca * start, F.cy + sa * start);
        ctx.lineTo(F.cx + ca * (start + len), F.cy + sa * (start + len));
        ctx.strokeStyle = col(L, f);
        glowStroke(ctx, L, o.lineWidth, 1);
    }
    if (!orb.show) {
        ctx.beginPath();
        ctx.arc(F.cx, F.cy, F.r0, 0, TAU);
        ctx.strokeStyle = col(L, 0.15);
        ctx.lineWidth = 1.5;
        ctx.globalAlpha = 0.8 * L.alpha;
        ctx.stroke();
    }
}

// Reference picture 11: segmented rings
function drawSegments(ctx, L) {
    var o = L.o, F = roundFrame(L);
    var m = Math.max(8, Math.round(o.density));
    var rows = Math.max(2, Math.round(o.segmentRows));
    var band = (F.R - F.r0) / rows;
    var radGap = band * 0.2;
    var angGap = clamp(o.barSpacing / 20, 0, 1) * 0.55 + 0.05;
    var seg = TAU / m;
    var lit = [];
    for (var j = 0; j < m; j++)
        lit.push(Math.round(mirrorSample(L.v, j / m) * rows));

    function sector(r0, r1, a0, a1) {
        ctx.moveTo(F.cx + Math.cos(a0) * r1, F.cy + Math.sin(a0) * r1);
        ctx.arc(F.cx, F.cy, r1, a0, a1, false);
        ctx.arc(F.cx, F.cy, r0, a1, a0, true);
        ctx.closePath();
    }

    for (var row = 0; row < rows; row++) {
        var ri = F.r0 + row * band + radGap / 2;
        var ro = ri + band - radGap;
        var half = seg * (1 - angGap) / 2;
        var f = rows === 1 ? 0 : row / (rows - 1);
        ctx.beginPath();
        var dim = [];
        for (var k = 0; k < m; k++) {
            var mid = -Math.PI / 2 + (k + 0.5) * seg + F.rot;
            if (row < lit[k])
                sector(ri, ro, mid - half, mid + half);
            else
                dim.push(mid);
        }
        ctx.fillStyle = col(L, f);
        ctx.globalAlpha = L.alpha;
        ctx.fill();
        if (o.dimUnlit && dim.length) {
            ctx.beginPath();
            for (var d = 0; d < dim.length; d++)
                sector(ri, ro, dim[d] - half, dim[d] + half);
            ctx.fillStyle = col(L, f);
            ctx.globalAlpha = 0.07 * L.alpha;
            ctx.fill();
        }
    }
    ctx.beginPath();
    ctx.arc(F.cx, F.cy, F.r0 * 0.86, 0, TAU);
    ctx.strokeStyle = col(L, 0);
    ctx.lineWidth = 1;
    ctx.globalAlpha = 0.35 * L.alpha;
    ctx.stroke();
}

// Pulse rings (LizardTune style)
function drawPulse(ctx, L) {
    var o = L.o, F = roundFrame(L), S = L.S;
    var sp = Math.max(0.05, speedOf(L));
    if (!S.rings)
        S.rings = [];
    S.bassAvg = S.bassAvg === undefined ? L.en.bass : S.bassAvg * 0.95 + L.en.bass * 0.05;
    var since = L.t - (S.lastSpawn || -10);
    var beat = L.en.bass > S.bassAvg * 1.18 + 0.03 && since > 0.22 / sp;
    if (beat || since > 1.4 / sp) {
        S.rings.push({ r: F.r0, s: beat ? clamp(L.en.bass * 1.4, 0.35, 1) : 0.3, f: (L.t * 0.07) % 1 });
        S.lastSpawn = L.t;
    }
    var maxN = Math.max(2, Math.round(o.ringCount));
    while (S.rings.length > maxN)
        S.rings.shift();
    var grow = (F.R - F.r0) * 0.45 * sp * L.dt;
    var keep = [];
    for (var i = 0; i < S.rings.length; i++) {
        var ring = S.rings[i];
        ring.r += grow * (0.6 + ring.s);
        var life = 1 - (ring.r - F.r0) / (F.R - F.r0);
        if (life <= 0)
            continue;
        keep.push(ring);
        ctx.beginPath();
        ctx.arc(F.cx, F.cy, ring.r, 0, TAU);
        ctx.strokeStyle = col(L, ring.f);
        glowStroke(ctx, L, o.lineWidth * (0.6 + ring.s * 1.6), life * (0.4 + 0.6 * ring.s));
    }
    S.rings = keep;
    // waveform ring hugging the orb
    var m = 120;
    ctx.beginPath();
    for (var k = 0; k <= m; k++) {
        var f = k / m;
        var a = -Math.PI / 2 + f * TAU + F.rot;
        var rr = F.r0 * 1.06 + mirrorSample(L.v, f) * (F.R - F.r0) * 0.22;
        var x = F.cx + Math.cos(a) * rr, y = F.cy + Math.sin(a) * rr;
        if (k === 0)
            ctx.moveTo(x, y);
        else
            ctx.lineTo(x, y);
    }
    ctx.closePath();
    ctx.strokeStyle = L.grad ? L.grad : (function () {
        var g = ctx.createConicalGradient(F.cx, F.cy, Math.PI / 2 - F.rot);
        for (var q = 0; q <= 12; q++)
            g.addColorStop(q / 12, L.pal.css(Math.abs(q / 12 - 0.5) * 2));
        return g;
    })();
    glowStroke(ctx, L, Math.max(1.5, o.lineWidth), 0.95);
}

// Liquid orb (LizardTune style)
function drawBlob(ctx, L) {
    var o = L.o, F = roundFrame(L);
    var n = Math.max(1, Math.round(o.layers));
    var sp = speedOf(L);
    var amp = o.amplitude / 100;
    var m = 96;
    if (o.additive)
        ctx.globalCompositeOperation = "lighter";
    for (var l = n - 1; l >= 0; l--) {
        var f = n === 1 ? 0.3 : l / (n - 1);
        var rb = F.r0 * 1.08 + (F.R - F.r0) * 0.28 * (l + 1) / n;
        var pts = [];
        for (var k = 0; k < m; k++) {
            var s = k / m;
            var a = s * TAU + F.rot + l * 0.7;
            var r = rb
                + amp * (F.R - F.r0) * 0.3 * mirrorSample(L.v, s) * (0.65 + 0.35 * Math.sin(3 * a + L.t * sp * (0.6 + l * 0.35)))
                + (F.R - F.r0) * 0.035 * Math.sin(5 * a - L.t * sp * 1.1 + l * 2);
            r = Math.min(r, F.R);
            pts.push([F.cx + Math.cos(a) * r, F.cy + Math.sin(a) * r]);
        }
        ctx.beginPath();
        var p0 = pts[0], pl = pts[m - 1];
        ctx.moveTo((pl[0] + p0[0]) / 2, (pl[1] + p0[1]) / 2);
        for (var q = 0; q < m; q++) {
            var c = pts[q], nx = pts[(q + 1) % m];
            ctx.quadraticCurveTo(c[0], c[1], (c[0] + nx[0]) / 2, (c[1] + nx[1]) / 2);
        }
        ctx.closePath();
        ctx.fillStyle = col(L, f);
        ctx.globalAlpha = L.alpha * (0.16 + 0.1 * (n - l) / n);
        ctx.fill();
        ctx.strokeStyle = col(L, f);
        glowStroke(ctx, L, 1.6, 0.9);
    }
    ctx.globalCompositeOperation = "source-over";
}

// Kaleidoscope (fractal-like bloom)
function drawKaleido(ctx, L) {
    var o = L.o, F = roundFrame(L);
    var k = Math.max(3, Math.round(o.symmetry));
    var n = Math.max(1, Math.round(o.layers));
    var sp = speedOf(L);
    var amp = o.amplitude / 100;
    var orb = orbGeometry(L.styleId, L.w, L.h, o);
    var r0 = orb.show ? orb.r * 1.15 : F.R * 0.05;
    if (o.additive)
        ctx.globalCompositeOperation = "lighter";
    for (var l = 0; l < n; l++) {
        var lf = n === 1 ? 0 : l / (n - 1);
        var band = bandAvg(L.v, l / n, (l + 1) / n);
        var reach = r0 + (F.R - r0) * (0.3 + 0.7 * (l + 1) / n) * clamp(0.4 + 0.75 * band * amp, 0.2, 1);
        var width = Math.PI / k * (0.45 + 0.4 * band);
        var twist = Math.sin(L.t * sp * 0.6 + l) * 0.25;
        for (var s = 0; s < k; s++) {
            var a = s * TAU / k + F.rot * (l % 2 ? -1 : 1) + l * Math.PI / k;
            var f = clamp(lf * 0.7 + (s / k) * 0.3, 0, 1);
            var ax = Math.cos(a), ay = Math.sin(a);
            var tipX = F.cx + ax * reach, tipY = F.cy + ay * reach;
            var mr = r0 + (reach - r0) * 0.55;
            var aL = a - width + twist, aR = a + width + twist;
            ctx.beginPath();
            ctx.moveTo(F.cx + ax * r0, F.cy + ay * r0);
            ctx.quadraticCurveTo(F.cx + Math.cos(aL) * mr, F.cy + Math.sin(aL) * mr, tipX, tipY);
            ctx.quadraticCurveTo(F.cx + Math.cos(aR) * mr, F.cy + Math.sin(aR) * mr, F.cx + ax * r0, F.cy + ay * r0);
            ctx.closePath();
            ctx.fillStyle = col(L, f);
            ctx.globalAlpha = L.alpha * 0.07;
            ctx.fill();
            ctx.strokeStyle = col(L, f);
            glowStroke(ctx, L, o.lineWidth, 0.85);
            ctx.beginPath();
            ctx.arc(tipX, tipY, 1.5 + 3.5 * band, 0, TAU);
            ctx.fillStyle = col(L, f);
            ctx.globalAlpha = L.alpha;
            ctx.fill();
        }
    }
    ctx.globalCompositeOperation = "source-over";
}

// ---- entry point ----------------------------------------------------------

function paint(ctx, F) {
    var q = F.q || 1;
    ctx.setTransform(1, 0, 0, 1, 0, 0);
    ctx.globalCompositeOperation = "source-over";
    ctx.globalAlpha = 1;
    ctx.clearRect(0, 0, Math.ceil(F.w * q) + 2, Math.ceil(F.h * q) + 2);
    var vals = F.values;
    if (!vals || !vals.length || F.w <= 2 || F.h <= 2)
        return;
    ctx.setTransform(q, 0, 0, q, 0, 0);

    var S = F.S;
    var dt = S.lastT !== undefined ? clamp(F.t - S.lastT, 0, 0.1) : 0.016;
    S.lastT = F.t;
    if (!S.sm || S.sm.length !== vals.length)
        S.sm = vals.slice();
    var kDown = clamp(1 - F.smoothing, 0.05, 1);
    var kUp = clamp(kDown * 2.2, 0.05, 1);
    for (var i = 0; i < vals.length; i++) {
        var d = vals[i] - S.sm[i];
        S.sm[i] += d * (d > 0 ? kUp : kDown);
    }

    var L = { w: F.w, h: F.h, v: S.sm, t: F.t, dt: dt, o: F.o, pal: F.pal, alpha: F.alpha,
              S: S, soft: F.soft || { left: 0, right: 0, base: 8 }, styleId: F.style };
    L.en = energy(S.sm);
    L.grad = globalGradient(ctx, L, F.map, F.angle);

    ctx.lineJoin = "round";
    ctx.lineCap = "butt";
    switch (F.style) {
    case "bars":          drawBars(ctx, L); break;
    case "spine":         drawSpine(ctx, L); break;
    case "wave":          drawWave(ctx, L); break;
    case "dots":          drawDots(ctx, L); break;
    case "particles":     drawParticles(ctx, L); break;
    case "macos-led":     drawLed(ctx, L); break;
    case "macos-skyline": drawSkyline(ctx, L); break;
    case "macos-bars":    drawMacBars(ctx, L); break;
    case "helix":         drawHelix(ctx, L); break;
    case "beams":         drawBeams(ctx, L); break;
    case "strings":       drawStrings(ctx, L); break;
    case "ribbons":       drawRibbons(ctx, L); break;
    case "silk":          drawSilk(ctx, L); break;
    case "ring":          drawRing(ctx, L); break;
    case "segments":      drawSegments(ctx, L); break;
    case "pulse":         drawPulse(ctx, L); break;
    case "blob":          drawBlob(ctx, L); break;
    case "kaleido":       drawKaleido(ctx, L); break;
    default:              drawMacosWave(ctx, L); break;
    }
    ctx.globalAlpha = 1;
    ctx.globalCompositeOperation = "source-over";
}
