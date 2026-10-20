// The CLAUDE page of the rotating column: the FAI account's session and weekly limits with their
// resets, the per-model shares, and the week's last 7 days. All from ClaudeUsage.qml: docs/notes/desktop/dash.md
import QtQuick
import QtQuick.Layouts
import "root:/"
import "root:/widgets"

ColumnLayout {
    id: page
    spacing: 18

    component Meter: Item {
        id: m
        property string label
        property var win
        property string resetText
        property color tone: Theme.colPeach
        Layout.fillWidth: true
        implicitHeight: row.implicitHeight
        Tip {
            title: m.label.toLowerCase() + " limit"
            lines: [m.win.resets ? "resets " + new Date(m.win.resets * 1000).toLocaleString(Qt.locale(), "ddd dd/MM HH:mm") : "no active window"]
        }
        RowLayout {
            id: row
            anchors.left: parent.left
            anchors.right: parent.right
            spacing: 16
            Text {
                Layout.preferredWidth: 110
                text: m.label
                color: Theme.colSubtext
                font.family: Theme.uiFont
                font.pixelSize: 14
                font.bold: true
                font.letterSpacing: 3
            }
            Text {
                Layout.preferredWidth: 90
                text: isNaN(m.win.pct) ? "–" : Math.round(m.win.pct) + "%"
                color: ClaudeUsage.color(m.win, m.tone)
                font.family: Theme.uiFont
                font.pixelSize: 34
                font.bold: true
                font.letterSpacing: -1
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
                Layout.preferredWidth: 150
                horizontalAlignment: Text.AlignRight
                text: m.resetText
                color: Theme.colDim
                font.family: Theme.uiFont
                font.pixelSize: 14
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
        label: "SESSION"
        win: ClaudeUsage.session
        resetText: ClaudeUsage.session.resets ? "resets in " + ClaudeUsage.left(ClaudeUsage.session.resets) : "idle"
    }
    Meter {
        visible: ClaudeUsage.ok
        label: "WEEKLY"
        tone: Theme.colMauve
        win: ClaudeUsage.weekly
        resetText: ClaudeUsage.weekly.resets ? "resets in " + ClaudeUsage.left(ClaudeUsage.weekly.resets) : ""
    }

    // The per-model shares of the week and the plan, one quiet line.
    Text {
        visible: ClaudeUsage.ok
        Layout.fillWidth: true
        elide: Text.ElideRight
        text: ClaudeUsage.scoped.map(s => s.label + " " + Math.round(s.pct || 0) + "%").concat([ClaudeUsage.plan, ClaudeUsage.extra.enabled ? "extra usage on" : "extra usage off"].filter(x => x)).join("  ·  ")
        color: Theme.colSubtext
        font.family: Theme.uiFont
        font.pixelSize: 14
    }

    // The week's last 7 days, one bar per hour on a 0 to 100 scale, each holding its value: a weekly
    // reset is the drop it was. The session is a current number above, not a second graph.
    ColumnLayout {
        visible: ClaudeUsage.ok
        Layout.fillWidth: true
        Layout.fillHeight: true
        spacing: 6
        Text {
            readonly property bool full: ClaudeUsage.historyStart <= ClaudeUsage.now - 7 * 86400 + 3600
            text: full ? "WEEK · LAST 7 DAYS" : "WEEK · SINCE " + Qt.formatDateTime(new Date(ClaudeUsage.historyStart * 1000), "dd/MM HH:mm")
            color: Theme.colDim
            font.family: Theme.uiFont
            font.pixelSize: 12
            font.bold: true
            font.letterSpacing: 3
        }
        Sparkline {
            Layout.fillWidth: true
            Layout.fillHeight: true
            series: ClaudeUsage.series("w", 7 * 86400, 3600)
            fill: Theme.colMauve
            placeholder: "collecting…"
        }
    }
}
