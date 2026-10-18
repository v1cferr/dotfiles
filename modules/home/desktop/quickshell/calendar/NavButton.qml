// A small text button of the calendar's header and filters: neutral at rest, the hover fill, the
// selection fill while `active`. Its name is its accessible name.
import QtQuick
import "root:/"

Rectangle {
    id: btn
    property string label: ""
    property string name: ""
    property bool active: false
    signal clicked

    implicitWidth: txt.implicitWidth + 2 * Theme.sp3
    implicitHeight: Theme.barControl
    radius: Theme.radiusControl
    color: area.pressed ? Theme.colPressFill : (area.containsMouse ? Theme.colHoverFill : (btn.active ? Theme.colSelectFill : Qt.alpha(Theme.colText, 0.04)))
    Behavior on color {
        ColorAnimation {
            duration: Theme.motionHover
        }
    }
    Accessible.role: Accessible.Button
    Accessible.name: btn.name || btn.label
    Text {
        id: txt
        anchors.centerIn: parent
        text: btn.label
        color: Theme.colText
        font.family: Theme.uiFont
        font.pixelSize: Theme.fontBody
        font.bold: true
    }
    MouseArea {
        id: area
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: btn.clicked()
    }
}
