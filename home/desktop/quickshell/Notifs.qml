pragma Singleton
// The notification service: Quickshell becomes the org.freedesktop.Notifications daemon (it
// replaces swaync). It holds the state (DND, live toasts, history) and exposes IPC:
//   qs ipc call notif toggle   -> opens/closes the center
//   qs ipc call notif dnd      -> toggles Do Not Disturb
//   qs ipc call notif clear    -> clears the history
// The UI is in Notifications.qml; the bar reads Notifs.barIcon / Notifs.count / Notifs.dnd.
import Quickshell
import Quickshell.Io
import Quickshell.Services.Notifications
import QtQuick

Singleton {
    id: root

    // ===== State =====
    property bool dnd: false
    property bool centerVisible: false
    // The toasts currently on screen (Notification objects; alive because they stay tracked).
    property var popups: []

    // The history = the notifications tracked by the server (an UntypedObjectModel).
    readonly property var history: server.trackedNotifications
    readonly property int count: server.trackedNotifications ? server.trackedNotifications.values.length : 0

    // The bell icon in the bar, the same glyphs swaync used.
    readonly property string barIcon: root.dnd
        ? (root.count > 0 ? "󰂛" : "󰪑")
        : (root.count > 0 ? "󰂚" : "󰂜")

    function removePopup(n) {
        root.popups = root.popups.filter(function (x) {
            return x !== n;
        });
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
    }
    function toggleCenter() {
        root.centerVisible = !root.centerVisible;
    }
    function toggleDnd() {
        root.dnd = !root.dnd;
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
            // A toast only shows up with DND off (Critical pierces DND).
            if (!root.dnd || n.urgency === NotificationUrgency.Critical)
                root.popups = root.popups.concat([n]);
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
        // The history's count, for the lock screen (qs ipc call notif count).
        function count(): string {
            return "" + root.count;
        }
    }
}
