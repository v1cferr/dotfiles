// The weather, ALIVE behind today's glyph: drops falling while it rains, a slow glow while the sun
// is out, nothing otherwise. Cheap by design (a few rectangles, no shader), because the band
// already repaints every frame for the horizon. Why only these two: docs/notes/desktop/dash.md
import QtQuick
import "root:/"

Item {
    id: amb

    property int code: -1
    property bool day: true

    // WMO groups: drizzle, rain and showers, thunderstorms.
    readonly property bool raining: (amb.code >= 51 && amb.code <= 67) || (amb.code >= 80 && amb.code <= 82) || amb.code >= 95
    readonly property bool sunny: amb.day && (amb.code === 0 || amb.code === 1)

    // ── Sun: a soft disc that breathes, behind the glyph ──
    Rectangle {
        anchors.centerIn: parent
        width: 84
        height: 84
        radius: 42
        visible: amb.sunny
        color: Theme.colYellow
        opacity: 0.0
        SequentialAnimation on opacity {
            running: amb.sunny
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
            running: amb.sunny
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
                y: -height
                rotation: 12
                NumberAnimation on y {
                    running: amb.raining
                    loops: Animation.Infinite
                    from: -12 - (index * 11) % 40
                    to: amb.height
                    duration: 900 + (index * 137) % 500
                }
            }
        }
    }
}
