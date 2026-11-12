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

    // ===== Open: the capsule grown downward (bar/IslandDrop.qml) =====
    // A pointer that rests on the capsule opens it, and it stays while the pointer is on the
    // capsule or on what came down; a click on the capsule keeps it. Only with something to show.
    property bool capsuleHover: false
    property bool dropHover: false
    property bool rested: false // the hover held long enough, and has not been away long enough
    property bool kept: false   // a click keeps it open
    readonly property bool hasMedia: Media.playing && Media.title !== ""
    readonly property bool hasUnseen: Notifs.unseenList.length > 0
    readonly property bool canOpen: root.current !== null && ["media", "unseen", "notification"].indexOf(root.current.kind) >= 0 && (root.hasMedia || root.hasUnseen)
    readonly property bool open: root.canOpen && (root.rested || root.kept)
    // How far what came down reaches, in px: the capsule squares its foot against it, and stays
    // wide until it is all the way back up.
    property real dropReach: 0
    readonly property bool wide: root.open || root.dropReach > 0
    // A click: keep it open, or shut it when it already was kept.
    function keep() {
        if (root.kept)
            root.shut();
        else
            root.kept = true;
    }
    function shut() {
        root.kept = false;
        root.rested = false;
    }
    onCanOpenChanged: if (!root.canOpen)
        root.kept = false
    Timer {
        interval: Theme.hoverIntent
        running: root.capsuleHover && !root.rested
        onTriggered: root.rested = true
    }
    Timer {
        interval: 400
        running: root.rested && !root.capsuleHover && !root.dropHover
        onTriggered: root.rested = false
    }
    // What is shown holds while the pointer is on either part, or while it is kept open.
    readonly property bool held: root.capsuleHover || root.dropHover || root.kept
    onHeldChanged: root.freeze(root.held)
    Binding {
        target: Audio
        property: "waveOpen"
        value: root.open && root.hasMedia && !Theme.motionReduced
    }
    Binding {
        target: Audio
        property: "islandOpen"
        value: root.open && root.hasMedia
    }

    // What was already true when the shell came up is not news: sources speak after this.
    property bool armed: false
    Timer {
        interval: 3000
        running: true
        onTriggered: root.armed = true
    }

    // ── Sources that are singletons themselves; the others (the OSD, the VPN, the disk) push in ──
    // Media is a STATE, not a moment: there while something plays, in place when the track
    // changes, gone on a pause. It needs no arming: what plays at startup is still what plays.
    function syncMedia() {
        if (Media.playing && Media.title !== "")
            root.push("media", {
                title: Media.title,
                artist: Media.artist,
                art: Media.artUrl
            });
        else
            root.drop("media");
    }
    onLiveChanged: {
        root.syncMedia();
        root.syncUnseen();
    }
    Component.onCompleted: {
        root.syncMedia();
        root.syncUnseen();
    }
    // The wave listens only while the media is what the capsule shows.
    Binding {
        target: Audio
        property: "waveIsland"
        value: root.live && root.current !== null && root.current.kind === "media" && !Theme.motionReduced
    }
    Connections {
        target: Media
        function onPlayingChanged() {
            root.syncMedia();
        }
        function onTitleChanged() {
            root.syncMedia();
        }
        function onArtistChanged() {
            root.syncMedia();
        }
        function onArtUrlChanged() {
            root.syncMedia();
        }
    }
    Connections {
        target: Notifs
        function onArrived(n) {
            root.push("notification", {
                icon: n.desktopEntry || n.appName || "",
                fallback: Notifs.appIconOf(n),
                app: n.appName || "",
                summary: n.summary || n.body || ""
            });
        }
    }
    // Apps with notifications not seen yet rest under everything else, media included; the count
    // changing updates them in place.
    function syncUnseen() {
        if (Notifs.unseenApps.length > 0)
            root.push("unseen", {
                count: Notifs.unseen
            });
        else
            root.drop("unseen");
    }
    Connections {
        target: Notifs
        function onUnseenAppsChanged() {
            root.syncUnseen();
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
