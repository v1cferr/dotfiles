// The HORIZON: the last 2 minutes of CPU along the band's bottom edge, which is also the line where
// the work area starts. Why it is the divider and not a rule: docs/notes/desktop/bar.md
import QtQuick
import QtQuick.Layouts
import "root:/"

Item {
    id: horizon

    property var series: []
    property real scaleTop: 100
    property color tint: Theme.colBlue
    property color edge: Theme.colSky // the newest sample, so "now" reads without counting bars
    property string caption: ""

    readonly property int count: horizon.series ? horizon.series.length : 0
    implicitHeight: 60

    RowLayout {
        anchors.fill: parent
        spacing: 2

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

                Layout.fillWidth: true
                Layout.fillHeight: true

                Rectangle {
                    anchors.bottom: parent.bottom
                    width: parent.width
                    radius: 2
                    height: sample.dead ? parent.height : Math.max(3, parent.height * Math.min(1, sample.modelData / horizon.scaleTop))

                    // Bright at the crest and nearly gone at the base: the eye follows the TOP edge,
                    // which is the shape of the reading, instead of a wall of solid color.
                    gradient: Gradient {
                        GradientStop {
                            position: 0
                            color: Qt.rgba(sample.base.r, sample.base.g, sample.base.b, sample.dead ? 0.5 : 0.95)
                        }
                        GradientStop {
                            position: 1
                            color: Qt.rgba(sample.base.r, sample.base.g, sample.base.b, sample.dead ? 0.2 : 0.12)
                        }
                    }

                    Behavior on height {
                        NumberAnimation {
                            duration: 220
                            easing.type: Easing.OutCubic
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
