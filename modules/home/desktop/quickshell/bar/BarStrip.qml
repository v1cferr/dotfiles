// One monitor's bar WINDOW: the glass strip, the geometry and the three regions. The data and the
// panel coordinator stay in Bar.qml (the `host`). The layout rules: docs/notes/desktop/bar.md
import Quickshell
import Quickshell.Wayland
import QtQuick
import QtQuick.Layouts
import "root:/"
import "root:/widgets"

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
    // The logo's compartment sits on the screen's EXACT center: its x comes from the width alone.
    readonly property int centerX: Math.floor(bar.width / 2)
    readonly property int slotX: bar.centerX - Theme.barCenterWidth / 2
    // The full bar puts the time left of the compartment and the date right of it, in two MIRRORED
    // cells of one width measured from a template ("00:00" and "00/00" are both five mono
    // columns), one slit away, so the pair is symmetric about the logo and a new minute or day
    // moves nothing.
    readonly property int clockW: Theme.barCellWidth(Math.ceil(tmClock.advanceWidth))
    readonly property int dateW: bar.clockW
    readonly property int clockX: bar.slotX - Theme.barGap - bar.clockW
    readonly property int dateX: bar.slotX + Theme.barCenterWidth + Theme.barGap
    // The center group's outer edges; the compact bar's is the compartment (1 px wider at its top).
    readonly property int centerLeft: bar.compact ? bar.slotX - 1 : bar.clockX
    readonly property int centerRight: bar.compact ? bar.slotX + Theme.barCenterWidth + 1 : bar.dateX + bar.dateW
    // What each side may fill: its edge margin and a gap before the center group.
    readonly property int leftRoom: bar.centerLeft - Theme.barEdge - Theme.sp4
    readonly property int rightRoom: bar.width - bar.centerRight - Theme.barEdge - Theme.sp4

    // ── LEFT: workspaces, title, media. Shares from the room alone, never from the texts ──
    // In order: media from 220 down to 120, media to its icon, then the title (a floor of 120,
    // under which it hides). A song or a focus change can never flip a level.
    readonly property int titleMin: 240
    readonly property bool mediaHere: !bar.compact && bar.host.spHasPlayer
    readonly property int leftAvail: bar.leftRoom - leftRow.wsWidth - Theme.barGap - (bar.mediaHere ? Theme.barGap : 0)
    readonly property int mediaIconW: Theme.barCellWidth(Math.ceil(tmMediaIcon.advanceWidth))
    readonly property int mediaW: !bar.mediaHere ? 0 : Math.max(bar.mediaIconW, Math.min(220, bar.leftAvail - bar.titleMin))
    readonly property bool mediaIconOnly: bar.mediaHere && bar.mediaW < 120
    readonly property int mediaUsed: !bar.mediaHere ? 0 : (bar.mediaIconOnly ? bar.mediaIconW : bar.mediaW)
    readonly property int titleMax: Math.min(520, bar.leftAvail - bar.mediaUsed)

    // ── RIGHT: the system and its tray. The tray is pinned to the edge; the rest folds by priority
    // when it would cross the center: the network's numbers and the VPN's name, then the weather.
    readonly property bool trayHere: !bar.compact || !bar.host.wideUp
    readonly property int trayW: bar.trayHere && tray.count > 0 ? tray.stableWidth + Theme.barGap : 0
    readonly property int squeeze: rightRow.measure(0) <= bar.rightRoom ? 0 : (rightRow.measure(1) <= bar.rightRoom ? 1 : 2)

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

        // ── The center: the official logo in its compartment, the NixOS Center on a click ──
        LogoSlot {
            id: logoSlot
            x: bar.slotX
            host: root
            barContent: barContent
            barWindow: bar
        }
        // Templates for the fixed widths: a mono face, so every minute and every date is this wide.
        TextMetrics {
            id: tmClock
            font.family: Theme.uiFont
            font.pixelSize: Theme.fontBody
            font.bold: true
            text: "00:00"
        }
        // The time, the logo, the date: placed from the compartment's edges, never centered as a
        // group, so the logo stays on the screen's center whatever the strings hold.
        Pill {
            id: clockPill
            visible: !bar.compact
            x: bar.clockX
            anchors.verticalCenter: parent.verticalCenter
            width: bar.clockW
            label: bar.host.barTimeStr
            labelColor: Theme.colText
            bold: true
            selected: bar.host.pinned === "cal"
            // Both open the ONE calendar, hung from the logo, so it never jumps between them.
            onHoveredChanged: bar.host.hoverPanel("cal", logoSlot, barContent, bar, hovered)
            onClicked: bar.host.togglePanel("cal", logoSlot, barContent, bar)
        }
        Pill {
            id: datePill
            visible: !bar.compact
            x: bar.dateX
            anchors.verticalCenter: parent.verticalCenter
            width: bar.dateW
            label: bar.host.barDateStr
            labelColor: Theme.colText
            bold: true
            selected: bar.host.pinned === "cal"
            onHoveredChanged: bar.host.hoverPanel("cal", logoSlot, barContent, bar, hovered)
            onClicked: bar.host.togglePanel("cal", logoSlot, barContent, bar)
        }

        // ── LEFT: this monitor's workspaces, the focused window's title, then the media ──
        TextMetrics {
            id: tmTitle
            font.family: Theme.uiFont
            font.pixelSize: Theme.fontBody
            font.italic: true
            text: bar.host.winTitle
        }
        TextMetrics {
            id: tmMediaIcon
            font.family: Theme.uiFont
            font.pixelSize: Theme.iconBar
            text: "󰝚"
        }
        RowLayout {
            id: leftRow
            readonly property int wsWidth: wsStrip.implicitWidth
            anchors.left: parent.left
            anchors.leftMargin: Theme.barEdge
            height: parent.height
            spacing: Theme.barGap
            WorkspaceStrip {
                id: wsStrip
                host: root
                monitor: bar.modelData ? bar.modelData.name : ""
                maxApps: bar.compact ? 2 : 3
                barContent: barContent
                barWindow: bar
            }
            Pill {
                id: winPill
                visible: bar.modelData && bar.modelData.name === bar.host.focusedMon && bar.host.winTitle !== "" && bar.titleMax >= 120
                label: bar.host.winTitle
                accent: Theme.colSky
                italic: true
                leftAligned: true
                maxWidth: bar.titleMax
                // In 64 px steps from the text's own metrics, so a focus change rarely moves the media.
                Layout.preferredWidth: Math.min(bar.titleMax, Math.max(120, Math.ceil(Theme.barCellWidth(tmTitle.advanceWidth + 1) / 64) * 64))
                onHoveredChanged: bar.host.hoverHint("win", winPill, barContent, bar, hovered)
            }
            Pill {
                id: spPill
                visible: bar.mediaHere
                icon: "󰝚"
                label: bar.mediaIconOnly ? "" : bar.host.spText
                accent: bar.host.spColor
                maxWidth: bar.mediaUsed
                onHoveredChanged: bar.host.hoverHint("music", spPill, barContent, bar, hovered)
                onClicked: {
                    bar.host.closePanels();
                    bar.host.hideHint();
                    bar.host.anchorPopover(spPill, barContent, bar);
                    bar.host.launch(["qs", "ipc", "call", "mpris", "toggleAt", "" + bar.host.popLeft(360)]);
                }
                onRightClicked: bar.host.launch(["playerctl", "--player=spotifast", "play-pause"])
                onScrolledUp: bar.host.launch(["playerctl", "--player=spotifast", "next"])
                onScrolledDown: bar.host.launch(["playerctl", "--player=spotifast", "previous"])
            }
        }

        // ── RIGHT EDGE: the tray, pinned there and growing left (also the band screen's, alone) ──
        TrayStrip {
            id: tray
            visible: bar.trayHere
            anchors.right: parent.right
            anchors.rightMargin: Theme.barEdge
            anchors.verticalCenter: parent.verticalCenter
            host: root
            barContent: barContent
            barWindow: bar
        }

        // ── RIGHT, compact screen: the operational alerts, nothing the band already shows ──
        OpsIndicator {
            visible: bar.compact
            anchors.right: parent.right
            anchors.rightMargin: Theme.barEdge + bar.trayW
            anchors.verticalCenter: parent.verticalCenter
            host: root
            barContent: barContent
            barWindow: bar
            maxWidth: bar.rightRoom - bar.trayW
        }

        // ── RIGHT, full: weather, CPU, network, VPN, sound, the session; the tray after it ──
        // Colors follow the states catalog (Theme.qml): neutral unless a condition is verifiable.
        RowLayout {
            id: rightRow
            visible: !bar.compact
            anchors.right: parent.right
            anchors.rightMargin: Theme.barEdge + bar.trayW
            height: parent.height
            spacing: Theme.barGap
            // The row's width at a squeeze level, the tray included, from the controls' own implicit
            // widths, which do not depend on what is visible: so the level never feeds back into itself.
            TextMetrics {
                id: tmNet
                font.family: Theme.uiFont
                font.pixelSize: Theme.fontBody
                text: bar.host.netPillText
            }
            TextMetrics {
                id: tmNetUnit
                font.family: Theme.uiFont
                font.pixelSize: Theme.fontSmall
                text: bar.host.netBusy ? "b/s" : ""
            }
            TextMetrics {
                id: tmVpn
                font.family: Theme.uiFont
                font.pixelSize: Theme.fontBody
                text: bar.host.vpnConnected ? bar.host.vpnName : ""
            }
            function measure(level) {
                // Cells and one slit after each but the last; the tray's slit is inside trayW.
                let w = usagePill.implicitWidth + volPill.implicitWidth + idlePill.implicitWidth + awayPill.implicitWidth;
                let n = 4;
                if (diskPill.visible) {
                    w += diskPill.implicitWidth;
                    n++;
                }
                // VPN and network change their own labels with the level, so they are measured in full
                // from text metrics, never from the pills: that is what keeps this free of a loop.
                const icon = Theme.iconBar;
                w += level >= 1 ? 2 * Theme.barCellWidth(icon) : Theme.barCellWidth(icon + Theme.sp1 + tmNet.advanceWidth + (bar.host.netBusy ? tmNetUnit.advanceWidth + Theme.sp1 : 0)) + Theme.barCellWidth(icon + (tmVpn.advanceWidth > 0 ? Theme.sp1 + tmVpn.advanceWidth : 0));
                n += 2;
                if (level < 2) {
                    w += weatherPill.implicitWidth;
                    n++;
                }
                return w + (n - 1) * Theme.barGap + bar.trayW;
            }
            Pill {
                visible: bar.squeeze < 2
                id: weatherPill
                icon: bar.host.wHas ? bar.host.weatherIcon(bar.host.wCode, bar.host.isDayNow()) : "󰖐"
                label: bar.host.wHas ? bar.host.wTemp + "°C" : "--°C"
                accent: bar.host.wHas ? Theme.colSubtext : Theme.colUnknown
                labelColor: bar.host.wHas ? Theme.colText : Theme.colUnknown
                off: !bar.host.wHas
                selected: bar.host.pinned === "weather"
                onHoveredChanged: if (bar.host.wHas)
                    bar.host.hoverPanel("weather", weatherPill, barContent, bar, hovered)
                onClicked: if (bar.host.wHas)
                    bar.host.togglePanel("weather", weatherPill, barContent, bar)
                // The forecast site moved here when the click became the panel's pin.
                onRightClicked: bar.host.launch(["xdg-open", "https://www.msn.com/en-us/weather/forecast/in-S%C3%A3o-Carlos,S%C3%A3o-Paulo"])
            }
            Pill {
                // CPU use. A busy CPU is not a fault: it turns to attention only when pegged.
                id: usagePill
                icon: "󰓅"
                label: bar.host.tab(bar.host.cpuPct, 3) + "%"
                accent: bar.host.cpuPct >= 90 ? Theme.colWarn : Theme.colSubtext
                labelColor: Theme.colText
                tint: bar.host.cpuPct >= 90 ? Theme.colWarn : "transparent"
                selected: bar.host.pinned === "usage"
                onHoveredChanged: bar.host.hoverPanel("usage", usagePill, barContent, bar, hovered)
                onClicked: bar.host.togglePanel("usage", usagePill, barContent, bar)
            }
            Pill {
                // Storage, ONLY when it needs a look: the root filesystem past 90% or under 20 GB
                // free (attention), past 95% or under 5 GB (critical). df every 30 s is the source.
                id: diskPill
                readonly property bool crit: bar.host.diskTotal > 0 && (bar.host.diskPct >= 95 || bar.host.diskFree < 5 * 1073741824)
                visible: bar.host.diskTotal > 0 && (diskPill.crit || bar.host.diskPct >= 90 || bar.host.diskFree < 20 * 1073741824)
                icon: "󰋊"
                label: bar.host.diskPct + "%"
                accent: diskPill.crit ? Theme.colCrit : Theme.colWarn
                labelColor: diskPill.accent
                tint: diskPill.accent
                onHoveredChanged: bar.host.hoverHint("disk", diskPill, barContent, bar, hovered)
                onClicked: bar.host.togglePanel("usage", diskPill, barContent, bar)
            }
            Pill {
                id: netPill
                icon: "󰛳"
                label: bar.squeeze >= 1 ? "" : bar.host.netPillText
                sub: bar.squeeze >= 1 || !bar.host.netBusy ? "" : "b/s" // ONE unit for both rates
                accent: bar.host.netQuality.color
                labelColor: Theme.colText
                selected: bar.host.pinned === "net"
                onHoveredChanged: bar.host.hoverPanel("net", netPill, barContent, bar, hovered)
                onClicked: bar.host.togglePanel("net", netPill, barContent, bar)
                onRightClicked: bar.host.launch(["nm-connection-editor"]) // was the left click before the pin
            }
            Pill {
                // VPN: click opens the actions popover, HOVER shows the statistics, right click drops everything.
                // Off by choice is neutral, never a failure. Information on hover, ACTION on click: docs/notes/desktop/bar.md
                id: vpnPill
                icon: "󰦝"
                label: bar.host.vpnConnected && bar.squeeze < 1 ? bar.host.vpnName : ""
                accent: bar.host.vpnConnected ? Theme.colOk : Theme.colUnknown
                labelColor: Theme.colText
                off: !bar.host.vpnConnected
                // Tor rides along in its own purple: a VPN and Tor can be up at once.
                badge: (bar.host.torSystem || bar.host.torBisq) ? "" + (bar.host.torBisq ? " Bisq" : "") : ""
                badgeColor: Theme.colLavender
                maxWidth: 190
                selected: bar.host.vpnPopVisible
                onHoveredChanged: bar.host.hoverPanel("vpn", vpnPill, barContent, bar, hovered)
                onClicked: {
                    const open = !bar.host.vpnPopVisible;
                    bar.host.closePanels(); // its actions menu is the one panel now
                    bar.host.anchorPopover(vpnPill, barContent, bar);
                    bar.host.vpnPopVisible = open;
                    if (bar.host.vpnPopVisible) {
                        bar.host.refreshVpn(); // a fresh state when it opens
                    }
                }
                onRightClicked: bar.host.runVpn("disconnect", "all")
            }
            Pill {
                id: volPill
                icon: bar.host.volIcon()
                label: bar.host.tab(Math.round(bar.host.volume * 100), 3) + "%"
                accent: bar.host.sinkMuted ? Theme.colUnknown : Theme.colSubtext
                labelColor: bar.host.sinkMuted ? Theme.colUnknown : Theme.colText
                off: bar.host.sinkMuted
                onHoveredChanged: bar.host.hoverHint("vol", volPill, barContent, bar, hovered)
                onClicked: bar.host.toggleMute()
                onRightClicked: bar.host.launch(["pavucontrol"])
                onScrolledUp: bar.host.setVol(0.05)
                onScrolledDown: bar.host.setVol(-0.05)
            }
            Pill {
                // hypridle: on is the normal state; off by choice is neutral, dimmed.
                id: idlePill
                icon: bar.host.hypridleIcon
                accent: bar.host.hypridleOn ? Theme.colSubtext : Theme.colUnknown
                off: !bar.host.hypridleOn
                onHoveredChanged: bar.host.hoverHint("idle", idlePill, barContent, bar, hovered)
                onClicked: bar.host.launch(["sh", "-c", "systemctl --user is-active --quiet hypridle.service && systemctl --user stop hypridle.service || systemctl --user start hypridle.service"])
            }
            Pill {
                // The away screen (Away.qml): it covers the bar too, so this only ever turns it on.
                id: awayPill
                icon: "󰽥"
                accent: Theme.colSubtext
                onHoveredChanged: bar.host.hoverHint("away", awayPill, barContent, bar, hovered)
                onClicked: {
                    bar.host.hideHint();
                    Away.enter();
                }
            }
        }
    }
}
