pragma Singleton
// The notification service: Quickshell IS the org.freedesktop.Notifications daemon (it replaced
// swaync). IPC: `qs ipc call notif toggle|dnd|clear`. The UI: docs/notes/desktop/nixos-center.md
import Quickshell
import Quickshell.Io
import Quickshell.Services.Notifications
import QtQuick

Singleton {
    id: root

    // ===== State =====
    // DND survives a restart of the shell: a two-key file in Quickshell's own state dir, no daemon.
    readonly property bool dnd: saved.dnd
    // A TEMPORARY hold (the away screen): quiet like DND while it lasts, never written to the saved
    // preference, so a crash mid-hold cannot leave DND stuck on.
    readonly property bool held: root.holders > 0
    property int holders: 0
    function hold(on) {
        root.holders = Math.max(0, root.holders + (on ? 1 : -1));
    }
    // What the toasts obey: the user's DND or a hold.
    readonly property bool quiet: root.dnd || root.held
    // The NixOS Center is open (bound by the Bar's coordinator): no toast competes with it.
    property bool centerOpen: false
    // The toasts on screen, newest last. Three at most: an older one leaves the screen, never the history.
    readonly property int maxToasts: 3
    property var popups: []
    // How many notifications to keep; past it the oldest go, but never a critical or resident one.
    readonly property int historyLimit: 100
    // Arrived while the Center was closed, and not seen yet: the dot beside the logo.
    property int unseen: 0
    property bool unseenCritical: false

    // When each one arrived (ms, by notification id): the server keeps no time. One handed over by a
    // hot reload gets the reload's time, the closest the shell can know.
    property var arrivedAt: ({})
    function ageOf(n) {
        const t = n ? root.arrivedAt[n.id] : undefined;
        return t === undefined ? -1 : Date.now() - t;
    }
    // "now", "3 min", "2 h", "4 d": the same words as the band's.
    function agoText(n) {
        const ms = root.ageOf(n);
        if (ms < 0)
            return "";
        const s = ms / 1000;
        return s < 60 ? "now" : (s < 3600 ? Math.floor(s / 60) + " min" : (s < 86400 ? Math.floor(s / 3600) + " h" : Math.floor(s / 86400) + " d"));
    }
    // The history = the notifications tracked by the server (an UntypedObjectModel).
    readonly property var history: server.trackedNotifications
    readonly property int count: server.trackedNotifications ? server.trackedNotifications.values.length : 0
    onCountChanged: {
        if (root.unseen > root.count)
            root.unseen = root.count;
        // Forget the times of what left the history, so the map never outgrows it.
        const live = ({});
        for (const n of server.trackedNotifications.values)
            if (root.arrivedAt[n.id] !== undefined)
                live[n.id] = root.arrivedAt[n.id];
        if (Object.keys(live).length !== Object.keys(root.arrivedAt).length)
            root.arrivedAt = live;
    }

    // The Bar asks for this to open or close the Center (the IPC toggle comes through here too).
    signal centerToggleRequested
    // Open or fold every group in the Center's history (IPC `expand`/`collapse`): a test needs no mouse.
    signal groupsRequested(bool open)

    function removePopup(n) {
        root.popups = root.popups.filter(x => x !== n);
    }
    function dismiss(n) {
        root.removePopup(n);
        if (n)
            n.dismiss();
    }
    function clearAll() {
        const vals = server.trackedNotifications.values.slice();
        for (let i = 0; i < vals.length; i++)
            vals[i].dismiss();
        root.popups = [];
        root.markSeen();
    }
    function markSeen() {
        root.unseen = 0;
        root.unseenCritical = false;
    }
    onCenterOpenChanged: if (root.centerOpen) {
        root.markSeen();
        root.popups = []; // what the Center shows needs no toast on top of it
    }
    function toggleCenter() {
        root.centerToggleRequested();
    }
    function toggleDnd() {
        saved.dnd = !saved.dnd;
    }
    // The oldest go first; critical and resident ones stay until they are dealt with.
    function trimHistory() {
        const vals = server.trackedNotifications.values;
        let over = vals.length - root.historyLimit;
        for (let i = 0; i < vals.length && over > 0; i++) {
            const n = vals[i];
            if (n.urgency === NotificationUrgency.Critical || n.resident)
                continue;
            n.dismiss();
            over--;
        }
    }

    FileView {
        path: Quickshell.statePath("notifs.json")
        blockLoading: true // the saved DND is in force before the first notification can arrive
        watchChanges: false
        onAdapterUpdated: writeAdapter()
        onLoadFailed: error => {
            if (error === FileViewError.FileNotFound)
                writeAdapter();
        }
        JsonAdapter {
            id: saved
            property bool dnd: false
        }
    }

    NotificationServer {
        id: server
        keepOnReload: true
        bodySupported: true
        bodyMarkupSupported: true
        imageSupported: true
        actionsSupported: true
        actionIconsSupported: true
        persistenceSupported: true

        onNotification: function (n) {
            // tracked = true keeps the object alive and puts it in the history.
            n.tracked = true;
            if (root.arrivedAt[n.id] === undefined) {
                const m = Object.assign({}, root.arrivedAt);
                m[n.id] = Date.now();
                root.arrivedAt = m;
            }
            // keepOnReload hands the old ones over again on a hot reload: history, not news.
            if (n.lastGeneration)
                return;
            const critical = n.urgency === NotificationUrgency.Critical;
            if (!root.centerOpen) {
                root.unseen++;
                root.unseenCritical = root.unseenCritical || critical;
            }
            // A toast only when not quiet (DND or a hold) and the Center is closed; Critical pierces all.
            if (critical || (!root.quiet && !root.centerOpen))
                root.popups = root.popups.concat([n]).slice(-root.maxToasts);
            if (root.count > root.historyLimit)
                root.trimHistory();
        }
    }

    IpcHandler {
        target: "notif"
        function toggle(): void {
            root.toggleCenter();
        }
        function dnd(): void {
            root.toggleDnd();
        }
        function clear(): void {
            root.clearAll();
        }
        function expand(): void {
            root.groupsRequested(true);
        }
        function collapse(): void {
            root.groupsRequested(false);
        }
    }
}
