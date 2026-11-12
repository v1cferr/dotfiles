// The PEEK: the notifications not seen yet, on a hover of the island. It reads Notifs and owns
// nothing; seeing them here does not mark them seen, the row at its foot does.
// docs/notes/desktop/island.md#the-apps-that-wait
import Quickshell
import QtQuick
import QtQuick.Layouts
import "root:/"
import "root:/control"
import "root:/notifications"
import "root:/widgets"

BarPanel {
    id: peek
    key: "peek"
    ready: Notifs.unseenList.length > 0
    readonly property int most: 4
    // Newest first.
    readonly property var shown: Notifs.unseenList.slice(-peek.most).reverse()

    implicitWidth: 380
    implicitHeight: card.implicitHeight

    PopCard {
        id: card
        shown: peek.visible
        pad: Theme.sp3
        gap: Theme.sp2
        onHoveredChanged: peek.bar.panelPopHovered = card.hovered

        Text {
            Layout.leftMargin: Theme.sp1
            text: Notifs.unseen + (Notifs.unseen === 1 ? " NEW NOTIFICATION" : " NEW NOTIFICATIONS")
            color: Theme.colDim
            font.family: Theme.uiFont
            font.pixelSize: Theme.fontMicro
            font.letterSpacing: 1
        }
        Repeater {
            model: peek.shown
            NotifCard {
                required property var modelData
                Layout.fillWidth: true
                notif: modelData
                isPopup: false
            }
        }
        Text {
            visible: Notifs.unseenList.length > peek.most
            Layout.leftMargin: Theme.sp1
            text: "and " + (Notifs.unseenList.length - peek.most) + " older, in the NixOS Center"
            color: Theme.colDim
            font.family: Theme.uiFont
            font.pixelSize: Theme.fontSmall
        }
        Hairline {}
        RowLayout {
            Layout.fillWidth: true
            spacing: Theme.sp2
            PageLink {
                label: "Mark as seen"
                mark: "done_all"
                onClicked: {
                    Notifs.markSeen();
                    peek.bar.closePanels();
                }
            }
            PageLink {
                label: "NixOS Center"
                onClicked: Notifs.toggleCenter()
            }
        }
    }
}
