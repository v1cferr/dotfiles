// The next 24 hours as ONE picture: a smooth hill whose color IS the temperature (WeatherSky.temp,
// interpolated hour by hour), the nights shaded behind it so sunset and sunrise read as edges, a
// "now" line, and a ribbon of rain chance in 3-hour blocks underneath. Why: docs/notes/desktop/dash.md
import QtQuick
import QtQuick.Layouts
import "root:/"

Item {
    id: chart

    property var host
    readonly property var hours: chart.host ? (chart.host.wHourly || []) : []
    readonly property int n: chart.hours.length
    readonly property real pad: 18 // the first and last labels must not touch the card's edge
    readonly property real step: (chart.width - 2 * chart.pad) / Math.max(1, chart.n - 1)
    readonly property real labelsH: 56
    readonly property real ribbonH: 26
    readonly property real plotTop: chart.labelsH + 8
    readonly property real plotH: chart.height - chart.plotTop - chart.ribbonH - 26
    readonly property var temps: chart.hours.map(h => h.temp)
    readonly property real tMin: chart.n ? Math.min.apply(null, chart.temps) - 2 : 0
    readonly property real tMax: chart.n ? Math.max.apply(null, chart.temps) + 2 : 1

    function xAt(i) {
        return chart.pad + i * chart.step;
    }
    function yAt(t) {
        return chart.plotTop + chart.plotH * (1 - (t - chart.tMin) / Math.max(1, chart.tMax - chart.tMin));
    }
    // A wall-clock time -> x, through the hourly grid (fractional hours past the first sample).
    function xAtTime(iso) {
        if (!iso || !chart.n)
            return -1;
        const h = (new Date(iso) - new Date(chart.hours[0].time)) / 3600000;
        return h < 0 || h > chart.n - 1 ? -1 : chart.xAt(h);
    }
    readonly property real nowX: {
        if (!chart.n)
            return -1;
        const h = (Date.now() - new Date(chart.hours[0].time)) / 3600000;
        return chart.xAt(Math.max(0, Math.min(chart.n - 1, h)));
    }
    // Today's and tomorrow's sun events that fall inside the 24 h window.
    readonly property var sunMarks: {
        if (!chart.host || !chart.n)
            return [];
        const out = [];
        for (const d in chart.host.wDaily) {
            const day = chart.host.wDaily[d];
            for (const ev of [["sunrise", "󰖜"], ["sunset", "󰖛"]]) {
                const x = chart.xAtTime(day[ev[0]]);
                if (x >= 0)
                    out.push({
                        x: x,
                        glyph: ev[1],
                        label: (day[ev[0]] || "").slice(11, 16)
                    });
            }
        }
        return out;
    }

    // ── 1. The hour ruler: every 2 hours, the time, the sky and the temperature ──
    Repeater {
        model: chart.n
        delegate: Column {
            required property int index
            readonly property var h: chart.hours[index]
            visible: index % 2 === 0
            x: chart.xAt(index) - width / 2
            y: 0
            spacing: 3
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: parent.index === 0 ? "now" : ("0" + parent.h.hour).slice(-2) + "h"
                color: parent.index === 0 ? Theme.colAccent : Theme.colDim
                font.family: Theme.uiFont
                font.pixelSize: 11
                font.bold: parent.index === 0
            }
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: chart.host ? chart.host.weatherIcon(parent.h.code, parent.h.day) : ""
                color: WeatherSky.color(parent.h.code)
                font.family: Theme.uiFont
                font.pixelSize: 17
            }
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: Math.round(parent.h.temp) + "°"
                color: WeatherSky.temp(parent.h.temp)
                font.family: Theme.uiFont
                font.pixelSize: 13
                font.bold: true
            }
        }
    }

    // ── 2. The hill: drawn once per forecast, revealed left to right ──
    Item {
        id: reveal
        width: chart.width * chart.progress
        height: chart.height
        clip: true

        Canvas {
            id: canvas
            width: chart.width
            height: chart.height
            onPaint: {
                const ctx = getContext("2d");
                ctx.reset();
                const n = chart.n;
                if (n < 2)
                    return;
                const pts = [];
                for (let i = 0; i < n; i++)
                    pts.push([chart.xAt(i), chart.yAt(chart.hours[i].temp)]);
                const base = chart.plotTop + chart.plotH;
                // The color runs along x with the temperature, hour by hour.
                const hue = function (alpha) {
                    const g = ctx.createLinearGradient(chart.xAt(0), 0, chart.xAt(n - 1), 0);
                    for (let i = 0; i < n; i++)
                        g.addColorStop(i / (n - 1), WeatherSky.css(WeatherSky.temp(chart.hours[i].temp), alpha));
                    return g;
                };
                // Catmull-Rom through the samples, as Bezier segments: a curve, not a polyline.
                const curve = function () {
                    ctx.moveTo(pts[0][0], pts[0][1]);
                    for (let i = 0; i < n - 1; i++) {
                        const p0 = pts[Math.max(0, i - 1)], p1 = pts[i], p2 = pts[i + 1], p3 = pts[Math.min(n - 1, i + 2)];
                        ctx.bezierCurveTo(p1[0] + (p2[0] - p0[0]) / 6, p1[1] + (p2[1] - p0[1]) / 6, p2[0] - (p3[0] - p1[0]) / 6, p2[1] - (p3[1] - p1[1]) / 6, p2[0], p2[1]);
                    }
                };
                ctx.beginPath();
                curve();
                ctx.lineTo(pts[n - 1][0], base);
                ctx.lineTo(pts[0][0], base);
                ctx.closePath();
                ctx.fillStyle = hue(0.85);
                ctx.fill();
                // Fade the hill toward its base, so it reads as light and not as a block.
                ctx.globalCompositeOperation = "destination-in";
                const fade = ctx.createLinearGradient(0, chart.plotTop, 0, base);
                fade.addColorStop(0, "rgba(0,0,0,1)");
                fade.addColorStop(1, "rgba(0,0,0,0.08)");
                ctx.fillStyle = fade;
                ctx.fillRect(0, 0, chart.width, chart.height);
                ctx.globalCompositeOperation = "source-over";
                // The crest, crisp, in the same moving color.
                ctx.beginPath();
                curve();
                ctx.lineWidth = 2.5;
                ctx.strokeStyle = hue(1);
                ctx.stroke();
                // The nights, BEHIND everything drawn so far.
                ctx.globalCompositeOperation = "destination-over";
                // One block per night, not one per hour: overlapping translucent hours drew stripes.
                ctx.fillStyle = "rgba(0,0,0,0.22)";
                for (let i = 0; i < n; i++) {
                    if (chart.hours[i].day)
                        continue;
                    let j = i;
                    while (j + 1 < n && !chart.hours[j + 1].day)
                        j++;
                    const x0 = Math.max(0, chart.xAt(i) - chart.step / 2), x1 = Math.min(chart.width, chart.xAt(j) + chart.step / 2);
                    ctx.fillRect(x0, chart.plotTop - 6, x1 - x0, chart.plotH + 6);
                    i = j;
                }
                ctx.globalCompositeOperation = "source-over";
            }
        }
    }
    // The reveal animates a FRACTION, not a width: a width animation captured its target while the
    // page was still 0 px wide and "revealed" nothing.
    property real progress: 1
    NumberAnimation {
        id: drawIn
        target: chart
        property: "progress"
        from: 0
        to: 1
        duration: 1100
        easing.type: Easing.OutCubic
    }
    function replay() {
        if (chart.width <= 0 || chart.n < 2)
            return;
        canvas.requestPaint();
        drawIn.restart();
    }
    onHoursChanged: chart.replay()
    onWidthChanged: chart.replay()
    onHeightChanged: canvas.requestPaint()
    // Shown again: the page draws itself in each time it comes around.
    onVisibleChanged: if (visible)
        chart.replay()

    // ── 3. Sun events and now, as marks over the hill ──
    Repeater {
        model: chart.sunMarks
        delegate: Item {
            required property var modelData
            x: modelData.x
            y: chart.plotTop - 6
            Rectangle {
                width: 1
                height: chart.plotH + 6
                color: Theme.colYellow
                opacity: 0.35
            }
            Text {
                x: 5
                y: chart.plotH - 18
                text: parent.modelData.glyph + " " + parent.modelData.label
                color: Theme.colYellow
                font.family: Theme.uiFont
                font.pixelSize: 11
            }
        }
    }
    Rectangle {
        visible: chart.nowX >= 0
        x: chart.nowX
        y: chart.plotTop - 6
        width: 1.5
        height: chart.plotH + 6
        color: Theme.colAccent
        opacity: 0.7
    }

    // ── 4. The rain ribbon: 3-hour blocks, blue with the chance where it matters ──
    Row {
        x: chart.xAt(0) - chart.step / 2
        y: chart.plotTop + chart.plotH + 10
        spacing: 3
        Repeater {
            model: Math.floor((chart.n - 1) / 3) // 24 hours = 8 blocks; the 25th sample only closes the curve
            delegate: Rectangle {
                required property int index
                readonly property int p: {
                    let m = 0;
                    for (let i = index * 3; i < Math.min(chart.n, index * 3 + 3); i++)
                        m = Math.max(m, chart.hours[i].precip || 0);
                    return m;
                }
                width: chart.step * 3 - 3
                height: chart.ribbonH
                radius: 6
                color: p >= 10 ? Qt.rgba(Theme.colSky.r, Theme.colSky.g, Theme.colSky.b, 0.18 + 0.5 * p / 100) : Theme.colGroupBg
                border.width: 1
                border.color: p >= 10 ? Qt.rgba(Theme.colSky.r, Theme.colSky.g, Theme.colSky.b, 0.5) : Theme.colGroupBorder
                Text {
                    anchors.centerIn: parent
                    text: (parent.p >= 10 ? "󰖗 " : "") + parent.p + "%"
                    color: parent.p >= 10 ? Theme.colText : Theme.colDim
                    font.family: Theme.uiFont
                    font.pixelSize: 11
                    font.bold: parent.p >= 10
                }
            }
        }
    }
}
