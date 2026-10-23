// The pin at the right end of a carousel's dots: a click holds the page until the next click. Lit while held.
import QtQuick
import "root:/"

GlyphText {
    id: pin
    property bool pinned: false

    text: pin.pinned ? "󰐃" : "󰤱"
    color: pin.pinned || area.containsMouse ? Theme.colAccent : Theme.colSubtext
    font.pixelSize: 20

    MouseArea {
        id: area
        anchors.fill: parent
        anchors.margins: -8
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: pin.pinned = !pin.pinned
    }
}
