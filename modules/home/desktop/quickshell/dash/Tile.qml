// One vital at glance size: the label names it, the value carries it, the bar shapes it and the hint
// is the context. MeterRow is the popover's version, sized for a hover and too small at 2 m.
import QtQuick
import QtQuick.Layouts
import "root:/"

ColumnLayout {
    id: tile
    property string label: ""
    property string value: ""
    property string hint: ""
    property real frac: 0
    property color barColor: Theme.colAccent
    // A NUMBER rolls to its new value instead of jumping; `value` stays for what cannot roll (NET).
    property real number: NaN
    property string unit: ""
    property real shown: 0
    Behavior on shown {
        NumberAnimation {
            duration: 650
            easing.type: Easing.OutCubic
        }
    }
    onNumberChanged: if (!isNaN(tile.number))
        tile.shown = tile.number
    // Past its limit the value breathes until it is back, so a hot tile is seen from the corner of an eye.
    property bool alert: false

    // Equal columns: a zero preferred width leaves fillWidth to split the row evenly.
    Layout.fillWidth: true
    Layout.preferredWidth: 0
    spacing: 4

    Text {
        text: tile.label
        color: Theme.colSubtext
        font.family: Theme.uiFont
        font.pixelSize: 13
        font.bold: true
        font.letterSpacing: 3
    }
    Text {
        Layout.fillWidth: true
        text: isNaN(tile.number) ? tile.value : Math.round(tile.shown) + tile.unit
        color: tile.barColor
        SequentialAnimation on opacity {
            running: tile.alert
            loops: Animation.Infinite
            alwaysRunToEnd: true
            NumberAnimation {
                to: 0.4
                duration: 600
                easing.type: Easing.InOutSine
            }
            NumberAnimation {
                to: 1
                duration: 600
                easing.type: Easing.InOutSine
            }
        }
        font.family: Theme.uiFont
        font.pixelSize: 36
        font.bold: true
        font.letterSpacing: -1
        elide: Text.ElideRight
    }
    Rectangle {
        Layout.fillWidth: true
        Layout.topMargin: 2
        implicitHeight: 6
        radius: 3
        color: Theme.colTrack
        Rectangle {
            width: parent.width * Math.max(0, Math.min(1, tile.frac))
            height: parent.height
            radius: parent.radius
            color: tile.barColor
            Behavior on width {
                NumberAnimation {
                    duration: 300
                    easing.type: Easing.OutCubic
                }
            }
        }
    }
    Text {
        Layout.fillWidth: true
        Layout.topMargin: 2
        text: tile.hint
        color: Theme.colDim
        font.family: Theme.uiFont
        font.pixelSize: 14
        elide: Text.ElideRight
    }
}
