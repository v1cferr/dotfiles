// The calendar popover (the whole year plus upcoming holidays), on hovering the clock. The state
// and the logic live in the Bar and arrive by reference through `bar`.
import Quickshell
import QtQuick
import QtQuick.Layouts
import "root:/"
import "root:/widgets"

PanelWindow {
    id: calPop
    required property var bar
    visible: bar.calPopVisible
    screen: bar.popScreen || bar.screenPrimary
    anchors {
        top: true
        left: true
    }
    margins {
        top: 4 // = Hyprland's gaps_out: it aligns the popover with the top of the windows (barExclusiveZone 30 already added)
        left: bar.popLeft(calPop.implicitWidth)
    }
    exclusiveZone: 0
    implicitWidth: 920
    implicitHeight: 470
    color: "transparent"
    PopCard {
        id: card
        onHoveredChanged: calPop.bar.calPopHovered = card.hovered

        RowLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 14

            // ---- The upcoming holidays (the left column) ----
            ColumnLayout {
                Layout.preferredWidth: 234
                Layout.fillHeight: true
                spacing: 7
                Text {
                    text: "Upcoming holidays"
                    color: Theme.colAccent
                    font.family: Theme.uiFont
                    font.pixelSize: 15
                    font.bold: true
                }
                Hairline {}
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
                        model: [{ c: "nac", t: "National" }, { c: "sp", t: "SP" }, { c: "sc", t: "S.Carlos" }]
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
                color: Theme.colBorder
                opacity: 0.5
            }

            // ---- The 12-month grid ----
            ColumnLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: 6
                Text {
                    text: "Calendar " + bar.calYear
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
                        // The current month is a PANEL, not just a colored name: at a glance the eye lands on
                        // the block first and only then looks for today's ring inside it.
                        Rectangle {
                            id: monthBlk
                            required property int index
                            readonly property bool isNow: (monthBlk.index + 1) === bar.calTodayM
                            Layout.alignment: Qt.AlignTop | Qt.AlignHCenter
                            implicitWidth: monthCol.implicitWidth + 12
                            implicitHeight: monthCol.implicitHeight + 8
                            radius: 7
                            color: monthBlk.isNow ? Theme.colNowPanel : "transparent"
                            border.width: monthBlk.isNow ? 1 : 0
                            border.color: Theme.colNowBorder
                            ColumnLayout {
                                id: monthCol
                                anchors.centerIn: parent
                                spacing: 1
                                // The current month also wears a PILL: the accent on the name alone was too close to colText
                                Item {
                                    implicitWidth: monthTxt.implicitWidth + 12
                                    implicitHeight: monthTxt.implicitHeight + 3
                                    Layout.alignment: Qt.AlignHCenter
                                    Rectangle {
                                        anchors.fill: parent
                                        radius: 5
                                        visible: monthBlk.isNow
                                        color: Theme.colNowBg
                                    }
                                    Text {
                                        id: monthTxt
                                        anchors.centerIn: parent
                                        text: bar.monthNames[monthBlk.index]
                                        color: monthBlk.isNow ? Theme.colAccent : Theme.colText
                                        font.family: Theme.uiFont
                                        font.pixelSize: 11
                                        font.bold: true
                                    }
                                }
                                Grid {
                                    columns: 7
                                    Layout.alignment: Qt.AlignHCenter
                                    Repeater {
                                        model: bar.monthCells(monthBlk.index + 1)
                                        Item {
                                            required property var modelData
                                            readonly property var hol: modelData.holiday
                                            readonly property bool isToday: modelData.today === true
                                            readonly property bool isHead: modelData.head !== undefined
                                            readonly property bool isFilled: (hol && !hol.fac) || (isToday && !hol) // a solid chip, so the number goes dark
                                            width: 19
                                            height: 15
                                            // TODAY is a RING plus a glow around the WHOLE cell, never one more color: accent == blue
                                            // in 2 of the 3 palettes, so the old filled chip was identical to an SP holiday.
                                            Rectangle {
                                                anchors.fill: parent
                                                radius: 5
                                                visible: parent.isToday
                                                color: Theme.colNowBg
                                                border.width: 1
                                                border.color: Theme.colAccent
                                            }
                                            // The chip is ALWAYS the holiday's, so a today that falls on one keeps both facts readable
                                            Rectangle {
                                                anchors.centerIn: parent
                                                width: 15
                                                height: 11
                                                radius: 3
                                                color: (parent.hol && !parent.hol.fac) ? bar.scopeColor(parent.hol.scope) : ((parent.isToday && !parent.hol) ? Theme.colAccent : "transparent")
                                                border.width: (parent.hol && parent.hol.fac) ? 1 : 0
                                                border.color: parent.hol ? bar.scopeColor(parent.hol.scope) : "transparent"
                                            }
                                            Text {
                                                anchors.centerIn: parent
                                                text: parent.isHead ? parent.modelData.head : (parent.modelData.d > 0 ? ("" + parent.modelData.d) : "")
                                                color: parent.isHead ? Theme.colDim : (parent.isFilled ? Theme.colBgSolid : (parent.hol ? bar.scopeColor(parent.hol.scope) : Theme.colWsInactive))
                                                font.family: Theme.uiFont
                                                font.pixelSize: parent.isHead ? 8 : 9
                                                font.bold: parent.isFilled || parent.isToday || parent.isHead
                                            }
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
