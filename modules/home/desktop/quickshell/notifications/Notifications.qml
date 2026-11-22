// The TOASTS: only where the island cannot be seen (a fullscreen window covers it, or it is off),
// at the top of the main monitor's middle, under the bar, where the island's card would come
// down. Everywhere else a notification is the island's. The card is NotifCard.qml:
// docs/notes/desktop/nixos-center.md
import Quickshell
import Quickshell.Wayland
import QtQuick
import QtQuick.Layouts
import "root:/"

Scope {
    id: root

    PanelWindow {
        id: popupWin
        WlrLayershell.namespace: "qs-panel"
        // Over a fullscreen window too, where the island cannot be seen.
        WlrLayershell.layer: Island.covered ? WlrLayer.Overlay : WlrLayer.Top
        visible: Notifs.popups.length > 0
        // The main monitor, or whichever screen is left when it is unplugged (Theme's fallback).
        screen: Theme.screenPrimary
        // Anchored to the top alone, so it stands centered on the screen: sp2 under the bar.
        anchors {
            top: true
        }
        exclusionMode: ExclusionMode.Ignore
        margins {
            top: Theme.bandTop
        }
        color: "transparent"
        implicitWidth: 380
        implicitHeight: Math.max(1, popupCol.implicitHeight)

        ColumnLayout {
            id: popupCol
            anchors.fill: parent
            spacing: Theme.sp2
            Repeater {
                // A ScriptModel DIFFS the array: an arrival creates one card and the others keep
                // theirs (and their dismiss timers), where a plain array rebuilt every card.
                model: ScriptModel {
                    values: Notifs.popups
                }
                NotifCard {
                    required property var modelData
                    Layout.fillWidth: true
                    notif: modelData
                    isPopup: true
                }
            }
        }
    }
}
