// The NETWORK page of the rotating column: the house as the router sees it (devices, who is in
// from outside over WireGuard, open connections) and the attacks on the exposed ports, all from
// glance-feed's `network` document (LAN and local journal only, no internet). What the threat
// feeds will add is marked as not enabled yet: docs/notes/desktop/dash.md
import QtQuick
import QtQuick.Layouts
import "root:/"

ColumnLayout {
    id: net

    readonly property var doc: feed.data || ({})
    readonly property var devices: net.doc.devices || []
    readonly property var remote: net.doc.remote || []
    readonly property var attacks: net.doc.attacks || ({})
    readonly property int newCount: net.devices.filter(d => d.new).length
    readonly property int unlisted: net.devices.filter(d => !d.known).length
    readonly property int remoteOn: net.remote.filter(r => r.active).length

    spacing: 12

    Feed {
        id: feed
        name: "network"
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

    // ── 1. The four numbers: who is home, who is new, who is in from outside, how busy ──
    RowLayout {
        Layout.fillWidth: true
        spacing: 10
        Repeater {
            model: [
                {
                    n: net.devices.length,
                    label: "online",
                    tone: Theme.colText
                },
                {
                    n: net.newCount,
                    label: "new today",
                    tone: net.newCount ? Theme.colPeach : Theme.colDim
                },
                {
                    n: net.remoteOn,
                    label: "remote now",
                    tone: net.remoteOn ? Theme.colSky : Theme.colDim
                },
                {
                    n: net.doc.connections || 0,
                    label: "connections",
                    tone: Theme.colSubtext
                }
            ]
            delegate: Rectangle {
                required property var modelData
                Layout.fillWidth: true
                Layout.preferredWidth: 0
                implicitHeight: 58
                radius: 10
                color: Theme.colGroupBg
                border.width: 1
                border.color: Theme.colGroupBorder
                Column {
                    anchors.centerIn: parent
                    spacing: 0
                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: "" + parent.parent.modelData.n
                        color: parent.parent.modelData.tone
                        font.family: Theme.uiFont
                        font.pixelSize: 24
                        font.bold: true
                    }
                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: parent.parent.modelData.label
                        color: Theme.colDim
                        font.family: Theme.uiFont
                        font.pixelSize: 11
                        font.letterSpacing: 1
                    }
                }
            }
        }
    }

    // ── 2. The exposed ports, last 24 h: what the internet tried ──
    RowLayout {
        Layout.fillWidth: true
        spacing: 14
        Text {
            text: "󰒃"
            color: (net.attacks.sshFails || 0) > 0 ? Theme.colPeach : Theme.colGreen
            font.family: Theme.uiFont
            font.pixelSize: 22
        }
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 1
            Text {
                text: (net.attacks.sshFails || 0) + " failed SSH logins from " + (net.attacks.sshIps || 0) + " IPs · " + (net.attacks.bans || 0) + " banned · 24 h"
                color: Theme.colText
                font.family: Theme.uiFont
                font.pixelSize: 14
                font.bold: true
            }
            Text {
                Layout.fillWidth: true
                elide: Text.ElideRight
                text: (net.attacks.top || []).length ? "most persistent: " + net.attacks.top.map(t => t.ip + " ×" + t.n).join("  ·  ") : "nobody tried"
                color: Theme.colDim
                font.family: Theme.uiFont
                font.pixelSize: 12
            }
        }
    }

    // ── 3. Devices: new first, then the ones not in the router's static list, then the known ──
    Text {
        text: "DEVICES" + (net.unlisted ? "  ·  " + net.unlisted + " not in the router's list" : "")
        color: Theme.colSubtext
        font.family: Theme.uiFont
        font.pixelSize: 12
        font.letterSpacing: 2
    }
    Flow {
        Layout.fillWidth: true
        spacing: 6
        Repeater {
            model: net.devices
            delegate: Rectangle {
                id: dev
                required property var modelData
                readonly property color tone: modelData.new ? Theme.colPeach : (modelData.known ? Theme.colGreen : Theme.colSubtext)
                implicitWidth: devRow.implicitWidth + 18
                implicitHeight: 26
                radius: 13
                color: modelData.new ? Qt.rgba(tone.r, tone.g, tone.b, 0.18) : Theme.colGroupBg
                border.width: 1
                border.color: modelData.new ? tone : Theme.colGroupBorder
                Row {
                    id: devRow
                    anchors.centerIn: parent
                    spacing: 6
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
                    Text {
                        text: (dev.modelData.ip || "").replace("192.168.1.", ".")
                        color: Theme.colDim
                        font.family: Theme.uiFont
                        font.pixelSize: 11
                    }
                }
            }
        }
    }

    // ── 4. Remote access over WireGuard: who is in from outside, and how much went through ──
    Text {
        text: "REMOTE ACCESS · WIREGUARD"
        color: Theme.colSubtext
        font.family: Theme.uiFont
        font.pixelSize: 12
        font.letterSpacing: 2
    }
    Repeater {
        model: net.remote
        delegate: RowLayout {
            required property var modelData
            Layout.fillWidth: true
            spacing: 10
            Rectangle {
                implicitWidth: 8
                implicitHeight: 8
                radius: 4
                color: parent.modelData.active ? Theme.colGreen : Theme.colTrack
            }
            Text {
                Layout.preferredWidth: 140
                text: parent.modelData.name
                color: parent.modelData.active ? Theme.colText : Theme.colSubtext
                font.family: Theme.uiFont
                font.pixelSize: 13
                font.bold: parent.modelData.active
            }
            Text {
                Layout.fillWidth: true
                text: parent.modelData.active ? "connected" : (parent.modelData.handshake ? "last seen " + net.ago(parent.modelData.handshake) : "never connected")
                color: parent.modelData.active ? Theme.colGreen : Theme.colDim
                font.family: Theme.uiFont
                font.pixelSize: 12
            }
            Text {
                visible: (parent.modelData.rx || 0) + (parent.modelData.tx || 0) > 0
                text: "↓ " + net.bytes(parent.modelData.tx) + "  ↑ " + net.bytes(parent.modelData.rx)
                color: Theme.colDim
                font.family: Theme.uiFont
                font.pixelSize: 11
            }
        }
    }

    Item {
        Layout.fillHeight: true
    }

    // ── 5. What is planned and not on yet, said instead of implied ──
    Text {
        Layout.fillWidth: true
        horizontalAlignment: Text.AlignRight
        text: "threat feeds (DNS, banIP): not enabled yet · router over the LAN · " + (feed.updatedAt ? "updated " + net.ago(feed.updatedAt) : "waiting for the first read")
        color: Theme.colDim
        font.family: Theme.uiFont
        font.pixelSize: 11
    }
}
