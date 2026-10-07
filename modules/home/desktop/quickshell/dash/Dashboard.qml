// The GLANCE band: the top 30% of a STANDING monitor, which is the part above eye level where a
// window would only hurt the neck. What earns a place here, and why: docs/notes/desktop/dash.md
import Quickshell
import QtQuick
import QtQuick.Layouts
import "root:/"

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
                    // fillWidth stays OFF: a nested layout inherits it from the grid and would starve the month.
                    Layout.fillWidth: false
                    Layout.preferredWidth: Math.round(dash.width * 0.55)
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

                    // Today's weather fills what was an empty gap under the date.
                    WeatherNow {
                        Layout.fillWidth: true
                        Layout.topMargin: 18
                        host: dash.host
                    }

                    Item {
                        Layout.fillHeight: true
                    }

                    // Six vitals in a 3x2 grid at a size read from the chair, not from a hover.
                    GridLayout {
                        Layout.fillWidth: true
                        columns: 3
                        columnSpacing: 28
                        rowSpacing: 26

                        Tile {
                            label: "CPU"
                            value: dash.host.cpuPct + "%"
                            hint: dash.host.cpuMhz > 0 ? (dash.host.cpuMhz / 1000).toFixed(1) + " GHz" : ""
                            frac: dash.host.cpuPct / 100
                            barColor: Theme.colBlue
                        }
                        Tile {
                            label: "RAM"
                            value: dash.host.memPct + "%"
                            hint: dash.host.fmtBytes(dash.host.memUsed) + " / " + dash.host.fmtBytes(dash.host.memTotal)
                            frac: dash.host.memPct / 100
                            barColor: Theme.colMauve
                        }
                        Tile {
                            label: "DISK"
                            value: dash.host.diskPct + "%"
                            hint: dash.host.fmtBytes(dash.host.diskFree) + " free"
                            frac: dash.host.diskPct / 100
                            barColor: Theme.colTeal
                        }
                        // The Arc publishes no busy %, so the bar is power against its own cap.
                        Tile {
                            label: "GPU"
                            value: dash.host.gpuWatts.toFixed(0) + " W"
                            hint: dash.host.gpuFreq > 0 ? (dash.host.gpuFreq / 1000).toFixed(2) + " GHz" : "idle"
                            frac: dash.host.gpuWattsCap > 0 ? dash.host.gpuWatts / dash.host.gpuWattsCap : 0
                            barColor: Theme.colPeach
                        }
                        Tile {
                            label: "TEMP"
                            value: dash.host.tempMax + "°C"
                            hint: dash.host.tempQuality ? dash.host.tempQuality.label : ""
                            frac: dash.host.tempMax / 100
                            barColor: dash.host.tempQuality ? dash.host.tempQuality.color : Theme.colGreen
                        }
                        // Download against the link speed, the only ceiling the NIC actually knows.
                        Tile {
                            readonly property real linkBps: Number((dash.host.netLink[dash.host.netMain] || {}).speed || 0) * 125000
                            label: "NET"
                            value: "↓ " + dash.host.fmtBytes(dash.host.netMainRx) + "/s"
                            hint: "↑ " + dash.host.fmtBytes(dash.host.netMainTx) + "/s" + (dash.host.netSpeed ? "  ·  " + dash.host.netSpeed : "")
                            frac: linkBps > 0 ? dash.host.netMainRx / linkBps : 0
                            barColor: Theme.colSky
                        }
                    }

                    Text {
                        Layout.topMargin: 14
                        text: "UP " + dash.host.fmtDur(dash.host.uptimeSec) + "   ·   LOAD " + dash.host.loadAvg.map(v => v.toFixed(2)).join("  ")
                        color: Theme.colSubtext
                        font.family: Theme.uiFont
                        font.pixelSize: 14
                        font.letterSpacing: 2
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

                // ── The rotating column: the month, then CI. One page at a time, every 15 s ──
                ColumnLayout {
                    id: pages
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    spacing: 10

                    // 0 = month, 1 = GitHub Actions, 2 = the FAI GitLab (only while it answers).
                    readonly property var order: Ci.gitlabShown ? [0, 1, 2] : [0, 1]
                    readonly property var titles: [(dash.host.monthNames[dash.host.calTodayM - 1] || "").toUpperCase() + "  " + dash.host.calYear, "GITHUB  ACTIONS", "FAI  ·  GITLAB"]
                    property int page: 0
                    function step(d) {
                        const n = pages.order.length;
                        const i = pages.order.indexOf(pages.page);
                        pages.page = pages.order[(i + d + n) % n];
                    }
                    // A page that leaves the rotation (VPN down) must not stay on screen.
                    onOrderChanged: if (pages.order.indexOf(pages.page) < 0)
                        pages.page = 0

                    // The pointer over the column holds the page: reading a row must not be a race.
                    HoverHandler {
                        id: pageHover
                    }
                    Timer {
                        interval: 15000
                        repeat: true
                        running: dash.visible && !pageHover.hovered && !ghList.detailOpen && !glList.detailOpen
                        onTriggered: pages.step(1)
                    }
                    // The wheel turns the pages too. No timer reset is needed: the pointer is over
                    // the column, which already holds the rotation until it leaves.
                    WheelHandler {
                        acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
                        onWheel: event => pages.step(event.angleDelta.y > 0 ? -1 : 1)
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 10

                        Text {
                            text: pages.titles[pages.page]
                            color: Theme.colText
                            font.family: Theme.uiFont
                            font.pixelSize: 14
                            font.bold: true
                            font.letterSpacing: 4
                        }
                        // Where the rotation is: arrows to step, a dot to jump.
                        Row {
                            spacing: 6
                            PageArrow {
                                anchors.verticalCenter: parent.verticalCenter
                                glyph: "‹"
                                onClicked: pages.step(-1)
                            }
                            Repeater {
                                model: pages.order
                                delegate: Rectangle {
                                    required property int modelData
                                    readonly property bool on: pages.page === modelData
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: on ? 18 : 7
                                    height: 7
                                    radius: 3.5
                                    color: on ? Theme.colAccent : Theme.colTrack
                                    Behavior on width {
                                        NumberAnimation {
                                            duration: 200
                                            easing.type: Easing.OutCubic
                                        }
                                    }
                                    MouseArea {
                                        anchors.fill: parent
                                        anchors.margins: -4
                                        onClicked: pages.page = parent.modelData
                                    }
                                }
                            }
                            PageArrow {
                                anchors.verticalCenter: parent.verticalCenter
                                glyph: "›"
                                onClicked: pages.step(1)
                            }
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
                        Layout.fillWidth: true
                        Layout.fillHeight: true

                        Item {
                            id: gridBox
                            anchors.fill: parent
                            opacity: pages.page === 0 ? 1 : 0
                            visible: opacity > 0
                            Behavior on opacity {
                                NumberAnimation {
                                    duration: 260
                                }
                            }

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
                                        // Days already gone step back, so the eye lands on what is still ahead.
                                        readonly property bool isPast: !isHead && cell.modelData.d > 0 && cell.modelData.d < dash.host.calTodayD
                                        readonly property int side: Math.min(width, height) - 6

                                        width: gridBox.cellW
                                        height: gridBox.cellH

                                        // TODAY is a ring around the WHOLE cell and never a fourth color: a FILL
                                        // already means a holiday here and an OUTLINE a facultative one.
                                        Rectangle {
                                            anchors.centerIn: parent
                                            width: cell.side
                                            height: cell.side
                                            radius: 9
                                            visible: cell.isToday
                                            color: Theme.colNowBg
                                            border.width: 1
                                            border.color: Theme.colAccent
                                        }
                                        Rectangle {
                                            anchors.centerIn: parent
                                            width: cell.side - 10
                                            height: cell.side - 10
                                            radius: 7
                                            color: (cell.hol && !cell.hol.fac) ? dash.host.scopeColor(cell.hol.scope) : ((cell.isToday && !cell.hol) ? Theme.colAccent : "transparent")
                                            border.width: (cell.hol && cell.hol.fac) ? 1 : 0
                                            border.color: cell.hol ? dash.host.scopeColor(cell.hol.scope) : "transparent"
                                        }
                                        Text {
                                            anchors.centerIn: parent
                                            text: cell.isHead ? cell.modelData.head : (cell.modelData.d > 0 ? ("" + cell.modelData.d) : "")
                                            color: cell.isHead ? Theme.colSubtext : (cell.isFilled ? Theme.colBgSolid : (cell.hol ? dash.host.scopeColor(cell.hol.scope) : (cell.isPast ? Theme.colDim : Theme.colText)))
                                            font.family: Theme.uiFont
                                            font.pixelSize: cell.isHead ? 13 : 18
                                            font.bold: cell.isFilled || cell.isToday || cell.isHead
                                            font.letterSpacing: cell.isHead ? 2 : 0
                                        }
                                    }
                                }
                            }
                        }

                        CiList {
                            id: ghList
                            anchors.fill: parent
                            held: pageHover.hovered
                            opacity: pages.page === 1 ? 1 : 0
                            visible: opacity > 0
                            Behavior on opacity {
                                NumberAnimation {
                                    duration: 260
                                }
                            }
                            source: Ci.github
                            dropOwners: ["v1cferr"]
                            errorText: ({
                                    auth: "gh is not logged in",
                                    loading: "loading…"
                                })
                        }
                        CiList {
                            id: glList
                            anchors.fill: parent
                            held: pageHover.hovered
                            opacity: pages.page === 2 ? 1 : 0
                            visible: opacity > 0
                            Behavior on opacity {
                                NumberAnimation {
                                    duration: 260
                                }
                            }
                            source: Ci.gitlab
                            emptyText: "no pipeline in the last 7 days"
                            errorText: ({
                                    "no-token": "No GitLab token yet: fai_gitlab_token (read_api) is not in sops.",
                                    auth: "The GitLab token was refused (expired, or without read_api).",
                                    loading: "loading…"
                                })
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
                Layout.preferredHeight: 104
                series: dash.host.cpuHist
                window: dash.host.histWindow
                period: dash.host.sysInterval
                // The ceiling follows the window's peak, in steps of 10: on a fixed 0-100 an idle
                // desktop at 8% drew a flat line. The caption says the scale, so a tall bar never lies.
                scaleTop: {
                    const v = (dash.host.cpuHist || []).filter(x => !isNaN(x));
                    const peak = v.length ? Math.max.apply(null, v) : 0;
                    return Math.min(100, Math.max(20, Math.ceil(peak * 1.25 / 10) * 10));
                }
                caption: "CPU · LAST 2 MIN"
                nowText: "now " + dash.host.cpuPct + "%"
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
