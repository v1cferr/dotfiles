// The NixOS Center's HEAD: its name left of the logo and its three switches right of it (the idle
// timeouts, do-not-disturb, clear), on the row the island's capsule was.
// The island's window places it; the logo between the two halves is not its to draw.
// docs/notes/desktop/nixos-center.md
import QtQuick
import QtQuick.Layouts
import "root:/"
import "root:/widgets"

RowLayout {
    id: head
    required property var bar
    property Item tips: null // the island's GlassTip
    spacing: Theme.sp1

    // As tall as the capsule it stands in for, so the row keeps the bar's rhythm.
    component HeadButton: IconButton {
        implicitWidth: Theme.barCell
        implicitHeight: Theme.barCell
    }

    Text {
        Layout.fillWidth: true
        text: "NixOS Center"
        color: Theme.colSubtext
        font.family: Theme.uiFont
        font.pixelSize: Theme.fontLabel
        font.letterSpacing: 1
        elide: Text.ElideRight
    }
    HeadButton {
        // hypridle: on is the normal state. Off shows on the bar too, so it is never forgotten.
        glyph: head.bar.hypridleIcon
        tint: head.bar.hypridleOn ? Theme.colSubtext : Theme.colWarn
        active: !head.bar.hypridleOn
        tips: head.tips
        name: "Idle timeouts"
        stateText: head.bar.hypridleOn ? "Enabled: the screens lock and sleep on idle" : "Disabled: nothing happens on idle"
        action: head.bar.hypridleOn ? "Click to disable" : "Click to enable"
        onClicked: head.bar.toggleIdle()
    }
    HeadButton {
        glyph: Notifs.dnd ? "󰂛" : "󰂚"
        tint: Notifs.dnd ? Theme.colAlert : Theme.colSubtext
        active: Notifs.dnd
        tips: head.tips
        name: "Do Not Disturb"
        stateText: Notifs.dnd ? "Enabled: toasts are held, critical ones still show" : "Disabled"
        action: Notifs.dnd ? "Click to disable" : "Click to enable"
        onClicked: Notifs.toggleDnd()
    }
    HeadButton {
        glyph: "󰎟"
        tint: Theme.colSubtext
        enabled: Notifs.count > 0
        tips: head.tips
        name: "Clear notifications"
        stateText: Notifs.count > 0 ? Notifs.count + " in the history" : "Nothing to clear"
        action: Notifs.count > 0 ? "Click to clear them all" : ""
        onClicked: Notifs.clearAll()
    }
}
