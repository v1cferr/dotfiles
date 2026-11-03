// The history graph: one sample per column, the most recent on the RIGHT, and the scale ALWAYS starts
// at zero (or at the log floor). Why zero, why log for throughput, and why a hole is a full red bar:
// docs/notes/desktop/bar.md
import QtQuick
import "root:/"

Item {
    id: spark
    property var series: []
    property real scaleTop: 100
    property color fill: Theme.colTeal
    property string placeholder: "measuring…"
    property bool downward: false // the bars hang from the top (the mirrored half of a graph)
    // A second series MIRRORED below a center axis, on the SAME scale: series grows up, series2 down.
    property var series2: null
    property color fill2: Theme.colPeach
    // "log" spreads idle and burst over the same height; the floor is the axis (a sample at or below
    // it draws nothing). "area" is a filled curve with a stroke on top instead of bars.
    property string scale: "linear"
    property real logFloor: 1
    property string style: "bars"
    property var gridValues: []
    property var gridLabel: null // v => text, drawn at the left of each grid line
    // The readout under the pointer: the nearest sample lit, a label with its value, and its time when
    // the caller says how far apart the samples are (stepS seconds, the last one now). format(v, v2)
    // replaces the plain number.
    property real stepS: 0
    property string unit: ""
    property int decimals: 0
    property var format: null
    property int hover: -1

    readonly property int count: spark.series ? spark.series.length : 0
    readonly property bool mirrored: spark.series2 !== null && spark.series2 !== undefined
    implicitHeight: 40

    function dead(v) {
        return v === null || v === undefined || isNaN(v);
    }
    // The share of the height a value takes, 0..1.
    function frac(v) {
        if (spark.scale === "log") {
            if (!(v > spark.logFloor))
                return 0;
            return Math.min(1, Math.log(v / spark.logFloor) / Math.log(spark.scaleTop / spark.logFloor));
        }
        return Math.min(1, Math.max(0, v / spark.scaleTop));
    }

    Text {
        anchors.centerIn: parent
        visible: spark.count < 2
        text: spark.placeholder
        color: Theme.colDim
        font.family: Theme.uiFont
        font.pixelSize: Theme.fontSmall
        font.italic: true
    }

    // ONE canvas, repainted when the series changes: a Repeater of 60 bars rebuilt all 60 delegates
    // on every 2 s sample, and at narrow widths landed them on fractional pixels.
    Canvas {
        id: cv
        anchors.fill: parent
        visible: spark.count >= 2
        onPaint: {
            const ctx = cv.getContext("2d");
            ctx.reset();
            const s = spark.series || [];
            const n = s.length;
            if (n < 2)
                return;
            const w = cv.width, h = cv.height;
            const axis = spark.mirrored ? Math.round(h / 2) : (spark.downward ? 0 : h);
            const room = spark.mirrored ? axis : h;

            // Grid first, under the data, with its label at the left.
            ctx.globalAlpha = 1;
            ctx.font = Theme.fontMicro + "px '" + Theme.uiFont + "'";
            for (const g of spark.gridValues || []) {
                const d = Math.round(spark.frac(g) * room);
                if (d <= 0 || d >= room)
                    continue;
                const ys = spark.mirrored ? [axis - d, axis + d] : [spark.downward ? d : h - d];
                for (const y of ys) {
                    ctx.fillStyle = Theme.colTrack;
                    ctx.fillRect(0, y, w, 1);
                    if (spark.gridLabel) {
                        ctx.fillStyle = Theme.colDim;
                        ctx.fillText(spark.gridLabel(g), 1, y < axis || !spark.mirrored ? y - 2 : y + Theme.fontMicro);
                    }
                }
            }

            const halves = spark.mirrored ? [[s, spark.fill, -1], [spark.series2 || [], spark.fill2, 1]] : [[s, spark.fill, spark.downward ? 1 : -1]];
            for (const [ser, color, dir] of halves) {
                const m = Math.min(n, ser.length);
                if (spark.style === "area") {
                    // x of sample i spans the full width, first at the left edge, last at the right.
                    const xs = i => i * w / (n - 1);
                    const ys = i => axis + dir * (spark.dead(ser[i]) ? 0 : spark.frac(ser[i]) * room);
                    ctx.beginPath();
                    ctx.moveTo(xs(0), axis);
                    for (let i = 0; i < m; i++)
                        ctx.lineTo(xs(i), ys(i));
                    ctx.lineTo(xs(m - 1), axis);
                    ctx.closePath();
                    ctx.globalAlpha = spark.hover < 0 ? 0.28 : 0.18;
                    ctx.fillStyle = color;
                    ctx.fill();
                    ctx.beginPath();
                    for (let i = 0; i < m; i++)
                        i === 0 ? ctx.moveTo(xs(i), ys(i)) : ctx.lineTo(xs(i), ys(i));
                    ctx.globalAlpha = 1;
                    ctx.strokeStyle = color;
                    ctx.lineWidth = 1.5;
                    ctx.lineJoin = "round";
                    ctx.stroke();
                    if (spark.hover >= 0 && spark.hover < m) {
                        ctx.fillStyle = color;
                        ctx.beginPath();
                        ctx.arc(xs(spark.hover), ys(spark.hover), 2.5, 0, 2 * Math.PI);
                        ctx.fill();
                    }
                    // A sample with no reading is a FULL faded column: the hole has to jump out.
                    for (let i = 0; i < m; i++)
                        if (spark.dead(ser[i])) {
                            ctx.globalAlpha = 0.45;
                            ctx.fillStyle = Theme.colRed;
                            ctx.fillRect(Math.round(xs(i) - w / n / 2), dir < 0 ? axis - room : axis, Math.max(1, Math.round(w / n)), room);
                        }
                    continue;
                }
                const gap = w / n >= 3 ? 1 : 0; // a gutter only where a bar can spare it
                for (let i = 0; i < m; i++) {
                    const x0 = Math.round(i * w / n);
                    const x1 = Math.round((i + 1) * w / n) - gap;
                    if (x1 <= x0)
                        continue;
                    // A sample with no reading is a FULL faded bar: the hole has to jump out, not vanish.
                    const v = ser[i];
                    const isDead = spark.dead(v);
                    const bh = isDead ? room : Math.max(2, Math.round(room * spark.frac(v)));
                    ctx.globalAlpha = isDead ? 0.45 : (spark.hover < 0 || i === spark.hover ? 1 : 0.45);
                    ctx.fillStyle = isDead ? Theme.colRed : color;
                    ctx.fillRect(x0, dir < 0 ? axis - bh : axis, x1 - x0, bh);
                }
            }
            if (spark.mirrored) {
                ctx.globalAlpha = 1;
                ctx.fillStyle = Theme.colEdge;
                ctx.fillRect(0, axis, w, 1);
            }
        }
    }
    onSeriesChanged: cv.requestPaint()
    onSeries2Changed: cv.requestPaint()
    onHoverChanged: cv.requestPaint()
    onScaleTopChanged: cv.requestPaint()
    onFillChanged: cv.requestPaint()
    onWidthChanged: cv.requestPaint()
    onHeightChanged: cv.requestPaint()

    MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.NoButton
        enabled: spark.count >= 2
        onPositionChanged: mouse => spark.hover = spark.style === "area" ? Math.max(0, Math.min(spark.count - 1, Math.round(mouse.x / (spark.width / (spark.count - 1))))) : Math.max(0, Math.min(spark.count - 1, Math.floor(mouse.x / (spark.width / spark.count))))
        onExited: spark.hover = -1
    }
    Rectangle {
        id: tip
        readonly property var v: spark.hover >= 0 ? spark.series[spark.hover] : NaN
        readonly property var v2: spark.hover >= 0 && spark.mirrored ? spark.series2[spark.hover] : NaN
        readonly property real cx: spark.style === "area" ? spark.hover * spark.width / Math.max(1, spark.count - 1) : (spark.hover + 0.5) * spark.width / Math.max(1, spark.count)
        visible: spark.hover >= 0
        z: 2
        radius: Theme.radiusControl
        color: Theme.colSurfaceTip
        border.width: Theme.hairline
        border.color: Theme.colEdge
        width: tipText.implicitWidth + 2 * Theme.sp2
        height: tipText.implicitHeight + 2 * Theme.sp1
        x: Math.max(0, Math.min(spark.width - width, tip.cx - width / 2))
        y: Theme.sp1
        Text {
            id: tipText
            anchors.centerIn: parent
            text: {
                const when = spark.stepS > 0 ? Qt.formatTime(new Date(Date.now() - (spark.count - 1 - spark.hover) * spark.stepS * 1000), spark.stepS >= 60 ? "HH:mm" : "HH:mm:ss") + "  ·  " : "";
                if (spark.format)
                    return when + spark.format(tip.v, tip.v2);
                return when + (spark.dead(tip.v) ? "no reading" : Number(tip.v).toFixed(spark.decimals) + spark.unit);
            }
            color: Theme.colText
            font.family: Theme.uiFont
            font.pixelSize: Theme.fontSmall
        }
    }
}
