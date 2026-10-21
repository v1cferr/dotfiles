// Which ink reads on THIS print, and on which side the type disturbs it least, from a small RGBA
// sample of the screen (64 px wide is plenty for a mean and two percentiles). WCAG math; pure
// functions, no Quickshell imports, so qmltestrunner can test them.
import QtQml

QtObject {
    function lin(c) {
        const s = c / 255;
        return s <= 0.04045 ? s / 12.92 : Math.pow((s + 0.055) / 1.055, 2.4);
    }
    function luminance(r, g, b) {
        return 0.2126 * lin(r) + 0.7152 * lin(g) + 0.0722 * lin(b);
    }
    function hexLuminance(hex) {
        const h = hex.replace("#", "").slice(-6);
        return luminance(parseInt(h.slice(0, 2), 16), parseInt(h.slice(2, 4), 16), parseInt(h.slice(4, 6), 16));
    }
    function contrast(a, b) {
        return (Math.max(a, b) + 0.05) / (Math.min(a, b) + 0.05);
    }
    function pct(sorted, p) {
        return sorted.length ? sorted[Math.min(sorted.length - 1, Math.floor(p * sorted.length))] : 0;
    }

    // One zone, {x, y, w, h} as fractions of the sample: the darkest and brightest 5% and how busy
    // it is (mean luminance step to the right-hand neighbour).
    function stats(data, w, h, z) {
        const x0 = Math.max(0, Math.floor(z.x * w)), x1 = Math.min(w, Math.ceil((z.x + z.w) * w));
        const y0 = Math.max(0, Math.floor(z.y * h)), y1 = Math.min(h, Math.ceil((z.y + z.h) * h));
        const ls = [];
        let edge = 0, n = 0;
        for (let y = y0; y < y1; y++) {
            let prev = -1;
            for (let x = x0; x < x1; x++) {
                const i = 4 * (y * w + x);
                const l = luminance(data[i], data[i + 1], data[i + 2]);
                ls.push(l);
                if (prev >= 0) {
                    edge += Math.abs(l - prev);
                    n++;
                }
                prev = l;
            }
        }
        ls.sort((a, b) => a - b);
        return { lo: pct(ls, 0.05), hi: pct(ls, 0.95), detail: n ? edge / n : 0 };
    }

    // The mirror of a zone about the vertical axis.
    function mirror(z) {
        return { x: 1 - z.x - z.w, y: z.y, w: z.w, h: z.h };
    }

    // zones: the type's zones on the LEFT side. inks: {light, dark} as "#rrggbb". target: the AA
    // ratio. Returns {side, ink: "light"|"dark", ratio, shade}: shade is how opaque (0..1) a soft
    // shadow of the opposite tone must be under the type to reach the target, 0 when the print
    // already gives it.
    function decide(data, w, h, zones, inks, target) {
        const detail = zs => zs.reduce((t, z) => t + stats(data, w, h, z).detail, 0);
        const side = detail(zones.map(mirror)) < detail(zones) * 0.9 ? "right" : "left";
        const zs = (side === "right" ? zones.map(mirror) : zones).map(z => stats(data, w, h, z));
        const lo = Math.min.apply(null, zs.map(s => s.lo));
        const hi = Math.max.apply(null, zs.map(s => s.hi));
        const L = hexLuminance(inks.light), D = hexLuminance(inks.dark);
        const light = contrast(L, hi); // light ink fails first on the brightest pixels
        const dark = contrast(D, lo); // dark ink fails first on the darkest
        const ink = light >= dark ? "light" : "dark";
        const ratio = Math.max(light, dark);
        let shade = 0;
        if (ratio < target) {
            // Mix the worst background toward the opposite tone until the ink reaches the target.
            const worst = ink === "light" ? hi : lo;
            const tone = ink === "light" ? D : L;
            const need = ink === "light" ? (L + 0.05) / target - 0.05 : target * (D + 0.05) - 0.05;
            shade = Math.min(1, Math.max(0, (worst - need) / (worst - tone)));
        }
        return { side: side, ink: ink, ratio: Math.round(ratio * 100) / 100, shade: Math.round(shade * 100) / 100 };
    }
}
