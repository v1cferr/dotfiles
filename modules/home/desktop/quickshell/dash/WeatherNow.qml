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
}
