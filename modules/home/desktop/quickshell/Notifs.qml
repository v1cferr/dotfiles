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
    // A new notification that is the ISLAND's to show: a plain one, while the island is up. A
    // critical one, or one with buttons, is a toast as before, and never both.
    signal arrived(var n)
    // Arrived while the Center was closed, and not seen yet: the dot on the logo, and the count on the bar's bell.
    property int unseen: 0
    property bool unseenCritical: false
    // The ones behind that count, newest last, and the apps they came from, newest first: the
    // island rests their icons beside the logo and a hover on it lists them.
    property var unseenList: []
    readonly property var unseenApps: {
        const out = [];
        const at = {};
        for (let i = root.unseenList.length - 1; i >= 0; i--) {
            const n = root.unseenList[i];
            const key = n.desktopEntry || n.appName || "";
            if (at[key] === undefined) {
                at[key] = out.length;
                out.push({
                    name: key,
                    label: n.appName || key,
                    icon: "",
                    count: 0
                });
            }
            out[at[key]].count++;
            if (out[at[key]].icon === "")
                out[at[key]].icon = root.appIconOf(n);
        }
        return out;
    }

    // The theme icon a notification names: its image when that is an icon, else its app icon.
    function iconName(n) {
        if (!n)
            return "";
        const m = (n.image || "").match(/^image:\/\/icon\/([^\/].*)$/);
        if (m)
            return m[1];
        const ai = n.appIcon || "";
        return (ai !== "" && !ai.startsWith("/") && ai.indexOf("://") < 0) ? ai : "";
    }
    // The APP's icon as the notification itself gives it, for an app no .desktop entry answers
    // for. Never a chat message's picture (a contact's photo): that is not who sent it.
    function appIconOf(n) {
        if (!n)
            return "";
        const ai = n.appIcon || "";
        if (ai.startsWith("/"))
            return "file://" + ai;
        if (ai.startsWith("file://"))
            return ai;
        const name = root.iconName(n);
        if (name !== "")
            return Quickshell.hasThemeIcon(name) ? Quickshell.iconPath(name) : "";
        // An image with no name to it (a file's path, or a browser's own mark as data) is the last
        // thing to try. Quickshell hands a bare path over as an icon name, image://icon//home/...
        const img = n.image || "";
        if (img === "" || (n.hints && ("" + (n.hints.category || "")).startsWith("im.")))
            return "";
        const bare = img.match(/^(?:image:\/\/icon\/)?(\/.+)$/);
        return bare ? "file://" + bare[1] : img;
    }

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
        // One that was dismissed or expired is not waiting to be seen any more.
        const here = server.trackedNotifications.values;
        const still = root.unseenList.filter(n => here.indexOf(n) >= 0);
        if (still.length !== root.unseenList.length)
            root.unseenList = still;
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
        root.unseenList = [];
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
                root.unseenList = root.unseenList.concat([n]);
            }
            // Shown only when not quiet (DND or a hold) and the Center is closed; Critical pierces all.
            // A plain one goes to the island when it is up; one that asks for an answer stays a toast.
            if (critical || (!root.quiet && !root.centerOpen)) {
                const asks = critical || (n.actions || []).some(a => a.identifier !== "default");
                if (Island.live && !asks)
                    root.arrived(n);
                else
                    root.popups = root.popups.concat([n]).slice(-root.maxToasts);
            }
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
