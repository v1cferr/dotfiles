// The Bluetooth page: the devices this machine knows, with what each is doing, then the ones in
// range. BlueZ is the one service behind it; discovery runs only while this page is on screen, and
// Blueman stays the pairing agent. docs/notes/desktop/control-center.md#bluetooth
import Quickshell
import Quickshell.Bluetooth
import QtQuick
import QtQuick.Layouts
import "root:/"
import "root:/widgets"

ColumnLayout {
    id: page
    property bool active: false
    signal leave(var command) // a fuller tool takes over: the panel closes and runs it
    spacing: Theme.sp1

    readonly property var adapter: Bluetooth.defaultAdapter
    readonly property bool on: !!page.adapter && page.adapter.enabled
    readonly property var all: page.adapter && page.adapter.devices ? page.adapter.devices.values : []
    readonly property var mine: page.all.filter(d => d.paired || d.bonded || d.connected)
    // In range and unknown; one that never said its name is noise, not a choice.
    readonly property var others: page.all.filter(d => !(d.paired || d.bonded || d.connected) && d.deviceName !== "")

    // Discovery costs radio time and battery on the other side: only while someone is looking.
    function look() {
        if (page.adapter && page.adapter.enabled && page.adapter.discovering !== page.active)
            page.adapter.discovering = page.active;
    }
    onActiveChanged: page.look()
    onOnChanged: page.look()

    function glyph(d) {
        const i = d.icon || "";
        return i.indexOf("head") >= 0 || i.indexOf("audio") >= 0 ? "headphones" : (i.indexOf("mouse") >= 0 ? "mouse" : (i.indexOf("keyboard") >= 0 ? "keyboard" : (i.indexOf("phone") >= 0 ? "smartphone" : (i.indexOf("gaming") >= 0 ? "sports_esports" : "bluetooth"))));
    }
    function word(d) {
        if (d.pairing)
            return "Pairing…";
        if (d.state === BluetoothDeviceState.Connecting)
            return "Connecting…";
        if (d.state === BluetoothDeviceState.Disconnecting)
            return "Disconnecting…";
        if (d.connected)
            return "Connected" + (d.batteryAvailable ? " · " + Math.round(d.battery * 100) + "%" : "");
        return d.paired || d.bonded ? "Not connected" : "Click to pair";
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
        Layout.fillWidth: true
        color: Theme.colDim
        font.family: Theme.uiFont
        font.pixelSize: Theme.fontBody
        wrapMode: Text.WordWrap
    }

    Note {
        visible: !page.adapter
        text: "This machine has no Bluetooth adapter"
    }
    Note {
        visible: !!page.adapter && !page.on
        text: "Bluetooth is off"
    }

    Heading {
        visible: page.on
        text: "MY DEVICES"
    }
    Note {
        visible: page.on && page.mine.length === 0
        text: "Nothing paired yet"
    }
    Repeater {
        model: page.on ? page.mine : []
        ListRow {
            required property var modelData
            icon: page.glyph(modelData)
            title: modelData.name || modelData.address
            status: page.word(modelData)
            lit: modelData.connected
            onClicked: modelData.connected ? modelData.disconnect() : modelData.connect()
        }
    }

    Heading {
        visible: page.on
        text: page.adapter && page.adapter.discovering ? "IN RANGE · LOOKING" : "IN RANGE"
    }
    Note {
        visible: page.on && page.others.length === 0
        text: "No other device in range"
    }
    Repeater {
        model: page.on ? page.others.slice(0, 6) : []
        ListRow {
            required property var modelData
            icon: page.glyph(modelData)
            title: modelData.name || modelData.address
            status: page.word(modelData)
            onClicked: modelData.pair()
        }
    }

    Hairline {
        Layout.topMargin: Theme.sp1
    }
    PageLink {
        label: "Bluetooth manager"
        onClicked: page.leave(["blueman-manager"])
    }
}
