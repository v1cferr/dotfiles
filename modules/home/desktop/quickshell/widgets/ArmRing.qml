// The ring of an ARMED action: what is left of its time to be confirmed, emptying clockwise from
// the top. Drawn as one stroke, never a glyph. docs/notes/desktop/nixos-center.md#the-confirmation
import QtQuick
import QtQuick.Shapes
import "root:/"

Shape {
    id: ring
    property real part: 1 // what is left: 1 full, 0 gone (`left` is an Item anchor, FINAL)
    property color tint: Theme.colRed
    property real line: 2
    preferredRendererType: Shape.CurveRenderer
    ShapePath {
        strokeColor: Qt.alpha(ring.tint, 0.25)
        strokeWidth: ring.line
        fillColor: "transparent"
        PathAngleArc {
            centerX: ring.width / 2
            centerY: ring.height / 2
            radiusX: ring.width / 2 - ring.line / 2
            radiusY: ring.height / 2 - ring.line / 2
            startAngle: 0
            sweepAngle: 360
        }
    }
    ShapePath {
        strokeColor: ring.tint
        strokeWidth: ring.line
        capStyle: ShapePath.RoundCap
        fillColor: "transparent"
        PathAngleArc {
            centerX: ring.width / 2
            centerY: ring.height / 2
            radiusX: ring.width / 2 - ring.line / 2
            radiusY: ring.height / 2 - ring.line / 2
            startAngle: -90
            sweepAngle: 360 * Math.max(0, Math.min(1, ring.part))
        }
    }
}
