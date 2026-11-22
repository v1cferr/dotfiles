// A part that ENTERS a panel already open (a page, the media card unfolding) comes in on the same
// short ease the panel's glass takes to its new size, so the two arrive together. It starts from a
// part of its opacity, never from nothing: from nothing, the frame between the part that left and
// the one coming read as a blink (22/11/2026, in a recording). `slide` moves it in from the side
// it comes from, as a page pushed or popped. docs/notes/desktop/motion.md#the-island
import QtQuick
import "root:/"

ParallelAnimation {
    id: fade
    required property Item target
    property real slide: 0 // px it comes in from: + from the right, - from the left
    NumberAnimation {
        target: fade.target
        property: "opacity"
        from: 0.4
        to: 1
        duration: Theme.motionNormal
        easing.type: Easing.OutCubic
    }
    NumberAnimation {
        target: shift
        property: "x"
        from: fade.slide
        to: 0
        duration: Theme.motionNormal
        easing.type: Easing.OutCubic
    }
    // The slide moves the part, never its place in the layout.
    property Translate shift: Translate {}
    Component.onCompleted: fade.target.transform = [fade.shift]
}
