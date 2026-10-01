// A popover's CARD: the glass, the radius, the border and the hover flag every hover panel needs.
// It was copied into 5 files, 3 of them with the palette written as a literal (rule 11).
import QtQuick
import QtQuick.Layouts
import "root:/"

Rectangle {
    id: card
    default property alias content: col.data
    property alias hovered: hover.hovered
    property int pad: 14
    property int gap: 10

    anchors.fill: parent
    implicitWidth: col.implicitWidth + card.pad * 2
    implicitHeight: col.implicitHeight + card.pad * 2
    radius: 12
    color: Theme.colBg
    border.color: Theme.colBorder
    border.width: 1

    HoverHandler {
        id: hover
    }

    ColumnLayout {
        id: col
        anchors.fill: parent
        anchors.margins: card.pad
        spacing: card.gap
    }
}
