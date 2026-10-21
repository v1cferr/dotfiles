// The away screen's windows: a black overlay on every monitor that swallows the keyboard. Enter
// leaves from here AND from the `away` submap in keybinds.lua, which still hears it when monitors
// switched off at the button recreate these windows without focus. The state is Away.qml.
// docs/notes/desktop/away.md
import Quickshell
import Quickshell.Wayland
import QtQuick
import "root:/"

Scope {
    Variants {
        model: Quickshell.screens

        PanelWindow {
            id: win
            required property var modelData
            screen: modelData
            visible: Away.active
            anchors {
                top: true
                bottom: true
                left: true
                right: true
            }
            exclusionMode: ExclusionMode.Ignore // over the bar too, not beside it
            color: "black"
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.namespace: "away"
            // Exclusive: every key lands here and dies, so nothing types into the agent's terminal.
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

            // A Wayland inhibitor, which hypridle honours: the 5-min lock would draw the lock screen over the
            // black. The idle clock starts over on Enter, so leaving it alone still locks.
            IdleInhibitor {
                window: win
                enabled: win.visible
            }

            // The cursor would otherwise sit lit in the middle of the black.
            MouseArea {
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.BlankCursor
            }

            Item {
                anchors.fill: parent
                focus: true
                Keys.onPressed: event => {
                    if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter)
                        Away.leave();
                    event.accepted = true;
                }
            }
        }
    }
}
