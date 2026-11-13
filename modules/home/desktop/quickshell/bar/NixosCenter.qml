// The NIXOS CENTER's window: the logo's panel, holding CenterCard.qml.
// docs/notes/desktop/nixos-center.md
import QtQuick
import QtQuick.Layouts
import "root:/"
import "root:/widgets"

BarPanel {
    id: center
    key: "center"
    layerNamespace: "qs-center" // shell-screenshot waits for exactly this layer to leave the frame

    implicitWidth: Math.min(520, (center.screen ? center.screen.width : 1920) - 2 * Theme.screenInset)
    implicitHeight: card.implicitHeight
    onKeyPressed: event => inner.keyPressed(event)

    PopCard {
        id: card
        shown: center.visible
        pad: Theme.sp4
        onHoveredChanged: center.bar.panelPopHovered = card.hovered

        CenterCard {
            id: inner
            Layout.fillWidth: true
            bar: center.bar
            screen: center.screen
            shown: center.visible
            onKeysWanted: center.takeKeys()
        }
    }
}
