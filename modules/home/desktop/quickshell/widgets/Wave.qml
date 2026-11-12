// A level's last moments as bars: the newest at the right, live, and each older one a step to the
// left. It draws what it is given and runs only while told to. docs/notes/desktop/island.md#the-wave
import QtQuick
import "root:/"

Item {
    id: wave
    property var read: null // a function giving what is heard now, 0 to 1
    property bool running: false
    property color color: Theme.colSubtext
    property color liveColor: Theme.colText

    readonly property int bar: 2
    readonly property int gap: 2
    readonly property int count: Math.max(0, Math.floor((wave.width + wave.gap) / (wave.bar + wave.gap)))
    // The level is looked at every `look` ms, and a bar holds `hold` looks: the loudest of them.
    readonly property int look: 40
    readonly property int hold: 2
    property var past: []
    property real now: 0
    property int looks: 0
    // The loudest heard lately, sinking slowly: the bars are drawn against it, so a quiet track
    // fills the height as a loud one does.
    property real loudest: wave.quiet
    readonly property real quiet: 0.05
    onRunningChanged: if (!wave.running) {
        wave.past = [];
        wave.now = 0;
        wave.looks = 0;
        wave.loudest = wave.quiet;
    }
    Timer {
        interval: wave.look
        repeat: true
        running: wave.running && wave.count > 0 && wave.read !== null
        onTriggered: {
            // The meter gives the cube root of the amplitude; the cube puts it back.
            const r = wave.read();
            const v = r * r * r;
            wave.loudest = Math.max(wave.quiet, wave.loudest * 0.995, v);
            if (wave.looks < wave.hold) {
                wave.now = Math.max(wave.now, v);
                wave.looks++;
                return;
            }
            const p = wave.past.slice(-(wave.count - 1));
            p.push(wave.now);
            wave.past = p;
            wave.now = v;
            wave.looks = 1;
        }
    }
    // Squared, a beat stands out of what is around it: mastered music barely leaves the top half.
    function tall(v) {
        const part = Math.min(1, v / wave.loudest);
        return Math.max(wave.bar, Math.round(part * part * wave.height));
    }
    Row {
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        height: parent.height
        spacing: wave.gap
        Repeater {
            model: wave.count
            Rectangle {
                required property int index
                // The last bar is the live one; the rest read the past, newest next to it.
                readonly property bool live: index === wave.count - 1
                readonly property int at: wave.past.length - (wave.count - 1 - index)
                readonly property real v: live ? wave.now : (at >= 0 && at < wave.past.length ? wave.past[at] : 0)
                anchors.verticalCenter: parent.verticalCenter
                width: wave.bar
                height: wave.tall(v)
                radius: wave.bar / 2
                color: live ? wave.liveColor : wave.color
            }
        }
    }
}
