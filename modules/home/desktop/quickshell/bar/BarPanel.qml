// A panel the bar opens: hung under its pill, one at a time through the Bar's coordinator, and when
// a click PINS it, a click outside or Escape closes it. The rules: docs/notes/desktop/bar.md
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import QtQuick
import "root:/"

PanelWindow {
    id: panel
    required property var bar
    property string key: "" // its name in the coordinator: weather, cal, temp, usage, net, vpn
    property bool ready: true // false while it has nothing to show (the weather before its first read)
    property string layerNamespace: "qs-panel" // the NixOS Center's is its own: a capture waits for it
    readonly property bool pinned: panel.bar.pinned === panel.key
    // A key while pinned, offered to the panel first (the calendar's arrows); one it leaves
    // unaccepted falls through, Escape closing.
    signal keyPressed(var event)

    visible: panel.ready && panel.bar.panelOpen === panel.key
    screen: panel.bar.popScreen || panel.bar.screenPrimary
    WlrLayershell.namespace: panel.layerNamespace
    // The keyboard only while pinned: a hover panel must never take it from the window under it.
    WlrLayershell.keyboardFocus: panel.pinned ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None
    anchors {
        top: true
        left: true
    }
    // Placed from the screen's edge, sp1 under the bar, so a band screen's strip never pushes it down.
    exclusionMode: ExclusionMode.Ignore
    margins {
        top: Theme.bandTop
        left: panel.bar.popLeft(panel.implicitWidth)
    }
    color: "transparent"

    // EVERY bar is in the grab, so a click on another pill SWITCHES panels, and on the other
    // monitor's bar MOVES it, instead of only closing (outside the grab the click is consumed).
    HyprlandFocusGrab {
        active: panel.visible && panel.pinned
        windows: [panel].concat(Object.values(panel.bar.bars))
        onCleared: if (panel.pinned)
            panel.bar.closePanels()
    }
    Item {
        focus: true
        Keys.onPressed: event => {
            panel.keyPressed(event);
            if (!event.accepted && event.key === Qt.Key_Escape) {
                panel.bar.closePanels();
                event.accepted = true;
            }
        }
    }
}
