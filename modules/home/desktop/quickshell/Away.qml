pragma Singleton
// The away screen's state: black on every monitor, the keyboard's and mouse's LEDs dark and the
// notifications held. Enter brings it back through the `away` submap in keybinds.lua.
// IPC: `qs ipc call away on|off|toggle`. The windows are away/AwayScreen.qml.
// Why black and not off: docs/notes/desktop/away.md
import Quickshell
import Quickshell.Io
import QtQuick

Singleton {
    id: root

    property bool active: false
    // The DND from before, so leaving restores it instead of forcing it off.
    property bool dndBefore: false

    function enter() {
        if (root.active)
            return;
        root.dndBefore = Notifs.dnd;
        Notifs.dnd = true; // a toast would light the screen up
        root.active = true;
        Quickshell.execDetached(["hyprctl", "dispatch", 'hl.dsp.submap("away")']);
        Quickshell.execDetached(["rgb-lights", "off"]); // modules/nixos/hardware/peripheral-rgb.nix
    }

    function leave() {
        if (!root.active)
            return;
        root.active = false;
        Quickshell.execDetached(["hyprctl", "dispatch", 'hl.dsp.submap("reset")']);
        Notifs.dnd = root.dndBefore;
        Quickshell.execDetached(["rgb-lights", "on"]);
    }

    function toggle() {
        root.active ? root.leave() : root.enter();
    }

    IpcHandler {
        target: "away"
        function on(): void {
            root.enter();
        }
        function off(): void {
            root.leave();
        }
        function toggle(): void {
            root.toggle();
        }
    }
}
