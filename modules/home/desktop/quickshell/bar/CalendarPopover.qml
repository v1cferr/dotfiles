// The VERIFIED CALENDAR (hover or click on the time or the date): the whole year, a month focused
// on demand, the selected day's detail with its sources, the upcoming events and the filters. The
// data is the holiday registry (Holidays.qml); the geometry comes from the screen it opens on, not
// from its name. docs/notes/desktop/calendar.md
import Quickshell
import QtQuick
import QtQuick.Layouts
import "root:/"
import "root:/widgets"
import "root:/calendar"

BarPanel {
    id: cal
    key: "cal"

    // ── State that outlives a close: the year shown stays until another is chosen ──
    property int viewYear: 0
    property int focusMonth: 0 // 0 = the year; 1-12 = that month, focused
    property string selected: ""
    readonly property int year: cal.viewYear > 0 ? cal.viewYear : cal.bar.calYear
    readonly property string todayIso: cal.bar.calYear + "-" + ("0" + cal.bar.calTodayM).slice(-2) + "-" + ("0" + cal.bar.calTodayD).slice(-2)
    readonly property var map: Holidays.mapFor(cal.year, Holidays.filters)
    readonly property var allMap: Holidays.mapFor(cal.year, ({
            sc: true,
            sp: true,
            br: true,
            un: true,
            holiday: true,
            optional: true,
            observance: true
        }))
    function goToday() {
        cal.viewYear = 0;
        cal.focusMonth = 0;
        cal.selected = cal.todayIso;
    }
    function focusOn(m, iso) {
        cal.focusMonth = m;
        if (iso)
            cal.selected = iso;
    }
    function stepMonth(dir) {
        let m = cal.focusMonth + dir, y = cal.year;
        if (m < 1) {
            m = 12;
            y--;
        } else if (m > 12) {
            m = 1;
            y++;
        }
        cal.viewYear = y === cal.bar.calYear ? 0 : y;
        cal.focusMonth = m;
    }

    // ── Geometry from the screen: four columns where the width allows (the 2560 px panel), three
    // on a narrow one (the standing 1080 px), a cell never under 26 px; past the screen's height the
    // body scrolls instead of shrinking the type. ──
    readonly property int sw: cal.screen ? cal.screen.width : 1920
    readonly property int sh: cal.screen ? cal.screen.height : 1080
    readonly property int availW: cal.sw - 2 * Theme.screenInset
    readonly property int availH: cal.sh - Theme.bandTop - Theme.screenInset
    readonly property bool wide: cal.availW >= 1200
    readonly property int pad: Theme.sp4
    readonly property int sideW: cal.wide ? 300 : 0
    readonly property int panelW: Math.min(cal.wide ? 1320 : 960, cal.availW)
    readonly property int cols: cal.wide ? 4 : 3
    readonly property int gridW: cal.panelW - 2 * cal.pad - (cal.wide ? cal.sideW + Theme.sp6 : 0)
    readonly property int colGap: Theme.sp4
    readonly property int monthW: Math.floor((cal.gridW - (cal.cols - 1) * cal.colGap) / cal.cols)
    readonly property int cellW: Math.max(26, Math.min(40, Math.floor((cal.monthW - Theme.sp2) / 7)))
    readonly property int cellH: Math.max(24, Math.min(30, Math.round(cal.cellW * 0.9)))
    readonly property int bigW: Math.max(64, Math.min(140, Math.floor((cal.gridW - 6 * Theme.sp1) / 7)))
    readonly property int bigH: Math.max(64, Math.min(96, Math.round(cal.bigW * 0.62)))

    implicitWidth: cal.panelW
    implicitHeight: Math.min(card.implicitHeight, cal.availH)
    onVisibleChanged: if (cal.visible) {
        Holidays.refresh();
        if (cal.selected === "")
            cal.selected = cal.todayIso;
    }

    PopCard {
        id: card
        shown: cal.visible
        pad: cal.pad
        gap: Theme.sp3
        onHoveredChanged: cal.bar.panelPopHovered = card.hovered

        // ── Header: the title, the year's (or month's) navigation, and the view ──
        RowLayout {
            Layout.fillWidth: true
            spacing: Theme.sp2
            Text {
                text: cal.focusMonth > 0 ? cal.bar.monthNames[cal.focusMonth - 1] + " " + cal.year : "Calendar " + cal.year
                color: Theme.colText
                font.family: Theme.uiFont
                font.pixelSize: 18
                font.bold: true
            }
            Text {
                visible: !Holidays.hasYear(cal.year)
                text: Holidays.loaded ? "no registry data for this year" : "registry not loaded"
                color: Theme.colWarn
                font.family: Theme.uiFont
                font.pixelSize: Theme.fontSmall
            }
            Item {
                Layout.fillWidth: true
            }
            NavButton {
                visible: cal.focusMonth > 0
                label: "Year"
                name: "Back to the whole year"
                onClicked: cal.focusMonth = 0
            }
            NavButton {
                label: "‹"
                name: cal.focusMonth > 0 ? "Previous month" : "Previous year"
                onClicked: cal.focusMonth > 0 ? cal.stepMonth(-1) : cal.viewYear = cal.year - 1
            }
            NavButton {
                label: "Today"
                name: "Back to today"
                active: cal.year === cal.bar.calYear && cal.selected === cal.todayIso
                onClicked: cal.goToday()
            }
            NavButton {
                label: "›"
                name: cal.focusMonth > 0 ? "Next month" : "Next year"
                onClicked: cal.focusMonth > 0 ? cal.stepMonth(1) : cal.viewYear = cal.year + 1
            }
        }

        // ── Filters: where, and what. Small, so they never eat the months' room ──
        Flow {
            Layout.fillWidth: true
            spacing: Theme.sp1
            Repeater {
                model: [
                    {
                        k: "sc",
                        t: "São Carlos"
                    },
                    {
                        k: "sp",
                        t: "São Paulo"
                    },
                    {
                        k: "br",
                        t: "Brasil"
                    },
                    {
                        k: "un",
                        t: "International"
                    },
                    {
                        k: "|"
                    },
                    {
                        k: "holiday",
                        t: "Holidays"
                    },
                    {
                        k: "optional",
                        t: "Optional days"
                    },
                    {
                        k: "observance",
                        t: "Observances"
                    }
                ]
                delegate: Item {
                    id: chipItem
                    required property var modelData
                    readonly property bool sep: chipItem.modelData.k === "|"
                    readonly property bool on: !chipItem.sep && Holidays.filters[chipItem.modelData.k] === true
                    readonly property bool isScope: ["sc", "sp", "br", "un"].indexOf(chipItem.modelData.k) >= 0
                    width: chipItem.sep ? Theme.sp3 : chipRow.implicitWidth + 2 * Theme.sp2
                    height: 24
                    Rectangle {
                        visible: !chipItem.sep
                        anchors.fill: parent
                        radius: 12
                        color: chipArea.containsMouse ? Theme.colHoverFill : (chipItem.on ? Theme.colSelectFill : "transparent")
                        border.width: chipItem.on ? 0 : 1
                        border.color: Theme.colEdge
                    }
                    Row {
                        id: chipRow
                        visible: !chipItem.sep
                        anchors.centerIn: parent
                        spacing: Theme.sp1
                        Rectangle {
                            visible: chipItem.isScope
                            width: 8
                            height: 8
                            radius: 4
                            anchors.verticalCenter: parent.verticalCenter
                            color: chipItem.isScope ? cal.bar.scopeColor(chipItem.modelData.k) : "transparent"
                            opacity: chipItem.on ? 1 : 0.4
                        }
                        Text {
                            text: chipItem.modelData.t || ""
                            color: chipItem.on ? Theme.colText : Theme.colDim
                            font.family: Theme.uiFont
                            font.pixelSize: Theme.fontSmall
                        }
                    }
                    MouseArea {
                        id: chipArea
                        visible: !chipItem.sep
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: Holidays.toggle(chipItem.modelData.k)
                    }
                    Accessible.role: Accessible.CheckBox
                    Accessible.checked: chipItem.on
                    Accessible.name: chipItem.modelData.t || ""
                }
            }
            NavButton {
                visible: !Holidays.isDefault
                label: "Reset"
                name: "Back to the default filters"
                height: 24
                onClicked: Holidays.resetFilters()
            }
        }

        // ── The body: scrolls past the screen's height, the header and filters stay ──
        Flickable {
            id: body
            Layout.fillWidth: true
            Layout.preferredHeight: Math.min(bodyRow.implicitHeight, Math.max(240, cal.availH - 2 * cal.pad - 110))
            contentWidth: width
            contentHeight: bodyRow.implicitHeight
            clip: true
            boundsBehavior: Flickable.StopAtBounds

            GridLayout {
                id: bodyRow
                width: body.width
                columns: cal.wide ? 2 : 1
                columnSpacing: Theme.sp6
                rowSpacing: Theme.sp4

                // The year, or one month focused.
                Item {
                    Layout.preferredWidth: cal.gridW
                    Layout.alignment: Qt.AlignTop
                    implicitHeight: cal.focusMonth > 0 ? bigMonth.implicitHeight : yearGrid.implicitHeight
                    GridLayout {
                        id: yearGrid
                        visible: cal.focusMonth === 0
                        width: cal.gridW
                        columns: cal.cols
                        columnSpacing: cal.colGap
                        rowSpacing: Theme.sp3
                        Repeater {
                            model: 12
                            delegate: Rectangle {
                                id: mBox
                                required property int index
                                readonly property bool isNow: cal.year === cal.bar.calYear && mBox.index + 1 === cal.bar.calTodayM
                                Layout.preferredWidth: cal.monthW
                                Layout.alignment: Qt.AlignTop
                                implicitHeight: mBlock.implicitHeight + Theme.sp2 * 2
                                radius: Theme.radiusSurface
                                // The current month is a surface of its own, no border.
                                color: mBox.isNow ? Theme.colNowPanel : "transparent"
                                MonthBlock {
                                    id: mBlock
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    y: Theme.sp2
                                    year: cal.year
                                    month: mBox.index + 1
                                    map: cal.map
                                    cellW: cal.cellW
                                    cellH: cal.cellH
                                    isNow: mBox.isNow
                                    today: cal.todayIso
                                    selected: cal.selected
                                    host: cal.bar
                                    onTitleClicked: cal.focusOn(mBox.index + 1, "")
                                    onDayClicked: iso => cal.focusOn(mBox.index + 1, iso)
                                }
                            }
                        }
                    }
                    MonthBlock {
                        id: bigMonth
                        visible: cal.focusMonth > 0
                        anchors.horizontalCenter: parent.horizontalCenter
                        year: cal.year
                        month: Math.max(1, cal.focusMonth)
                        map: cal.map
                        big: true
                        cellW: cal.bigW
                        cellH: cal.bigH
                        today: cal.todayIso
                        selected: cal.selected
                        host: cal.bar
                        onDayClicked: iso => cal.selected = iso
                    }
                }

                // The side: the selected day once a month is focused, the upcoming events otherwise.
                ColumnLayout {
                    Layout.preferredWidth: cal.wide ? cal.sideW : cal.gridW
                    Layout.alignment: Qt.AlignTop
                    spacing: Theme.sp3
                    DayDetail {
                        visible: cal.focusMonth > 0 && cal.selected !== ""
                        Layout.fillWidth: true
                        iso: cal.selected
                        events: cal.map[cal.selected.slice(5)] || []
                        hidden: (cal.allMap[cal.selected.slice(5)] || []).length - (cal.map[cal.selected.slice(5)] || []).length
                        host: cal.bar
                    }
                    Text {
                        visible: cal.focusMonth === 0
                        text: "Upcoming"
                        color: Theme.colText
                        font.family: Theme.uiFont
                        font.pixelSize: Theme.fontTitle
                        font.bold: true
                    }
                    Repeater {
                        model: cal.focusMonth === 0 ? Holidays.upcoming(cal.bar.calYear, cal.bar.calTodayM, cal.bar.calTodayD, 8, Holidays.filters) : []
                        delegate: Rectangle {
                            id: up
                            required property var modelData
                            readonly property var o: up.modelData
                            readonly property int n: Holidays.daysBetween(cal.todayIso, up.o.date)
                            Layout.fillWidth: true
                            implicitHeight: upRow.implicitHeight + Theme.sp1 * 2
                            radius: Theme.radiusControl
                            color: upArea.containsMouse ? Theme.colHoverFill : "transparent"
                            RowLayout {
                                id: upRow
                                anchors.left: parent.left
                                anchors.right: parent.right
                                anchors.verticalCenter: parent.verticalCenter
                                anchors.margins: Theme.sp1
                                spacing: Theme.sp2
                                Rectangle {
                                    Layout.fillHeight: true
                                    implicitWidth: 3
                                    radius: 1.5
                                    color: cal.bar.scopeColor(Holidays.scopeOf(up.o))
                                }
                                ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: 0
                                    Text {
                                        Layout.fillWidth: true
                                        text: up.o.display
                                        color: Theme.colText
                                        font.family: Theme.uiFont
                                        font.pixelSize: Theme.fontBody
                                        font.bold: Holidays.classOf(up.o) === "holiday"
                                        elide: Text.ElideRight
                                    }
                                    Text {
                                        Layout.fillWidth: true
                                        text: up.o.date.slice(8, 10) + "/" + up.o.date.slice(5, 7) + " · " + Holidays.kindWord(up.o) + " · " + Holidays.scopeNames[Holidays.scopeOf(up.o)] + (up.o.applicability.indexOf("general") < 0 && Holidays.classOf(up.o) !== "observance" ? " · " + Holidays.forWhom(up.o) : "")
                                        color: Theme.colDim
                                        font.family: Theme.uiFont
                                        font.pixelSize: Theme.fontSmall
                                        elide: Text.ElideRight
                                    }
                                }
                                ColumnLayout {
                                    spacing: 0
                                    Text {
                                        Layout.alignment: Qt.AlignRight
                                        text: up.n <= 0 ? "today" : (up.n === 1 ? "tomorrow" : "in " + up.n + " d")
                                        color: Theme.colSky
                                        font.family: Theme.uiFont
                                        font.pixelSize: Theme.fontSmall
                                        font.bold: true
                                    }
                                    Text {
                                        visible: up.o.status !== "verified"
                                        Layout.alignment: Qt.AlignRight
                                        text: up.o.status
                                        color: Theme.colWarn
                                        font.family: Theme.uiFont
                                        font.pixelSize: Theme.fontMicro
                                    }
                                }
                            }
                            MouseArea {
                                id: upArea
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    cal.viewYear = +up.o.date.slice(0, 4) === cal.bar.calYear ? 0 : +up.o.date.slice(0, 4);
                                    cal.focusOn(+up.o.date.slice(5, 7), up.o.date);
                                }
                            }
                        }
                    }
                }
            }
        }

        // ── The legend: what each signal means, in a line that wraps on a narrow screen ──
        Flow {
            Layout.fillWidth: true
            spacing: Theme.sp4
            Repeater {
                model: [
                    {
                        t: "Brasil",
                        k: "br"
                    },
                    {
                        t: "São Paulo",
                        k: "sp"
                    },
                    {
                        t: "São Carlos",
                        k: "sc"
                    },
                    {
                        t: "International",
                        k: "un"
                    },
                    {
                        t: "Holiday: filled",
                        k: "fill"
                    },
                    {
                        t: "Optional or restricted: outlined",
                        k: "line"
                    },
                    {
                        t: "Observance: dot",
                        k: "dot"
                    },
                    {
                        t: "Today: ring",
                        k: "ring"
                    },
                    {
                        t: "More than one: corner dot",
                        k: "multi"
                    }
                ]
                delegate: Row {
                    id: lg
                    required property var modelData
                    spacing: Theme.sp1
                    Rectangle {
                        anchors.verticalCenter: parent.verticalCenter
                        width: lg.modelData.k === "dot" || lg.modelData.k === "multi" ? 6 : 14
                        height: lg.modelData.k === "dot" || lg.modelData.k === "multi" ? 6 : 12
                        radius: lg.modelData.k === "dot" || lg.modelData.k === "multi" ? 3 : 4
                        readonly property bool scope: ["br", "sp", "sc", "un"].indexOf(lg.modelData.k) >= 0
                        color: scope ? cal.bar.scopeColor(lg.modelData.k) : (lg.modelData.k === "fill" ? Theme.colSubtext : (lg.modelData.k === "dot" ? Theme.colTeal : (lg.modelData.k === "multi" ? Theme.colText : "transparent")))
                        border.width: lg.modelData.k === "line" ? 1.5 : (lg.modelData.k === "ring" ? 2 : 0)
                        border.color: lg.modelData.k === "ring" ? Theme.colAccent : Theme.colSubtext
                    }
                    Text {
                        text: lg.modelData.t
                        color: Theme.colDim
                        font.family: Theme.uiFont
                        font.pixelSize: Theme.fontSmall
                    }
                }
            }
        }
    }
}
