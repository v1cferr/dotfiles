// One MONTH of the calendar: its name, the week heads and the days, each day carrying separate
// signals (today a ring, a holiday a fill, an optional day an outline, an observance a dot, more
// than one event a corner dot). The year view and the focused month both draw this; `big` adds
// the event names inside the cells. The signals: docs/notes/desktop/calendar.md#the-grid
import QtQuick
import QtQuick.Layouts
import "root:/"

ColumnLayout {
    id: blk
    required property int year
    required property int month // 1-12
    required property var map   // "MM-DD" -> [occurrence], already filtered
    property int cellW: 28
    property int cellH: 26
    property bool big: false
    property bool isNow: false
    property string today: ""    // "YYYY-MM-DD"
    property string selected: "" // "YYYY-MM-DD"
    property var host: null      // the Bar's Scope: month names and the scope colors
    signal dayClicked(string iso)
    signal titleClicked

    spacing: blk.big ? Theme.sp2 : 2

    readonly property var heads: ["D", "S", "T", "Q", "Q", "S", "S"]
    readonly property int first: new Date(blk.year, blk.month - 1, 1).getDay()
    readonly property int days: new Date(blk.year, blk.month, 0).getDate()
    function iso(d) {
        return blk.year + "-" + ("0" + blk.month).slice(-2) + "-" + ("0" + d).slice(-2);
    }

    // The month's name: the way into the focused view, and the current month's pill.
    Rectangle {
        visible: !blk.big
        Layout.alignment: Qt.AlignHCenter
        implicitWidth: title.implicitWidth + 2 * Theme.sp2
        implicitHeight: title.implicitHeight + Theme.sp1
        radius: Theme.radiusControl
        color: titleArea.containsMouse ? Theme.colHoverFill : (blk.isNow ? Theme.colNowBg : "transparent")
        Text {
            id: title
            anchors.centerIn: parent
            text: blk.host ? blk.host.monthNames[blk.month - 1] : ""
            color: blk.isNow ? Theme.colAccent : Theme.colText
            font.family: Theme.uiFont
            font.pixelSize: Theme.fontLabel
            font.bold: true
        }
        MouseArea {
            id: titleArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: blk.titleClicked()
        }
        Accessible.role: Accessible.Button
        Accessible.name: "Open " + title.text
    }

    Grid {
        columns: 7
        columnSpacing: blk.big ? Theme.sp1 : 0
        rowSpacing: blk.big ? Theme.sp1 : 0
        Layout.alignment: Qt.AlignHCenter
        Repeater {
            model: 7
            Text {
                required property int index
                width: blk.cellW
                height: blk.big ? 22 : Math.round(blk.cellH * 0.75)
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
                text: blk.heads[index]
                color: Theme.colDim
                font.family: Theme.uiFont
                font.pixelSize: blk.big ? Theme.fontBody : Theme.fontSmall
                font.bold: true
            }
        }
        Repeater {
            model: blk.first
            Item {
                width: blk.cellW
                height: blk.cellH
            }
        }
        Repeater {
            model: blk.days
            Item {
                id: cell
                required property int index
                readonly property int d: cell.index + 1
                readonly property string key: blk.iso(cell.d)
                readonly property var list: blk.map[cell.key.slice(5)] || []
                readonly property var main: Holidays.primary(cell.list)
                readonly property string cls: cell.main ? Holidays.classOf(cell.main) : ""
                readonly property bool everyone: cell.main !== null && cell.main.applicability.indexOf("general") >= 0
                readonly property color tone: cell.main && blk.host ? blk.host.scopeColor(Holidays.scopeOf(cell.main)) : Theme.colText
                readonly property bool filled: cell.cls === "holiday" && cell.everyone
                readonly property bool isToday: cell.key === blk.today
                readonly property bool isSel: cell.key === blk.selected
                width: blk.cellW
                height: blk.cellH

                // Selected: a neutral fill under everything.
                Rectangle {
                    anchors.fill: parent
                    radius: Theme.radiusControl - 2
                    visible: cell.isSel || dayArea.containsMouse
                    color: cell.isSel ? Theme.colSelectFill : Theme.colHoverFill
                }
                // A holiday for everyone FILLS the chip; a restricted one or an optional day OUTLINES it.
                Rectangle {
                    id: chip
                    x: blk.big ? Theme.sp1 : Math.round((cell.width - chip.width) / 2)
                    y: blk.big ? Theme.sp1 : Math.round((cell.height - chip.height) / 2)
                    width: blk.big ? 26 : cell.width - 6
                    height: blk.big ? 22 : cell.height - 6
                    radius: 5
                    visible: cell.cls === "holiday" || cell.cls === "optional"
                    color: cell.filled ? Qt.alpha(cell.tone, 0.9) : "transparent"
                    border.width: cell.filled ? 0 : 1.5
                    border.color: cell.tone
                }
                Text {
                    x: chip.x
                    y: chip.y
                    width: chip.width
                    height: chip.height
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                    text: cell.d
                    color: cell.filled ? Theme.colBgSolid : (cell.cls === "holiday" || cell.cls === "optional" ? cell.tone : Theme.colText)
                    font.family: Theme.uiFont
                    font.pixelSize: blk.big ? Theme.fontTitle : Theme.fontBody
                    font.bold: cell.filled || cell.isToday || cell.main !== null
                }
                // An observance: a dot under the number, never a fill.
                Rectangle {
                    visible: cell.list.some(o => Holidays.classOf(o) === "observance")
                    width: 4
                    height: 4
                    radius: 2
                    x: chip.x + chip.width / 2 - 2
                    y: chip.y + chip.height - (blk.big ? 3 : 1)
                    color: Theme.colTeal
                }
                // More than one event that day: a small corner dot; the detail lists them all.
                Rectangle {
                    visible: cell.list.length > 1
                    width: 5
                    height: 5
                    radius: 2.5
                    x: chip.x + chip.width - 4
                    y: chip.y - 1
                    color: Theme.colText
                    border.color: Theme.colBgSolid
                    border.width: 1
                }
                // TODAY: a ring around the whole cell, independent of every other signal.
                Rectangle {
                    anchors.fill: parent
                    anchors.margins: 1
                    radius: Theme.radiusControl - 2
                    visible: cell.isToday
                    color: "transparent"
                    border.width: 2
                    border.color: Theme.colAccent
                }
                // The focused month names the day's events inside the cell.
                Column {
                    visible: blk.big
                    x: Theme.sp1 + 2
                    y: chip.y + chip.height + 2
                    width: cell.width - 2 * Theme.sp1
                    spacing: 1
                    Repeater {
                        model: blk.big ? cell.list.slice(0, 2) : []
                        Text {
                            required property var modelData
                            width: parent.width
                            text: modelData.display
                            color: blk.host ? blk.host.scopeColor(Holidays.scopeOf(modelData)) : Theme.colText
                            opacity: Holidays.classOf(modelData) === "observance" ? 0.8 : 1
                            font.family: Theme.uiFont
                            font.pixelSize: Theme.fontSmall
                            elide: Text.ElideRight
                        }
                    }
                    Text {
                        visible: blk.big && cell.list.length > 2
                        text: "+" + (cell.list.length - 2) + " more"
                        color: Theme.colDim
                        font.family: Theme.uiFont
                        font.pixelSize: Theme.fontMicro
                    }
                }
                MouseArea {
                    id: dayArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: blk.dayClicked(cell.key)
                }
                Accessible.role: Accessible.Button
                Accessible.name: cell.d + (cell.isToday ? ", today" : "") + (cell.list.length ? ", " + cell.list.map(o => o.display).join(", ") : "")
            }
        }
    }
}
