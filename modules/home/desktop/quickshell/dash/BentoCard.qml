// One cell of the band's bento grid. Its FRAME lives in real pixels (integer edges, so borders stay
// crisp); its CONTENT keeps the band's design canvas, scaled by `k` inside it. docs/notes/desktop/dash.md
import QtQuick
import "root:/"
import "root:/widgets"

GlassSurface {
    id: card
    default property alias content: stage.data
    property real k: 1 // design units to pixels, the band's one scale
    property int pad: Theme.sp3 // in pixels, like the frame

    level: "card"

    // The content's box in design units: whatever is inside lays out as it always did.
    Item {
        id: stage
        x: card.pad
        y: card.pad
        width: (card.width - 2 * card.pad) / card.k
        height: (card.height - 2 * card.pad) / card.k
        scale: card.k
        transformOrigin: Item.TopLeft
    }
}
