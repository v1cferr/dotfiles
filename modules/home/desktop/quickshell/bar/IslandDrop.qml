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
import "root:/notifications"

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
    // Room for what it holds, and for the spring to pass its size on the way down. It GROWS at once,
    // with headroom for the next growth (the media card unfolding), and shrinks only while the island
    // is shut. A layer surface that resizes waits on the compositor's answer, and on Hyprland the
    // frame held still for about 260 ms each time the open Center got shorter (22/11/2026, seen in a
    // recording; sway, in the harness, never showed it). The room left over is transparent, and
    // the compositor's blur ignores it (ignore_alpha, hypr/lua/appearance.lua).
    readonly property int needTall: Math.max(drop.bodyTall, drop.peekTall)
    readonly property int headroom: 260
    readonly property int roomMax: drop.screen ? drop.screen.height - Theme.barTop - drop.headBottom - Theme.sp6 : 1200
    property int roomTall: 0
    function reroom() {
        if (!Island.wide)
            drop.roomTall = drop.needTall;
        else if (drop.needTall > drop.roomTall)
            drop.roomTall = Math.min(drop.roomMax, drop.needTall + drop.headroom);
    }
    onNeedTallChanged: drop.reroom()
    implicitHeight: drop.headBottom + drop.roomTall + Theme.sp6
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
            drop.homeName = Island.aim;
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
            drop.reroom();
        }
        function onAimChanged() {
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
    // The logo is the Center's title: open, it is this size, its top a step under the shape's, and
    // the Center starts under it. Shut, it is the bar's own logo on its own pixel.
    readonly property int logoOpen: 44
    readonly property int logoTop: drop.headTop + Theme.sp3
    // How much lower the Center starts than it did with the logo in the bar's row.
    readonly property int titleRoom: Math.max(0, drop.logoTop + drop.logoOpen + Theme.sp3 - drop.headBottom - drop.bodyTop)
    readonly property int bodyTall: center.item ? drop.bodyTop + drop.titleRoom + Math.ceil(center.item.implicitHeight) + drop.pad : 0
    // A notification shown as a card: the capsule's own width at its widest, and its card's height.
    readonly property int peekHalf: Theme.islandHalf
    readonly property int peekTall: drop.bodyTop + Math.ceil(peekCard.implicitHeight) + drop.pad
    readonly property real wantReach: Island.open ? drop.bodyTall : (Island.peek ? drop.peekTall : 0)
    // Shut, it is the capsule that rests on the main monitor; on another screen, the logo's own slot.
    readonly property bool atHome: !!drop.screen && !!Theme.screenPrimary && drop.screen.name === Theme.screenPrimary.name
    readonly property real wantHalf: Island.open ? drop.wide / 2 : (Island.peek ? drop.peekHalf : Math.max(Theme.barCenterWidth / 2, drop.atHome ? Island.headHalf : 0))
    // Shut, its middle sits where the lopsided capsule's does; out, it centers on the logo.
    readonly property real wantShift: Island.open || Island.peek ? 0 : (drop.atHome ? Island.headShift : 0)
    // Which of the two it holds while it is out: the card, from a notification that came down until
    // the Center opens or the shape is back in. Held, so the Center never shows in a closing card.
    property bool peekMode: false
    property var peekNotif: null
    Connections {
        target: Island
        function onPeekChanged() {
            if (Island.peek) {
                drop.peekNotif = Island.peek;
                drop.peekMode = true;
            }
        }
    }

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
    // Growing is the spring and shrinking the ease, whichever of the two sizes it goes to or from.
    // Once the Center has settled open, a change of ITS size (the media card, a page, a notification
    // arriving) is a short ease both ways: the content changes at once, and a spring would trail
    // it, cutting the foot on the way out and leaving bare glass on the way in.
    onWantReachChanged: {
        if (Island.open && drop.peekMode) {
            drop.cardLeaving = true; // the card fades as the Center comes in over it
            drop.peekMode = false;
        }
        if (Island.open && drop.settled && !Theme.motionReduced) {
            fall.stop();
            rise.stop();
            resize.to = drop.wantReach;
            resize.restart();
        } else {
            resize.stop();
            drop.move(fall, rise, "reach", drop.wantReach, drop.wantReach > shape.reach);
        }
    }
    NumberAnimation {
        id: resize
        target: shape
        property: "reach"
        duration: Theme.motionNormal
        easing.type: Easing.OutCubic
    }
    // Settled: open, and done with the spring that brought it there.
    property bool settled: false
    Connections {
        target: fall
        function onRunningChanged() {
            if (!fall.running && Island.open)
                drop.settled = true;
        }
    }
    // The half follows the capsule while shut (nothing is drawn then), and moves only to open or shut.
    onWantHalfChanged: {
        if (Island.wide || Island.open || Island.peek)
            drop.move(spread, gather, "half", drop.wantHalf, drop.wantHalf > shape.half);
        else
            shape.half = drop.wantHalf;
    }
    onWantShiftChanged: {
        if (Island.wide || Island.open || Island.peek)
            drop.move(toLogo, offCenter, "shift", drop.wantShift, Math.abs(drop.wantShift) < Math.abs(shape.shift));
        else
            shape.shift = drop.wantShift;
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
    Pull {
        id: toLogo
        property: "shift"
    }
    Ease {
        id: offCenter
        property: "shift"
    }
    Binding {
        target: Island
        property: "dropReach"
        value: Math.max(0, shape.reach)
    }
    // All the way in: the next time out is the Center's, unless a card comes down again.
    Connections {
        target: Island
        function onDropReachChanged() {
            if (Island.dropReach <= 0 && !Island.peek)
                drop.peekMode = false;
        }
    }

    // What it holds follows the SHAPE, never a clock of its own: the Center (or the card) shows in
    // step with how far the glass has come down from where this opening started, so no frame has the
    // glass bare, and on the way back in it fades as the glass rises instead of being cut. The card
    // that becomes the Center fades out on the same progress the Center fades in on.
    property real fromReach: 0
    property bool cardLeaving: false
    Connections {
        target: Island
        function onOpenChanged() {
            drop.settled = false;
            drop.fromReach = Island.open ? Math.max(0, shape.reach) : 0;
            if (!Island.open)
                drop.cardLeaving = false;
        }
    }
    function progress(target, from) {
        const span = target - from;
        return span <= 0 ? 1 : Math.max(0, Math.min(1, (shape.reach - from) / (span * 0.7)));
    }
    // Settled open, the Center is whole whatever its size does next (a page, the media card).
    readonly property real centerShown: Theme.motionReduced || drop.settled ? 1 : drop.progress(drop.bodyTall, drop.fromReach)
    readonly property real cardShown: Theme.motionReduced ? 1 : (drop.cardLeaving ? 1 - drop.centerShown : drop.progress(drop.peekTall, 0))
    onCenterShownChanged: if (drop.cardLeaving && drop.centerShown >= 1)
        drop.cardLeaving = false

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
        property real shift: 0 // how far its middle sits right of the logo's
        visible: Island.wide
        level: "island"
        radius: Theme.barCell / 2
        // Never wider than its window: the spring's overshoot is spent on the way, not past the edge.
        readonly property real span: Math.min(drop.wide / 2, shape.half)
        x: Math.round(drop.wide / 2 - shape.span + shape.shift)
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
            // It travels with the glass (the same progress the Center shows on): grows from the bar's
            // size to the Center's title and comes down to the top's middle, and back when it shuts.
            // With a notification's card out it stays on the bar's pixel: the card is not the Center.
            Image {
                id: logoImg
                readonly property string logo: Quickshell.iconPath("nix-snowflake", true)
                readonly property real t: drop.peekMode ? 0 : drop.centerShown * (Island.open || shape.reach > 0 ? 1 : 0)
                readonly property real size: Theme.barLogo + (drop.logoOpen - Theme.barLogo) * logoImg.t
                readonly property real midY: Theme.barHeight / 2 + (drop.logoTop + drop.logoOpen / 2 - Theme.barHeight / 2) * logoImg.t
                x: (drop.wide - logoImg.size) / 2
                y: logoImg.midY - logoImg.size / 2
                width: logoImg.size
                height: logoImg.size
                source: logo
                sourceSize.width: drop.logoOpen * 2
                sourceSize.height: drop.logoOpen * 2
                fillMode: Image.PreserveAspectFit
                smooth: true
                mipmap: true
                MouseArea {
                    anchors.fill: parent
                    anchors.margins: -(Theme.barCenterWidth - Theme.barLogo) / 2
                    cursorShape: Qt.PointingHandCursor
                    Accessible.role: Accessible.Button
                    Accessible.name: Island.full ? "Close the NixOS Center" : "Keep the NixOS Center open"
                    onClicked: Island.full ? drop.bar.closePanels() : Notifs.toggleCenter()
                }
            }

            // ── A notification as a card, under the logo: a click goes where it leads, its buttons and
            // its ✕ are its own, the pointer on it holds it (Island.held) and never opens the Center ──
            MouseArea {
                anchors.fill: peekCard
                visible: drop.peekMode && !Island.open
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    const n = drop.peekNotif;
                    if (n && Notifs.open(n.id))
                        Island.dismiss();
                    else
                        Notifs.toggleCenter();
                }
            }
            NotifCard {
                id: peekCard
                x: (drop.wide - 2 * drop.peekHalf) / 2 + Theme.sp2
                y: drop.headBottom + drop.bodyTop
                width: 2 * drop.peekHalf - 2 * Theme.sp2
                visible: drop.peekMode || drop.cardLeaving
                opacity: drop.cardShown
                notif: drop.peekNotif
                inIsland: true
            }

            // ── The NixOS Center, made the first time the island opens ──
            Loader {
                id: center
                x: drop.pad
                y: drop.headBottom + drop.bodyTop + drop.titleRoom
                width: drop.wide - 2 * drop.pad
                active: drop.everOpen
                visible: !drop.peekMode
                opacity: drop.centerShown
                transform: Translate {
                    y: (1 - drop.centerShown) * -6
                }
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
