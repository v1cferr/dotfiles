// The media panel as a window of its own: what the bar's media item opens where the island is
// off, and `qs ipc call mpris toggle` anywhere. Its content is MediaCard.qml, which the open
// island shows too. docs/notes/desktop/island.md#the-media-panel
import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import QtQuick
import QtQuick.Layouts
import "root:/"
import "root:/widgets"

Scope {
    id: root

    property bool panelVisible: false
    property int panelLeft: Theme.barTop // the screen x the bar asked for; the left edge otherwise
    // Opened by a hover on the island: it closes soon after the pointer leaves both.
    property bool byHover: false
    // Even, so the panel's middle is a whole pixel: the logo's.
    readonly property int panelWidth: 360

    // The wave listens while the panel shows what plays.
    Binding {
        target: Audio
        property: "wavePanel"
        value: root.panelVisible && Media.playing && !Theme.motionReduced
    }
    // And it wants the player's own stream, for the volume.
    Binding {
        target: Audio
        property: "panelOpen"
        value: root.panelVisible
    }

    IpcHandler {
        target: "mpris"

        function toggle(): void {
            root.byHover = false;
            root.panelVisible = !root.panelVisible;
        }
        // The bar's media pill: hung under the pill at screen x `x`, like every bar panel.
        function toggleAt(x: int): void {
            root.panelLeft = x;
            // A click on what a hover opened keeps it, as a pin does on the bar's panels.
            if (root.panelVisible && root.byHover) {
                root.byHover = false;
                return;
            }
            root.byHover = false;
            root.panelVisible = !root.panelVisible;
        }
        // The island's hover: open it there, never close it.
        function openAt(x: int): void {
            root.panelLeft = x;
            if (!root.panelVisible) {
                root.byHover = true;
                root.panelVisible = true;
            }
        }
        // "open" and not "show" (show collides with the `qs ipc show` subcommand)
        function open(): void {
            root.byHover = false;
            root.panelVisible = true;
        }
        function hide(): void {
            root.panelVisible = false;
        }
    }

    // It closes when the pointer is on neither the panel nor the island's media: soon after a
    // hover opened it, later after a click did.
    Timer {
        interval: root.byHover ? 600 : 2500
        running: root.panelVisible && !panelHover.hovered && !Media.hover
        onTriggered: root.panelVisible = false
    }

    PanelWindow {
        id: panel
        WlrLayershell.namespace: "qs-panel"
        visible: root.panelVisible

        // On the main monitor, placed from the screen's edge sp1 under the bar (the same rule as BarPanel).
        screen: Theme.screenPrimary

        anchors {
            top: true
            left: true
        }
        exclusionMode: ExclusionMode.Ignore
        margins {
            top: Theme.bandTop
            left: root.panelLeft
        }

        implicitWidth: root.panelWidth
        implicitHeight: content.implicitHeight + 2 * Theme.sp4
        color: "transparent"

        GlassSurface {
            anchors.fill: parent
            level: "pop"

            transform: Translate {
                id: drop
            }
            PopIn {
                target: drop
                shown: panel.visible
            }

            HoverHandler {
                id: panelHover
            }

            MediaCard {
                id: content
                anchors.fill: parent
                anchors.margins: Theme.sp4
                active: root.panelVisible
                wave: Audio.wavePanel
                onRevealed: root.panelVisible = false
            }
        }
    }
}
