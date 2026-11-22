pragma Singleton
// The screen's LEVEL as the shell knows it: a panel's backlight where the machine has one, else
// the compositor's gamma. `brightness-osd` (hypr.nix) owns the truth and says it here over the
// OSD's IPC; a slider asks that same script. docs/notes/desktop/nixos-center.md#the-levels
import Quickshell
import QtQuick

Singleton {
    id: root
    // What the script said last. Until it speaks, the gamma's own rest: 100 of 150.
    property int value: 100
    property int max: 150
    readonly property real level: root.max > 0 ? root.value / root.max : 0
    function said(value, max) {
        root.max = max > 0 ? max : 150;
        root.value = value;
    }
    // A slider's: the script is asked at most every 80 ms, with where the hand is by then.
    property int wanted: -1
    function set(frac) {
        root.wanted = Math.round(Math.max(0, Math.min(1, frac)) * root.max);
        root.value = root.wanted; // the slider follows the hand, the script the slider
        if (!send.running)
            send.start();
    }
    Timer {
        id: send
        interval: 80
        onTriggered: {
            Quickshell.execDetached(["brightness-osd", "set", "" + root.wanted]);
            root.wanted = -1;
        }
    }
}
