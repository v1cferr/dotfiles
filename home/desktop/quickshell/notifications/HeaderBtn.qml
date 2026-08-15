// A header button of the notification center (DND, Clear).
// Its own file (not inline) so the MouseArea's handler can see the root's id on this Qt: in an
// inline component the id does not resolve inside a handler.
import QtQuick
import "root:/"

Rectangle {
    id: hb
    property string text: ""
    property bool active: false
    signal clicked

    implicitWidth: hbLabel.implicitWidth + 18
    implicitHeight: 26
    radius: 8
    opacity: hb.enabled ? 1 : 0.4
    color: hbArea.containsMouse ? Theme.colHoverBg : "transparent"
    Behavior on color {
        ColorAnimation {
            duration: Theme.hoverAnim
            easing.type: Easing.OutQuad
        }
    }
    border.color: hb.active ? Theme.colPeach : Theme.colBorder
    border.width: 1

    Text {
        id: hbLabel
        anchors.centerIn: parent
        text: hb.text
        color: hb.active ? Theme.colPeach : Theme.colText
        font.family: Theme.uiFont
        font.pixelSize: 11
    }
    MouseArea {
        id: hbArea
        anchors.fill: parent
        hoverEnabled: true
        onClicked: hb.clicked()
    }
}
