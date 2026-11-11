// The notification STATE on the bar: a bell that exists only while there is one to show, do-not-disturb
// on or notifications not seen yet. It reads Notifs, the one owner. docs/notes/desktop/bar.md
import QtQuick
import "root:/"
import "root:/widgets"

Pill {
    id: bell
    required property var host // the Bar's Scope: the hint goes through it
    property var barContent: null
    property var barWindow: null
    readonly property bool active: Notifs.dnd || Notifs.unseen > 0

    icon: Notifs.dnd ? "notifications_off" : "notifications"
    label: Notifs.unseen > 0 ? (Notifs.unseen > 9 ? "9+" : "" + Notifs.unseen) : ""
    accent: Notifs.dnd ? Theme.colAlert : (Notifs.unseenCritical ? Theme.colCrit : Theme.colAccent)
    labelColor: Theme.colText
    selected: bell.host.pinned === "center"
    onHoveredChanged: bell.host.hoverHint("notif", bell, bell.barContent, bell.barWindow, hovered)
    // The Center hangs from the logo whoever asks for it, so it opens through the service's own toggle.
    onClicked: {
        bell.host.hideHint();
        Notifs.toggleCenter();
    }
    onRightClicked: Notifs.toggleDnd()
}
