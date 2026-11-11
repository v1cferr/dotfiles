// The bar's CENTER: the official NixOS logo, on the screen's exact center, opening the NixOS Center.
// Its geometry never reads its neighbors, and it is one self-contained Item so the center can grow
// later without the sides knowing: docs/notes/desktop/bar.md
import Quickshell
import QtQuick
import "root:/"

Item {
    id: slot
    required property var host // the Bar's Scope: the coordinator the Center opens through
    property var barContent: null
    property var barWindow: null

    readonly property bool open: slot.host.pinned === "center" && slot.host.popBar === slot.barWindow
    width: Theme.barCenterWidth
    height: Theme.barHeight

    // The same highlight as every item: nothing at rest, neutral on hover, the accent while open.
    Rectangle {
        y: Theme.barCellY
        width: parent.width
        height: Theme.barCell
        radius: Theme.radiusControl
        color: area.pressed ? Theme.colCellPressFill : slot.open ? Theme.colCellOpenFill : area.containsMouse ? Theme.colCellHoverFill : Qt.alpha(Theme.colCellHoverFill, 0)
        Behavior on color {
            ColorAnimation {
                duration: Theme.motionHover
            }
        }
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
        text: ""
        color: Theme.colSapphire
        font.family: Theme.uiFont
        font.pixelSize: Theme.barLogo
    }

    // Unseen notifications: a 6 px dot at a FIXED spot, on the logo's upper right corner. Red when one
    // of them is critical. History alone never lights it.
    Rectangle {
        visible: Notifs.unseen > 0
        x: slot.width / 2 + Theme.barLogo / 2 - 2
        y: Theme.barCellY + 1
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
