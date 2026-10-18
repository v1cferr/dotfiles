// The TOASTS, top right of the main monitor under the bar; the history lives in the NixOS Center
// (bar/NixosCenter.qml). The card is NotifCard.qml: docs/notes/desktop/nixos-center.md
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
        visible: Notifs.popups.length > 0
        // The main monitor, or whichever screen is left when it is unplugged (Theme's fallback).
        screen: Theme.screenPrimary
        anchors {
            top: true
            right: true
        }
        // From the screen's edge: sp2 under the bar, and right on the windows' outer gap.
        exclusionMode: ExclusionMode.Ignore
        margins {
            top: Theme.bandTop
            right: Theme.screenInset
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
