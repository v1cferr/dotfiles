// A quiet text row that leaves the Control Center for a fuller surface (the NixOS Center, a mixer).
import QtQuick
import QtQuick.Layouts
import "root:/"
import "root:/widgets"

Rectangle {
    id: link
    property string label: ""
    property string mark: "arrow_outward" // a Material Symbols name: what the row does
    signal clicked
    Layout.fillWidth: true
    implicitHeight: Theme.barControl
    radius: Theme.radiusControl
    color: area.pressed ? Theme.colPressFill : (area.containsMouse ? Theme.colHoverFill : "transparent")
    Accessible.role: Accessible.Button
    Accessible.name: link.label
    Text {
        anchors.verticalCenter: parent.verticalCenter
        x: Theme.sp2
        text: link.label
        color: Theme.colSubtext
        font.family: Theme.uiFont
        font.pixelSize: Theme.fontBody
    }
    Text {
        anchors.verticalCenter: parent.verticalCenter
        anchors.right: parent.right
        anchors.rightMargin: Theme.sp2
        text: link.mark
        color: Theme.colDim
        font.family: Theme.iconFont
        font.pixelSize: Theme.iconBar
        font.variableAxes: Theme.iconAxes
    }
    MouseArea {
        id: area
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: link.clicked()
    }
    KeyTarget {
        onActivated: link.clicked()
    }
}
