pragma Singleton
// The band's tooltip state: which Tip is under the pointer, and when its card shows. It opens after
// 350 ms of rest (a pointer only crossing the band shows nothing), and for 300 ms after one closes
// a neighbour opens at once, the "warm window". Why: docs/notes/desktop/dash.md
import Quickshell
import QtQuick

Singleton {
    id: root

    property var target: null // the Tip item being shown, or about to be
    property bool shown: false

    function show(tip) {
        root.target = tip;
        if (warm.running) {
            warm.stop();
            root.shown = true;
        } else {
            root.shown = false;
            delay.restart();
        }
    }
    function hide(tip) {
        if (root.target !== tip)
            return;
        delay.stop();
        if (root.shown)
            warm.restart();
        root.shown = false;
        root.target = null;
    }

    Timer {
        id: delay
        interval: 350
        onTriggered: root.shown = root.target !== null
    }
    Timer {
        id: warm
        interval: 300
    }
}
