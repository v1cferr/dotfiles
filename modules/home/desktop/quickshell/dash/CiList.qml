// One CI page of the band: a tally, then one row per repo with its worst state, newest first. A
// click opens that repo's card (CiDetail.qml) in place. Rows that do not fit are dropped, never squeezed.
import QtQuick
import QtQuick.Layouts
import "root:/"

ColumnLayout {
    id: list

    property var source: ({
            ok: false,
            error: "loading",
            runs: []
        })
    property string emptyText: "nothing ran in the last 7 days"
    property var errorText: ({})
    // Owner/ prefixes that add nothing on this page (the account's own name).
    property var dropOwners: []
    // True while the pointer is over the column (Dashboard's HoverHandler): an open card stays.
    property bool held: false

    // The card is kept by NAME, so a refresh of the feed keeps it open on fresh data.
    property string openRepo: ""
    readonly property var openGroup: list.groups.find(g => g.repo === list.openRepo) || null
    readonly property bool detailOpen: list.openGroup !== null

    readonly property var runs: list.source.runs || []
    // ONE row per repo: five green workflows of the same repo were five rows saying one thing.
    // The row wears its worst state, and the runs arrive newest first, so the order holds.
    readonly property var groups: {
        const rank = {
            failure: 0,
            running: 1,
            queued: 2,
            cancelled: 3,
            skipped: 4,
            success: 5
        };
        const out = [];
        const at = ({});
        for (let i = 0; i < list.runs.length; i++) {
            const r = list.runs[i];
            if (at[r.repo] === undefined) {
                at[r.repo] = out.length;
                out.push({
                    repo: r.repo,
                    state: r.state,
                    created: r.created,
                    lead: r,
                    runs: []
                });
            }
            const g = out[at[r.repo]];
            g.runs.push(r);
            if (rank[r.state] < rank[g.state]) {
                g.state = r.state;
                g.lead = r; // the row tells what is wrong, not what is newest
            }
        }
        return out;
    }
    readonly property int rowH: 62
    readonly property int fits: Math.max(1, Math.floor((list.height - 34) / list.rowH))

    spacing: 0

    function tally(state) {
        return list.runs.filter(r => r.state === state).length;
    }
    function stateGlyph(s) {
        return s === "success" ? "󰗠" : s === "failure" ? "󰅙" : s === "running" ? "󰑮" : s === "queued" ? "󰅐" : s === "cancelled" ? "󰜺" : "󰙢";
    }
    function stateColor(s) {
        return s === "success" ? Theme.colGreen : s === "failure" ? Theme.colRed : s === "running" ? Theme.colYellow : Theme.colDim;
    }
    function shortRepo(r) {
        for (let i = 0; i < list.dropOwners.length; i++)
            if (r.indexOf(list.dropOwners[i] + "/") === 0)
                return r.slice(list.dropOwners[i].length + 1);
        return r;
    }

    // ── The tally: what failed is what the glance is for, so it leads ──
    RowLayout {
        Layout.fillWidth: true
        Layout.preferredHeight: 34
        spacing: 18
        visible: list.source.ok && list.runs.length > 0 && !list.detailOpen

        Repeater {
            model: ["failure", "running", "queued", "success"]
            delegate: Text {
                required property string modelData
                readonly property int n: list.tally(modelData)
                visible: n > 0 || modelData === "failure"
                text: list.stateGlyph(modelData) + "  " + n
                color: n > 0 ? list.stateColor(modelData) : Theme.colDim
                font.family: Theme.uiFont
                font.pixelSize: 16
                font.bold: n > 0
            }
        }
        Item {
            Layout.fillWidth: true
        }
        // Fed by the pipeline hook instead of the API: live, but only what GitLab has pushed so far.
        Text {
            visible: list.source.via === "webhook" && list.source.stale !== true
            text: "󱂛  webhook"
            color: Theme.colDim
            font.family: Theme.uiFont
            font.pixelSize: 13
        }
        // A served-from-cache page says so, and how old it is: stale must never pass for live.
        Text {
            visible: list.source.stale === true
            text: "󰖪  offline · " + Ci.agoSec(list.source.staleSince)
            color: Theme.colPeach
            font.family: Theme.uiFont
            font.pixelSize: 13
        }
    }

    // ── The rows ──
    Repeater {
        model: list.source.ok && !list.detailOpen ? list.groups.slice(0, list.fits) : []

        delegate: Item {
            id: row
            required property var modelData
            Layout.fillWidth: true
            Layout.preferredHeight: list.rowH

            Rectangle {
                anchors.fill: parent
                anchors.topMargin: 2
                anchors.bottomMargin: 2
                radius: 8
                color: rowArea.containsMouse ? Theme.colHoverBgAccent : "transparent"
            }

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 8
                anchors.rightMargin: 8
                spacing: 12

                Text {
                    id: glyph
                    text: list.stateGlyph(row.modelData.state)
                    color: list.stateColor(row.modelData.state)
                    font.family: Theme.uiFont
                    font.pixelSize: 20

                    // Only a live run breathes, so motion itself means "still going".
                    SequentialAnimation on opacity {
                        running: row.modelData.state === "running"
                        loops: Animation.Infinite
                        NumberAnimation {
                            to: 0.35
                            duration: 700
                            easing.type: Easing.InOutSine
                        }
                        NumberAnimation {
                            to: 1
                            duration: 700
                            easing.type: Easing.InOutSine
                        }
                    }
                }
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 0
                    Text {
                        Layout.fillWidth: true
                        text: list.shortRepo(row.modelData.repo)
                        color: Theme.colText
                        font.family: Theme.uiFont
                        font.pixelSize: 15
                        font.bold: true
                        elide: Text.ElideRight
                    }
                    // What triggered the run that leads the row: the commit or PR title.
                    Text {
                        Layout.fillWidth: true
                        text: row.modelData.lead.title || ""
                        color: Theme.colSubtext
                        font.family: Theme.uiFont
                        font.pixelSize: 13
                        elide: Text.ElideRight
                    }
                    // Each workflow as a tinted name, so the one that broke is found without a click.
                    Item {
                        Layout.fillWidth: true
                        implicitHeight: 16
                        clip: true
                        Row {
                            spacing: 12
                            Repeater {
                                model: row.modelData.runs
                                delegate: Text {
                                    required property var modelData
                                    text: modelData.name + (modelData.ref && modelData.ref !== modelData.name && ["main", "master", "nixos"].indexOf(modelData.ref) < 0 ? " @" + modelData.ref : "")
                                    color: modelData.state === "success" ? Theme.colDim : list.stateColor(modelData.state)
                                    font.family: Theme.uiFont
                                    font.pixelSize: 12
                                }
                            }
                        }
                    }
                }
                Text {
                    text: Ci.ago(row.modelData.created)
                    color: Theme.colSubtext
                    font.family: Theme.uiFont
                    font.pixelSize: 13
                }
            }
            MouseArea {
                id: rowArea
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: list.openRepo = row.modelData.repo
            }
        }
    }

    // ── The card of one repo, in place of the list ──
    CiDetail {
        Layout.fillWidth: true
        Layout.fillHeight: true
        visible: list.detailOpen
        group: list.openGroup
        label: list.openGroup ? list.shortRepo(list.openGroup.repo) : ""
        onBack: list.openRepo = ""
    }
    // An open card closes itself 20 s after the pointer leaves, so the rotation never stays parked.
    Timer {
        interval: 20000
        running: list.detailOpen && !list.held
        onTriggered: list.openRepo = ""
    }

    // ── Nothing to list: say why, in the band's own quiet voice ──
    Text {
        Layout.fillWidth: true
        Layout.topMargin: 12
        visible: !list.source.ok || list.runs.length === 0
        text: list.source.ok ? list.emptyText : (list.errorText[list.source.error] || list.source.error)
        color: Theme.colDim
        font.family: Theme.uiFont
        font.pixelSize: 14
        wrapMode: Text.WordWrap
    }

    Item {
        Layout.fillHeight: true
        visible: !list.detailOpen
    }
}
