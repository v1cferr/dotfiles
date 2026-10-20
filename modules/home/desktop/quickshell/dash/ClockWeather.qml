// The band's time and the weather now, above the energy graph: the clock with seconds from the bar's
// own clock (no second timer) and the sky from the bar's forecast (no second request). docs/notes/desktop/dash.md
import QtQuick
import QtQuick.Layouts
import "root:/"

RowLayout {
    id: cw

    property var host // the Bar's Scope, as the rest of the band reads it
    readonly property bool sky: !!cw.host && cw.host.wHas
    spacing: Theme.sp4

    ColumnLayout {
        spacing: 0
        Text {
            text: cw.host ? cw.host.timeStr : ""
            color: Theme.colText
            font.family: Theme.uiFont
            font.pixelSize: 64
            font.weight: Font.Light
            font.letterSpacing: -2
        }
        Text {
            readonly property string month: cw.host ? (cw.host.monthNames[cw.host.calTodayM - 1] || "") : ""
            text: cw.host ? (cw.host.dowNames[cw.host.calTodayW] || "") + ", " + cw.host.calTodayD + " de " + month.toLowerCase() : ""
            color: Theme.colSubtext
            font.family: Theme.uiFont
            font.pixelSize: 18
        }
    }
    Item {
        Layout.fillWidth: true // pushes the weather to the card's right edge
    }
    ColumnLayout {
        visible: cw.sky
        Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
        spacing: 2
        RowLayout {
            Layout.alignment: Qt.AlignRight
            spacing: 10
            Text {
                text: cw.sky ? cw.host.weatherIcon(cw.host.wCode, cw.host.isDayNow()) : ""
                color: cw.sky ? WeatherSky.color(cw.host.wCode) : Theme.colSubtext
                font.family: Theme.uiFont
                font.pixelSize: 38
            }
            Text {
                text: cw.sky ? cw.host.wTemp + "°" : ""
                color: Theme.colText
                font.family: Theme.uiFont
                font.pixelSize: 44
                font.weight: Font.Light
            }
        }
        Text {
            Layout.alignment: Qt.AlignRight
            text: cw.sky ? [cw.host.wConf.place, cw.host.wText].filter(x => x).join("  ·  ") : ""
            color: Theme.colSubtext
            font.family: Theme.uiFont
            font.pixelSize: 15
        }
    }
}
