// A popover's ENTRANCE: the card drops 6 px out of the bar while Hyprland fades the layer in. It
// replays on SHOW only, never on a content change. Usage and why: docs/notes/desktop/motion.md
import QtQuick
import "root:/"

NumberAnimation {
    id: popIn
    property bool shown: false // bind it to the window's visible
    property: "y" // of the Translate passed as `target`
    from: -6
    to: 0
    duration: Theme.motionNormal
    easing.type: Easing.OutCubic
    onShownChanged: if (popIn.shown)
        popIn.restart()
}
