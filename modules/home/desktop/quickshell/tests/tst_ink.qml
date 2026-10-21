// InkMath: WCAG luminance and contrast, the side, the ink and the shade, on synthetic samples.
import QtQuick
import QtTest
import "../lock"

TestCase {
    name: "Ink"

    InkMath {
        id: m
    }
    // A w x h RGBA sample: the left half one gray, the right half another, busy (alternating) if asked.
    function sample(w, h, left, right, busyLeft) {
        const d = [];
        for (let y = 0; y < h; y++)
            for (let x = 0; x < w; x++) {
                let v = x < w / 2 ? left : right;
                if (busyLeft && x < w / 2 && x % 2)
                    v = 255 - v;
                d.push(v, v, v, 255);
            }
        return d;
    }
    readonly property var inks: ({ light: "#c0caf5", dark: "#1a1b26" })
    readonly property var zones: [{ x: 0, y: 0, w: 0.4, h: 1 }]

    function test_contrast() {
        fuzzyCompare(m.contrast(1, 0), 21, 0.001);
        fuzzyCompare(m.contrast(m.hexLuminance("#ffffff"), m.hexLuminance("#000000")), 21, 0.01);
    }
    function test_dark_ink_on_paper() {
        const r = m.decide(sample(20, 10, 240, 240), 20, 10, zones, inks, 4.5);
        compare(r.ink, "dark");
        verify(r.ratio >= 4.5);
        compare(r.shade, 0, "paper already reads: no wash");
    }
    function test_light_ink_on_night() {
        const r = m.decide(sample(20, 10, 15, 15), 20, 10, zones, inks, 4.5);
        compare(r.ink, "light");
        compare(r.shade, 0);
    }
    function test_mid_gray_needs_a_shade() {
        const r = m.decide(sample(20, 10, 128, 128), 20, 10, zones, inks, 4.5);
        verify(r.ratio < 4.95);
        verify(r.shade > 0 && r.shade <= 1);
    }
    function test_side_avoids_detail() {
        compare(m.decide(sample(20, 10, 200, 200, true), 20, 10, zones, inks, 4.5).side, "right", "the busy left loses");
        compare(m.decide(sample(20, 10, 200, 200, false), 20, 10, zones, inks, 4.5).side, "left", "a tie stays left");
    }
}
