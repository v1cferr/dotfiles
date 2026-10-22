// The CLAUDE page of the rotating column: the FAI account's session and weekly limits, one clear
// block each (what it is, how much is used, when it renews), and the week as one picture. The
// per-model shares and the plan live in the blocks' tip. All from ClaudeUsage.qml: docs/notes/desktop/dash.md
import QtQuick
import QtQuick.Layouts
import "root:/"
import "root:/widgets"

ColumnLayout {
    id: page
    spacing: 18

    // When a window renews, as the clock will show it: today's hour, or the weekday and the hour.
    function renews(t) {
        if (!t)
            return "";
        const d = new Date(t * 1000), now = new Date();
        const sameDay = d.toDateString() === now.toDateString();
        return "renews " + Qt.formatDateTime(d, sameDay ? "HH:mm" : "ddd HH:mm") + "  ·  in " + ClaudeUsage.left(t);
    }
    // What the tip adds: the models' shares of the week, the plan, extra usage.
    readonly property var details: ClaudeUsage.scoped.map(s => s.label + " " + Math.round(s.pct || 0) + "% of the week").concat([ClaudeUsage.plan, ClaudeUsage.extra.enabled ? "extra usage on" : "extra usage off"].filter(x => x))

    // One limit, three lines: what it is and how much is used; the bar; when it renews.
    component Meter: Item {
        id: m
        property string label
        property string period
        property var win
        property color tone: Theme.colPeach
        Layout.fillWidth: true
        implicitHeight: col.implicitHeight
        Tip {
            title: m.label.toLowerCase() + " limit"
            lines: [m.win.resets ? "renews " + new Date(m.win.resets * 1000).toLocaleString(Qt.locale(), "ddd dd/MM HH:mm") : "no active window"].concat(page.details)
        }
        ColumnLayout {
            id: col
            anchors.left: parent.left
            anchors.right: parent.right
            spacing: 6
            RowLayout {
                Layout.fillWidth: true
                spacing: 10
                Text {
                    text: m.label
                    color: Theme.colText
                    font.family: Theme.uiFont
                    font.pixelSize: 15
                    font.bold: true
                }
                Text {
                    text: m.period
                    color: Theme.colDim
                    font.family: Theme.uiFont
                    font.pixelSize: 13
                }
                Item {
                    Layout.fillWidth: true
                }
                Text {
                    text: isNaN(m.win.pct) ? "–" : Math.round(m.win.pct) + "% used"
                    color: ClaudeUsage.color(m.win, m.tone)
                    font.family: Theme.uiFont
                    font.pixelSize: 22
                    font.bold: true
                }
            }
            Rectangle {
                Layout.fillWidth: true
                implicitHeight: 8
                radius: 4
                color: Theme.colTrack
                Rectangle {
                    width: parent.width * Math.max(0, Math.min(1, (m.win.pct || 0) / 100))
                    height: parent.height
                    radius: parent.radius
                    color: ClaudeUsage.color(m.win, m.tone)
                    Behavior on width {
                        NumberAnimation {
                            duration: Theme.motionSlow
                            easing.type: Easing.OutCubic
                        }
                    }
                }
            }
            Text {
                text: m.win.resets ? page.renews(m.win.resets) : "idle: no window open"
                color: Theme.colSubtext
                font.family: Theme.uiFont
                font.pixelSize: 13
            }
        }
    }

    Text {
        visible: !ClaudeUsage.ok
        Layout.fillWidth: true
        wrapMode: Text.WordWrap
        text: ({
                "no-credentials": "No Claude login for the FAI account yet: run claude-fai once.",
                loading: "loading…"
            })[ClaudeUsage.error] || ClaudeUsage.error
        color: Theme.colDim
        font.family: Theme.uiFont
        font.pixelSize: 14
    }

    Meter {
        visible: ClaudeUsage.ok
        label: "Session"
        period: "5-hour window"
        win: ClaudeUsage.session
    }
    Meter {
        visible: ClaudeUsage.ok
        label: "Week"
        period: "7-day limit"
        tone: Theme.colMauve
        win: ClaudeUsage.weekly
    }

    // The week as one picture: the share used as a step line across the limit's own week.
    ColumnLayout {
        visible: ClaudeUsage.ok
        Layout.fillWidth: true
        Layout.fillHeight: true
        spacing: 6
        Text {
            text: "THIS WEEK · FROM ONE RENEWAL TO THE NEXT"
            color: Theme.colDim
            font.family: Theme.uiFont
            font.pixelSize: 12
            font.bold: true
            font.letterSpacing: 3
        }
        ClaudeWeek {
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.minimumHeight: 90
        }
    }
}
