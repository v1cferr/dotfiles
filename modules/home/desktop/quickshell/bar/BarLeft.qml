// The bar's LEFT region: this monitor's workspaces, the focused app's name, then the media.
// It folds by priority from the room it is given, never from a text: docs/notes/desktop/bar.md
import QtQuick
import QtQuick.Layouts
import "root:/"
import "root:/widgets"

RowLayout {
    id: left
    required property var host // the Bar's Scope
    required property var bar // this monitor's bar window
    required property var barContent
    property int room: 0 // what this region may fill, from the screen's width alone
    readonly property string monitor: left.bar.modelData ? left.bar.modelData.name : ""

    // In order: media from 220 down to 120, media to its icon, then the app's name (a floor of 120,
    // under which it hides). The workspaces never fold. A song or a focus change never flips a level.
    readonly property int titleMin: 240
    // With the island up the track is announced there, and its controls are in the Control Center.
    readonly property bool mediaHere: !left.bar.compact && Media.hasPlayer && !Island.live
    readonly property int avail: left.room - wsStrip.implicitWidth - Theme.barGap - (left.mediaHere ? Theme.barGap : 0)
    readonly property int mediaIconW: Theme.barCellWidth(Math.ceil(tmMediaIcon.advanceWidth))
    readonly property int mediaW: !left.mediaHere ? 0 : Math.max(left.mediaIconW, Math.min(220, left.avail - left.titleMin))
    readonly property bool mediaIconOnly: left.mediaHere && left.mediaW < 120
    readonly property int mediaUsed: !left.mediaHere ? 0 : (left.mediaIconOnly ? left.mediaIconW : left.mediaW)
    readonly property int titleMax: Math.min(520, left.avail - left.mediaUsed)

    spacing: Theme.barGap

    TextMetrics {
        id: tmMediaIcon
        font.family: Theme.iconFont
        font.pixelSize: Theme.iconSymbol
        text: "music_note"
    }
    WorkspaceStrip {
        id: wsStrip
        host: left.host
        monitor: left.monitor
        maxApps: left.bar.compact ? 2 : 3
        barContent: left.barContent
        barWindow: left.bar
    }
    Pill {
        // The focused app's NAME; the window's full title is one hover away, in the hint.
        id: winPill
        visible: left.monitor === left.host.focusedMon && left.host.appName !== "" && left.titleMax >= 120
        label: left.host.appName
        labelColor: Theme.colText
        bold: true
        maxWidth: left.titleMax
        onHoveredChanged: left.host.hoverHint("win", winPill, left.barContent, left.bar, hovered)
    }
    Pill {
        id: spPill
        visible: left.mediaHere
        icon: "music_note"
        label: left.mediaIconOnly ? "" : Media.line
        accent: Theme.colSubtext
        labelColor: Theme.colSubtext
        off: !Media.playing
        maxWidth: left.mediaUsed
        onHoveredChanged: left.host.hoverHint("music", spPill, left.barContent, left.bar, hovered)
        onClicked: {
            left.host.closePanels();
            left.host.hideHint();
            left.host.anchorPopover(spPill, left.barContent, left.bar);
            left.host.launch(["qs", "ipc", "call", "mpris", "toggleAt", "" + left.host.popLeft(360)]);
        }
        onRightClicked: left.host.launch(["playerctl", "--player=spotifast", "play-pause"])
        onScrolledUp: left.host.launch(["playerctl", "--player=spotifast", "next"])
        onScrolledDown: left.host.launch(["playerctl", "--player=spotifast", "previous"])
    }
}
