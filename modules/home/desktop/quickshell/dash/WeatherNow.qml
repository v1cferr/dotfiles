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

    // ── Now: the glyph and the temperature carry it, the condition names it, the rest is on hover ──
    Item {
        Layout.fillWidth: true
        implicitHeight: nowRow.implicitHeight

        Tip {
            title: now.ready ? now.host.wText + " · " + now.host.wTemp + "°" : ""
            lines: !now.ready ? [] : ["feels like " + now.host.wFeels + "°", "humidity " + now.host.wHumidity + "%", "wind " + now.host.wWind, now.today && now.today.precip !== undefined ? "rain today " + now.today.precip + "%" : ""].filter(x => x)
        }

        RowLayout {
            id: nowRow
            anchors.left: parent.left
            anchors.right: parent.right
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
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 12
                    Text {
                        Layout.fillWidth: true
                        text: now.ready ? now.host.wText : ""
                        color: Theme.colText
                        font.family: Theme.uiFont
                        font.pixelSize: 20
                        elide: Text.ElideRight
                    }
                    // An INMET alert in force right now rides on the condition line: no extra height, never missed.
                    Rectangle {
                        readonly property var al: Inmet.activeNow.length ? Inmet.activeNow[0] : null
                        readonly property color tone: al ? Inmet.color(al.severity) : Theme.colYellow
                        visible: !!al
                        implicitWidth: alertText.implicitWidth + 20
                        implicitHeight: 24
                        radius: 12
                        color: Qt.rgba(tone.r, tone.g, tone.b, 0.2)
                        border.width: 1
                        border.color: tone
                        Text {
                            id: alertText
                            anchors.centerIn: parent
                            text: parent.al ? "󰀦 " + parent.al.event + " · until " + parent.al.until : ""
                            color: parent.tone
                            font.family: Theme.uiFont
                            font.pixelSize: 13
                            font.bold: true
                        }
                        SequentialAnimation on opacity {
                            running: parent.visible
                            loops: Animation.Infinite
                            alwaysRunToEnd: true
                            NumberAnimation {
                                to: 0.55
                                duration: 1400
                                easing.type: Easing.InOutSine
                            }
                            NumberAnimation {
                                to: 1
                                duration: 1400
                                easing.type: Easing.InOutSine
                            }
                        }
                    }
                }
                Text {
                    Layout.fillWidth: true
                    // Only the day's range; feels like, humidity, wind and rain are in the tooltip.
                    text: now.ready && now.today ? "↑" + now.today.high + "°  ↓" + now.today.low + "°" : ""
                    color: Theme.colSubtext
                    font.family: Theme.uiFont
                    font.pixelSize: 14
                    elide: Text.ElideRight
                }
            }
        }
    }

    // ── The day in one line: when it gets light and dark, and rain only when it is likely. The
    // daylight and a weaker chance of rain are on hover ──
    Item {
        Layout.fillWidth: true
        Layout.topMargin: 16
        implicitHeight: dayRow.implicitHeight
        visible: now.ready

        Tip {
            title: "Today"
            lines: [dayRow.daylight ? dayRow.daylight + " of daylight" : "", dayRow.rainText].filter(x => x)
        }

        RowLayout {
            id: dayRow
            anchors.left: parent.left
            anchors.right: parent.right
            spacing: 24
            readonly property string daylight: {
                if (!now.today || !now.today.sunrise)
                    return "";
                const m = Math.round((new Date(now.today.sunset) - new Date(now.today.sunrise)) / 60000);
                return Math.floor(m / 60) + "h " + (m % 60) + "m";
            }
            readonly property string rainText: {
                const r = dayRow.rain;
                if (!r)
                    return "dry for the next 24 h";
                const when = r.h === (now.host.wHourly || [])[0] ? "now" : "at " + ("0" + r.h.hour).slice(-2) + "h";
                return (r.strong ? "rain likely " : "a chance of rain ") + when + " · " + r.h.precip + "%";
            }

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
            Item {
                Layout.fillWidth: true
            }
            Text {
                visible: !!dayRow.rain && dayRow.rain.strong
                text: visible ? "󰖗 " + (dayRow.rain.h === (now.host.wHourly || [])[0] ? "now" : ("0" + dayRow.rain.h.hour).slice(-2) + "h") + " · " + dayRow.rain.h.precip + "%" : ""
                color: Theme.colSky
                font.family: Theme.uiFont
                font.pixelSize: 15
                font.bold: true
            }
        }
    }
}
