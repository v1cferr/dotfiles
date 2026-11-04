// The bar's CENTER: the official NixOS logo in its compartment, on the screen's exact center,
// opening the NixOS Center. Its geometry never reads its neighbors: docs/notes/desktop/bar.md
import Quickshell
import QtQuick
import QtQuick.Shapes
import "root:/"

Item {
    id: slot
    required property var host // the Bar's Scope: the coordinator the Center opens through
    property var barContent: null
    property var barWindow: null

    readonly property bool open: slot.host.pinned === "center" && slot.host.popBar === slot.barWindow
    width: Theme.barCenterWidth
    height: Theme.barHeight

    // The compartment, "\_/": 3 px taller than the cells above and below (rows 2 to 31), its sides on
    // the cells' own 1:3 lines, so the slits to the time and the date stay parallel. Each side passes
    // through the cells' top row (y 5) at x 0 and x width.
    readonly property int rowTop: Theme.barCellY - 3
    readonly property int rowBottom: Theme.barCellY + Theme.barCell + 3
    readonly property real lt: -(Theme.barCellY - slot.rowTop) / 3 // the left side at the top row
    readonly property real lb: (slot.rowBottom - Theme.barCellY) / 3 // and at the bottom row
    readonly property color shade: slot.open ? Qt.alpha(Theme.colAccent, 0.18) : (area.containsMouse ? Theme.colCellHoverFill : Theme.colCompFill)
    readonly property color rim: slot.open ? Qt.alpha(Theme.colAccent, 0.6) : (area.containsMouse ? Theme.colCellHoverEdge : Theme.colCompEdge)
    Shape {
        preferredRendererType: Shape.CurveRenderer
        ShapePath {
            strokeColor: "transparent"
            fillColor: slot.shade
            startX: slot.lt
            startY: slot.rowTop
            PathLine {
                x: slot.width - slot.lt
                y: slot.rowTop
            }
            PathLine {
                x: slot.width - slot.lb
                y: slot.rowBottom
            }
            PathLine {
                x: slot.lb
                y: slot.rowBottom
            }
            PathLine {
                x: slot.lt
                y: slot.rowTop
            }
        }
        // The 1 px edge half a pixel inside the fill, as on every cell (SlantCell.qml).
        ShapePath {
            strokeColor: slot.rim
            strokeWidth: Theme.hairline
            fillColor: "transparent"
            startX: slot.lt + 0.5 / 3 + 0.527
            startY: slot.rowTop + 0.5
            PathLine {
                x: slot.width - slot.lt - 0.5 / 3 - 0.527
                y: slot.rowTop + 0.5
            }
            PathLine {
                x: slot.width - slot.lb + 0.5 / 3 - 0.527
                y: slot.rowBottom - 0.5
            }
            PathLine {
                x: slot.lb - 0.5 / 3 + 0.527
                y: slot.rowBottom - 0.5
            }
            PathLine {
                x: slot.lt + 0.5 / 3 + 0.527
                y: slot.rowTop + 0.5
            }
        }
    }
    // The one accent line at rest: 24 px on the bar's foot, right under the compartment.
    Rectangle {
        x: (slot.width - 24) / 2
        y: Theme.barHeight - 2
        width: 24
        height: 2
        radius: 1
        color: Theme.colBarAccent
    }

    // nixos-artwork's snowflake from nixos-icons (in hicolor on every NixOS system), drawn as a vector
    // at its own aspect; the glyph only if the icon is missing.
    readonly property string logo: Quickshell.iconPath("nix-snowflake", true)
    Image {
        id: logo
        visible: slot.logo !== ""
        x: (slot.width - Theme.barLogo) / 2
        y: slot.rowTop + 5 // 5 px of air above and below, inside rows 2 to 31
        width: Theme.barLogo
        height: Theme.barLogo
        source: slot.logo
        sourceSize.width: Theme.barLogo * 2
        sourceSize.height: Theme.barLogo * 2
        fillMode: Image.PreserveAspectFit
        smooth: true
    }
    Text {
        visible: !logo.visible
        anchors.centerIn: parent
        text: "\uf313"
        color: Theme.colSapphire
        font.family: Theme.uiFont
        font.pixelSize: Theme.barLogo
    }

    // Unseen notifications: a 6 px dot at a FIXED spot, right of the logo and clear of it. Red when one
    // of them is critical. History alone never lights it.
    Rectangle {
        visible: Notifs.unseen > 0
        x: slot.width / 2 + Theme.barLogo / 2 + 3
        y: slot.rowTop + 4
        width: 6
        height: 6
        radius: 3
        color: Notifs.unseenCritical ? Theme.colRed : Theme.colAccent
    }

    MouseArea {
        id: area
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        Accessible.role: Accessible.Button
        Accessible.name: "NixOS Center: notifications and the session" + (Notifs.unseen > 0 ? ", " + Notifs.unseen + " unseen" : "")
        onClicked: slot.host.togglePanel("center", slot, slot.barContent, slot.barWindow)
    }
}
