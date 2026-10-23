// The pin beside a carousel's dots: a click holds the page until the next click. Lit while held.
import QtQuick
import "root:/"

Text {
    id: pin
    property bool pinned: false

    text: pin.pinned ? "󰐃" : "󰤱"
    color: pin.pinned || area.containsMouse ? Theme.colAccent : Theme.colSubtext
    font.family: Theme.uiFont
    font.pixelSize: 15

    MouseArea {
        id: area
        anchors.fill: parent
        anchors.margins: -8
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: pin.pinned = !pin.pinned
    }
}
