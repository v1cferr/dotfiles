// The CONTROL CENTER: the everyday switches and levels in one panel, hung under its item on the
// bar's right. It owns no state: every tile reads and sets the service that does.
// What lives here and what stays in the NixOS Center: docs/notes/desktop/control-center.md
import Quickshell
import Quickshell.Bluetooth
import QtQuick
import QtQuick.Layouts
import "root:/"
import "root:/bar"
import "root:/widgets"

BarPanel {
    id: cc
    key: "control"
    // "" is the main view; a tile with a page of its own swaps the card's content in place.
    property string page: ""
    readonly property var adapter: Bluetooth.defaultAdapter
    readonly property var btConnected: (cc.adapter && cc.adapter.devices ? cc.adapter.devices.values : []).filter(d => d.connected)
    readonly property var vpnUp: cc.bar.vpnList.filter(v => v.connected)
    readonly property string vpnPending: Object.keys(cc.bar.vpnPhase).find(id => cc.bar.vpnPhase[id] === "connecting") || ""

    implicitWidth: 340
    implicitHeight: card.implicitHeight
    onVisibleChanged: {
        cc.page = ""; // every open starts on the main view
        if (cc.visible)
            cc.takeKeys();
    }
    onPageChanged: cc.takeKeys()
    onKeyPressed: event => {
        if ([Qt.Key_Down, Qt.Key_Right].includes(event.key)) {
            card.nextItemInFocusChain(true).forceActiveFocus(Qt.TabFocusReason);
            event.accepted = true;
        } else if ([Qt.Key_Up, Qt.Key_Left].includes(event.key)) {
            card.nextItemInFocusChain(false).forceActiveFocus(Qt.BacktabFocusReason);
            event.accepted = true;
        } else if (event.key === Qt.Key_Escape && cc.page !== "") {
            cc.page = ""; // Escape leaves a page first, the panel second
            event.accepted = true;
        }
    }

    PopCard {
        id: card
        shown: cc.visible
        pad: Theme.sp3
        gap: Theme.sp2
        Keys.onPressed: event => {
            if (event.key !== Qt.Key_Escape)
                return;
            cc.page !== "" ? cc.page = "" : cc.bar.closePanels();
            event.accepted = true;
        }

        // ── The main view ──
        GridLayout {
            visible: cc.page === ""
            Layout.fillWidth: true
            columns: 2
            rowSpacing: Theme.sp2
            columnSpacing: Theme.sp2

            ControlTile {
                icon: !cc.bar.netConnected ? "signal_disconnected" : (cc.bar.netEthernet ? "lan" : "wifi")
                title: "Network"
                // The link's kind while it is steady; its trouble, in a word, when it is not.
                status: !cc.bar.netConnected ? "Offline" : (cc.bar.netQuality.label === "steady" ? (cc.bar.netEthernet ? "Ethernet" : "Wi-Fi") : cc.bar.netQuality.label)
                on: cc.bar.netConnected
                toggles: false
                hasPage: true
                // The link's own panel, under the same item, until the Network page lands.
                onOpened: cc.bar.togglePanel("net", null, null, cc.bar.popBar)
            }
            ControlTile {
                icon: cc.adapter && cc.adapter.enabled ? "bluetooth" : "bluetooth_disabled"
                title: "Bluetooth"
                available: !!cc.adapter
                status: !cc.adapter ? "No adapter" : (!cc.adapter.enabled ? "Off" : (cc.btConnected.length === 0 ? "On" : cc.btConnected.map(d => d.name).join(", ")))
                on: !!cc.adapter && cc.adapter.enabled
                hasPage: true
                onToggled: cc.adapter.enabled = !cc.adapter.enabled
                // Blueman stays the pairing agent and the full manager until the Bluetooth page lands.
                onOpened: {
                    cc.bar.closePanels();
                    cc.bar.launch(["blueman-manager"]);
                }
            }
            ControlTile {
                visible: Theme.hasVpn
                icon: cc.vpnUp.length > 0 ? "shield_lock" : "shield"
                title: "VPN"
                status: cc.vpnPending !== "" ? "Connecting…" : (cc.vpnUp.length > 0 ? cc.vpnUp.map(v => v.name).join(", ") : "Off")
                on: cc.vpnUp.length > 0
                hasPage: true
                onToggled: cc.vpnUp.length > 0 ? cc.bar.runVpn("disconnect", "all") : cc.bar.runVpn("connect", cc.bar.vpnLast)
                onOpened: cc.page = "vpn"
            }
            ControlTile {
                icon: Notifs.dnd ? "do_not_disturb_on" : "notifications"
                title: "Focus"
                status: Notifs.dnd ? "Do Not Disturb" : "Notifications on"
                on: Notifs.dnd
                onToggled: Notifs.toggleDnd()
            }
        }

        MediaRow {
            visible: cc.page === "" && Media.hasPlayer
            Layout.fillWidth: true
        }

        RowLayout {
            visible: cc.page === ""
            Layout.fillWidth: true
            spacing: Theme.sp2
            Slider {
                Layout.fillWidth: true
                name: "Volume"
                icon: Audio.muted || Audio.volume <= 0 ? "volume_off" : (Audio.volume <= 0.5 ? "volume_down" : "volume_up")
                value: Audio.volume
                dimmed: Audio.muted
                onMoved: v => Audio.setVolume(v)
                onIconClicked: Audio.toggleMute()
            }
            IconButton {
                glyph: "chevron_right"
                tint: Theme.colSubtext
                name: "Sound"
                onClicked: cc.page = "sound"
            }
        }

        Hairline {
            visible: cc.page === ""
        }
        PageLink {
            visible: cc.page === ""
            label: "NixOS Center"
            onClicked: Notifs.toggleCenter()
        }

        // ── The pages ──
        PageHeader {
            visible: cc.page !== ""
            title: cc.page === "sound" ? "Sound" : "VPN"
            onBack: cc.page = ""
        }
        SoundPage {
            visible: cc.page === "sound"
            active: cc.visible && cc.page === "sound"
            Layout.fillWidth: true
            onLeave: cmd => {
                cc.bar.closePanels();
                cc.bar.launch(cmd);
            }
        }
        VpnPage {
            visible: cc.page === "vpn"
            Layout.fillWidth: true
            host: cc.bar
        }
    }
}
