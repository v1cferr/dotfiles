// The HORIZON: the last 2 minutes of CPU along the band's bottom edge, which is also the line where
// the work area starts. Why it SCROLLS, and why it now explains itself: docs/notes/desktop/dash.md
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
    property string nowText: "" // the reading at the right edge, said in words and not left to the eye

    readonly property int count: horizon.series ? horizon.series.length : 0
    // window - 1 and not window: the track has to be exactly ONE step wider than the viewport, or
    // the left edge shows a sliver of nothing at the start of every cycle.
    readonly property real step: plot.width / Math.max(1, horizon.window - 1)

    // The ONE animated property. A new sample shifts the data one step to the LEFT, so the track
    // jumps one step RIGHT at that same instant and walks back: the pixels never jump, they flow.
    property real slide: 0

    implicitHeight: 104

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

    // ── What it is (left) and what it reads now (right): the graph never has to be decoded ──
    Text {
        id: cap
        anchors.left: parent.left
        anchors.top: parent.top
        text: horizon.caption
        color: Theme.colSubtext
        font.family: Theme.uiFont
        font.pixelSize: 13
        font.letterSpacing: 2
    }
    Text {
        anchors.right: parent.right
        anchors.baseline: cap.baseline
        text: horizon.nowText
        color: horizon.edge
        font.family: Theme.uiFont
        font.pixelSize: 15
        font.bold: true
    }

    Item {
        id: plot
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.top: cap.bottom
        anchors.topMargin: 8
        clip: true

        // The ruler, drawn UNDER the bars: the ceiling and its half, each labelled, so the adaptive
        // scale is visible instead of a number in the caption nobody connects to the bars.
        Repeater {
            model: [1, 0.5]
            delegate: Item {
                required property real modelData
                width: plot.width
                height: 1
                y: plot.height * (1 - modelData)
                Rectangle {
                    anchors.fill: parent
                    color: Theme.colBorder
                    opacity: 0.45
                }
                Text {
                    anchors.left: parent.left
                    anchors.top: parent.bottom
                    anchors.topMargin: 2
                    text: Math.round(horizon.scaleTop * parent.modelData) + "%"
                    color: Theme.colDim
                    font.family: Theme.uiFont
                    font.pixelSize: 10
                }
            }
        }
        // Time, fixed while the data flows under it: the middle of the window is one minute ago.
        Rectangle {
            x: plot.width / 2
            width: 1
            height: plot.height
            color: Theme.colBorder
            opacity: 0.3
        }
        Text {
            x: plot.width / 2 + 4
            y: 3
            text: "−1 min"
            color: Theme.colDim
            font.family: Theme.uiFont
            font.pixelSize: 10
        }

        Row {
            id: track
            height: parent.height
            spacing: 2
            // Right-aligned: "now" stays at the right edge while the history is still filling in.
            x: plot.width - horizon.count * horizon.step + horizon.slide

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
    }
}
