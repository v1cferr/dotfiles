pragma Singleton
// Serviço de notificações — o Quickshell vira o daemon org.freedesktop.Notifications
// (substitui o swaync). Guarda o estado (DND, toasts ativos, histórico) e expõe IPC:
//   qs ipc call notif toggle   -> abre/fecha a central
//   qs ipc call notif dnd      -> alterna Não Perturbe
//   qs ipc call notif clear    -> limpa o histórico
// UI em Notifications.qml; a barra lê Notifs.barIcon / Notifs.count / Notifs.dnd.
import Quickshell
import Quickshell.Io
import Quickshell.Services.Notifications
import QtQuick

Singleton {
    id: root

    // ===== Estado =====
    property bool dnd: false
    property bool centerVisible: false
    // Toasts atualmente na tela (objetos Notification; vivos porque ficam tracked).
    property var popups: []

    // Histórico = notificações rastreadas pelo servidor (UntypedObjectModel).
    readonly property var history: server.trackedNotifications
    readonly property int count: server.trackedNotifications ? server.trackedNotifications.values.length : 0

    // Ícone do sino na barra — mesmos glyphs que o swaync usava.
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
            // tracked = true mantém o objeto vivo e o coloca no histórico.
            n.tracked = true;
            // Toast só aparece com DND desligado (Critical fura o DND).
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
        // Contagem do histórico p/ a tela de bloqueio (qs ipc call notif count).
        function count(): string {
            return "" + root.count;
        }
    }
}
