// A clickable surface's KEYBOARD half: placed inside it, it joins the Tab chain, answers Enter and
// Space like a click, walks the chain with the arrows and draws the focus ring over its parent.
// The panel keys, and why the arrows are linear: docs/notes/desktop/nixos-center.md
import QtQuick
import "root:/"

Item {
    id: target
    signal activated
    signal deleted // Delete or Backspace, for what a card can dismiss
    anchors.fill: parent
    activeFocusOnTab: true

    Keys.onPressed: event => {
        switch (event.key) {
        case Qt.Key_Return:
        case Qt.Key_Enter:
        case Qt.Key_Space:
            target.activated();
            break;
        case Qt.Key_Delete:
        case Qt.Key_Backspace:
            target.deleted();
            break;
        case Qt.Key_Right:
        case Qt.Key_Down:
            target.nextItemInFocusChain(true).forceActiveFocus(Qt.TabFocusReason);
            break;
        case Qt.Key_Left:
        case Qt.Key_Up:
            target.nextItemInFocusChain(false).forceActiveFocus(Qt.BacktabFocusReason);
            break;
        default:
            return;
        }
        event.accepted = true;
    }

    // Only with the keyboard: a click focuses nothing (no MouseArea takes focus), so no stray ring.
    // `focus`, not `activeFocus`, which drops while the keyboard is re-entered; the Center hands
    // the focus back to the panel on every open, so no ring is left over.
    Rectangle {
        anchors.fill: parent
        radius: target.parent ? target.parent.radius || 0 : 0
        color: "transparent"
        border.width: 2
        border.color: Theme.colAccent
        visible: target.focus
    }
}
