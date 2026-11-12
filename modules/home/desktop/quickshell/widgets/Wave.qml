// What is heard, as bars that rise and fall in place: one level per band, bass first. It only
// draws what it is given (Audio.bands, from cava), so it has no clock of its own.
// docs/notes/desktop/island.md#the-wave
import QtQuick
import "root:/"

Item {
    id: wave
    property var bands: [] // 0 to 1 each, bass first
    // Mirrored, the bass is in the middle and the treble at both ends; else the bass is at the right.
    property bool mirror: false
    property color color: Theme.colSubtext
    property int bar: 3
    property int gap: 2

    // As many bars as fit; mirrored, one fewer when that leaves the two margins unequal.
    readonly property int fit: Math.max(0, Math.floor((wave.width + wave.gap) / (wave.bar + wave.gap)))
    readonly property int count: (wave.mirror && wave.fit > 0 && (wave.width - wave.span(wave.fit)) % 2 !== 0) ? wave.fit - 1 : wave.fit
    function span(n) {
        return n * (wave.bar + wave.gap) - wave.gap;
    }
    // The level `far` of the way from the bass (0) to the treble (1), between the two bands around it.
    function level(far) {
        const n = wave.bands.length;
        if (n === 0)
            return 0;
        const at = Math.max(0, Math.min(1, far)) * (n - 1);
        const lo = Math.floor(at);
        const hi = Math.min(n - 1, lo + 1);
        return wave.bands[lo] + (wave.bands[hi] - wave.bands[lo]) * (at - lo);
    }
    Row {
        x: wave.mirror ? (wave.width - width) / 2 : wave.width - width
        anchors.verticalCenter: parent.verticalCenter
        height: parent.height
        spacing: wave.gap
        Repeater {
            model: wave.count
            Rectangle {
                required property int index
                readonly property real far: wave.count < 2 ? 0 : (wave.mirror ? Math.abs(2 * index - (wave.count - 1)) / (wave.count - 1) : (wave.count - 1 - index) / (wave.count - 1))
                anchors.verticalCenter: parent.verticalCenter
                width: wave.bar
                // Never shorter than it is wide: silence is a row of dots. cava keeps the loudest
                // band near the top and the rest low; the power lifts the rest into view.
                height: Math.max(wave.bar, Math.round(Math.pow(wave.level(far), 0.7) * wave.height))
                radius: wave.bar / 2
                color: wave.color
            }
        }
    }
}
