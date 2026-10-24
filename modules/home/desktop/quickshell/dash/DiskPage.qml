// The DISK page of the rotating column: how full the NVMe and the games disk are right now, what
// grew since the last weekly snapshot and the heaviest paths, all from glance-feed's `disk`
// document (df live, sizes from disk-insight's weekly trend, never a du): docs/notes/desktop/dash.md
import QtQuick
import QtQuick.Layouts
import "root:/"

ColumnLayout {
    id: disk

    readonly property var doc: feed.data || ({})
    readonly property var filesystems: disk.doc.filesystems || []
    readonly property var grew: disk.doc.grew || []
    readonly property var heaviest: (disk.doc.top || []).slice(0, 5)
    readonly property real topMax: disk.heaviest.length ? disk.heaviest[0].gib : 1
    readonly property string since: disk.doc.trend_date ? disk.doc.trend_date.slice(8, 10) + "/" + disk.doc.trend_date.slice(5, 7) : "?"

    spacing: 14

    Feed {
        id: feed
        name: "disk"
    }

    function gib(b) {
        return Math.round(b / 1073741824);
    }
    // Past 90% is red, as on the DISK tile; past 75% a warning, while there is still room to choose.
    function tone(frac) {
        return frac >= 0.9 ? Theme.colRed : frac >= 0.75 ? Theme.colPeach : Theme.colGreen;
    }

    // ── 1. One bar per disk, the free space in GiB because what matters is whether the next thing fits ──
    Repeater {
        model: disk.filesystems
        delegate: ColumnLayout {
            id: fs
            required property var modelData
            readonly property real frac: fs.modelData.size ? fs.modelData.used / fs.modelData.size : 0
            Layout.fillWidth: true
            spacing: 6
            RowLayout {
                Layout.fillWidth: true
                Text {
                    Layout.fillWidth: true
                    elide: Text.ElideMiddle
                    text: fs.modelData.mount === "/" ? "NVMe  ·  /" : "Games  ·  " + fs.modelData.mount
                    color: Theme.colText
                    font.family: Theme.uiFont
                    font.pixelSize: 14
                    font.bold: true
                }
                Text {
                    text: disk.gib(fs.modelData.avail) + " GiB free  ·  " + Math.round(100 * fs.frac) + "%"
                    color: disk.tone(fs.frac)
                    font.family: Theme.uiFont
                    font.pixelSize: 13
                    font.bold: true
                }
            }
            Rectangle {
                Layout.fillWidth: true
                implicitHeight: 8
                radius: 4
                color: Theme.colGroupBg
                border.width: 1
                border.color: Theme.colGroupBorder
                Rectangle {
                    width: parent.width * fs.frac
                    height: parent.height
                    radius: 4
                    color: disk.tone(fs.frac)
                }
            }
        }
    }

    // ── 2. What grew since the last weekly snapshot: the thing to act on, ahead of the ranking ──
    Text {
        Layout.topMargin: 4
        text: "GREW SINCE " + disk.since
        color: Theme.colSubtext
        font.family: Theme.uiFont
        font.pixelSize: 11
        font.bold: true
    }
    Text {
        visible: disk.grew.length === 0
        Layout.topMargin: -8
        text: "nothing grew past 1 GiB"
        color: Theme.colDim
        font.family: Theme.uiFont
        font.pixelSize: 12
    }
    Repeater {
        model: disk.grew.slice(0, 3)
        delegate: RowLayout {
            id: g
            required property var modelData
            Layout.fillWidth: true
            Layout.topMargin: -8
            Text {
                Layout.preferredWidth: 72
                horizontalAlignment: Text.AlignRight
                text: (g.modelData.gib > 0 ? "+" : "") + g.modelData.gib.toFixed(1) + " GiB"
                color: g.modelData.gib > 0 ? Theme.colPeach : Theme.colGreen
                font.family: Theme.uiFont
                font.pixelSize: 12
                font.bold: true
            }
            Text {
                Layout.fillWidth: true
                elide: Text.ElideMiddle
                text: g.modelData.path
                color: Theme.colText
                font.family: Theme.uiFont
                font.pixelSize: 12
            }
        }
    }

    // ── 3. The heaviest paths, a bar each relative to the biggest; the date says how old the sizes are ──
    Text {
        Layout.topMargin: 4
        text: "HEAVIEST  ·  " + disk.since
        color: Theme.colSubtext
        font.family: Theme.uiFont
        font.pixelSize: 11
        font.bold: true
    }
    Repeater {
        model: disk.heaviest
        delegate: Item {
            id: t
            required property var modelData
            Layout.fillWidth: true
            Layout.topMargin: -8
            implicitHeight: 18
            Rectangle {
                width: parent.width * (t.modelData.gib / disk.topMax)
                height: parent.height
                radius: 4
                color: Theme.colGroupBg
                border.width: 1
                border.color: Theme.colGroupBorder
            }
            Text {
                anchors.left: parent.left
                anchors.leftMargin: 6
                anchors.right: size.left
                anchors.verticalCenter: parent.verticalCenter
                elide: Text.ElideMiddle
                text: t.modelData.path
                color: Theme.colText
                font.family: Theme.uiFont
                font.pixelSize: 12
            }
            Text {
                id: size
                anchors.right: parent.right
                anchors.rightMargin: 6
                anchors.verticalCenter: parent.verticalCenter
                text: Math.round(t.modelData.gib) + " GiB"
                color: Theme.colSubtext
                font.family: Theme.uiFont
                font.pixelSize: 12
            }
        }
    }

    // ── 4. Snapshots: what no du can see, and the one tool that can ──
    Text {
        Layout.topMargin: 4
        Layout.fillWidth: true
        elide: Text.ElideRight
        text: "󰋊  " + (disk.doc.snapshots || 0) + " btrbk snapshots  ·  what they hold: sudo btdu /"
        color: Theme.colDim
        font.family: Theme.uiFont
        font.pixelSize: 12
    }

    Item {
        Layout.fillHeight: true
    }
}
