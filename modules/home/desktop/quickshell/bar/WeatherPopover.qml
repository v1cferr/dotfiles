// The weather popover (current plus a 7-day forecast). The state lives in the Bar, through `bar`.
import Quickshell
import QtQuick
import QtQuick.Layouts
import "root:/"
import "root:/widgets"

PanelWindow {
    id: wPop
    required property var bar
    visible: bar.wPopVisible && bar.wHas
    screen: bar.popScreen || bar.screenPrimary
    anchors {
        top: true
        left: true
    }
    margins {
        top: 4 // = Hyprland's gaps_out: it aligns the popover with the top of the windows (barExclusiveZone 30 already added)
        left: bar.popLeft(wPop.implicitWidth)
    }
    exclusiveZone: 0
    // The card fits the content (+28 = the 14*2 margins). With no fixed width there is no empty
    // space left on the right: the 7-day grid defines the width.
    implicitWidth: card.implicitWidth
    implicitHeight: card.implicitHeight
    color: "transparent"

    PopCard {
        id: card
        onHoveredChanged: wPop.bar.wPopHovered = card.hovered

        ColumnLayout {
            id: wContent
            spacing: 10

            // A centered header, then the metrics on one line. AlignHCenter and not fillWidth, which does not
            // stretch in this Quickshell context.
            ColumnLayout {
                Layout.alignment: Qt.AlignHCenter
                spacing: 8

                // The hero: the icon plus the big temperature, with the condition right below
                ColumnLayout {
                    Layout.alignment: Qt.AlignHCenter
                    spacing: 0
                    RowLayout {
                        Layout.alignment: Qt.AlignHCenter
                        spacing: 10
                        Text {
                            text: bar.weatherIcon(bar.wCode, bar.isDayNow())
                            color: Theme.colSapphire
                            font.family: Theme.uiFont
                            font.pixelSize: 34
                        }
                        Text {
                            text: bar.wTemp + "°C"
                            color: Theme.colText
                            font.family: Theme.uiFont
                            font.pixelSize: 28
                            font.bold: true
                        }
                    }
                    Text {
                        Layout.alignment: Qt.AlignHCenter
                        text: bar.wText
                        color: Theme.colSapphire
                        font.family: Theme.uiFont
                        font.pixelSize: 12
                    }
                }

                // The metrics on one line, centered, separated by "·"
                RowLayout {
                    Layout.alignment: Qt.AlignHCenter
                    spacing: 6
                    Repeater {
                        model: [
                            {
                                label: "Feels like",
                                value: bar.wFeels + "°"
                            },
                            {
                                label: "Humidity",
                                value: bar.wHumidity + "%"
                            },
                            {
                                label: "Wind",
                                value: bar.wWind
                            }
                        ]
                        RowLayout {
                            required property var modelData
                            required property int index
                            spacing: 6
                            Text {
                                visible: index > 0
                                text: "·"
                                color: Theme.colDim
                                font.family: Theme.uiFont
                                font.pixelSize: 12
                            }
                            Text {
                                text: modelData.label
                                color: Theme.colDim
                                font.family: Theme.uiFont
                                font.pixelSize: 11
                            }
                            Text {
                                text: modelData.value
                                color: Theme.colText
                                font.family: Theme.uiFont
                                font.pixelSize: 11
                                font.bold: true
                            }
                        }
                    }
                }
            }

            Hairline {}

            RowLayout {
                Layout.fillWidth: true
                spacing: 6
                Repeater {
                    model: bar.wForecast
                    ColumnLayout {
                        required property var modelData
                        Layout.fillWidth: true
                        spacing: 2
                        Text {
                            Layout.alignment: Qt.AlignHCenter
                            text: modelData.day
                            color: Theme.colText
                            font.family: Theme.uiFont
                            font.pixelSize: 11
                            font.bold: true
                        }
                        Text {
                            Layout.alignment: Qt.AlignHCenter
                            text: bar.weatherIcon(modelData.code, true)
                            color: Theme.colSapphire
                            font.family: Theme.uiFont
                            font.pixelSize: 18
                        }
                        Text {
                            Layout.alignment: Qt.AlignHCenter
                            text: modelData.high + "° / " + modelData.low + "°"
                            color: Theme.colText
                            font.family: Theme.uiFont
                            font.pixelSize: 10
                        }
                        Text {
                            Layout.alignment: Qt.AlignHCenter
                            visible: modelData.precip !== ""
                            text: "󰖎 " + modelData.precip + "%"
                            color: Theme.colBlue
                            font.family: Theme.uiFont
                            font.pixelSize: 9
                        }
                    }
                }
            }
        }
    }
}
