// The pause closing a carousel's dots: two bars while it turns, a play triangle in the accent while
// it holds. Drawn in whole pixels, never a font glyph, in a box exactly as wide as its ink, so it ends
// flush with the card's padding the way the title starts.
import QtQuick
import QtQuick.Shapes
import "root:/"

Item {
    id: pause
    property bool paused: false
    readonly property color tint: pause.paused || area.containsMouse ? Theme.colAccent : Theme.colSubtext

    width: 7
    height: 16

    Rectangle {
        visible: !pause.paused
        x: 0
        y: 4
        width: 2
        height: 8
        radius: 1
        color: pause.tint
    }
    Rectangle {
        visible: !pause.paused
        x: 4
        y: 4
        width: 2
        height: 8
        radius: 1
        color: pause.tint
    }
    Shape {
        visible: pause.paused
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer
        ShapePath {
            strokeColor: "transparent"
            fillColor: pause.tint
            startX: 0
            startY: 4
            PathLine {
                x: 7
                y: 8
            }
            PathLine {
                x: 0
                y: 12
            }
            PathLine {
                x: 0
                y: 4
            }
        }
    }
    MouseArea {
        id: area
        anchors.fill: parent
        anchors.margins: -6
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: pause.paused = !pause.paused
    }
}
