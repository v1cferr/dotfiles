// CLAUDE CODE, always in sight: the 5 h session and the week as rings with their resets, and the last
// 24 h. Every number and color is ClaudeUsage.qml's, so this and the page cannot disagree. docs/notes/desktop/dash.md
import QtQuick
import QtQuick.Layouts
import "root:/"
import "root:/widgets"

ColumnLayout {
    id: panel
    spacing: 8

    Text {
        text: "✦  CLAUDE CODE  ·  FAI"
        color: Theme.colMauve
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
    RowLayout {
        visible: ClaudeUsage.ok
        Layout.fillWidth: true
        Layout.fillHeight: true
        spacing: 20

        Repeater {
            model: [{
                    win: ClaudeUsage.session,
                    tone: Theme.colPeach,
                    cap: "SESSION"
                }, {
                    win: ClaudeUsage.weekly,
                    tone: Theme.colMauve,
                    cap: "WEEK"
                }]
            delegate: ColumnLayout {
                required property var modelData
                spacing: 4
                Ring {
                    Layout.alignment: Qt.AlignHCenter
                    value: modelData.win.pct
                    tone: ClaudeUsage.color(modelData.win, modelData.tone)
                    caption: modelData.cap
                }
                Text {
                    Layout.alignment: Qt.AlignHCenter
                    text: modelData.win.resets ? "resets in " + ClaudeUsage.left(modelData.win.resets) : "no window"
                    color: Theme.colDim
                    font.family: Theme.uiFont
                    font.pixelSize: 12
                }
            }
        }
        // The last 24 h beside the rings: the week over the session, both 0 to 100, held, never interpolated.
        ColumnLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 4
            Text {
                text: "LAST 24 H"
                color: Theme.colDim
                font.family: Theme.uiFont
                font.pixelSize: 11
                font.bold: true
                font.letterSpacing: 3
            }
            Sparkline {
                Layout.fillWidth: true
                Layout.fillHeight: true
                series: ClaudeUsage.series("w")
                fill: Theme.colMauve
                placeholder: "collecting…"
            }
            Sparkline {
                Layout.fillWidth: true
                Layout.fillHeight: true
                series: ClaudeUsage.series("s")
                fill: Theme.colPeach
                placeholder: ""
            }
        }
    }
}
