// Popover do calendário (ano inteiro + próximos feriados), aberto pelo hover no
// relógio da barra. Estado/lógica (calMap, calUpcoming, monthCells, feriados…)
// ficam no Bar e chegam por referência via `bar`.
import Quickshell
import QtQuick
import QtQuick.Layouts
import "root:/"

PanelWindow {
    id: calPop
    required property var bar
    visible: bar.calPopVisible
    screen: bar.popScreen || bar.screenDP1
    anchors {
        top: true
        left: true
    }
    margins {
        top: 33
        left: bar.popLeft(calPop.implicitWidth)
    }
    exclusiveZone: 0
    implicitWidth: 880
    implicitHeight: 470
    color: "transparent"
    Rectangle {
        anchors.fill: parent
        radius: 12
        color: "#f21a1b26"
        border.color: "#414868"
        border.width: 1
        HoverHandler {
            onHoveredChanged: bar.calPopHovered = hovered
        }
        RowLayout {
            anchors.fill: parent
            anchors.margins: 14
            spacing: 14

            // ---- Próximos feriados (coluna esquerda) ----
            ColumnLayout {
                Layout.preferredWidth: 234
                Layout.fillHeight: true
                spacing: 7
                Text {
                    text: "Próximos feriados"
                    color: Theme.colAccent
                    font.family: Theme.uiFont
                    font.pixelSize: 15
                    font.bold: true
                }
                Rectangle {
                    Layout.fillWidth: true
                    height: 1
                    color: "#414868"
                    opacity: 0.5
                }
                Repeater {
                    model: bar.calUpcoming
                    RowLayout {
                        required property var modelData
                        Layout.fillWidth: true
                        spacing: 8
                        Rectangle {
                            width: 8
                            height: 8
                            radius: 4
                            color: bar.scopeColor(modelData.scope)
                            Layout.alignment: Qt.AlignVCenter
                        }
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 0
                            Text {
                                Layout.fillWidth: true
                                text: modelData.name
                                color: Theme.colText
                                font.family: Theme.uiFont
                                font.pixelSize: 12
                                font.bold: true
                                elide: Text.ElideRight
                            }
                            Text {
                                text: bar.fmtHolidayDate(modelData.date) + "  ·  " + bar.scopeLabel(modelData.scope)
                                color: Theme.colDim
                                font.family: Theme.uiFont
                                font.pixelSize: 10
                            }
                        }
                        Text {
                            text: bar.daysUntilLabel(modelData.date)
                            color: Theme.colSky
                            font.family: Theme.uiFont
                            font.pixelSize: 10
                            font.bold: true
                        }
                    }
                }
                Item {
                    Layout.fillHeight: true
                }
                RowLayout {
                    spacing: 10
                    Repeater {
                        model: [{ c: "nac", t: "Nacional" }, { c: "sp", t: "SP" }, { c: "sc", t: "S.Carlos" }]
                        RowLayout {
                            required property var modelData
                            spacing: 4
                            Rectangle {
                                width: 8
                                height: 8
                                radius: 4
                                color: bar.scopeColor(modelData.c)
                            }
                            Text {
                                text: modelData.t
                                color: Theme.colDim
                                font.family: Theme.uiFont
                                font.pixelSize: 9
                            }
                        }
                    }
                }
            }

            Rectangle {
                Layout.fillHeight: true
                width: 1
                color: "#414868"
                opacity: 0.5
            }

            // ---- Grade de 12 meses ----
            ColumnLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: 6
                Text {
                    text: "Calendário " + bar.calYear
                    color: Theme.colText
                    font.family: Theme.uiFont
                    font.pixelSize: 15
                    font.bold: true
                    Layout.alignment: Qt.AlignHCenter
                }
                GridLayout {
                    Layout.fillWidth: true
                    columns: 4
                    rowSpacing: 8
                    columnSpacing: 12
                    Repeater {
                        model: 12
                        ColumnLayout {
                            required property int index
                            spacing: 1
                            Layout.alignment: Qt.AlignTop | Qt.AlignHCenter
                            Text {
                                text: bar.monthNames[index]
                                color: (index + 1 === bar.calTodayM) ? Theme.colAccent : Theme.colText
                                font.family: Theme.uiFont
                                font.pixelSize: 11
                                font.bold: true
                                Layout.alignment: Qt.AlignHCenter
                            }
                            Grid {
                                columns: 7
                                Layout.alignment: Qt.AlignHCenter
                                Repeater {
                                    model: bar.monthCells(index + 1)
                                    Item {
                                        required property var modelData
                                        readonly property var hol: modelData.holiday
                                        readonly property bool isToday: modelData.today === true
                                        readonly property bool isHead: modelData.head !== undefined
                                        width: 19
                                        height: 15
                                        Rectangle {
                                            anchors.centerIn: parent
                                            width: 16
                                            height: 13
                                            radius: 3
                                            color: parent.isToday ? Theme.colAccent : (parent.hol && !parent.hol.fac ? bar.scopeColor(parent.hol.scope) : "transparent")
                                            border.width: (!parent.isToday && parent.hol && parent.hol.fac) ? 1 : 0
                                            border.color: parent.hol ? bar.scopeColor(parent.hol.scope) : "transparent"
                                        }
                                        Text {
                                            anchors.centerIn: parent
                                            text: parent.isHead ? parent.modelData.head : (parent.modelData.d > 0 ? ("" + parent.modelData.d) : "")
                                            color: parent.isHead ? Theme.colDim : (parent.isToday ? "#1a1b26" : (parent.hol && !parent.hol.fac ? "#1a1b26" : (parent.hol && parent.hol.fac ? bar.scopeColor(parent.hol.scope) : Theme.colWsInactive)))
                                            font.family: Theme.uiFont
                                            font.pixelSize: parent.isHead ? 8 : 9
                                            font.bold: parent.isToday || (parent.hol && !parent.hol.fac) || parent.isHead
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
                Item {
                    Layout.fillHeight: true
                }
            }
        }
    }
}
