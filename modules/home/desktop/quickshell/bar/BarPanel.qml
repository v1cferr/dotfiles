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
    readonly property bool pinned: panel.bar.pinned === panel.key

    visible: panel.ready && panel.bar.panelOpen === panel.key
    screen: panel.bar.popScreen || panel.bar.screenPrimary
    WlrLayershell.namespace: "qs-panel"
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

    // The bar is in the grab, so a click on another pill SWITCHES panels instead of only closing.
    HyprlandFocusGrab {
        active: panel.visible && panel.pinned
        windows: panel.bar.popBar ? [panel, panel.bar.popBar] : [panel]
        onCleared: if (panel.pinned)
            panel.bar.closePanels()
    }
    Item {
        focus: true
        Keys.onEscapePressed: panel.bar.closePanels()
    }
}
