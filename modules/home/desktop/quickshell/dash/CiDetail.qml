// The card of ONE repo, opened from a CI row: every workflow (or pipeline ref) with what triggered
// it, who, when, how long, and for a failure the job and step that broke. A click on an entry opens
// that run in the browser; the arrow goes back to the list.
import QtQuick
import QtQuick.Layouts
import "root:/"

ColumnLayout {
    id: card

    property var group: null
    property string label: ""
    signal back

    spacing: 10
    clip: true

    function stateGlyph(s) {
        return s === "success" ? "󰗠" : s === "failure" ? "󰅙" : s === "running" ? "󰑮" : s === "queued" ? "󰅐" : s === "cancelled" ? "󰜺" : "󰙢";
    }
    function stateColor(s) {
        return s === "success" ? Theme.colGreen : s === "failure" ? Theme.colRed : s === "running" ? Theme.colYellow : Theme.colDim;
    }

    // ── Header: back, the repo, and how many runs the card holds ──
    RowLayout {
        Layout.fillWidth: true
        Layout.preferredHeight: 34
        spacing: 12

        PageArrow {
            Layout.alignment: Qt.AlignVCenter
            glyph: "‹"
            onClicked: card.back()
        }
        Text {
            Layout.fillWidth: true
            text: card.label
            color: Theme.colText
            font.family: Theme.uiFont
            font.pixelSize: 17
            font.bold: true
            elide: Text.ElideRight
        }
        Text {
            text: card.group ? card.group.runs.length + (card.group.runs.length === 1 ? " run" : " runs") : ""
            color: Theme.colDim
            font.family: Theme.uiFont
            font.pixelSize: 13
        }
    }

    Repeater {
        model: card.group ? card.group.runs : []

        delegate: Item {
            id: entry
            required property var modelData
            readonly property var r: entry.modelData
            readonly property bool live: entry.r.state === "running" || entry.r.state === "queued"

            Layout.fillWidth: true
            implicitHeight: body.implicitHeight + 12

            Rectangle {
                anchors.fill: parent
                radius: 8
                color: entryArea.containsMouse ? Theme.colHoverBgAccent : Theme.colGroupBg
                border.width: 1
                border.color: entry.r.state === "failure" ? Qt.rgba(Theme.colRed.r, Theme.colRed.g, Theme.colRed.b, 0.45) : Theme.colGroupBorder
            }

            ColumnLayout {
                id: body
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                anchors.leftMargin: 10
                anchors.rightMargin: 10
                spacing: 2

                // State, name and branch, with the duration on the right.
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8
                    Text {
                        text: card.stateGlyph(entry.r.state)
                        color: card.stateColor(entry.r.state)
                        font.family: Theme.uiFont
                        font.pixelSize: 15
                    }
                    Text {
                        Layout.fillWidth: true
                        text: entry.r.name + (entry.r.ref && entry.r.ref !== entry.r.name ? "  @" + entry.r.ref : "")
                        color: Theme.colText
                        font.family: Theme.uiFont
                        font.pixelSize: 14
                        font.bold: true
                        elide: Text.ElideRight
                    }
                    Text {
                        text: Ci.dur(entry.r.started, entry.r.finished, entry.live)
                        color: entry.live ? Theme.colYellow : Theme.colSubtext
                        font.family: Theme.uiFont
                        font.pixelSize: 13
                    }
                }
                // What triggered it.
                Text {
                    Layout.fillWidth: true
                    visible: text !== ""
                    text: entry.r.title || ""
                    color: Theme.colSubtext
                    font.family: Theme.uiFont
                    font.pixelSize: 13
                    elide: Text.ElideRight
                }
                // How, who and when; the attempt only when it is a re-run.
                Text {
                    Layout.fillWidth: true
                    text: [entry.r.event, entry.r.actor, Ci.ago(entry.r.created) + (Ci.ago(entry.r.created) === "now" ? "" : " ago"), entry.r.attempt > 1 ? "attempt " + entry.r.attempt : ""].filter(x => x).join("  ·  ")
                    color: Theme.colDim
                    font.family: Theme.uiFont
                    font.pixelSize: 12
                    elide: Text.ElideRight
                }
                // What broke: the first failed job and its step (GitLab: stage and reason).
                Text {
                    Layout.fillWidth: true
                    visible: !!entry.r.failure
                    text: entry.r.failure ? "󰅙  " + entry.r.failure.job + (entry.r.failure.step ? "  ›  " + entry.r.failure.step : "") : ""
                    color: Theme.colRed
                    font.family: Theme.uiFont
                    font.pixelSize: 12
                    font.bold: true
                    elide: Text.ElideRight
                }
            }

            MouseArea {
                id: entryArea
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: Qt.openUrlExternally(entry.r.url)
            }
        }
    }

    Item {
        Layout.fillHeight: true
    }
}
