// A quiet chart for the lock's cards: a line (with a faint fill) or bars, on a zero-based scale; a
// sample with no reading is a GAP, never a zero. One color, the accent.
import QtQuick

Canvas {
    id: tr

    property var series: []
    property real scaleTop: 0 // 0 = the series' own maximum
    property color color: "#c4342c"
    property bool bars: false

    onSeriesChanged: requestPaint()
    onScaleTopChanged: requestPaint()
    onWidthChanged: requestPaint()
    onHeightChanged: requestPaint()

    onPaint: {
        const ctx = getContext("2d");
        ctx.reset();
        const s = tr.series || [];
        const n = s.length;
        if (n < 2)
            return;
        const vals = s.filter(v => v !== null && v !== undefined && !isNaN(v));
        const top = tr.scaleTop > 0 ? tr.scaleTop : Math.max(1, 1.15 * Math.max.apply(null, vals.length ? vals : [1]));
        const w = width, h = height, pad = 2;
        const y = v => h - pad - (h - 2 * pad) * Math.min(1, Math.max(0, v / top));
        const gone = v => v === null || v === undefined || isNaN(v);
        ctx.fillStyle = tr.color;
        ctx.strokeStyle = tr.color;
        if (tr.bars) {
            const bw = w / n;
            for (let i = 0; i < n; i++) {
                if (gone(s[i]))
                    continue;
                const top0 = y(s[i]);
                ctx.globalAlpha = 0.35 + 0.65 * (i / (n - 1));
                ctx.fillRect(i * bw + 1, top0, Math.max(1, bw - 2), h - pad - top0);
            }
            return;
        }
        const x = i => pad + (w - 2 * pad) * i / (n - 1);
        // Each unbroken run: a faint fill under it, then the line.
        let i = 0;
        while (i < n) {
            while (i < n && gone(s[i]))
                i++;
            let j = i;
            while (j < n && !gone(s[j]))
                j++;
            if (j - i >= 2) {
                const fade = ctx.createLinearGradient(0, 0, 0, h);
                fade.addColorStop(0, Qt.rgba(tr.color.r, tr.color.g, tr.color.b, 0.28));
                fade.addColorStop(1, Qt.rgba(tr.color.r, tr.color.g, tr.color.b, 0));
                ctx.fillStyle = fade;
                ctx.beginPath();
                ctx.moveTo(x(i), h);
                for (let k = i; k < j; k++)
                    ctx.lineTo(x(k), y(s[k]));
                ctx.lineTo(x(j - 1), h);
                ctx.closePath();
                ctx.fill();
                ctx.fillStyle = tr.color;
                ctx.lineWidth = 2;
                ctx.lineJoin = "round";
                ctx.beginPath();
                ctx.moveTo(x(i), y(s[i]));
                for (let k = i + 1; k < j; k++)
                    ctx.lineTo(x(k), y(s[k]));
                ctx.stroke();
            }
            i = j;
        }
    }
}
