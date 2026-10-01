// The VERDICT badge: the outlined chip that answers "is this fine?" without reading the rows below.
import QtQuick
import "root:/"

Rectangle {
    id: badge
    property string label: ""
    property color accent: Theme.colDim

    implicitWidth: txt.implicitWidth + 18
    implicitHeight: 20
    radius: 6
    color: "transparent"
    border.color: badge.accent
    border.width: 1

    Text {
        id: txt
        anchors.centerIn: parent
        text: badge.label
        color: badge.accent
        font.family: Theme.uiFont
        font.pixelSize: 10
    }
}
