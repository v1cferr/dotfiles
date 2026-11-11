// One monitor's bar WINDOW: the glass strip, the logo on its center and a region on each side. The
// data and the panel coordinator stay in Bar.qml (the `host`). The rules: docs/notes/desktop/bar.md
import Quickshell
import Quickshell.Wayland
import QtQuick
import "root:/"

PanelWindow {
    id: bar
    required property var modelData
    required property var host // the Bar's Scope: the data, the panel coordinator, the IPC
    screen: modelData
    WlrLayershell.namespace: "qs-bar" // the glass blur rule matches it (appearance.lua)

    // ONE glass strip, edge to edge; its items sit bare on it, the logo on its exact center.
    anchors {
        top: true
        left: true
        right: true
    }
    implicitHeight: Theme.barHeight
    visible: !bar.host.hidden
    // On a band screen the BAR reserves the whole top share and the band draws inside it,
    // so the order the two layers map in can never stack the bar under the band.
    exclusiveZone: bar.compact && bar.screen ? Theme.bandReserve(bar.screen.height) : Theme.barHeight

    // COMPACT: a screen too narrow for the full set (the standing LG) keeps the workspaces and
    // its context on the left and the operational alerts on the right; the band has the rest.
    readonly property bool compact: bar.width < Theme.compactWidth
    color: "transparent"

    // ── The geometry: every region from the screen's width and fixed tokens, never from content ──
    // The logo sits on the screen's EXACT center: its x comes from the width alone.
    readonly property int centerX: Math.floor(bar.width / 2)
    readonly property int slotX: bar.centerX - Theme.barCenterWidth / 2
    // Where the sides stop. A center that grows one day widens these two and nothing else.
    readonly property int centerLeft: bar.slotX
    readonly property int centerRight: bar.slotX + Theme.barCenterWidth
    // An item's content, not its highlight, sits on the windows' column.
    readonly property int edge: Math.max(0, Theme.barEdge - Theme.barPad)
    readonly property int leftRoom: bar.centerLeft - bar.edge - Theme.sp4
    readonly property int rightRoom: bar.width - bar.centerRight - bar.edge - Theme.sp4
    // The clock's center, for a panel of its own opened without a pointer (IPC); the logo's otherwise.
    readonly property int clockCenterX: bar.compact ? bar.centerX : bar.width - bar.edge - right.clockW / 2

    Component.onCompleted: bar.host.registerBar(bar)
    Component.onDestruction: bar.host.unregisterBar(bar)

    // A full-width Item used as the coordinate reference for the popovers (mapToItem
    // into a real Item is reliable; mapToItem(null) is not).
    Item {
        id: barContent
        anchors.fill: parent

        // ── The surface: one frosted strip, a sheen on its top row, a hairline at its foot ──
        Rectangle {
            anchors.fill: parent
            color: Theme.colSurfaceBar
        }
        Rectangle {
            anchors.left: parent.left
            anchors.right: parent.right
            height: Theme.hairline
            color: Theme.colSheen
        }
        Rectangle {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            height: Theme.hairline
            color: Theme.colEdge
        }

        LogoSlot {
            x: bar.slotX
            host: bar.host
            barContent: barContent
            barWindow: bar
        }
        BarLeft {
            anchors.left: parent.left
            anchors.leftMargin: bar.edge
            height: parent.height
            host: bar.host
            bar: bar
            barContent: barContent
            room: bar.leftRoom
        }
        BarRight {
            id: right
            anchors.right: parent.right
            anchors.rightMargin: bar.edge
            height: parent.height
            host: bar.host
            bar: bar
            barContent: barContent
            room: bar.rightRoom
        }
    }
}
