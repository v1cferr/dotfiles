// The GLANCE band: the top 30% of a STANDING monitor, which is the part above eye level where a
// window would only hurt the neck. What earns a place here, and why: docs/notes/desktop/bar.md
import Quickshell
import QtQuick
import QtQuick.Layouts
import "root:/"
import "root:/widgets"

PanelWindow {
    id: dash

    required property var modelData // the screen this instance belongs to
    property var host // the Bar's Scope: every number below is ALREADY collected there

    screen: modelData

    // 30% of the screen for the glance and 70% for the windows. The bar's own strip counts toward
    // the 30%, so it comes off here along with this panel's top margin.
    readonly property int band: Math.round((dash.screen ? dash.screen.height : 0) * 0.3) - dash.host.barExclusiveZone - 8

    anchors {
        top: true
        left: true
        right: true
    }
    margins {
        top: 4
        left: 4
        right: 4
    }
    implicitHeight: dash.band
    exclusiveZone: dash.band
    color: "transparent"

    Rectangle {
        id: card
        anchors.fill: parent
        radius: 14
        color: Theme.colCard
        border.width: 1
        border.color: Theme.colGroupBorder
        clip: true
        opacity: 0

        // ONE entrance, not an effect per element: the card fades while the content rises into it,
        // and the horizon follows a beat later so the eye lands on the time first.
        Component.onCompleted: intro.start()
        SequentialAnimation {
            id: intro
            ParallelAnimation {
                NumberAnimation {
                    target: card
                    property: "opacity"
                    from: 0
                    to: 1
                    duration: 320
                    easing.type: Easing.OutQuad
                }
                NumberAnimation {
                    target: rise
                    property: "y"
                    from: 18
                    to: 0
                    duration: 560
                    easing.type: Easing.OutQuint
                }
            }
        }

        ColumnLayout {
            transform: Translate {
                id: rise
                y: 14
            }
            anchors.fill: parent
            anchors.margins: 20
            anchors.bottomMargin: 0 // the horizon sits flush with the card's edge
            spacing: 12

            // ── The two columns: the machine on the left, the month on the right ──
            RowLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: 22

                ColumnLayout {
                    Layout.preferredWidth: 420
                    Layout.fillHeight: true
                    spacing: 2

                    // HH:mm carries the glance; the seconds are there to prove the panel is alive.
                    Text {
                        text: dash.host.timeStr
                        color: Theme.colText
                        font.family: Theme.uiFont
                        font.pixelSize: 68
                        font.bold: true
                        font.letterSpacing: -1
                    }

                    // The spelled-out weekday is what a person actually wants off a clock, so it
                    // gets a size close to the time's; the ISO line under it is the record.
                    Text {
                        Layout.topMargin: 4
                        text: dash.host.dowNames[dash.host.calTodayW] || ""
                        color: Theme.colText
                        font.family: Theme.uiFont
                        font.pixelSize: 38
                        font.letterSpacing: -1
                    }
                    Text {
                        Layout.topMargin: 6
                        text: dash.host.calYear + "-" + ("0" + dash.host.calTodayM).slice(-2) + "-" + ("0" + dash.host.calTodayD).slice(-2) + "  ·  " + (dash.host.monthNames[dash.host.calTodayM - 1] || "") + "  ·  W" + dash.host.isoWeek(dash.host.calYear, dash.host.calTodayM, dash.host.calTodayD)
                        color: Theme.colSubtext
                        font.family: Theme.uiFont
                        font.pixelSize: 22
                        font.letterSpacing: 1
                    }

                    Item {
                        Layout.fillHeight: true
                    }

                    Hairline {}

                    ColumnLayout {
                        Layout.fillWidth: true
                        Layout.topMargin: 12
                        spacing: 9

                        MeterRow {
                            label: "CPU"
                            value: dash.host.cpuPct + "%"
                            hint: dash.host.cpuMhz > 0 ? (dash.host.cpuMhz / 1000).toFixed(1) + " GHz" : ""
                            frac: dash.host.cpuPct / 100
                            barColor: Theme.colBlue
                        }
                        MeterRow {
                            label: "RAM"
                            value: dash.host.memPct + "%"
                            hint: dash.host.fmtBytes(dash.host.memUsed) + " / " + dash.host.fmtBytes(dash.host.memTotal)
                            frac: dash.host.memPct / 100
                            barColor: Theme.colMauve
                        }
                        MeterRow {
                            label: "DISK"
                            value: dash.host.diskPct + "%"
                            hint: dash.host.fmtBytes(dash.host.diskFree) + " free"
                            frac: dash.host.diskPct / 100
                            barColor: Theme.colTeal
                        }
                        MeterRow {
                            label: "TEMP"
                            value: dash.host.tempMax + "°C"
                            hint: dash.host.gpuWatts > 0 ? dash.host.gpuWatts.toFixed(0) + " W GPU" : ""
                            frac: dash.host.tempMax / 100
                            barColor: dash.host.tempQuality ? dash.host.tempQuality.color : Theme.colGreen
                        }
                    }
                }

                Rectangle {
                    Layout.fillHeight: true
                    Layout.topMargin: 4
                    Layout.bottomMargin: 4
                    implicitWidth: 1
                    color: Theme.colBorder
                    opacity: 0.4
                }

                // ── The month, at a size you read from a glance and not from a hover ──
                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    spacing: 10

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 10

                        Text {
                            text: (dash.host.monthNames[dash.host.calTodayM - 1] || "").toUpperCase() + "  " + dash.host.calYear
                            color: Theme.colText
                            font.family: Theme.uiFont
                            font.pixelSize: 12
                            font.bold: true
                            font.letterSpacing: 4
                        }
                        Item {
                            Layout.fillWidth: true
                        }
                        // The feed stays CLOSED: the bell is a count and a way in, nothing else.
                        Rectangle {
                            implicitWidth: bell.implicitWidth + 18
                            implicitHeight: 24
                            radius: 12
                            color: bellArea.containsMouse ? Theme.colHoverBgAccent : Theme.colGroupBg
                            border.width: 1
                            border.color: bellArea.containsMouse ? Theme.colHoverBorder : Theme.colPillBorder

                            Behavior on color {
                                ColorAnimation {
                                    duration: Theme.hoverAnim
                                }
                            }
                            Behavior on border.color {
                                ColorAnimation {
                                    duration: Theme.hoverAnim
                                }
                            }

                            RowLayout {
                                id: bell
                                anchors.centerIn: parent
                                spacing: 6
                                Text {
                                    text: Notifs.barIcon || "󰂜"
                                    color: Notifs.dnd ? Theme.colRed : (Notifs.count > 0 ? Theme.colPeach : Theme.colDim)
                                    font.family: Theme.uiFont
                                    font.pixelSize: 13
                                }
                                Text {
                                    visible: Notifs.count > 0
                                    text: "" + Notifs.count
                                    color: Theme.colPeach
                                    font.family: Theme.uiFont
                                    font.pixelSize: 12
                                    font.bold: true
                                }
                            }
                            MouseArea {
                                id: bellArea
                                anchors.fill: parent
                                hoverEnabled: true
                                acceptedButtons: Qt.LeftButton | Qt.RightButton
                                onClicked: mouse => mouse.button === Qt.RightButton ? Notifs.toggleDnd() : Notifs.toggleCenter()
                            }
                        }
                    }

                    // The Grid is sized by the BOX and never by its children, otherwise the cells
                    // reading the Grid's own width close a binding loop on implicitWidth.
                    Item {
                        id: gridBox
                        Layout.fillWidth: true
                        Layout.fillHeight: true

                        readonly property int cellW: Math.floor(gridBox.width / 7)
                        readonly property int cellH: Math.floor(gridBox.height / 7)

                        Grid {
                        id: monthGrid
                        columns: 7
                        anchors.fill: parent

                        Repeater {
                            model: dash.host.monthCells(dash.host.calTodayM)

                            delegate: Item {
                                id: cell
                                required property var modelData
                                readonly property var hol: cell.modelData.holiday
                                readonly property bool isToday: cell.modelData.today === true
                                readonly property bool isHead: cell.modelData.head !== undefined
                                readonly property bool isFilled: (hol && !hol.fac) || (isToday && !hol)

                                width: gridBox.cellW
                                height: gridBox.cellH

                                // TODAY is a ring around the WHOLE cell and never a fourth color: a FILL
                                // already means a holiday here and an OUTLINE a facultative one.
                                Rectangle {
                                    anchors.fill: parent
                                    anchors.margins: 2
                                    radius: 9
                                    visible: cell.isToday
                                    color: Theme.colNowBg
                                    border.width: 1
                                    border.color: Theme.colAccent
                                }
                                Rectangle {
                                    anchors.centerIn: parent
                                    width: parent.width - 18
                                    height: parent.height - 14
                                    radius: 7
                                    color: (cell.hol && !cell.hol.fac) ? dash.host.scopeColor(cell.hol.scope) : ((cell.isToday && !cell.hol) ? Theme.colAccent : "transparent")
                                    border.width: (cell.hol && cell.hol.fac) ? 1 : 0
                                    border.color: cell.hol ? dash.host.scopeColor(cell.hol.scope) : "transparent"
                                }
                                Text {
                                    anchors.centerIn: parent
                                    text: cell.isHead ? cell.modelData.head : (cell.modelData.d > 0 ? ("" + cell.modelData.d) : "")
                                    color: cell.isHead ? Theme.colDim : (cell.isFilled ? Theme.colBgSolid : (cell.hol ? dash.host.scopeColor(cell.hol.scope) : Theme.colWsInactive))
                                    font.family: Theme.uiFont
                                    font.pixelSize: cell.isHead ? 11 : 17
                                    font.bold: cell.isFilled || cell.isToday || cell.isHead
                                    font.letterSpacing: cell.isHead ? 2 : 0
                                }
                            }
                        }
                        }
                    }
                }
            }

            // ── What is playing, when something is ──
            RowLayout {
                Layout.fillWidth: true
                Layout.bottomMargin: 10
                visible: dash.host.spHasPlayer
                spacing: 12

                Text {
                    text: dash.host.spPlaying ? "󰐊" : "󰏤"
                    color: dash.host.spColor
                    font.family: Theme.uiFont
                    font.pixelSize: 16
                }
                Text {
                    Layout.fillWidth: true
                    elide: Text.ElideRight
                    text: dash.host.spTitle
                    color: Theme.colText
                    font.family: Theme.uiFont
                    font.pixelSize: 14
                }
                Text {
                    text: dash.host.spArtist
                    color: Theme.colDim
                    font.family: Theme.uiFont
                    font.pixelSize: 13
                    font.italic: true
                }
            }

            // ── The horizon: the last 2 minutes of CPU, and the line where the work area starts ──
            Horizon {
                id: horizon
                Layout.fillWidth: true
                Layout.preferredHeight: 62
                series: dash.host.cpuHist
                window: dash.host.histWindow
                period: dash.host.sysInterval
                caption: "CPU · 2 MIN"
                opacity: 0

                // A beat behind the card, so the reading arrives after the time and not with it.
                Component.onCompleted: horizonIn.start()
                NumberAnimation {
                    id: horizonIn
                    target: horizon
                    property: "opacity"
                    from: 0
                    to: 0.9
                    duration: 520
                    easing.type: Easing.OutQuad
                }
            }
        }
    }
}
