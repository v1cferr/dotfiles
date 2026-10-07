// The week as ranges: per day the sky, the rain chance when it matters, and a bar from the min to
// the max on ONE scale for the whole week, painted from the min's color to the max's. A hot day
// reads as a long warm bar to the right before a single number is read.
import QtQuick
import QtQuick.Layouts
import "root:/"

ColumnLayout {
    id: week

    property var host
    readonly property var days: {
        if (!week.host)
            return [];
        // From TOMORROW: today already has the block under the clock and the start of the 24 h chart.
        const keys = Object.keys(week.host.wDaily || {}).sort().slice(1, 8);
        return keys.map(k => Object.assign({
                date: k
            }, week.host.wDaily[k]));
    }
    readonly property real lo: week.days.length ? Math.min.apply(null, week.days.map(d => d.low)) : 0
    readonly property real hi: week.days.length ? Math.max.apply(null, week.days.map(d => d.high)) : 1

    spacing: 2

    Repeater {
        model: week.days
        delegate: RowLayout {
            id: row
            required property var modelData
            required property int index
            readonly property var d: row.modelData
            Layout.fillWidth: true
            spacing: 12

            Text {
                Layout.preferredWidth: 62
                text: row.index === 0 ? "amanhã" : (week.host.dowAbbr[new Date(row.d.date + "T12:00:00").getDay()] || "")
                color: Theme.colText
                font.family: Theme.uiFont
                font.pixelSize: 14
                font.bold: true
            }
            Text {
                Layout.preferredWidth: 22
                horizontalAlignment: Text.AlignHCenter
                text: week.host.weatherIcon(row.d.code, true)
                color: WeatherSky.color(row.d.code)
                font.family: Theme.uiFont
                font.pixelSize: 17
            }
            Text {
                Layout.preferredWidth: 48
                text: (row.d.precip || 0) >= 20 ? "󰖗 " + row.d.precip + "%" : ""
                color: Theme.colSky
                font.family: Theme.uiFont
                font.pixelSize: 12
            }
            Text {
                Layout.preferredWidth: 30
                horizontalAlignment: Text.AlignRight
                text: row.d.low + "°"
                color: Theme.colSubtext
                font.family: Theme.uiFont
                font.pixelSize: 14
            }
            // The range, on the week's own scale.
            Item {
                Layout.fillWidth: true
                implicitHeight: 8
                Rectangle {
                    anchors.fill: parent
                    radius: 4
                    color: Theme.colTrack
                }
                Rectangle {
                    readonly property real span: Math.max(1, week.hi - week.lo)
                    x: parent.width * (row.d.low - week.lo) / span
                    width: Math.max(8, parent.width * (row.d.high - row.d.low) / span)
                    height: parent.height
                    radius: 4
                    gradient: Gradient {
                        orientation: Gradient.Horizontal
                        GradientStop {
                            position: 0
                            color: WeatherSky.temp(row.d.low)
                        }
                        GradientStop {
                            position: 1
                            color: WeatherSky.temp(row.d.high)
                        }
                    }
                }
            }
            Text {
                Layout.preferredWidth: 30
                text: row.d.high + "°"
                color: Theme.colText
                font.family: Theme.uiFont
                font.pixelSize: 14
                font.bold: true
            }
        }
    }
}
