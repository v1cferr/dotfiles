// TODAY's weather, under the date: what it is now in big type and the rest in one line. The hours
// and the week have their own page (WeatherChart, WeatherWeek): docs/notes/desktop/dash.md
import QtQuick
import QtQuick.Layouts
import "root:/"

ColumnLayout {
    id: now

    property var host
    readonly property bool ready: now.host && now.host.wHas
    readonly property var today: {
        if (!now.host)
            return null;
        const d = new Date();
        const key = d.getFullYear() + "-" + ("0" + (d.getMonth() + 1)).slice(-2) + "-" + ("0" + d.getDate()).slice(-2);
        return now.host.wDaily[key] || null;
    }

    spacing: 6
    visible: now.ready

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
                color: now.ready ? WeatherSky.color(now.host.wCode) : Theme.colSubtext
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

    // ── The day in one line: when it gets dark, how long the light lasts, and the next rain ──
    RowLayout {
        Layout.fillWidth: true
        Layout.topMargin: 10
        spacing: 22
        visible: now.ready

        // The next hour worth an umbrella: 40% and up is "likely", 20% and up only "a chance".
        readonly property var rain: {
            const hs = now.host ? now.host.wHourly || [] : [];
            const likely = hs.find(h => (h.precip || 0) >= 40);
            if (likely)
                return {
                    strong: true,
                    h: likely
                };
            const maybe = hs.find(h => (h.precip || 0) >= 20);
            return maybe ? {
                strong: false,
                h: maybe
            } : null;
        }
        function hhmm(iso) {
            return (iso || "").slice(11, 16);
        }

        Text {
            visible: !!now.today && !!now.today.sunrise
            text: "󰖜 " + parent.hhmm(now.today ? now.today.sunrise : "") + "   󰖛 " + parent.hhmm(now.today ? now.today.sunset : "")
            color: Theme.colYellow
            font.family: Theme.uiFont
            font.pixelSize: 15
        }
        Text {
            visible: !!now.today && !!now.today.sunrise
            text: {
                if (!now.today || !now.today.sunrise)
                    return "";
                const m = Math.round((new Date(now.today.sunset) - new Date(now.today.sunrise)) / 60000);
                return Math.floor(m / 60) + "h " + (m % 60) + "m of daylight";
            }
            color: Theme.colSubtext
            font.family: Theme.uiFont
            font.pixelSize: 15
        }
        Item {
            Layout.fillWidth: true
        }
        Text {
            text: {
                const r = parent.rain;
                if (!r)
                    return "dry for the next 24 h";
                const when = r.h === (now.host.wHourly || [])[0] ? "now" : "at " + ("0" + r.h.hour).slice(-2) + "h";
                return "󰖗 " + (r.strong ? "rain likely " : "a chance of rain ") + when + " · " + r.h.precip + "%";
            }
            color: parent.rain ? Theme.colSky : Theme.colGreen
            font.family: Theme.uiFont
            font.pixelSize: 15
            font.bold: !!parent.rain && parent.rain.strong
        }
    }
}
