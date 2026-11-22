// The bar's RIGHT region, read from the edge inward: the clock, the tray, the notification state,
// then sound, VPN and network, then the alerts that show only while they need a look. The standing
// screen keeps its operational chips instead. docs/notes/desktop/bar.md
import QtQuick
import QtQuick.Layouts
import "root:/"
import "root:/widgets"

RowLayout {
    id: right
    required property var host // the Bar's Scope
    required property var bar // this monitor's bar window
    required property var barContent
    property int room: 0 // what this region may fill, from the screen's width alone

    // The tray also lands on the band screen's bar when that is the only screen left.
    readonly property bool trayHere: !right.bar.compact || !right.host.wideUp
    readonly property int trayW: right.trayHere && tray.count > 0 ? tray.stableWidth + Theme.barGap : 0
    // The clock's width from today's date and a template time: tabular digits, so no minute moves it.
    // On the clear bar the time is the strong part and the date the quiet one, a step apart.
    readonly property int clockW: Theme.barCellWidth(Math.ceil(tmClock.advanceWidth) + (Theme.barClear ? Theme.sp2 + Math.ceil(tmTime.advanceWidth) : 0))
    // And the clock stands a breath away from the status left of it.
    readonly property int clockGap: Theme.barClear ? Theme.sp2 : 0
    readonly property bool cpuPegged: right.host.cpuPct >= 90
    // What the NixOS Center holds is not said twice on the strip: the network is its icon, the VPN
    // shows only while it is up or coming up, and the sound only while muted.
    readonly property bool vpnHere: Theme.hasVpn && (right.host.vpnConnected || Object.keys(right.host.vpnPhase).length > 0)
    readonly property bool volHere: Audio.muted

    spacing: Theme.barGap

    TextMetrics {
        id: tmClock
        font.family: Theme.uiFont
        font.pixelSize: Theme.fontBody
        font.features: Theme.fontTabular
        text: Theme.barClear ? right.host.dateStr : right.host.dateStr + "  00:00"
    }
    TextMetrics {
        id: tmTime
        font.family: Theme.uiFont
        font.pixelSize: Theme.fontBody
        font.weight: Theme.weightStrong
        font.features: Theme.fontTabular
        text: "00:00"
    }
    function volSymbol() {
        if (Audio.muted || Audio.volume <= 0)
            return "volume_off";
        return Audio.volume <= 0.33 ? "volume_mute" : (Audio.volume <= 0.66 ? "volume_down" : "volume_up");
    }

    // ── The standing screen: the operational alerts, nothing the band already shows ──
    OpsIndicator {
        visible: right.bar.compact
        host: right.host
        barContent: right.barContent
        barWindow: right.bar
        maxWidth: right.room - right.trayW
    }

    // ── Alerts: here only while they need a look, left of the standing status ──
    Pill {
        // hypridle turned off by hand: nothing locks or sleeps, which must not be forgotten.
        id: idlePill
        visible: !right.bar.compact && !right.host.hypridleOn
        icon: "bedtime_off"
        accent: Theme.colWarn
        onHoveredChanged: right.host.hoverHint("idle", idlePill, right.barContent, right.bar, hovered)
        onClicked: right.host.toggleIdle()
    }
    Pill {
        // A busy CPU is not a fault: it shows only when pegged. Its panel is the answer to a hover.
        id: cpuPill
        visible: !right.bar.compact && right.cpuPegged
        icon: "speed"
        label: right.host.tab(right.host.cpuPct, 3) + "%"
        accent: Theme.colWarn
        labelColor: Theme.colWarn
        tint: Theme.colWarn
        selected: right.host.pinned === "usage"
        onHoveredChanged: right.host.hoverPanel("usage", cpuPill, right.barContent, right.bar, hovered)
        onClicked: right.host.togglePanel("usage", cpuPill, right.barContent, right.bar)
    }
    Pill {
        // Storage, ONLY when it needs a look: the root filesystem past 90% or under 20 GB
        // free (attention), past 95% or under 5 GB (critical). df every 30 s is the source.
        id: diskPill
        readonly property bool crit: right.host.diskTotal > 0 && (right.host.diskPct >= 95 || right.host.diskFree < 5 * 1073741824)
        readonly property bool shown: right.host.diskTotal > 0 && (diskPill.crit || right.host.diskPct >= 90 || right.host.diskFree < 20 * 1073741824)
        visible: !right.bar.compact && diskPill.shown
        icon: "hard_drive"
        label: right.host.diskPct + "%"
        accent: diskPill.crit ? Theme.colCrit : Theme.colWarn
        labelColor: diskPill.accent
        tint: diskPill.accent
        onHoveredChanged: right.host.hoverHint("disk", diskPill, right.barContent, right.bar, hovered)
        onClicked: right.host.togglePanel("usage", diskPill, right.barContent, right.bar)
    }

    // ── Status: network, VPN, sound. Colors follow the states catalog (Theme.qml) ──
    Pill {
        id: netPill
        visible: !right.bar.compact
        icon: "lan"
        // Neutral while the link is steady: color is for a state that needs a look.
        accent: right.host.netQuality.label === "steady" ? Theme.colSubtext : right.host.netQuality.color
        labelColor: Theme.colText
        selected: right.host.pinned === "net"
        onHoveredChanged: right.host.hoverPanel("net", netPill, right.barContent, right.bar, hovered)
        onClicked: right.host.togglePanel("net", netPill, right.barContent, right.bar)
        onRightClicked: right.host.launch(["nm-connection-editor"])
    }
    Pill {
        // VPN: click opens the actions popover, HOVER shows the statistics, right click drops everything.
        // Off by choice is neutral, never a failure. Information on hover, ACTION on click: docs/notes/desktop/bar.md
        id: vpnPill
        visible: !right.bar.compact && right.vpnHere
        icon: "shield_lock"
        accent: right.host.vpnConnected ? Theme.colText : Theme.colUnknown
        off: !right.host.vpnConnected
        // Tor rides along in its own purple: a VPN and Tor can be up at once.
        badge: (right.host.torSystem || right.host.torBisq) ? "" + (right.host.torBisq ? " Bisq" : "") : ""
        badgeColor: Theme.colLavender
        maxWidth: 190
        selected: right.host.vpnPopVisible
        onHoveredChanged: right.host.hoverPanel("vpn", vpnPill, right.barContent, right.bar, hovered)
        onClicked: {
            const open = !right.host.vpnPopVisible;
            right.host.closePanels(); // its actions menu is the one panel now
            right.host.anchorPopover(vpnPill, right.barContent, right.bar);
            right.host.vpnPopVisible = open;
            if (right.host.vpnPopVisible)
                right.host.refreshVpn(); // a fresh state when it opens
        }
        onRightClicked: right.host.runVpn("disconnect", "all")
    }
    Pill {
        id: volPill
        visible: !right.bar.compact && right.volHere
        icon: right.volSymbol()
        accent: Audio.muted ? Theme.colUnknown : Theme.colSubtext
        off: Audio.muted
        onHoveredChanged: right.host.hoverHint("vol", volPill, right.barContent, right.bar, hovered)
        onClicked: Audio.toggleMute()
        onRightClicked: right.host.launch(["pavucontrol"])
        onScrolledUp: Audio.changeVolume(0.05)
        onScrolledDown: Audio.changeVolume(-0.05)
    }

    // ── The tray, then the clock on the edge ──
    TrayStrip {
        id: tray
        visible: right.trayHere
        host: right.host
        barContent: right.barContent
        barWindow: right.bar
    }
    Pill {
        // The NixOS Center's door on this side; a scroll on it is the volume, so sound needs no item.
        id: centerPill
        visible: !right.bar.compact
        // Do Not Disturb shows HERE while it is on: the strip has no bell.
        icon: Notifs.dnd ? "do_not_disturb_on" : "tune"
        accent: Notifs.dnd ? Theme.colAlert : Theme.colBarQuiet
        selected: right.host.pinned === "center"
        onHoveredChanged: right.host.hoverHint("center", centerPill, right.barContent, right.bar, hovered)
        // The Center hangs from the logo whoever asks for it, so it opens through the service's own toggle.
        onClicked: {
            right.host.hideHint();
            Notifs.toggleCenter();
        }
        onScrolledUp: Audio.changeVolume(0.05)
        onScrolledDown: Audio.changeVolume(-0.05)
    }
    Pill {
        // Hover or click: the calendar. Right click: the weather, which left the bar for this.
        id: clockPill
        visible: !right.bar.compact
        Layout.preferredWidth: right.clockW
        Layout.leftMargin: right.clockGap
        label: Theme.barClear ? right.host.dateStr : right.host.dateStr + "  " + right.host.barTimeStr
        labelColor: Theme.colBarQuiet
        badge: Theme.barClear ? right.host.barTimeStr : ""
        badgeColor: Theme.colText
        badgeStrong: true
        gap: Theme.sp2
        selected: right.host.pinned === "cal" || right.host.pinned === "weather"
        onHoveredChanged: right.host.hoverPanel("cal", clockPill, right.barContent, right.bar, hovered)
        onClicked: right.host.togglePanel("cal", clockPill, right.barContent, right.bar)
        onRightClicked: if (right.host.wHas)
            right.host.togglePanel("weather", clockPill, right.barContent, right.bar)
    }
}
