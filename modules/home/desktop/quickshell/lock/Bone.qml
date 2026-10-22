// A skeleton block: a quiet rounded shape where content will be, pulsing while it waits. The lock
// shows these until the print, the ink and the data are in, so nothing pops in from nothing.
import QtQuick
import "root:/"

Rectangle {
    id: bone

    property color tone: Qt.rgba(1, 1, 1, 0.10)
    radius: 6
    color: bone.tone

    SequentialAnimation on opacity {
        running: bone.visible
        loops: Animation.Infinite
        NumberAnimation {
            from: 1
            to: 0.45
            duration: Theme.ms(700)
            easing.type: Easing.InOutSine
        }
        NumberAnimation {
            from: 0.45
            to: 1
            duration: Theme.ms(700)
            easing.type: Easing.InOutSine
        }
    }
}
