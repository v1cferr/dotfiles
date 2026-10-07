// The weather page of the rotating column: INMET's alerts on top (official, by municipality), the
// week as ranges, INMET's own words for today, the next 24 hours, and where each part comes from.
import QtQuick
import QtQuick.Layouts
import "root:/"

ColumnLayout {
    id: page

    property var host
    // Follows the panel's own calendar, so the page turns over at midnight like everything else.
    readonly property string today: page.host ? page.host.calYear + "-" + ("0" + page.host.calTodayM).slice(-2) + "-" + ("0" + page.host.calTodayD).slice(-2) : ""
    readonly property var inmetToday: Inmet.days[page.today] || null
    // Today's and upcoming alerts, at most two, so the chart keeps its height.
    readonly property var shownAlerts: Inmet.alerts.filter(a => a.to >= Date.now()).slice(0, 2)

    spacing: 10

    // ── 1. Alerts, INMET's ladder of colors, one line each ──
    Repeater {
        model: page.shownAlerts
        delegate: Rectangle {
            id: al
            required property var modelData
            readonly property bool live: modelData.from <= Date.now()
            readonly property color tone: Inmet.color(modelData.severity)
            Layout.fillWidth: true
            implicitHeight: 30
            radius: 8
            color: Qt.rgba(al.tone.r, al.tone.g, al.tone.b, al.live ? 0.22 : 0.1)
            border.width: 1
            border.color: Qt.rgba(al.tone.r, al.tone.g, al.tone.b, al.live ? 0.8 : 0.4)
            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 10
                anchors.rightMargin: 10
                spacing: 8
                Text {
                    text: "󰀦"
                    color: al.tone
                    font.family: Theme.uiFont
                    font.pixelSize: 15
                }
                Text {
                    text: al.modelData.event + " · " + al.modelData.severity.toLowerCase()
                    color: Theme.colText
                    font.family: Theme.uiFont
                    font.pixelSize: 13
                    font.bold: true
                }
                Text {
                    Layout.fillWidth: true
                    elide: Text.ElideRight
                    text: al.modelData.risk
                    color: Theme.colSubtext
                    font.family: Theme.uiFont
                    font.pixelSize: 12
                }
                Text {
                    text: al.live ? "until " + al.modelData.until : "from " + new Date(al.modelData.from).toLocaleString(Qt.locale("pt_BR"), "ddd HH:mm")
                    color: al.tone
                    font.family: Theme.uiFont
                    font.pixelSize: 12
                    font.bold: true
                }
            }
        }
    }

    WeatherWeek {
        Layout.fillWidth: true
        host: page.host
    }

    // ── 2. INMET's forecasters, in their words, for today ──
    Text {
        Layout.fillWidth: true
        visible: !!page.inmetToday
        elide: Text.ElideRight
        text: {
            const t = page.inmetToday;
            if (!t)
                return "";
            const p = t.periods;
            return "INMET  " + (p ? ["manhã: " + p.manha, "tarde: " + p.tarde, "noite: " + p.noite].filter(x => !x.endsWith(": ")).join("  ·  ") : t.summary) + "  ·  " + t.min + "–" + t.max + "°";
        }
        color: Theme.colSubtext
        font.family: Theme.uiFont
        font.pixelSize: 12
    }

    WeatherChart {
        Layout.fillWidth: true
        Layout.fillHeight: true
        host: page.host
    }

    // ── 3. Where every part comes from ──
    Text {
        Layout.fillWidth: true
        horizontalAlignment: Text.AlignRight
        text: "hourly and week: " + (page.host ? page.host.wModel.replace("ecmwf_ifs", "ECMWF IFS 9 km") : "") + " via Open-Meteo  ·  text and alerts: INMET"
        color: Theme.colDim
        font.family: Theme.uiFont
        font.pixelSize: 11
    }
}
