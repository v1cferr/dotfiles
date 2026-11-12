pragma Singleton
// The ISLAND's one owner: what the capsule around the logo shows right now. Sources push events,
// IslandMath decides, one timer fires at the next deadline and nothing polls.
// docs/notes/desktop/island.md
import Quickshell
import Quickshell.Bluetooth
import QtQml.Models
import QtQuick
import "root:/island"

Singleton {
    id: root

    // On, and with a screen wide enough to hold it: without one the OSD and the toasts stay in charge.
    readonly property bool live: Theme.islandOn && !!Theme.screenPrimary && Theme.screenPrimary.width >= Theme.compactWidth
    property var state: math.idle
    readonly property var current: root.live ? root.state.current : null
    readonly property int seq: root.state.seq

    IslandMath {
        id: math
    }
    function push(kind, data, ttl, id) {
        if (root.live)
            root.state = math.push(root.state, math.event(kind, data, ttl, id), Date.now());
    }
    function drop(kind, id) {
        root.state = math.drop(root.state, kind + ":" + (id || ""), Date.now());
    }
    // The user dealt with what is shown.
    function dismiss() {
        if (root.state.current)
            root.state = math.drop(root.state, root.state.current.key, Date.now());
    }
    function freeze(on) {
        root.state = math.freeze(root.state, on, Date.now());
    }
    // One timer, set for the next deadline. A timer may fire a hair early, and a tick that changes
    // nothing changes no property: so it re-arms itself instead of waiting for a state change.
    function arm() {
        const d = math.deadline(root.state);
        if (d > 0) {
            due.interval = Math.max(1, d - Date.now() + 2);
            due.restart();
        } else {
            due.stop();
        }
    }
    onStateChanged: root.arm()
    Timer {
        id: due
        onTriggered: {
            root.state = math.tick(root.state, Date.now());
            root.arm();
        }
    }

    // What was already true when the shell came up is not news: sources speak after this.
    property bool armed: false
    Timer {
        interval: 3000
        running: true
        onTriggered: root.armed = true
    }

    // ── Sources that are singletons themselves; the others (the OSD, the VPN, the disk) push in ──
    Connections {
        target: Media
        function onTitleChanged() {
            if (root.armed && Media.playing && Media.title !== "")
                root.push("track", {
                    title: Media.title,
                    artist: Media.artist
                });
        }
    }
    Connections {
        target: Notifs
        function onArrived(n) {
            root.push("notification", {
                app: n.appName || "",
                summary: n.summary || n.body || ""
            });
        }
    }
    Instantiator {
        model: Bluetooth.devices ? Bluetooth.devices.values : []
        delegate: Connections {
            required property var modelData
            target: modelData
            function onConnectedChanged() {
                if (root.armed)
                    root.push("bluetooth", {
                        name: modelData.name || modelData.address,
                        on: modelData.connected
                    }, undefined, modelData.address);
            }
        }
    }
}
