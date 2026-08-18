// A StatRow plus the bar that turns the number into a shape: the eye reads "how full" before it
// reads the digits. `frac` is already normalized against the row's OWN limit, never against 100.
import QtQuick
import QtQuick.Layouts
import "root:/"

ColumnLayout {
    id: meter
    property alias label: row.label
    property alias value: row.value
    property alias hint: row.hint
    property alias labelWidth: row.labelWidth
    property real frac: 0
    property color barColor: Theme.colAccent

    Layout.fillWidth: true
    spacing: 3

    StatRow {
        id: row
        valueColor: meter.barColor
    }
    Rectangle {
        Layout.fillWidth: true
        implicitHeight: 5
        radius: 2.5
        color: Theme.colTrack
        Rectangle {
            width: parent.width * Math.max(0, Math.min(1, meter.frac))
            height: parent.height
            radius: parent.radius
            color: meter.barColor
            Behavior on width {
                NumberAnimation {
                    duration: 300
                    easing.type: Easing.OutCubic
                }
            }
        }
    }
}
