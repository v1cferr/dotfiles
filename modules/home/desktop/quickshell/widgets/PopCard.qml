// A popover's CARD: the glass, the radius, the border and the hover flag every hover panel needs.
// It sits on GlassSurface at the densest level, the one read the longest.
import QtQuick
import QtQuick.Layouts
import "root:/"

GlassSurface {
    id: card
    default property alias content: col.data
    property alias hovered: hover.hovered
    property int pad: 14
    property int gap: 10
    property bool shown: false // bind it to the window's visible: the entrance replays on each show

    anchors.fill: parent
    implicitWidth: col.implicitWidth + card.pad * 2
    implicitHeight: col.implicitHeight + card.pad * 2
    level: "pop"

    transform: Translate {
        id: drop
    }
    PopIn {
        target: drop
        shown: card.shown
    }

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
