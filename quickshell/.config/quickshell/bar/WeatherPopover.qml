// Popover do clima (atual + previsão 7 dias). Estado no Bar, via `bar`.
import Quickshell
import QtQuick
import QtQuick.Layouts
import "root:/"

PanelWindow {
    id: wPop
    required property var bar
    visible: bar.wPopVisible && bar.wHas
    screen: bar.popScreen || bar.screenDP1
    anchors {
        top: true
        left: true
    }
    margins {
        top: 33
        left: bar.popLeft(wPop.implicitWidth)
    }
    exclusiveZone: 0
    // Card se ajusta ao conteúdo (+28 = margens 14*2). Sem largura fixa,
    // não sobra espaço vazio à direita: a grade de 7 dias define a largura.
    implicitWidth: wContent.implicitWidth + 28
    implicitHeight: wContent.implicitHeight + 28
    color: "transparent"

    Rectangle {
        anchors.fill: parent
        radius: 12
        color: "#f21a1b26"
        border.color: "#414868"
        border.width: 1

        HoverHandler {
            id: wPopHover
            onHoveredChanged: bar.wPopHovered = hovered
        }

        ColumnLayout {
            id: wContent
            anchors.fill: parent
            anchors.margins: 14
            spacing: 10

            // Cabeçalho centralizado: hero (ícone + temperatura grande) e condição
            // no topo; métricas numa linha única separadas por "·". Tudo no centro.
            // AlignHCenter (e não fillWidth) centraliza o bloco dentro da largura
            // da grade — fillWidth não estica neste contexto do Quickshell.
            ColumnLayout {
                Layout.alignment: Qt.AlignHCenter
                spacing: 8

                // Hero — ícone + temperatura grande, condição logo abaixo
                ColumnLayout {
                    Layout.alignment: Qt.AlignHCenter
                    spacing: 0
                    RowLayout {
                        Layout.alignment: Qt.AlignHCenter
                        spacing: 10
                        Text {
                            text: bar.weatherIcon(bar.wText, bar.isDayNow())
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

                // Métricas em uma linha, centralizadas, separadas por "·"
                RowLayout {
                    Layout.alignment: Qt.AlignHCenter
                    spacing: 6
                    Repeater {
                        model: [
                            {
                                label: "Sensação",
                                value: bar.wFeels + "°"
                            },
                            {
                                label: "Umidade",
                                value: bar.wHumidity + "%"
                            },
                            {
                                label: "Vento",
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

            Rectangle {
                Layout.fillWidth: true
                height: 1
                color: "#414868"
                opacity: 0.5
            }

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
                            text: bar.weatherIcon(modelData.text, true)
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
