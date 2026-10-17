// The weather behind today's glyph: drops while it rains, a glow while the sun is out, nothing
// otherwise. It MOVES for 8 s when that sky begins, then holds still: docs/notes/desktop/dash.md
import QtQuick
import "root:/"

Item {
    id: amb

    property int code: -1
    property bool day: true

    // WMO groups: drizzle, rain and showers, thunderstorms.
    readonly property bool raining: (amb.code >= 51 && amb.code <= 67) || (amb.code >= 80 && amb.code <= 82) || amb.code >= 95
    readonly property bool sunny: amb.day && (amb.code === 0 || amb.code === 1)

    // A loop that never stops kept the whole band repainting every frame (measured: docs/notes/
    // desktop/dash.md). The motion now plays when the sky changes, and what it leaves is the cue.
    readonly property bool playing: !Theme.motionReduced && !settle.done && (amb.raining || amb.sunny)
    Timer {
        id: settle
        property bool done: false
        interval: 8000
        running: (amb.raining || amb.sunny) && !settle.done
        onTriggered: settle.done = true
    }
    onRainingChanged: settle.done = false
    onSunnyChanged: settle.done = false

    // ── Sun: a soft disc that breathes, behind the glyph ──
    Rectangle {
        anchors.centerIn: parent
        width: 84
        height: 84
        radius: 42
        visible: amb.sunny
        color: Theme.colYellow
        opacity: 0.12 // the still glow, mid-breath
        SequentialAnimation on opacity {
            running: amb.sunny && amb.playing
            loops: Animation.Infinite
            NumberAnimation {
                from: 0.06
                to: 0.18
                duration: 2600
                easing.type: Easing.InOutSine
            }
            NumberAnimation {
                from: 0.18
                to: 0.06
                duration: 2600
                easing.type: Easing.InOutSine
            }
        }
        SequentialAnimation on scale {
            running: amb.sunny && amb.playing
            loops: Animation.Infinite
            NumberAnimation {
                from: 0.92
                to: 1.06
                duration: 2600
                easing.type: Easing.InOutSine
            }
            NumberAnimation {
                from: 1.06
                to: 0.92
                duration: 2600
                easing.type: Easing.InOutSine
            }
        }
    }

    // ── Rain: a handful of drops, each on its own phase so they never fall in step ──
    Item {
        anchors.fill: parent
        visible: amb.raining
        clip: true
        Repeater {
            model: 9
            delegate: Rectangle {
                required property int index
                width: 2
                height: 12
                radius: 1
                color: Theme.colSky
                opacity: 0.45
                x: 8 + (index * 37) % (amb.width - 16)
                // Still, each drop rests at its own height, so the picture reads as rain.
                y: (index * 29) % Math.max(1, amb.height - 12)
                rotation: 12
                NumberAnimation on y {
                    running: amb.raining && amb.playing
                    loops: Animation.Infinite
                    from: -12 - (index * 11) % 40
                    to: amb.height
                    duration: 900 + (index * 137) % 500
                }
            }
        }
    }
}
