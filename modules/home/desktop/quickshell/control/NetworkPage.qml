// The Network page: the wired links, then Wi-Fi where the machine has it, with its networks and
// a password field for one that asks. NetworkManager is the one service behind it; the scan runs
// only while this page is on screen. docs/notes/desktop/control-center.md#network
import Quickshell
import Quickshell.Networking
import QtQuick
import QtQuick.Layouts
import "root:/"
import "root:/widgets"

ColumnLayout {
    id: page
    property bool active: false
    signal detail // the link's full panel: rates, latency, the speed test
    spacing: Theme.sp1

    readonly property var devices: Networking.devices ? Networking.devices.values : []
    readonly property var wired: page.devices.filter(d => d.type === DeviceType.Wired)
    readonly property var wifi: page.devices.find(d => d.type === DeviceType.Wifi) || null
    // Connected first, then the ones this machine knows, then by signal.
    readonly property var networks: {
        const list = page.wifi && page.wifi.networks ? page.wifi.networks.values.slice() : [];
        list.sort((a, b) => (b.connected - a.connected) || (b.known - a.known) || (b.signalStrength - a.signalStrength));
        return list.slice(0, 8);
    }
    property string asking: "" // the network whose password field is open
    property var failed: ({}) // name -> why the last attempt did not connect

    onActiveChanged: {
        page.asking = "";
        if (page.wifi)
            page.wifi.scannerEnabled = page.active;
    }

    function bars(s) {
        return s >= 0.66 ? "wifi" : (s >= 0.33 ? "wifi_2_bar" : "wifi_1_bar");
    }
    function word(n) {
        if (n.state === ConnectionState.Connecting)
            return "Connecting…";
        if (n.state === ConnectionState.Disconnecting)
            return "Disconnecting…";
        if (n.connected)
            return "Connected";
        if (page.failed[n.name])
            return page.failed[n.name];
        return n.known ? "Saved" : "";
    }
    function pick(n) {
        if (n.connected) {
            n.disconnect();
        } else if (n.known || n.security === WifiSecurityType.Open) {
            n.connect();
        } else {
            page.asking = page.asking === n.name ? "" : n.name;
        }
    }

    component Heading: Text {
        Layout.leftMargin: Theme.sp2
        Layout.topMargin: Theme.sp1
        color: Theme.colDim
        font.family: Theme.uiFont
        font.pixelSize: Theme.fontMicro
        font.letterSpacing: 1
    }
    component Note: Text {
        Layout.leftMargin: Theme.sp2
        color: Theme.colDim
        font.family: Theme.uiFont
        font.pixelSize: Theme.fontBody
    }

    Note {
        visible: page.devices.length === 0
        text: "NetworkManager reports no device"
    }

    Heading {
        visible: page.wired.length > 0
        text: "WIRED"
    }
    Repeater {
        model: page.wired
        ListRow {
            required property var modelData
            icon: "lan"
            title: modelData.name
            status: !modelData.hasLink ? "No cable" : (modelData.connected ? "Connected" + (modelData.linkSpeed > 0 ? " · " + (modelData.linkSpeed >= 1000 ? modelData.linkSpeed / 1000 + " Gb/s" : modelData.linkSpeed + " Mb/s") : "") : "Cable in, not connected")
            lit: modelData.connected
            mark: "chevron_right"
            onClicked: page.detail()
        }
    }

    Heading {
        visible: page.wifi !== null
        text: page.wifi && page.wifi.scannerEnabled ? "WI-FI · LOOKING" : "WI-FI"
    }
    ListRow {
        visible: page.wifi !== null
        icon: Networking.wifiEnabled ? "wifi" : "wifi_off"
        title: "Wi-Fi"
        status: !Networking.wifiHardwareEnabled ? "Off by the hardware switch" : (Networking.wifiEnabled ? "On" : "Off")
        lit: Networking.wifiEnabled
        onClicked: Networking.wifiEnabled = !Networking.wifiEnabled
    }
    Repeater {
        model: page.wifi !== null && Networking.wifiEnabled ? page.networks : []
        ColumnLayout {
            id: net
            required property var modelData
            Layout.fillWidth: true
            spacing: Theme.sp1
            // A network that asks for a password fails with NoSecrets: that opens the field.
            Connections {
                target: net.modelData
                function onConnectionFailed(reason) {
                    const f = Object.assign({}, page.failed);
                    f[net.modelData.name] = reason === ConnectionFailReason.NoSecrets ? "Needs its password" : "Did not connect";
                    page.failed = f;
                    if (reason === ConnectionFailReason.NoSecrets)
                        page.asking = net.modelData.name;
                }
            }
            ListRow {
                icon: page.bars(net.modelData.signalStrength)
                title: net.modelData.name
                status: page.word(net.modelData)
                statusColor: page.failed[net.modelData.name] && !net.modelData.connected ? Theme.colWarn : Theme.colSubtext
                lit: net.modelData.connected
                mark: net.modelData.security === WifiSecurityType.Open ? "" : "lock"
                onClicked: page.pick(net.modelData)
            }
            Rectangle {
                visible: page.asking === net.modelData.name
                Layout.fillWidth: true
                Layout.leftMargin: Theme.sp2
                Layout.rightMargin: Theme.sp2
                implicitHeight: Theme.barControl
                radius: Theme.radiusControl
                color: Theme.colCellHoverFill
                border.width: psk.activeFocus ? 2 : 0
                border.color: Theme.colAccent
                onVisibleChanged: if (visible)
                    psk.forceActiveFocus()
                TextInput {
                    id: psk
                    anchors.fill: parent
                    anchors.leftMargin: Theme.sp2
                    anchors.rightMargin: Theme.sp2
                    verticalAlignment: TextInput.AlignVCenter
                    echoMode: TextInput.Password
                    color: Theme.colText
                    font.family: Theme.uiFont
                    font.pixelSize: Theme.fontBody
                    clip: true
                    Accessible.name: "Password for " + net.modelData.name
                    // The password goes to NetworkManager and nowhere else; the field forgets it.
                    onAccepted: {
                        if (psk.text.length > 0)
                            net.modelData.connectWithPsk(psk.text);
                        psk.text = "";
                        page.asking = "";
                    }
                    Keys.onEscapePressed: {
                        psk.text = "";
                        page.asking = "";
                    }
                    Text {
                        visible: psk.text === ""
                        anchors.verticalCenter: parent.verticalCenter
                        text: "Password, then Enter"
                        color: Theme.colDim
                        font: psk.font
                    }
                }
            }
        }
    }

    Hairline {
        Layout.topMargin: Theme.sp1
    }
    PageLink {
        label: "Rates, latency and speed test"
        onClicked: page.detail()
    }
}
