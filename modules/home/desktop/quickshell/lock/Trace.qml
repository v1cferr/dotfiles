// A quiet chart for the lock's cards: a line (with a faint fill) or bars, on a zero-based scale; a
// sample with no reading is a GAP, never a zero. One color, the accent. Under the pointer it reads
// out: a hairline at the nearest sample, a dot, and a small label with its time and value.
import QtQuick
import "root:/"

Item {
    id: tr

    property var series: []
    property real scaleTop: 0 // 0 = the series' own maximum (with headroom)
    // Zero-based by default (a watt or a % is honest only from zero); a temperature sets its own floor.
    property real scaleBottom: 0
    property color color: "#c4342c"
    property bool bars: false
    property var labels: [] // one per sample, what the readout says it is ("14:32", "qui 18h")
    property string unit: "" // glued after the value in the readout (" W", "%", "°")
    property int decimals: 0
    property int hover: -1 // the sample under the pointer, -1 when none
    readonly property int pad: 2

    readonly property int count: tr.series ? tr.series.length : 0
    readonly property real ceiling: {
        const vals = (tr.series || []).filter(v => !tr.gone(v));
        if (tr.scaleTop > 0)
            return tr.scaleTop;
        const max = Math.max.apply(null, vals.length ? vals : [1]);
        return tr.scaleBottom !== 0 ? max + 0.15 * (max - tr.scaleBottom) : Math.max(1, 1.15 * max);
    }
    function gone(v) {
        return v === null || v === undefined || isNaN(v);
    }
    function xAt(i) {
        if (tr.bars)
            return (i + 0.5) * tr.width / Math.max(1, tr.count);
        return tr.pad + (tr.width - 2 * tr.pad) * i / Math.max(1, tr.count - 1);
    }
    function yAt(v) {
        return tr.height - tr.pad - (tr.height - 2 * tr.pad) * Math.min(1, Math.max(0, (v - tr.scaleBottom) / Math.max(1e-6, tr.ceiling - tr.scaleBottom)));
    }

    onSeriesChanged: cv.requestPaint()
    onCeilingChanged: cv.requestPaint()
    onWidthChanged: cv.requestPaint()
    onHeightChanged: cv.requestPaint()
    onHoverChanged: cv.requestPaint()

    // The marks. The readout is a sibling, not a child: a Canvas draws none of its children.
    Canvas {
        id: cv
        anchors.fill: parent
        onPaint: {
            const ctx = cv.getContext("2d");
            ctx.reset();
            const s = tr.series || [];
            const n = s.length;
            if (n < 2)
                return;
            const w = cv.width, h = cv.height;
            ctx.fillStyle = tr.color;
            ctx.strokeStyle = tr.color;
            if (tr.bars) {
                const bw = w / n;
                for (let i = 0; i < n; i++) {
                    if (tr.gone(s[i]))
                        continue;
                    const top0 = tr.yAt(s[i]);
                    ctx.globalAlpha = i === tr.hover ? 1 : (tr.hover >= 0 ? 0.35 : 0.35 + 0.65 * (i / (n - 1)));
                    ctx.fillRect(i * bw + 1, top0, Math.max(1, bw - 2), h - tr.pad - top0);
                }
                return;
            }
            // Each unbroken run: a faint fill under it, then the line.
            let i = 0;
            while (i < n) {
                while (i < n && tr.gone(s[i]))
                    i++;
                let j = i;
                while (j < n && !tr.gone(s[j]))
                    j++;
                if (j - i >= 2) {
                    const fade = ctx.createLinearGradient(0, 0, 0, h);
                    fade.addColorStop(0, Qt.rgba(tr.color.r, tr.color.g, tr.color.b, 0.28));
                    fade.addColorStop(1, Qt.rgba(tr.color.r, tr.color.g, tr.color.b, 0));
                    ctx.fillStyle = fade;
                    ctx.beginPath();
                    ctx.moveTo(tr.xAt(i), h);
                    for (let k = i; k < j; k++)
                        ctx.lineTo(tr.xAt(k), tr.yAt(s[k]));
                    ctx.lineTo(tr.xAt(j - 1), h);
                    ctx.closePath();
                    ctx.fill();
                    ctx.globalAlpha = 1;
                    ctx.lineWidth = 2;
                    ctx.lineJoin = "round";
                    ctx.beginPath();
                    ctx.moveTo(tr.xAt(i), tr.yAt(s[i]));
                    for (let k = i + 1; k < j; k++)
                        ctx.lineTo(tr.xAt(k), tr.yAt(s[k]));
                    ctx.stroke();
                }
                i = j;
            }
        }
    }

    // The readout: the nearest sample to the pointer.
    MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.NoButton
        onPositionChanged: mouse => {
            if (tr.count < 2)
                return;
            const i = tr.bars ? Math.floor(mouse.x / (tr.width / tr.count)) : Math.round((mouse.x - tr.pad) / (tr.width - 2 * tr.pad) * (tr.count - 1));
            tr.hover = Math.max(0, Math.min(tr.count - 1, i));
        }
        onExited: tr.hover = -1
    }
    Rectangle {
        visible: tr.hover >= 0 && !tr.bars
        x: tr.hover >= 0 ? tr.xAt(tr.hover) : 0
        y: 0
        width: 1
        height: tr.height
        color: Theme.colText
        opacity: 0.35
    }
    Rectangle {
        readonly property var v: tr.hover >= 0 ? tr.series[tr.hover] : NaN
        visible: tr.hover >= 0 && !tr.bars && !tr.gone(v)
        width: 8
        height: 8
        radius: 4
        color: tr.color
        border.width: 2
        border.color: Theme.colText
        x: tr.hover >= 0 ? tr.xAt(tr.hover) - 4 : 0
        y: tr.gone(v) ? 0 : tr.yAt(v) - 4
    }
    Rectangle {
        id: tip
        readonly property var v: tr.hover >= 0 ? tr.series[tr.hover] : NaN
        visible: tr.hover >= 0
        z: 2
        radius: 6
        color: Qt.rgba(0.06, 0.07, 0.1, 0.88)
        width: tipText.implicitWidth + 16
        height: tipText.implicitHeight + 8
        x: tr.hover >= 0 ? Math.max(0, Math.min(tr.width - width, tr.xAt(tr.hover) - width / 2)) : 0
        y: -height - 6
        Text {
            id: tipText
            anchors.centerIn: parent
            text: {
                const when = tr.labels && tr.hover >= 0 && tr.labels[tr.hover] ? tr.labels[tr.hover] + "  ·  " : "";
                return when + (tr.gone(tip.v) ? "sem leitura" : Number(tip.v).toFixed(tr.decimals).replace(".", ",") + tr.unit);
            }
            color: Theme.colText
            font.family: "Geist"
            font.pixelSize: 15
            font.features: {
                "tnum": 1
            }
        }
    }
}
