// The bar's LEFT region: this monitor's workspaces, the focused window's title, then the media.
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

    // In order: media from 220 down to 120, media to its icon, then the title (a floor of 120,
    // under which it hides). The workspaces never fold. A song or a focus change never flips a level.
    readonly property int titleMin: 240
    readonly property bool mediaHere: !left.bar.compact && left.host.spHasPlayer
    readonly property int avail: left.room - wsStrip.implicitWidth - Theme.barGap - (left.mediaHere ? Theme.barGap : 0)
    readonly property int mediaIconW: Theme.barCellWidth(Math.ceil(tmMediaIcon.advanceWidth))
    readonly property int mediaW: !left.mediaHere ? 0 : Math.max(left.mediaIconW, Math.min(220, left.avail - left.titleMin))
    readonly property bool mediaIconOnly: left.mediaHere && left.mediaW < 120
    readonly property int mediaUsed: !left.mediaHere ? 0 : (left.mediaIconOnly ? left.mediaIconW : left.mediaW)
    readonly property int titleMax: Math.min(520, left.avail - left.mediaUsed)

    spacing: Theme.barGap

    TextMetrics {
        id: tmTitle
        font.family: Theme.uiFont
        font.pixelSize: Theme.fontBody
        font.italic: true
        text: left.host.winTitle
    }
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
        id: winPill
        visible: left.monitor === left.host.focusedMon && left.host.winTitle !== "" && left.titleMax >= 120
        label: left.host.winTitle
        accent: Theme.colSky
        italic: true
        leftAligned: true
        maxWidth: left.titleMax
        // In 64 px steps from the text's own metrics, so a focus change rarely moves the media.
        Layout.preferredWidth: Math.min(left.titleMax, Math.max(120, Math.ceil(Theme.barCellWidth(tmTitle.advanceWidth + 1) / 64) * 64))
        onHoveredChanged: left.host.hoverHint("win", winPill, left.barContent, left.bar, hovered)
    }
    Pill {
        id: spPill
        visible: left.mediaHere
        icon: "music_note"
        label: left.mediaIconOnly ? "" : left.host.spText
        accent: left.host.spColor
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
