// The island GROWN DOWNWARD: the body of the one shape whose head is the capsule in the bar. It
// starts where the bar ends, as wide as the open capsule, and comes down on the island's spring
// with what plays and what was not seen yet. Island.qml decides when; this only draws it.
// docs/notes/desktop/island.md#open
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import QtQuick
import QtQuick.Layouts
import "root:/"
import "root:/control"
import "root:/media"
import "root:/notifications"
import "root:/widgets"

PanelWindow {
    id: drop
    required property var bar

    // Always mapped, and empty while shut: opening is then the island's own motion from its first
    // frame, with no layer to map and no fade of the compositor's over it. Shut, it takes no
    // pointer (the mask is the body, zero tall) and draws nothing.
    visible: Island.live
    screen: Theme.screenPrimary
    WlrLayershell.namespace: "qs-island"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    anchors {
        top: true
        left: true
    }
    exclusionMode: ExclusionMode.Ignore
    margins {
        top: Theme.barTop + Theme.barHeight
        left: drop.screen ? Math.floor(drop.screen.width / 2) - Theme.islandHalf : 0
    }
    implicitWidth: 2 * Theme.islandHalf
    // Room for the spring to pass its size on the way down.
    implicitHeight: drop.full + Theme.sp6
    color: "transparent"
    mask: Region {
        item: body
    }

    readonly property int most: 3
    // Newest first.
    readonly property var unseen: Notifs.unseenList.slice(-drop.most).reverse()
    readonly property int full: Math.ceil(content.implicitHeight) + Theme.sp3 + Theme.sp4
    readonly property real want: Island.open ? drop.full : 0

    // Down on the spring, back up on a short ease: faster out than in.
    function move() {
        fall.stop();
        rise.stop();
        if (Theme.motionReduced) {
            body.reach = drop.want;
        } else if (drop.want > 0) {
            fall.to = drop.want;
            fall.restart();
        } else {
            rise.to = 0;
            rise.restart();
        }
    }
    onWantChanged: drop.move()
    SpringAnimation {
        id: fall
        target: body
        property: "reach"
        spring: Theme.islandSpring
        damping: Theme.islandDamping
        epsilon: 0.25
    }
    NumberAnimation {
        id: rise
        target: body
        property: "reach"
        duration: Theme.motionHover
        easing.type: Easing.OutCubic
    }
    Binding {
        target: Island
        property: "dropReach"
        value: Math.max(0, body.reach)
    }

    // What it holds enters in two beats as it opens: what plays, then what waits.
    property real beat0: 1
    property real beat1: 1
    Connections {
        target: Island
        function onOpenChanged() {
            if (!Island.open || Theme.motionReduced)
                return;
            drop.beat0 = 0;
            drop.beat1 = 0;
            enter.restart();
        }
    }
    ParallelAnimation {
        id: enter
        NumberAnimation {
            target: drop
            property: "beat0"
            from: 0
            to: 1
            duration: Theme.motionNormal
            easing.type: Easing.OutCubic
        }
        SequentialAnimation {
            PauseAnimation {
                duration: Theme.motionStagger * 2
            }
            NumberAnimation {
                target: drop
                property: "beat1"
                from: 0
                to: 1
                duration: Theme.motionNormal
                easing.type: Easing.OutCubic
            }
        }
    }

    // Kept open by a click, a click anywhere else shuts it; the bars are in the grab so a click on
    // the capsule or on another item still reaches them.
    HyprlandFocusGrab {
        active: Island.kept && Island.open
        windows: [drop].concat(Object.values(drop.bar.bars))
        onCleared: Island.shut()
    }

    Item {
        id: body
        property real reach: 0
        width: parent.width
        height: Math.max(0, Math.round(body.reach))
        clip: true

        // The same fill and edge as the head, begun above the window so its top corners and its
        // top edge are never drawn: the two meet in a straight line.
        Rectangle {
            y: -Theme.radiusSurface
            width: parent.width
            height: parent.height + Theme.radiusSurface
            radius: Theme.radiusSurface
            color: Theme.colIsland
            border.width: Theme.hairline
            border.color: Theme.colIslandEdge
        }
        HoverHandler {
            onHoveredChanged: Island.dropHover = hovered
        }
        // Revealed by the body coming down, never squeezed: it has its full size from the start.
        ColumnLayout {
            id: content
            x: Theme.sp4
            y: Theme.sp3
            width: parent.width - 2 * Theme.sp4
            spacing: Theme.sp3

            MediaCard {
                Layout.fillWidth: true
                visible: Island.hasMedia
                opacity: drop.beat0
                active: Island.open && Island.hasMedia
                wave: Audio.waveOpen
                onRevealed: Island.shut()
            }
            Hairline {
                visible: Island.hasMedia && Island.hasUnseen
                opacity: drop.beat1
            }
            ColumnLayout {
                Layout.fillWidth: true
                visible: Island.hasUnseen
                opacity: drop.beat1
                spacing: Theme.sp2

                Text {
                    Layout.leftMargin: Theme.sp1
                    text: Notifs.unseen + (Notifs.unseen === 1 ? " NEW NOTIFICATION" : " NEW NOTIFICATIONS")
                    color: Theme.colDim
                    font.family: Theme.uiFont
                    font.pixelSize: Theme.fontMicro
                    font.letterSpacing: 1
                }
                Repeater {
                    model: drop.unseen
                    NotifCard {
                        required property var modelData
                        Layout.fillWidth: true
                        notif: modelData
                        isPopup: false
                    }
                }
                Text {
                    visible: Notifs.unseenList.length > drop.most
                    Layout.leftMargin: Theme.sp1
                    text: "and " + (Notifs.unseenList.length - drop.most) + " older, in the NixOS Center"
                    color: Theme.colDim
                    font.family: Theme.uiFont
                    font.pixelSize: Theme.fontSmall
                }
                RowLayout {
                    Layout.fillWidth: true
                    spacing: Theme.sp2
                    PageLink {
                        label: "Mark as seen"
                        mark: "done_all"
                        onClicked: Notifs.markSeen()
                    }
                    PageLink {
                        label: "NixOS Center"
                        onClicked: Notifs.toggleCenter()
                    }
                }
            }
        }
    }
}
