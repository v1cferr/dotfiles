// CLAUDE CODE, always in sight: the 5 h session and the week, with their resets and the last 24 h.
// Every number and color is ClaudeUsage.qml's, so this and the page can never disagree. docs/notes/desktop/dash.md
import QtQuick
import QtQuick.Layouts
import "root:/"
import "root:/widgets"

ColumnLayout {
    id: panel
    spacing: 6

    component Limit: RowLayout {
        id: lim
        property string label
        property var win
        property color tone
        Layout.fillWidth: true
        spacing: 12
        Text {
            Layout.preferredWidth: 78
            text: lim.label
            color: Theme.colSubtext
            font.family: Theme.uiFont
            font.pixelSize: 13
            font.bold: true
            font.letterSpacing: 2
        }
        Text {
            Layout.preferredWidth: 64
            text: isNaN(lim.win.pct) ? "–" : Math.round(lim.win.pct) + "%"
            color: ClaudeUsage.color(lim.win, lim.tone)
            font.family: Theme.uiFont
            font.pixelSize: 26
            font.bold: true
        }
        Rectangle {
            Layout.fillWidth: true
            implicitHeight: 6
            radius: 3
            color: Theme.colTrack
            Rectangle {
                width: parent.width * Math.max(0, Math.min(1, (lim.win.pct || 0) / 100))
                height: parent.height
                radius: parent.radius
                color: ClaudeUsage.color(lim.win, lim.tone)
            }
        }
        Text {
            Layout.preferredWidth: 92
            horizontalAlignment: Text.AlignRight
            text: lim.win.resets ? ClaudeUsage.left(lim.win.resets) : "–"
            color: Theme.colDim
            font.family: Theme.uiFont
            font.pixelSize: 13
        }
    }

    Text {
        text: "CLAUDE CODE  ·  FAI"
        color: Theme.colSubtext
        font.family: Theme.uiFont
        font.pixelSize: 13
        font.bold: true
        font.letterSpacing: 3
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
        font.pixelSize: 13
    }
    Limit {
        visible: ClaudeUsage.ok
        label: "SESSION"
        win: ClaudeUsage.session
        tone: Theme.colPeach
    }
    Limit {
        visible: ClaudeUsage.ok
        label: "WEEK"
        win: ClaudeUsage.weekly
        tone: Theme.colMauve
    }
    // The last 24 h, the week over the session, both 0 to 100: held values, never interpolated.
    Sparkline {
        visible: ClaudeUsage.ok
        Layout.fillWidth: true
        Layout.fillHeight: true
        Layout.minimumHeight: 18
        series: ClaudeUsage.series("w")
        fill: Theme.colMauve
        placeholder: "collecting…"
    }
    Sparkline {
        visible: ClaudeUsage.ok
        Layout.fillWidth: true
        Layout.fillHeight: true
        Layout.minimumHeight: 18
        series: ClaudeUsage.series("s")
        fill: Theme.colPeach
        placeholder: ""
    }
}
