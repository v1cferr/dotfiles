// The GLANCE band: the top 30% of a STANDING monitor, which is the part above eye level where a
// window would only hurt the neck. What earns a place here, and why: docs/notes/desktop/dash.md
import Quickshell
import Quickshell.Wayland
import QtQuick
import QtQuick.Layouts
import "root:/"

PanelWindow {
    id: dash

    required property var modelData // the screen this instance belongs to
    property var host // the Bar's Scope: every number below is ALREADY collected there

    screen: modelData
    WlrLayershell.namespace: "qs-dash" // the glass blur rule matches it (appearance.lua)

    // The band fills the top share the BAR reserves on this screen (Bar.qml), from under the bar to
    // where the windows begin. It ignores other zones, so it never depends on which layer mapped first.
    readonly property int band: Theme.bandReserve(dash.screen ? dash.screen.height : 0) - Theme.bandTop

    anchors {
        top: true
        left: true
        right: true
    }
    margins {
        top: Theme.bandTop
        left: Theme.barTop
        right: Theme.barTop
    }
    exclusionMode: ExclusionMode.Ignore
    implicitHeight: dash.band
    color: "transparent"

    // The band is DRAWN on a fixed canvas, the 1440 logical width it was designed at (scale 0.75)
    // minus the window margins, and scaled to the real width INSIDE Quickshell: the glyphs are then
    // rasterized at their final size and stay sharp, where the compositor's downscale of a finished
    // frame blurred them. Why the LG left 0.75: docs/notes/desktop/dash.md
    readonly property real designWidth: 1432
    readonly property real k: dash.width > 0 ? dash.width / dash.designWidth : 1

    // The detail on hover: one card per band, fed by any `Tip` inside it (Tip.qml, Tips.qml).
    TipWindow {
        band: dash
    }

    Item {
        id: stage
        readonly property var tipBand: dash // TipWindow.inBand finds the band by it
        width: dash.width / dash.k
        height: dash.height / dash.k
        scale: dash.k
        transformOrigin: Item.TopLeft

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
                        duration: Theme.ms(320)
                        easing.type: Easing.OutQuad
                    }
                    NumberAnimation {
                        target: rise
                        property: "y"
                        from: 18
                        to: 0
                        duration: Theme.ms(560)
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
                anchors.margins: 32
                spacing: 24

                // ── The two columns: the machine on the left, the month on the right ──
                RowLayout {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    spacing: 32

                    ColumnLayout {
                        // fillWidth stays OFF: a nested layout inherits it from the grid and would starve the month.
                        Layout.fillWidth: false
                        Layout.preferredWidth: Math.round(stage.width * 0.55) // design units, not the window's
                        Layout.fillHeight: true
                        spacing: 2

                        // The time and the day side by side: HH:mm:ss carries the glance, the spelled-out
                        // weekday is what a person wants off a clock, and one short date line under it.
                        // The full date, the ISO date and the uptime are in the tooltip of either.
                        RowLayout {
                            id: clockRow
                            readonly property int week: dash.host.isoWeek(dash.host.calYear, dash.host.calTodayM, dash.host.calTodayD)
                            readonly property string month: dash.host.monthNames[dash.host.calTodayM - 1] || ""
                            readonly property string tipTitle: (dash.host.dowNames[dash.host.calTodayW] || "") + ", " + dash.host.calTodayD + " de " + clockRow.month.toLowerCase() + " de " + dash.host.calYear
                            readonly property var tipLines: [dash.host.calYear + "-" + ("0" + dash.host.calTodayM).slice(-2) + "-" + ("0" + dash.host.calTodayD).slice(-2) + "  ·  ISO week " + clockRow.week, "up " + dash.host.fmtDur(dash.host.uptimeSec)]
                            Layout.fillWidth: true
                            spacing: 24
                            Text {
                                Tip {
                                    title: clockRow.tipTitle
                                    lines: clockRow.tipLines
                                }
                                text: dash.host.timeStr
                                color: Theme.colText
                                font.family: Theme.uiFont
                                font.pixelSize: 68
                                font.bold: true
                                font.letterSpacing: -1
                            }
                            ColumnLayout {
                                Layout.alignment: Qt.AlignVCenter
                                spacing: 2
                                Text {
                                    text: dash.host.dowNames[dash.host.calTodayW] || ""
                                    color: Theme.colText
                                    font.family: Theme.uiFont
                                    font.pixelSize: 32
                                    font.letterSpacing: -1
                                }
                                Text {
                                    Tip {
                                        title: clockRow.tipTitle
                                        lines: clockRow.tipLines
                                    }
                                    text: dash.host.calTodayD + " " + clockRow.month.slice(0, 3).toLowerCase() + "  ·  W" + clockRow.week
                                    color: Theme.colSubtext
                                    font.family: Theme.uiFont
                                    font.pixelSize: 18
                                    font.letterSpacing: 1
                                }
                            }
                        }

                        // Today's weather fills what was an empty gap under the date.
                        WeatherNow {
                            Layout.fillWidth: true
                            Layout.topMargin: 16
                            host: dash.host
                        }

                        Item {
                            Layout.fillHeight: true
                        }

                        // Six vitals in a 3x2 grid at a size read from the chair, not from a hover.
                        GridLayout {
                            Layout.fillWidth: true
                            columns: 3
                            columnSpacing: 32
                            rowSpacing: 24

                            Tile {
                                label: "CPU"
                                number: dash.host.cpuPct
                                unit: "%"
                                alert: dash.host.cpuPct >= 90
                                // The last 2 minutes, where they mean something: beside the CPU's own number.
                                series: dash.host.cpuHist
                                seriesTop: {
                                    const v = (dash.host.cpuHist || []).filter(x => !isNaN(x));
                                    const peak = v.length ? Math.max.apply(null, v) : 0;
                                    return Math.min(100, Math.max(20, Math.ceil(peak * 1.25 / 10) * 10));
                                }
                                hint: dash.host.cpuMhz > 0 ? (dash.host.cpuMhz / 1000).toFixed(1) + " GHz" : ""
                                frac: dash.host.cpuPct / 100
                                barColor: Theme.colBlue
                                tipTitle: dash.host.cpuModel
                                tipLines: [dash.host.cpuCores + " cores · " + dash.host.cpuThreads + " threads" + (dash.host.cpuMhzMax > 0 ? " · max " + (dash.host.cpuMhzMax / 1000).toFixed(1) + " GHz" : ""), "load " + dash.host.loadAvg.map(v => v.toFixed(2)).join("  "), "up " + dash.host.fmtDur(dash.host.uptimeSec)]
                            }
                            Tile {
                                label: "RAM"
                                number: dash.host.memPct
                                unit: "%"
                                alert: dash.host.memPct >= 90
                                hint: dash.host.fmtBytes(dash.host.memUsed) + " / " + dash.host.fmtBytes(dash.host.memTotal)
                                frac: dash.host.memPct / 100
                                barColor: Theme.colMauve
                                tipTitle: "Memory"
                                tipLines: [dash.host.fmtBytes(dash.host.memAvail) + " available · " + dash.host.fmtBytes(dash.host.memCached) + " cached", dash.host.swapTotal > 0 ? "swap " + dash.host.fmtBytes(dash.host.swapUsed) + " / " + dash.host.fmtBytes(dash.host.swapTotal) : "no swap"]
                            }
                            Tile {
                                label: "DISK"
                                number: dash.host.diskPct
                                unit: "%"
                                alert: dash.host.diskPct >= 90
                                hint: dash.host.fmtBytes(dash.host.diskFree) + " free"
                                frac: dash.host.diskPct / 100
                                barColor: Theme.colTeal
                                tipTitle: "Root filesystem" + (dash.host.diskFs ? " · " + dash.host.diskFs : "")
                                tipLines: [dash.host.fmtBytes(dash.host.diskUsed) + " used of " + dash.host.fmtBytes(dash.host.diskTotal) + (dash.host.diskDev ? " on " + dash.host.diskDev : ""), "read " + dash.host.fmtBytes(dash.host.diskReadBps) + "/s · write " + dash.host.fmtBytes(dash.host.diskWriteBps) + "/s"]
                            }
                            // The Arc publishes no busy %, so the bar is power against its own cap.
                            Tile {
                                label: "GPU"
                                number: dash.host.gpuWatts
                                unit: " W"
                                alert: dash.host.gpuWattsCap > 0 && dash.host.gpuWatts >= 0.9 * dash.host.gpuWattsCap
                                hint: dash.host.gpuFreq > 0 ? (dash.host.gpuFreq / 1000).toFixed(2) + " GHz" : "idle"
                                frac: dash.host.gpuWattsCap > 0 ? dash.host.gpuWatts / dash.host.gpuWattsCap : 0
                                barColor: Theme.colPeach
                                tipTitle: "GPU"
                                tipLines: [dash.host.gpuWattsCap > 0 ? "power cap " + Math.round(dash.host.gpuWattsCap) + " W" : "", dash.host.gpuFreqMax > 0 ? "clock max " + (dash.host.gpuFreqMax / 1000).toFixed(2) + " GHz" : "", dash.host.gpuFan >= 0 ? "fan " + Math.round(dash.host.gpuFan) + " rpm" : ""].filter(x => x)
                            }
                            Tile {
                                label: "TEMP"
                                number: dash.host.tempMax
                                unit: "°C"
                                alert: !!dash.host.tempQuality && dash.host.tempQuality.label === "critical"
                                hint: dash.host.tempQuality ? dash.host.tempQuality.label : ""
                                frac: dash.host.tempMax / 100
                                barColor: dash.host.tempQuality ? dash.host.tempQuality.color : Theme.colGreen
                                tipTitle: "Temperatures"
                                tipLines: (dash.host.tempList || []).map(s => s.name + "  " + s.temp + "°C")
                            }
                            // Download against the link speed, the only ceiling the NIC actually knows.
                            Tile {
                                readonly property real linkBps: Number((dash.host.netLink[dash.host.netMain] || {}).speed || 0) * 125000
                                label: "NET"
                                value: "↓ " + dash.host.fmtBytes(dash.host.netMainRx) + "/s"
                                hint: "↑ " + dash.host.fmtBytes(dash.host.netMainTx) + "/s"
                                frac: linkBps > 0 ? dash.host.netMainRx / linkBps : 0
                                barColor: Theme.colSky
                                tipTitle: dash.host.netMain || "offline"
                                tipLines: [dash.host.netAddr[dash.host.netMain] || "", dash.host.netSpeed ? "link " + dash.host.netSpeed : "", dash.host.netGw ? "gateway " + dash.host.netGw : ""].filter(x => x)
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

                    // ── The rotating column: the month, then CI. One page at a time, every 15 s ──
                    ColumnLayout {
                        id: pages
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        spacing: 10

                        // 0 = month, 1 = GitHub Actions, 2 = the FAI GitLab (only while it answers).
                        // Page ids are stable (3 = weather, 4 = network, in the order they were added); `order` is the rotation.
                        readonly property var order: Ci.gitlabShown ? [0, 3, 4, 1, 2] : [0, 3, 4, 1]
                        readonly property var titles: [(dash.host.monthNames[dash.host.calTodayM - 1] || "").toUpperCase() + "  " + dash.host.calYear, "GITHUB  ACTIONS", "FAI  ·  GITLAB", "WEATHER  ·  24 H", "NETWORK  ·  LAN"]
                        property int page: 0
                        function step(d) {
                            const n = pages.order.length;
                            const i = pages.order.indexOf(pages.page);
                            pages.dir = d > 0 ? 1 : -1;
                            pages.page = pages.order[(i + d + n) % n];
                        }
                        // The slide: the page coming in enters from the side being moved toward, and the
                        // one leaving exits the other way, so the column reads as a strip and not a flicker.
                        property int dir: 1
                        property int prevPage: -1
                        property int curPage: 0
                        onPageChanged: {
                            pages.prevPage = pages.curPage;
                            pages.curPage = pages.page;
                        }
                        function offsetOf(i) {
                            return pages.page === i ? 0 : (i === pages.prevPage ? -pages.dir : pages.dir) * 56;
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
                                                duration: Theme.motionNormal
                                                easing.type: Easing.OutCubic
                                            }
                                        }
                                        MouseArea {
                                            anchors.fill: parent
                                            anchors.margins: -4
                                            onClicked: {
                                                pages.dir = parent.modelData > pages.page ? 1 : -1;
                                                pages.page = parent.modelData;
                                            }
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
                                        duration: Theme.motionHover
                                    }
                                }
                                Behavior on border.color {
                                    ColorAnimation {
                                        duration: Theme.motionHover
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
                                transform: Translate {
                                    x: pages.offsetOf(0)
                                    Behavior on x {
                                        NumberAnimation {
                                            duration: Theme.ms(420)
                                            easing.type: Easing.OutCubic
                                        }
                                    }
                                }
                                visible: opacity > 0
                                Behavior on opacity {
                                    NumberAnimation {
                                        duration: Theme.ms(260)
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
                                            // The WEEK's weather rides on its own days: today and the six after it.
                                            readonly property var wx: (isHead || !(cell.modelData.d > 0)) ? null : dash.host.wDaily[dash.host.calYear + "-" + ("0" + dash.host.calTodayM).slice(-2) + "-" + ("0" + cell.modelData.d).slice(-2)] || null

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
                                                anchors.verticalCenterOffset: cell.wx ? -11 : 0
                                                text: cell.isHead ? cell.modelData.head : (cell.modelData.d > 0 ? ("" + cell.modelData.d) : "")
                                                color: cell.isHead ? Theme.colSubtext : (cell.isFilled ? Theme.colBgSolid : (cell.hol ? dash.host.scopeColor(cell.hol.scope) : (cell.isPast ? Theme.colDim : Theme.colText)))
                                                font.family: Theme.uiFont
                                                font.pixelSize: cell.isHead ? 13 : 18
                                                font.bold: cell.isFilled || cell.isToday || cell.isHead
                                                font.letterSpacing: cell.isHead ? 2 : 0
                                            }
                                            Row {
                                                anchors.horizontalCenter: parent.horizontalCenter
                                                anchors.verticalCenter: parent.verticalCenter
                                                anchors.verticalCenterOffset: 13
                                                visible: !!cell.wx
                                                spacing: 4
                                                Text {
                                                    text: cell.wx ? dash.host.weatherIcon(cell.wx.code, true) : ""
                                                    color: cell.isFilled ? Theme.colBgSolid : WeatherSky.color(cell.wx ? cell.wx.code : -1)
                                                    font.family: Theme.uiFont
                                                    font.pixelSize: 14
                                                }
                                                Text {
                                                    text: cell.wx ? cell.wx.high + "°" : ""
                                                    color: cell.isFilled ? Theme.colBgSolid : Theme.colText
                                                    font.family: Theme.uiFont
                                                    font.pixelSize: 12
                                                    font.bold: true
                                                }
                                            }
                                            // The day's minimum, rain, holiday and INMET's words: on hover.
                                            Tip {
                                                readonly property string key: dash.host.calYear + "-" + ("0" + dash.host.calTodayM).slice(-2) + "-" + ("0" + cell.modelData.d).slice(-2)
                                                readonly property var inmet: Inmet.days[key] || null
                                                title: cell.isHead || !(cell.modelData.d > 0) ? "" : cell.modelData.d + " " + (dash.host.monthNames[dash.host.calTodayM - 1] || "").slice(0, 3).toLowerCase() + (cell.hol ? " · " + cell.hol.name : "")
                                                lines: !cell.wx ? [] : [dash.host.wmoText(cell.wx.code), "↑" + cell.wx.high + "°  ↓" + cell.wx.low + "°" + (cell.wx.precip ? "  ·  rain " + cell.wx.precip + "%" : ""), inmet ? "INMET: " + inmet.summary : ""].filter(x => x)
                                            }
                                        }
                                    }
                                }
                            }

                            // The weather page (WeatherPage.qml): alerts, the week, INMET's words, the 24 hours.
                            ColumnLayout {
                                anchors.fill: parent
                                spacing: 18
                                opacity: pages.page === 3 ? 1 : 0
                                visible: opacity > 0
                                Behavior on opacity {
                                    NumberAnimation {
                                        duration: Theme.ms(260)
                                    }
                                }
                                transform: Translate {
                                    x: pages.offsetOf(3)
                                    Behavior on x {
                                        NumberAnimation {
                                            duration: Theme.ms(420)
                                            easing.type: Easing.OutCubic
                                        }
                                    }
                                }
                                WeatherPage {
                                    Layout.fillWidth: true
                                    Layout.fillHeight: true
                                    Layout.topMargin: 6
                                    host: dash.host
                                }
                            }

                            // The network page (NetworkPage.qml): devices, remote access, attacks on the exposed ports.
                            NetworkPage {
                                anchors.fill: parent
                                anchors.topMargin: 6
                                opacity: pages.page === 4 ? 1 : 0
                                visible: opacity > 0
                                Behavior on opacity {
                                    NumberAnimation {
                                        duration: Theme.ms(260)
                                    }
                                }
                                transform: Translate {
                                    x: pages.offsetOf(4)
                                    Behavior on x {
                                        NumberAnimation {
                                            duration: Theme.ms(420)
                                            easing.type: Easing.OutCubic
                                        }
                                    }
                                }
                            }

                            CiList {
                                id: ghList
                                anchors.fill: parent
                                held: pageHover.hovered
                                opacity: pages.page === 1 ? 1 : 0
                                transform: Translate {
                                    x: pages.offsetOf(1)
                                    Behavior on x {
                                        NumberAnimation {
                                            duration: Theme.ms(420)
                                            easing.type: Easing.OutCubic
                                        }
                                    }
                                }
                                visible: opacity > 0
                                Behavior on opacity {
                                    NumberAnimation {
                                        duration: Theme.ms(260)
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
                                transform: Translate {
                                    x: pages.offsetOf(2)
                                    Behavior on x {
                                        NumberAnimation {
                                            duration: Theme.ms(420)
                                            easing.type: Easing.OutCubic
                                        }
                                    }
                                }
                                visible: opacity > 0
                                Behavior on opacity {
                                    NumberAnimation {
                                        duration: Theme.ms(260)
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

                // ── The services: what runs on this machine and what each costs, as a carousel ──
                ServiceStrip {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 100
                }
            }
        }
    }
}
