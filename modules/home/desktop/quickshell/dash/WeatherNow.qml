// TODAY's weather, under the date: what it is now in big type, the rest in one line, and the next
// 12 hours as a curve (temperature) over a floor of bars (rain chance). The week lives on the month
// grid instead (CalendarWeather); why the split: docs/notes/desktop/dash.md
import QtQuick
import QtQuick.Layouts
import "root:/"

ColumnLayout {
    id: now

    property var host
    readonly property bool ready: now.host && now.host.wHas
    readonly property var hours: now.host ? now.host.wHourly || [] : []
    readonly property var today: {
        if (!now.host)
            return null;
        const d = new Date();
        const key = d.getFullYear() + "-" + ("0" + (d.getMonth() + 1)).slice(-2) + "-" + ("0" + d.getDate()).slice(-2);
        return now.host.wDaily[key] || null;
    }

    spacing: 6
    visible: now.ready

    // The glyph's color says the sky before the glyph is read: sun, rain, or neither.
    function skyColor(code) {
        if (code === 0 || code === 1)
            return Theme.colYellow;
        if ((code >= 51 && code <= 67) || (code >= 80 && code <= 82) || code >= 95)
            return Theme.colSky;
        return Theme.colSubtext;
    }
    // Canvas wants CSS colors; a QML color would stringify as #AARRGGBB, which CSS reads wrong.
    function css(c, a) {
        return "rgba(" + Math.round(c.r * 255) + "," + Math.round(c.g * 255) + "," + Math.round(c.b * 255) + "," + a + ")";
    }

    // ── Now: the glyph and the temperature carry it, the condition names it ──
    RowLayout {
        Layout.fillWidth: true
        spacing: 16

        Item {
            id: glyphBox
            implicitWidth: 64
            implicitHeight: 64

            WeatherAmbient {
                anchors.centerIn: parent
                width: 120
                height: 96
                code: now.ready ? now.host.wCode : -1
                day: now.ready ? now.host.isDayNow() : true
            }
            Text {
                anchors.centerIn: parent
                text: now.ready ? now.host.weatherIcon(now.host.wCode, now.host.isDayNow()) : ""
                color: now.ready ? now.skyColor(now.host.wCode) : Theme.colSubtext
                font.family: Theme.uiFont
                font.pixelSize: 54
            }
        }
        Text {
            text: now.ready ? now.host.wTemp + "°" : ""
            color: Theme.colText
            font.family: Theme.uiFont
            font.pixelSize: 58
            font.bold: true
            font.letterSpacing: -2
        }
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 2
            Text {
                Layout.fillWidth: true
                text: now.ready ? now.host.wText : ""
                color: Theme.colText
                font.family: Theme.uiFont
                font.pixelSize: 20
                elide: Text.ElideRight
            }
            Text {
                Layout.fillWidth: true
                // Glyphs instead of words, so the whole line fits: max/min, feels like, humidity, wind, rain.
                text: !now.ready ? "" : [now.today ? "↑" + now.today.high + "° ↓" + now.today.low + "°" : "", "feels " + now.host.wFeels + "°", "󰖎 " + now.host.wHumidity + "%", "󰖝 " + now.host.wWind, now.today && now.today.precip ? "󰖗 " + now.today.precip + "%" : ""].filter(x => x).join("  ·  ")
                color: Theme.colSubtext
                font.family: Theme.uiFont
                font.pixelSize: 14
                elide: Text.ElideRight
            }
        }
    }

    // ── The next 12 hours: a line for the temperature over bars for the rain chance ──
    Item {
        id: curveBox
        Layout.fillWidth: true
        Layout.preferredHeight: 62
        visible: now.hours.length > 1

        readonly property var temps: now.hours.map(h => h.temp)
        readonly property real tMin: Math.min.apply(null, curveBox.temps)
        readonly property real tMax: Math.max.apply(null, curveBox.temps)
        readonly property real plotTop: 14
        readonly property real plotH: 30
        function xAt(i) {
            return i * curveBox.width / Math.max(1, now.hours.length - 1);
        }
        function yAt(t) {
            const span = Math.max(1, curveBox.tMax - curveBox.tMin);
            return curveBox.plotTop + curveBox.plotH * (1 - (t - curveBox.tMin) / span);
        }

        // The curve DRAWS IN when the forecast arrives: a clip that opens left to right, so the
        // reading is "from now on" before a single label is read.
        Item {
            id: reveal
            width: 0
            height: parent.height
            clip: true

            Canvas {
                id: canvas
                width: curveBox.width
                height: curveBox.height
                onPaint: {
                    const ctx = getContext("2d");
                    ctx.reset();
                    const n = now.hours.length;
                    if (n < 2)
                        return;
                    // Rain chance: thin bars on the floor, only where it is worth noticing.
                    const sky = Theme.colSky;
                    for (let i = 0; i < n; i++) {
                        const p = now.hours[i].precip || 0;
                        if (p < 10)
                            continue;
                        const h = 14 * p / 100;
                        ctx.fillStyle = now.css(sky, 0.25 + 0.5 * p / 100);
                        ctx.fillRect(curveBox.xAt(i) - 3, curveBox.height - 14 - h, 6, h); // up from the floor
                    }
                    // Temperature: a soft fill under a crisp line.
                    const warm = Theme.colPeach;
                    const g = ctx.createLinearGradient(0, curveBox.plotTop, 0, curveBox.plotTop + curveBox.plotH);
                    g.addColorStop(0, now.css(warm, 0.28));
                    g.addColorStop(1, now.css(warm, 0));
                    ctx.beginPath();
                    ctx.moveTo(curveBox.xAt(0), curveBox.plotTop + curveBox.plotH);
                    for (let i = 0; i < n; i++)
                        ctx.lineTo(curveBox.xAt(i), curveBox.yAt(now.hours[i].temp));
                    ctx.lineTo(curveBox.xAt(n - 1), curveBox.plotTop + curveBox.plotH);
                    ctx.closePath();
                    ctx.fillStyle = g;
                    ctx.fill();
                    ctx.beginPath();
                    for (let i = 0; i < n; i++) {
                        const x = curveBox.xAt(i), y = curveBox.yAt(now.hours[i].temp);
                        if (i === 0)
                            ctx.moveTo(x, y);
                        else
                            ctx.lineTo(x, y);
                    }
                    ctx.strokeStyle = now.css(warm, 1);
                    ctx.lineWidth = 2;
                    ctx.stroke();
                }
            }
        }
        NumberAnimation {
            id: drawIn
            target: reveal
            property: "width"
            from: 0
            to: curveBox.width
            duration: 900
            easing.type: Easing.OutCubic
        }
        // Draw in once there is both data and a width; a later resize just repaints at full width.
        function replay() {
            if (curveBox.width <= 0 || now.hours.length < 2)
                return;
            canvas.requestPaint();
            drawIn.restart();
        }
        Connections {
            target: now
            function onHoursChanged() {
                curveBox.replay();
            }
        }
        onWidthChanged: {
            if (drawIn.running || reveal.width === 0)
                curveBox.replay();
            else {
                reveal.width = curveBox.width;
                canvas.requestPaint();
            }
        }

        // Every 3 hours: the hour under the line and the temperature above it.
        Repeater {
            model: now.hours.length
            delegate: Item {
                required property int index
                readonly property var h: now.hours[index]
                visible: index % 3 === 0
                x: curveBox.xAt(index)
                Text {
                    x: index === 0 ? 0 : -width / 2
                    y: curveBox.yAt(parent.h.temp) - 16
                    text: Math.round(parent.h.temp) + "°"
                    color: Theme.colText
                    font.family: Theme.uiFont
                    font.pixelSize: 11
                    font.bold: true
                }
                Text {
                    x: index === 0 ? 0 : -width / 2
                    y: curveBox.height - 12
                    text: index === 0 ? "now" : ("0" + parent.h.hour).slice(-2) + "h"
                    color: Theme.colDim
                    font.family: Theme.uiFont
                    font.pixelSize: 10
                }
            }
        }
    }
}
