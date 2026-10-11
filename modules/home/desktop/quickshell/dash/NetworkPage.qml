// The NETWORK page of the rotating column: the house as the router sees it (devices, who is in
// from outside over WireGuard, open connections) and the attacks on the exposed ports, all from
// glance-feed's `network` document (LAN and local journal only, no internet), and what the router's
// own log says about threats (`threats`: DNS blocks by the TIF/DoH lists, banIP): docs/notes/desktop/dash.md
import QtQuick
import QtQuick.Layouts
import "root:/"

ColumnLayout {
    id: net

    readonly property var doc: feed.data || ({})
    readonly property var devices: net.doc.devices || []
    readonly property var remote: net.doc.remote || []
    readonly property var remoteOff: net.remote.filter(r => !r.active)
    readonly property var attacks: net.doc.attacks || ({})
    readonly property int newCount: net.devices.filter(d => d.new).length
    readonly property int unlisted: net.devices.filter(d => !d.known).length
    readonly property int remoteOn: net.remote.filter(r => r.active).length
    readonly property var threats: threatFeed.data || ({})
    readonly property var dns: net.threats.dns || ({})
    readonly property var inbound: net.threats.inbound || ({})
    // Contacts with a listed threat first, then the DoH bypass attempts: the worst is always on screen.
    readonly property var hits: (net.threats.hits || []).slice().sort((a, b) => (a.kind === "dns-doh") - (b.kind === "dns-doh"))
    // A threat block or a LAN device reaching a listed IP is red; a DoH bypass attempt only peach.
    readonly property int danger: net.hits.filter(h => h.kind !== "dns-doh").length

    spacing: 16

    Feed {
        id: feed
        name: "network"
    }
    Feed {
        id: threatFeed
        name: "threats"
    }

    function bytes(b) {
        if (b >= 1073741824)
            return (b / 1073741824).toFixed(1) + " GB";
        if (b >= 1048576)
            return Math.round(b / 1048576) + " MB";
        return Math.round((b || 0) / 1024) + " KB";
    }
    function ago(sec) {
        if (!sec)
            return "never";
        const s = Math.max(0, Date.now() / 1000 - sec);
        return s < 60 ? "now" : s < 3600 ? Math.floor(s / 60) + " min ago" : s < 86400 ? Math.floor(s / 3600) + " h ago" : Math.floor(s / 86400) + " d ago";
    }
    function hitLine(h) {
        return (h.name || h.client) + ": " + (h.kind === "ip-out" ? "reached " : "asked ") + h.target + (h.n > 1 ? " ×" + h.n : "") + " · " + ({
                "dns-threat": "threat list",
                "dns-doh": "DoH bypass",
                "ip-out": "banIP " + h.feed
            })[h.kind] + " · " + net.ago(h.last);
    }

    // ── 1. The four numbers as glyph chips: who is home, who is new, who is in from outside, how busy ──
    RowLayout {
        Layout.fillWidth: true
        spacing: 8
        Repeater {
            model: [
                {
                    g: "󰖩",
                    n: net.devices.length,
                    tone: Theme.colText,
                    tip: "devices online",
                    more: net.unlisted ? net.unlisted + " not in the router's static list" : "all in the router's static list"
                },
                {
                    g: "󰐕",
                    n: net.newCount,
                    tone: net.newCount ? Theme.colPeach : Theme.colDim,
                    tip: "new devices today",
                    more: net.newCount ? net.devices.filter(d => d.new).map(d => d.name || d.ip).join(" · ") : "none"
                },
                {
                    g: "󰖂",
                    n: net.remoteOn,
                    tone: net.remoteOn ? Theme.colSky : Theme.colDim,
                    tip: "in from outside over WireGuard",
                    more: net.remoteOn ? net.remote.filter(r => r.active).map(r => r.name).join(" · ") : "nobody right now"
                },
                {
                    g: "󰌘",
                    n: net.doc.connections || 0,
                    tone: Theme.colSubtext,
                    tip: "open connections through the router",
                    more: ""
                }
            ]
            delegate: Rectangle {
                id: chip
                required property var modelData
                Layout.fillWidth: true
                Layout.preferredWidth: 0
                implicitHeight: 40
                radius: 10
                color: Theme.colGroupBg
                border.width: 1
                border.color: Theme.colGroupBorder
                Tip {
                    title: chip.modelData.n + " " + chip.modelData.tip
                    lines: chip.modelData.more ? [chip.modelData.more] : []
                }
                Row {
                    anchors.centerIn: parent
                    spacing: 10
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: chip.modelData.g
                        color: chip.modelData.tone
                        font.family: Theme.uiFont
                        font.pixelSize: 18
                    }
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "" + chip.modelData.n
                        color: chip.modelData.tone
                        font.family: Theme.uiFont
                        font.pixelSize: 22
                        font.bold: true
                    }
                }
            }
        }
    }

    // ── 2. The exposed ports, last 24 h: one line, the most persistent IPs on hover ──
    Item {
        Layout.fillWidth: true
        implicitHeight: sshRow.implicitHeight
        Tip {
            title: "SSH, last 24 h"
            lines: [(net.attacks.sshFails || 0) + " failed logins from " + (net.attacks.sshIps || 0) + " IPs · " + (net.attacks.bans || 0) + " banned"].concat((net.attacks.top || []).map(t => t.ip + "  ×" + t.n))
        }
        RowLayout {
            id: sshRow
            anchors.left: parent.left
            anchors.right: parent.right
            spacing: 16
            Text {
                Layout.preferredWidth: 24
                text: "󰒃"
                color: (net.attacks.sshFails || 0) > 0 ? Theme.colPeach : Theme.colGreen
                font.family: Theme.uiFont
                font.pixelSize: 20
            }
            Text {
                Layout.fillWidth: true
                elide: Text.ElideRight
                text: (net.attacks.sshFails || 0) ? net.attacks.sshFails + " failed SSH · " + (net.attacks.sshIps || 0) + " IPs · " + (net.attacks.bans || 0) + " banned" : "no SSH attempts"
                color: Theme.colText
                font.family: Theme.uiFont
                font.pixelSize: 14
                font.bold: true
            }
        }
    }

    // ── 3. Threats, last 24 h: one line, then at most two events (contacts first), the rest on hover ──
    Item {
        Layout.fillWidth: true
        implicitHeight: threatRow.implicitHeight
        Tip {
            title: "Threats, last 24 h"
            lines: [(net.inbound.drops || 0) + " inbound scans dropped", (net.dns.queries || 0).toLocaleString(Qt.locale(), "f", 0) + " DNS queries from " + (net.dns.clients || 0) + " clients · " + (net.dns.blocked || 0).toLocaleString(Qt.locale(), "f", 0) + " blocked (" + (net.dns.queries ? Math.round(100 * net.dns.blocked / net.dns.queries) : 0) + "%)"].concat(net.hits.slice(2).map(h => net.hitLine(h)))
        }
        RowLayout {
            id: threatRow
            anchors.left: parent.left
            anchors.right: parent.right
            spacing: 16
            Text {
                Layout.preferredWidth: 24
                text: "󰻌"
                color: net.danger ? Theme.colRed : (net.hits.length ? Theme.colPeach : Theme.colGreen)
                font.family: Theme.uiFont
                font.pixelSize: 20
            }
            Text {
                Layout.fillWidth: true
                elide: Text.ElideRight
                text: (net.danger ? net.danger + " threat contacts" : "no threat contacts") + (net.hits.length > 2 ? "  ·  +" + (net.hits.length - 2) + " more" : "")
                color: net.danger ? Theme.colRed : Theme.colText
                font.family: Theme.uiFont
                font.pixelSize: 14
                font.bold: true
            }
        }
    }
    Repeater {
        model: net.hits.slice(0, 2)
        delegate: Item {
            id: hit
            required property var modelData
            readonly property color tone: modelData.kind === "dns-doh" ? Theme.colPeach : Theme.colRed
            Layout.fillWidth: true
            Layout.topMargin: -8
            implicitHeight: hitRow.implicitHeight
            Tip {
                title: hit.modelData.name || hit.modelData.client
                lines: [net.hitLine(hit.modelData)]
            }
            RowLayout {
                id: hitRow
                anchors.left: parent.left
                anchors.right: parent.right
                spacing: 8
                Rectangle {
                    Layout.leftMargin: 40
                    implicitWidth: 8
                    implicitHeight: 8
                    radius: 4
                    color: hit.tone
                }
                Text {
                    text: hit.modelData.name || hit.modelData.client
                    color: Theme.colText
                    font.family: Theme.uiFont
                    font.pixelSize: 13
                    font.bold: true
                }
                Text {
                    Layout.fillWidth: true
                    elide: Text.ElideMiddle
                    text: hit.modelData.target + (hit.modelData.n > 1 ? " ×" + hit.modelData.n : "")
                    color: Theme.colSubtext
                    font.family: Theme.uiFont
                    font.pixelSize: 12
                }
            }
        }
    }

    // ── 4. Devices: new first, then the ones not in the router's static list, then the known. The
    // name is the chip; its address is on hover ──
    Flow {
        Layout.fillWidth: true
        spacing: 8
        Repeater {
            model: net.devices
            delegate: Rectangle {
                id: dev
                required property var modelData
                readonly property color tone: modelData.new ? Theme.colPeach : (modelData.known ? Theme.colGreen : Theme.colSubtext)
                implicitWidth: devRow.implicitWidth + 20
                implicitHeight: 26
                radius: 13
                color: modelData.new ? Qt.rgba(tone.r, tone.g, tone.b, 0.18) : Theme.colGroupBg
                border.width: 1
                border.color: modelData.new ? tone : Theme.colGroupBorder
                Tip {
                    title: dev.modelData.name || "unnamed"
                    lines: [dev.modelData.ip || "", dev.modelData.mac || "", dev.modelData.new ? "first seen today" : (dev.modelData.known ? "in the router's static list" : "not in the router's static list")].filter(x => x)
                }
                Row {
                    id: devRow
                    anchors.centerIn: parent
                    spacing: 8
                    Rectangle {
                        anchors.verticalCenter: parent.verticalCenter
                        width: 7
                        height: 7
                        radius: 3.5
                        color: dev.tone
                    }
                    Text {
                        text: (dev.modelData.name || "unnamed") + (dev.modelData.new ? "  NEW" : "")
                        color: Theme.colText
                        font.family: Theme.uiFont
                        font.pixelSize: 12
                        font.bold: dev.modelData.new
                    }
                }
            }
        }
    }

    // ── 5. Remote access over WireGuard: who is in now; the others are one chip, listed on hover ──
    Flow {
        Layout.fillWidth: true
        spacing: 8
        Text {
            height: 26
            verticalAlignment: Text.AlignVCenter
            text: "󰖂"
            color: net.remoteOn ? Theme.colSky : Theme.colDim
            font.family: Theme.uiFont
            font.pixelSize: 18
        }
        Repeater {
            model: net.remote.filter(r => r.active)
            delegate: Rectangle {
                id: peer
                required property var modelData
                implicitWidth: peerText.implicitWidth + 20
                implicitHeight: 26
                radius: 13
                color: Qt.rgba(Theme.colGreen.r, Theme.colGreen.g, Theme.colGreen.b, 0.15)
                border.width: 1
                border.color: Theme.colGreen
                Tip {
                    title: peer.modelData.name + " · connected"
                    lines: ["↓ " + net.bytes(peer.modelData.tx) + "  ↑ " + net.bytes(peer.modelData.rx)]
                }
                Text {
                    id: peerText
                    anchors.centerIn: parent
                    text: peer.modelData.name
                    color: Theme.colText
                    font.family: Theme.uiFont
                    font.pixelSize: 12
                    font.bold: true
                }
            }
        }
        Rectangle {
            visible: net.remoteOff.length > 0
            implicitWidth: offText.implicitWidth + 20
            implicitHeight: 26
            radius: 13
            color: Theme.colGroupBg
            border.width: 1
            border.color: Theme.colGroupBorder
            Tip {
                title: "WireGuard peers not connected"
                lines: net.remoteOff.map(r => r.name + " · " + (r.handshake ? "last seen " + net.ago(r.handshake) : "never connected"))
            }
            Text {
                id: offText
                anchors.centerIn: parent
                text: net.remoteOff.length + " offline"
                color: Theme.colDim
                font.family: Theme.uiFont
                font.pixelSize: 12
            }
        }
    }

    Item {
        Layout.fillHeight: true
    }

    // ── 6. Where it comes from, and how fresh: a glyph, the sources on hover ──
    Text {
        Layout.alignment: Qt.AlignRight
        text: "󰋼"
        color: Theme.colDim
        font.family: Theme.uiFont
        font.pixelSize: 16
        Tip {
            title: "Sources"
            lines: ["router over the LAN, no internet", ((net.threats.lists || {}).tif || 0).toLocaleString(Qt.locale(), "f", 0) + " threat domains listed", feed.updatedAt ? "updated " + net.ago(feed.updatedAt) : "waiting for the first read"]
        }
    }
}
