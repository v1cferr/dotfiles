// The history graph: one bar per sample, the most recent on the RIGHT, and the scale ALWAYS starts
// at zero. Why zero, and why a hole is a full red bar: docs/notes/desktop/bar.md
import QtQuick
import "root:/"

Item {
    id: spark
    property var series: []
    property real scaleTop: 100
    property color fill: Theme.colTeal
    property string placeholder: "measuring…"
    property bool downward: false // the bars hang from the top (the mirrored half of a graph)
    // The readout under the pointer: the nearest bar lit, a label with its value, and its time when
    // the caller says how far apart the samples are (stepS seconds, the last one now).
    property real stepS: 0
    property string unit: ""
    property int decimals: 0
    property int hover: -1

    readonly property int count: spark.series ? spark.series.length : 0
    implicitHeight: 40

    Text {
        anchors.centerIn: parent
        visible: spark.count < 2
        text: spark.placeholder
        color: Theme.colDim
        font.family: Theme.uiFont
        font.pixelSize: 11
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
            const gap = w / n >= 3 ? 1 : 0; // a gutter only where a bar can spare it
            for (let i = 0; i < n; i++) {
                const x0 = Math.round(i * w / n);
                const x1 = Math.round((i + 1) * w / n) - gap;
                if (x1 <= x0)
                    continue;
                // A sample with no reading is a FULL faded bar: the hole has to jump out, not vanish.
                const v = s[i];
                const dead = v === null || v === undefined || isNaN(v);
                const bh = dead ? h : Math.max(2, Math.round(h * Math.min(1, v / spark.scaleTop)));
                ctx.globalAlpha = dead ? 0.45 : (spark.hover < 0 || i === spark.hover ? 1 : 0.45);
                ctx.fillStyle = dead ? Theme.colRed : spark.fill;
                ctx.fillRect(x0, spark.downward ? 0 : h - bh, x1 - x0, bh);
            }
        }
    }
    onSeriesChanged: cv.requestPaint()
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
        onPositionChanged: mouse => spark.hover = Math.max(0, Math.min(spark.count - 1, Math.floor(mouse.x / (spark.width / spark.count))))
        onExited: spark.hover = -1
    }
    Rectangle {
        id: tip
        readonly property var v: spark.hover >= 0 ? spark.series[spark.hover] : NaN
        readonly property bool dead: v === null || v === undefined || isNaN(v)
        visible: spark.hover >= 0
        z: 2
        radius: Theme.radiusControl
        color: Theme.colSurfaceTip
        border.width: Theme.hairline
        border.color: Theme.colEdge
        width: tipText.implicitWidth + 2 * Theme.sp2
        height: tipText.implicitHeight + 2 * Theme.sp1
        x: Math.max(0, Math.min(spark.width - width, (spark.hover + 0.5) * spark.width / Math.max(1, spark.count) - width / 2))
        y: Theme.sp1
        Text {
            id: tipText
            anchors.centerIn: parent
            text: {
                const when = spark.stepS > 0 ? Qt.formatTime(new Date(Date.now() - (spark.count - 1 - spark.hover) * spark.stepS * 1000), spark.stepS >= 60 ? "HH:mm" : "HH:mm:ss") + "  ·  " : "";
                return when + (tip.dead ? "no reading" : Number(tip.v).toFixed(spark.decimals) + spark.unit);
            }
            color: Theme.colText
            font.family: Theme.uiFont
            font.pixelSize: Theme.fontSmall
        }
    }
}
