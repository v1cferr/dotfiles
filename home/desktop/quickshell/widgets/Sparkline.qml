// The history graph: one bar per sample, the most recent on the RIGHT, and the scale ALWAYS starts
// at zero. Why zero, and why a hole is a full red bar: docs/notes/desktop/bar.md
import QtQuick
import QtQuick.Layouts
import "root:/"

Item {
    id: spark
    property var series: []
    property real scaleTop: 100
    property color fill: Theme.colTeal
    property string placeholder: "measuring…"
    property bool downward: false // the bars hang from the top (the mirrored half of a graph)

    readonly property int count: spark.series ? spark.series.length : 0
    implicitHeight: 40

    Text {
        anchors.centerIn: parent
        visible: spark.count < 2
        text: spark.placeholder
        color: Theme.colDim
        font.family: Theme.uiFont
        font.pixelSize: 11
        font.italic: true
    }

    RowLayout {
        anchors.fill: parent
        visible: spark.count >= 2
        spacing: 1

        Repeater {
            model: spark.series

            delegate: Item {
                id: sample
                required property var modelData
                // A sample with no reading is a FULL faded bar: the hole has to jump out, not vanish.
                // The test is broad because a null can reach the delegate as undefined.
                readonly property bool dead: sample.modelData === null || sample.modelData === undefined || isNaN(sample.modelData)

                Layout.fillWidth: true
                Layout.fillHeight: true

                Rectangle {
                    anchors.top: spark.downward ? parent.top : undefined
                    anchors.bottom: spark.downward ? undefined : parent.bottom
                    width: parent.width
                    height: sample.dead ? parent.height : Math.max(2, parent.height * Math.min(1, sample.modelData / spark.scaleTop))
                    radius: 1
                    opacity: sample.dead ? 0.45 : 1
                    color: sample.dead ? Theme.colRed : spark.fill
                }
            }
        }
    }
}
