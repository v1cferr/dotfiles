// The weather page of the rotating column: INMET's alerts on top (official, by municipality), the
// week as ranges, the next 24 hours, and INMET's own words and the sources on hover.
import QtQuick
import QtQuick.Layouts
import "root:/"

ColumnLayout {
    id: page

    property var host
    // Follows the panel's own calendar, so the page turns over at midnight like everything else.
    readonly property string today: page.host ? page.host.calYear + "-" + ("0" + page.host.calTodayM).slice(-2) + "-" + ("0" + page.host.calTodayD).slice(-2) : ""
    readonly property var inmetToday: Inmet.days[page.today] || null
    // Today's and upcoming alerts. One chip carries them all: the worst severity, the first event and
    // its time stay visible (an alert is never only on hover); each one's risk is in the tooltip.
    readonly property var alerts: Inmet.alerts.filter(a => a.to >= Date.now())
    function rank(sev) {
        const s = (sev || "").toLowerCase();
        return s.indexOf("grande") >= 0 ? 3 : (s.indexOf("potencial") >= 0 ? 1 : 2);
    }
    readonly property var worst: page.alerts.length ? page.alerts.reduce((w, a) => page.rank(a.severity) > page.rank(w.severity) ? a : w) : null
    function when(a) {
        return a.from <= Date.now() ? "until " + a.until : "from " + new Date(a.from).toLocaleString(Qt.locale("pt_BR"), "ddd HH:mm");
    }

    spacing: 16

    // ── 1. Alerts, INMET's ladder of colors, in one chip ──
    Rectangle {
        id: al
        readonly property bool live: !!page.worst && page.alerts.some(a => a.from <= Date.now())
        readonly property color tone: page.worst ? Inmet.color(page.worst.severity) : Theme.colYellow
        visible: !!page.worst
        Layout.fillWidth: true
        implicitHeight: 32
        radius: 8
        color: Qt.rgba(al.tone.r, al.tone.g, al.tone.b, al.live ? 0.22 : 0.1)
        border.width: 1
        border.color: Qt.rgba(al.tone.r, al.tone.g, al.tone.b, al.live ? 0.8 : 0.4)
        Tip {
            title: page.alerts.length + (page.alerts.length > 1 ? " INMET alerts" : " INMET alert")
            lines: page.alerts.map(a => a.event + " · " + a.severity.toLowerCase() + " · " + page.when(a) + "\n" + a.risk)
        }
        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 12
            anchors.rightMargin: 12
            spacing: 8
            Text {
                text: "󰀦"
                color: al.tone
                font.family: Theme.uiFont
                font.pixelSize: 15
            }
            Text {
                Layout.fillWidth: true
                elide: Text.ElideRight
                text: page.worst ? page.worst.event + " · " + page.worst.severity.toLowerCase() : ""
                color: Theme.colText
                font.family: Theme.uiFont
                font.pixelSize: 13
                font.bold: true
            }
            Text {
                visible: page.alerts.length > 1
                text: "+" + (page.alerts.length - 1)
                color: al.tone
                font.family: Theme.uiFont
                font.pixelSize: 12
                font.bold: true
            }
            Text {
                text: page.worst ? page.when(page.worst) : ""
                color: al.tone
                font.family: Theme.uiFont
                font.pixelSize: 12
                font.bold: true
            }
        }
    }

    WeatherWeek {
        Layout.fillWidth: true
        host: page.host
    }

    WeatherChart {
        Layout.fillWidth: true
        Layout.fillHeight: true
        host: page.host
    }

    // ── 2. INMET's forecasters in their words, and where every part comes from: glyphs, on hover ──
    Row {
        Layout.alignment: Qt.AlignRight
        spacing: 16
        Text {
            visible: !!page.inmetToday
            text: "󰖐 INMET"
            color: Theme.colDim
            font.family: Theme.uiFont
            font.pixelSize: 12
            font.letterSpacing: 1
            Tip {
                title: page.inmetToday ? "INMET today · " + page.inmetToday.min + "–" + page.inmetToday.max + "°" : ""
                lines: {
                    const t = page.inmetToday;
                    if (!t)
                        return [];
                    const p = t.periods;
                    return p ? ["manhã: " + p.manha, "tarde: " + p.tarde, "noite: " + p.noite].filter(x => !x.endsWith(": ")) : [t.summary];
                }
            }
        }
        Text {
            text: "󰋼"
            color: Theme.colDim
            font.family: Theme.uiFont
            font.pixelSize: 14
            Tip {
                title: "Sources"
                lines: ["hourly and week: " + (page.host ? page.host.wModel.replace("ecmwf_ifs", "ECMWF IFS 9 km") : "") + " via Open-Meteo", "text and alerts: INMET"]
            }
        }
    }
}
