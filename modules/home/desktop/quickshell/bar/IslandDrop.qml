// The island OPEN: the NixOS Center as one shape of glass, in one window. It starts as the capsule
// that rests around the logo (same place, same width, same corners) and grows on the island's
// spring to the Center's width and down to its foot. While any of it is out, the bar's own capsule
// and logo step aside and this window draws the logo on the very same pixels. Island.qml decides
// when; this draws it and holds the keys. docs/notes/desktop/island.md#open
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import QtQuick
import QtQuick.Layouts
import "root:/"
import "root:/widgets"

PanelWindow {
    id: drop
    required property var bar

    // Always mapped, and empty while shut: opening is then the island's own motion from its first
    // frame, with no layer to map and no fade of the compositor's over it. Shut, it takes no
    // pointer (the mask is the shape, nothing) and draws nothing.
    // Shown one turn of the event loop after it is made, never at once: a window already visible
    // when a hot reload hands it the old one's surface crashed the shell in QWindow::setScreen
    // (12/11/2026, Quickshell 0.3.2; a stand-in window of ten lines did the same).
    property bool up: false
    Component.onCompleted: Qt.callLater(() => drop.up = true)
    visible: drop.up
    screen: drop.home
    WlrLayershell.namespace: "qs-island" // the compositor's glass and blur match it (hypr/lua)
    // The keyboard only while pinned: opened by a hover it must never take it from the window under it.
    WlrLayershell.keyboardFocus: Island.full ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None
    anchors {
        top: true
        left: true
    }
    exclusionMode: ExclusionMode.Ignore
    margins {
        top: Theme.barTop
        left: drop.screen ? Math.floor(drop.screen.width / 2) - drop.wide / 2 : 0
    }
    // The Center's width, never more than the screen leaves. Even, so its middle is the logo's.
    readonly property int wide: Math.max(2 * Theme.islandHalf, Math.min(2 * Theme.islandOpenHalf, Math.floor(((drop.screen ? drop.screen.width : 1920) - 2 * Theme.screenInset) / 2) * 2))
    implicitWidth: drop.wide
    // Room for the spring to pass its size on the way down.
    implicitHeight: drop.headBottom + drop.bodyTall + Theme.sp6
    color: "transparent"
    mask: Region {
        item: shape.visible ? shape : nothing
    }
    Item {
        id: nothing
    }

    // Where it hangs: the main monitor, or the screen whose logo pinned it. It moves only while
    // shut, so closing on one screen never flashes a head on the other.
    // Kept as a NAME and looked up, so nothing here holds a screen object across a hot reload.
    property string homeName: ""
    readonly property var home: (drop.homeName !== "" && Quickshell.screens.find(x => x.name === drop.homeName)) || Theme.screenPrimary
    function rehome() {
        if (Island.full)
            drop.homeName = drop.bar.popScreen ? drop.bar.popScreen.name : "";
        else if (!Island.wide)
            drop.homeName = "";
    }
    Connections {
        target: Island
        function onFullChanged() {
            drop.rehome();
            if (Island.full)
                keys.forceActiveFocus();
        }
        function onWideChanged() {
            drop.rehome();
        }
        // The Center is made the first time the island opens, and kept.
        function onOpenChanged() {
            if (Island.open)
                drop.everOpen = true;
        }
    }
    property bool everOpen: false
    Binding {
        target: Island
        property: "where"
        value: drop.screen ? drop.screen.name : ""
    }

    // ── The geometry: the capsule's own row, then what comes down under it ──
    readonly property int headTop: Theme.barCellY
    readonly property int headBottom: Theme.barCellY + Theme.barCell
    readonly property int pad: Theme.sp4
    // The Center begins a step under the bar's foot, and ends a pad above the shape's.
    readonly property int bodyTop: Theme.barHeight + Theme.sp1 - drop.headBottom
    readonly property int bodyTall: center.item ? drop.bodyTop + Math.ceil(center.item.implicitHeight) + drop.pad : 0
    readonly property real wantReach: Island.open ? drop.bodyTall : 0
    readonly property real wantHalf: Island.open ? drop.wide / 2 : Math.max(Theme.barCenterWidth / 2, Island.headHalf)

    // Out and down on the spring, back on a short ease: faster out than in.
    // A long way down passes its size by the same share, which is many more pixels: past
    // `longWay` the spring is damped harder, so the Center settles instead of bouncing.
    readonly property int longWay: 400
    readonly property real longDamping: 0.45
    function move(pull, ease, what, to, opening) {
        pull.stop();
        ease.stop();
        if (Theme.motionReduced) {
            shape[what] = to;
        } else if (opening) {
            pull.damping = Math.abs(to - shape[what]) > drop.longWay ? drop.longDamping : Theme.islandDamping;
            pull.to = to;
            pull.restart();
        } else {
            ease.to = to;
            ease.restart();
        }
    }
    onWantReachChanged: drop.move(fall, rise, "reach", drop.wantReach, Island.open)
    // The half follows the capsule while shut (nothing is drawn then), and moves only to open or shut.
    onWantHalfChanged: {
        if (Island.wide)
            drop.move(spread, gather, "half", drop.wantHalf, Island.open);
        else
            shape.half = drop.wantHalf;
    }
    component Pull: SpringAnimation {
        target: shape
        spring: Theme.islandSpring
        damping: Theme.islandDamping
        epsilon: 0.25
    }
    component Ease: NumberAnimation {
        target: shape
        duration: Theme.motionHover
        easing.type: Easing.OutCubic
    }
    Pull {
        id: fall
        property: "reach"
    }
    Ease {
        id: rise
        property: "reach"
    }
    Pull {
        id: spread
        property: "half"
    }
    Ease {
        id: gather
        property: "half"
    }
    Binding {
        target: Island
        property: "dropReach"
        value: Math.max(0, shape.reach)
    }

    // What it holds enters as it opens: the logo is there from the first frame, the Center a beat later.
    property real beat1: 1
    Connections {
        target: Island
        function onOpenChanged() {
            if (!Island.open || Theme.motionReduced)
                return;
            drop.beat1 = 0;
            enter.restart();
        }
    }
    SequentialAnimation {
        id: enter
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

    // Pinned, it closes on a click anywhere else; every bar is in the grab, so a click on another
    // item switches panels and a logo's own click still reaches it.
    HyprlandFocusGrab {
        active: Island.full
        windows: [drop].concat(Object.values(drop.bar.bars))
        onCleared: if (Island.full)
            drop.bar.closePanels()
    }

    // ONE surface of glass: a rounded rectangle that is the capsule at one end of its motion and
    // the Center at the other. Its corners are the capsule's all the way.
    GlassSurface {
        id: shape
        property real half: Theme.barCenterWidth / 2 // from the logo's middle to each side
        property real reach: 0 // how far it comes down under the capsule's row
        visible: Island.wide
        level: "island"
        radius: Theme.barCell / 2
        // Never wider than its window: the spring's overshoot is spent on the way, not past the edge.
        readonly property real span: Math.min(drop.wide / 2, shape.half)
        x: Math.round(drop.wide / 2 - shape.span)
        y: drop.headTop
        width: Math.round(2 * shape.span)
        height: Theme.barCell + Math.max(0, Math.round(shape.reach))
        clip: true

        HoverHandler {
            onHoveredChanged: Island.dropHover = hovered
        }
        // The keys, while it is pinned: the Center first, then Escape closes.
        Item {
            id: keys
            focus: true
            Keys.onPressed: event => {
                if (center.item)
                    center.item.keyPressed(event);
                if (!event.accepted && event.key === Qt.Key_Escape) {
                    drop.bar.closePanels();
                    event.accepted = true;
                }
            }
        }

        // What it holds keeps its full size and its place in the WINDOW while the shape grows over
        // it: revealed, never squeezed, and the logo never moves.
        Item {
            id: holds
            x: -shape.x
            y: -shape.y
            width: drop.wide
            height: drop.implicitHeight

            // ── The head, on the capsule's row, holds the logo alone: the Center's switches are in
            // its own sections, so the row is the same on both sides of the logo ──
            // The logo, on the pixels the bar's own stands on: a click pins the island, or closes it.
            Image {
                readonly property string logo: Quickshell.iconPath("nix-snowflake", true)
                x: (drop.wide - Theme.barLogo) / 2
                y: (Theme.barHeight - Theme.barLogo) / 2
                width: Theme.barLogo
                height: Theme.barLogo
                source: logo
                sourceSize.width: Theme.barLogo * 2
                sourceSize.height: Theme.barLogo * 2
                fillMode: Image.PreserveAspectFit
                smooth: true
                MouseArea {
                    anchors.fill: parent
                    anchors.margins: -(Theme.barCenterWidth - Theme.barLogo) / 2
                    cursorShape: Qt.PointingHandCursor
                    Accessible.role: Accessible.Button
                    Accessible.name: Island.full ? "Close the NixOS Center" : "Keep the NixOS Center open"
                    onClicked: Island.full ? drop.bar.closePanels() : Notifs.toggleCenter()
                }
            }

            // ── The NixOS Center, made the first time the island opens ──
            Loader {
                id: center
                x: drop.pad
                y: drop.headBottom + drop.bodyTop
                width: drop.wide - 2 * drop.pad
                active: drop.everOpen
                opacity: drop.beat1
                sourceComponent: CenterCard {
                    bar: drop.bar
                    screen: drop.screen
                    shown: Island.open
                    onKeysWanted: keys.forceActiveFocus()
                }
            }
        }
    }
}
