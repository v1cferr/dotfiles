// A glass SURFACE: the palette's bg at one of Theme's three glass levels, a hairline edge and a 1 px
// sheen along the top. Every bar cluster, band card and panel is one: docs/notes/desktop/theme.md
import QtQuick
import "root:/"

Rectangle {
    id: glass
    property string level: "card" // "bar" | "card" | "pop", the three opacities in Theme

    radius: Theme.radiusSurface
    color: glass.level === "bar" ? Theme.colSurfaceBar : (glass.level === "pop" ? Theme.colSurfacePop : Theme.colSurfaceCard)
    border.width: Theme.hairline
    border.color: Theme.colEdge

    // Light on the top edge, inset past the corners: the surface reads as a pane over the photo.
    Rectangle {
        x: glass.radius
        y: Theme.hairline
        width: Math.max(0, glass.width - 2 * glass.radius)
        height: Theme.hairline
        color: Theme.colSheen
    }
}
