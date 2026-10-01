// The HORIZON: the last 2 minutes of CPU along the band's bottom edge, which is also the line where
// the work area starts. Why it SCROLLS instead of morphing: docs/notes/desktop/bar.md
import QtQuick
import "root:/"

Item {
    id: horizon

    property var series: []
    property int window: 60 // the sample count the width is cut into, full or not
    property int period: 2000 // the source's interval: the slide has to last exactly one sample
    property real scaleTop: 100
    property color tint: Theme.colBlue
    property color edge: Theme.colSky // the newest sample, so "now" reads without counting bars
    property string caption: ""

    readonly property int count: horizon.series ? horizon.series.length : 0
    // window - 1 and not window: the track has to be exactly ONE step wider than the viewport, or
    // the left edge shows a sliver of nothing at the start of every cycle.
    readonly property real step: horizon.width / Math.max(1, horizon.window - 1)

    // The ONE animated property. A new sample shifts the data one step to the LEFT, so the track
    // jumps one step RIGHT at that same instant and walks back: the pixels never jump, they flow.
    property real slide: 0

    implicitHeight: 60
    clip: true

    onSeriesChanged: flow.restart()

    NumberAnimation {
        id: flow
        target: horizon
        property: "slide"
        from: horizon.step
        to: 0
        duration: horizon.period
        easing.type: Easing.Linear
    }

    Row {
        id: track
        height: parent.height
        spacing: 2
        // Right-aligned: "now" stays at the right edge while the history is still filling in.
        x: horizon.width - horizon.count * horizon.step + horizon.slide

        Repeater {
            model: horizon.series

            delegate: Item {
                id: sample
                required property var modelData
                required property int index

                readonly property bool newest: sample.index === horizon.count - 1
                // A sample with no reading is a FULL faded bar: a hole has to jump out, not vanish.
                readonly property bool dead: sample.modelData === null || sample.modelData === undefined || isNaN(sample.modelData)
                readonly property color base: sample.dead ? Theme.colRed : (sample.newest ? horizon.edge : horizon.tint)

                width: horizon.step - track.spacing
                height: track.height

                Rectangle {
                    anchors.bottom: parent.bottom
                    width: parent.width
                    radius: 2
                    height: sample.dead ? parent.height : Math.max(3, parent.height * Math.min(1, sample.modelData / horizon.scaleTop))

                    // Bright at the crest and nearly gone at the base, so the eye follows the TOP
                    // edge, which is the shape of the reading. The height never animates, so the
                    // gradient is baked ONCE per sample instead of every frame.
                    gradient: Gradient {
                        GradientStop {
                            position: 0
                            color: Qt.rgba(sample.base.r, sample.base.g, sample.base.b, sample.dead ? 0.5 : 0.95)
                        }
                        GradientStop {
                            position: 1
                            color: Qt.rgba(sample.base.r, sample.base.g, sample.base.b, sample.dead ? 0.2 : 0.1)
                        }
                    }
                }
            }
        }
    }

    // It is CPU and not audio, and a graph with no label invites the wrong guess.
    Text {
        anchors.left: parent.left
        anchors.top: parent.top
        text: horizon.caption
        color: Theme.colDim
        font.family: Theme.uiFont
        font.pixelSize: 10
        font.letterSpacing: 2
    }
}
