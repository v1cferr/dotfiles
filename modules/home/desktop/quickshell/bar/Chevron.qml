// A Powerline divider: one 1 px diagonal across the bar. The left half leans one way and the right
// half the other, mirrored on the screen's center. docs/notes/desktop/bar.md
import QtQuick
import QtQuick.Layouts
import QtQuick.Shapes
import "root:/"

Shape {
    id: ch
    property bool rising: true // "/" on the right half, "\\" on the left
    property color lineColor: Theme.colEdge

    // Sized and drawn from the tokens alone: a path that read the shape's own size, inside a
    // RowLayout, sent the layout into a polish loop.
    implicitWidth: Theme.barSlant
    implicitHeight: Theme.barHeight
    Layout.preferredWidth: Theme.barSlant
    Layout.preferredHeight: Theme.barHeight
    preferredRendererType: Shape.CurveRenderer // antialiased without a multisampled layer

    ShapePath {
        strokeColor: ch.lineColor
        strokeWidth: Theme.hairline
        fillColor: "transparent"
        startX: ch.rising ? 0 : Theme.barSlant
        startY: Theme.barHeight
        PathLine {
            x: ch.rising ? Theme.barSlant : 0
            y: 0
        }
    }
}
