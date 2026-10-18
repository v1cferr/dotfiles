// The Powerline's CENTER: the official NixOS logo in its compartment, on the screen's exact center,
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

    // The compartment: wider at the top by one slant on each side, so its edges are the two
    // dividers mirrored ("\\_/"), and a shade lighter than the bar.
    Shape {
        x: -Theme.barSlant
        width: slot.width + 2 * Theme.barSlant
        height: slot.height
        preferredRendererType: Shape.CurveRenderer
        ShapePath {
            fillColor: slot.open || area.containsMouse ? Theme.colSelectFill : Theme.colBarCenter
            strokeColor: Theme.colEdge
            strokeWidth: Theme.hairline
            startX: 0
            startY: 0
            PathLine {
                x: Theme.barSlant
                y: slot.height
            }
            PathLine {
                x: Theme.barSlant + slot.width
                y: slot.height
            }
            PathLine {
                x: 2 * Theme.barSlant + slot.width
                y: 0
            }
        }
    }
    // The one blue line on the bar, under the logo.
    Rectangle {
        x: Theme.sp2
        y: slot.height - 2
        width: slot.width - 2 * Theme.sp2
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
        y: (slot.height - Theme.barLogo) / 2
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
        y: Theme.sp2 + 1
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
