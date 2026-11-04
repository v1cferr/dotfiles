// One glass cell of the bar: a parallelogram on the 1:3 grid, leaning "\" left of the logo and "/"
// right of it, so two neighbors always leave a parallel slit. docs/notes/desktop/bar.md#cells
import QtQuick
import QtQuick.Shapes
import "root:/"

Item {
    id: cell
    property int lean: 1 // -1 = "\" (left of the logo), +1 = "/" (right of it)
    property color fill: Theme.colCellFill
    property color edge: Theme.colCellEdge
    // The 24 px accent line on the bar's foot, under the cell's center line: its panel is open.
    property bool marked: false

    // The item is the TOP edge; the bottom edge is it shifted one slant (right for "\", left for "/").
    readonly property int dx: cell.lean < 0 ? Theme.barSlant : -Theme.barSlant
    readonly property real k: cell.dx / Theme.barCell
    implicitHeight: Theme.barCell

    Behavior on fill {
        ColorAnimation {
            duration: Theme.motionHover
        }
    }
    Behavior on edge {
        ColorAnimation {
            duration: Theme.motionHover
        }
    }

    Shape {
        preferredRendererType: Shape.CurveRenderer
        // The fill on whole-pixel vertices, so its top and bottom rows are crisp.
        ShapePath {
            strokeColor: "transparent"
            fillColor: cell.fill
            startX: 0
            startY: 0
            PathLine {
                x: cell.width
                y: 0
            }
            PathLine {
                x: cell.width + cell.dx
                y: Theme.barCell
            }
            PathLine {
                x: cell.dx
                y: Theme.barCell
            }
            PathLine {
                x: 0
                y: 0
            }
        }
        // The 1 px edge half a pixel inside the fill (0.527 = 0.5 across a 1:3 side), one row exactly.
        ShapePath {
            strokeColor: cell.edge
            strokeWidth: Theme.hairline
            fillColor: "transparent"
            startX: cell.k * 0.5 + 0.527
            startY: 0.5
            PathLine {
                x: cell.width + cell.k * 0.5 - 0.527
                y: 0.5
            }
            PathLine {
                x: cell.width + cell.k * (Theme.barCell - 0.5) - 0.527
                y: Theme.barCell - 0.5
            }
            PathLine {
                x: cell.k * (Theme.barCell - 0.5) + 0.527
                y: Theme.barCell - 0.5
            }
            PathLine {
                x: cell.k * 0.5 + 0.527
                y: 0.5
            }
        }
    }
    Rectangle {
        visible: cell.marked
        x: Math.round(cell.width / 2 + cell.k * 28 - 12)
        y: Theme.barHeight - 2 - Theme.barCellY
        width: 24
        height: 2
        radius: 1
        color: Theme.colBarAccent
    }
}
