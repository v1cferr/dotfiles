// A part that ENTERS a panel already open (a page, the media card unfolding) comes in on the same
// short ease the panel's glass takes to its new size, so the two arrive together.
// docs/notes/desktop/motion.md#the-island
import QtQuick
import "root:/"

NumberAnimation {
    property: "opacity"
    from: 0
    to: 1
    duration: Theme.motionNormal
    easing.type: Easing.OutCubic
}
