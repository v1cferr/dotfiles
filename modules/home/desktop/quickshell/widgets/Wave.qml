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

    property int bar: 2
    property int gap: 2
    readonly property int count: Math.max(0, Math.floor((wave.width + wave.gap) / (wave.bar + wave.gap)))
    // The level is looked at every `look` ms, and a bar holds `hold` looks: the loudest of them.
    readonly property int look: 40
    readonly property int hold: 2
    property var past: [] // each bar's share of the height, 0 to 1, as it was drawn
    property real now: 0
    property int looks: 0
    // The loudest and the quietest heard lately, each drifting back toward what plays: a bar is
    // drawn between the two, so a dense track and a sparse one both move over the whole height,
    // and a bar once drawn keeps its size.
    property real loud: 0
    property real soft: 0
    readonly property real silence: 0.02
    onRunningChanged: if (!wave.running) {
        wave.past = [];
        wave.now = 0;
        wave.looks = 0;
        wave.loud = 0;
        wave.soft = 0;
    }
    function share(v) {
        if (v < wave.silence)
            return 0;
        // Never a window narrower than a fifth of the loudest: a steady tone is not a storm.
        const span = Math.max(wave.loud - wave.soft, 0.2 * wave.loud);
        return 0.15 + 0.85 * Math.max(0, Math.min(1, (v - (wave.loud - span)) / span));
    }
    Timer {
        interval: wave.look
        repeat: true
        running: wave.running && wave.count > 0 && wave.read !== null
        onTriggered: {
            const v = wave.read();
            if (wave.loud === 0) {
                // The first sound: a guess at the window, until the track teaches the real one.
                wave.loud = v;
                wave.soft = 0.6 * v;
            } else {
                wave.loud = v > wave.loud ? v : wave.loud + (v - wave.loud) * 0.005;
                wave.soft = v < wave.soft ? v : wave.soft + (v - wave.soft) * 0.02;
            }
            if (wave.looks < wave.hold) {
                wave.now = Math.max(wave.now, wave.share(v));
                wave.looks++;
                return;
            }
            const p = wave.past.slice(-(wave.count - 1));
            p.push(wave.now);
            wave.past = p;
            wave.now = wave.share(v);
            wave.looks = 1;
        }
    }
    function tall(part) {
        return Math.max(wave.bar, Math.round(part * wave.height));
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
