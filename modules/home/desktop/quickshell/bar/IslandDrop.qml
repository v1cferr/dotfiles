// The island GROWN DOWNWARD: the body of the one shape whose head is the capsule in the bar. It
// starts where the bar ends and comes down on the island's spring, in two sizes: the SUMMARY (as
// wide as the head: what plays, what was not seen yet) and FULL (the NixOS Center, wider than the
// head by a shoulder on each side). Island.qml decides which; this draws it and holds the keys.
// docs/notes/desktop/island.md#open
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import QtQuick
import QtQuick.Layouts
import QtQuick.Shapes
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
    screen: drop.home || Theme.screenPrimary
    WlrLayershell.namespace: "qs-island"
    // The keyboard only for the Center: the summary must never take it from the window under it.
    WlrLayershell.keyboardFocus: Island.full ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None
    anchors {
        top: true
        left: true
    }
    exclusionMode: ExclusionMode.Ignore
    margins {
        top: Theme.barTop + Theme.barHeight
        left: drop.screen ? Math.floor(drop.screen.width / 2) - drop.wide / 2 : 0
    }
    // As wide as the Center; the summary uses the middle of it. Even, like the head, so the two
    // share a center on a whole pixel.
    readonly property int wide: Math.max(2 * Theme.islandHalf, Math.min(520, (drop.screen ? drop.screen.width : 1920) - 2 * Theme.screenInset))
    readonly property int shoulder: (drop.wide - 2 * Theme.islandHalf) / 2
    implicitWidth: drop.wide
    // Room for the spring to pass its size on the way down.
    implicitHeight: Math.max(drop.fullTall, drop.summaryTall) + Theme.sp6
    color: "transparent"
    mask: Region {
        item: hit
    }

    // Where it hangs: the main monitor, or the screen whose logo opened the Center. It moves only
    // while shut, so a Center closing on one screen never flashes a head on the other.
    property var home: Theme.screenPrimary
    function rehome() {
        if (Island.full)
            drop.home = drop.bar.popScreen || Theme.screenPrimary;
        else if (body.reach <= 0)
            drop.home = Theme.screenPrimary;
    }
    Connections {
        target: Island
        function onFullChanged() {
            drop.rehome();
            if (Island.full) {
                drop.everFull = true;
                keys.forceActiveFocus();
            }
        }
    }
    Binding {
        target: Island
        property: "where"
        value: drop.screen ? drop.screen.name : ""
    }

    readonly property int most: 3
    // Newest first.
    readonly property var unseen: Notifs.unseenList.slice(-drop.most).reverse()
    readonly property int summaryTall: Math.ceil(summary.implicitHeight) + Theme.sp3 + Theme.sp4
    readonly property int fullTall: center.item ? Math.ceil(center.item.implicitHeight) + Theme.sp3 + Theme.sp4 : 0
    readonly property real want: !Island.open ? 0 : (Island.full ? drop.fullTall : drop.summaryTall)
    readonly property real wantFlare: Island.full ? drop.shoulder : 0

    // Down and out on the spring, back on a short ease: faster out than in.
    function move(anim, back, target, to) {
        anim.stop();
        back.stop();
        if (Theme.motionReduced) {
            body[target] = to;
        } else if (to > body[target] || to > 0) {
            // A long way down passes its size by the same share, which is many more pixels: past
            // `longWay` the spring is damped harder, so the Center settles instead of bouncing.
            anim.damping = Math.abs(to - body[target]) > drop.longWay ? drop.longDamping : Theme.islandDamping;
            anim.to = to;
            anim.restart();
        } else {
            back.to = to;
            back.restart();
        }
    }
    readonly property int longWay: 400
    readonly property real longDamping: 0.45
    onWantChanged: drop.move(fall, rise, "reach", drop.want)
    onWantFlareChanged: drop.move(spread, gather, "flare", drop.wantFlare)
    component Pull: SpringAnimation {
        target: body
        spring: Theme.islandSpring
        damping: Theme.islandDamping
        epsilon: 0.25
    }
    component Ease: NumberAnimation {
        target: body
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
        onFinished: drop.rehome()
    }
    Pull {
        id: spread
        property: "flare"
    }
    Ease {
        id: gather
        property: "flare"
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
    component Beat: NumberAnimation {
        target: drop
        from: 0
        to: 1
        duration: Theme.motionNormal
        easing.type: Easing.OutCubic
    }
    ParallelAnimation {
        id: enter
        Beat {
            property: "beat0"
        }
        SequentialAnimation {
            PauseAnimation {
                duration: Theme.motionStagger * 2
            }
            Beat {
                property: "beat1"
            }
        }
    }

    // The Center closes on a click anywhere else; every bar is in the grab, so a click on another
    // item switches panels and the logo's own click still reaches it.
    HyprlandFocusGrab {
        active: Island.full
        windows: [drop].concat(Object.values(drop.bar.bars))
        onCleared: if (Island.full)
            drop.bar.closePanels()
    }

    // The body's box: what takes the pointer, and what the hover is read on.
    Item {
        id: hit
        x: drop.shoulder - Math.round(Math.max(0, Math.min(drop.shoulder, body.flare)))
        width: drop.wide - 2 * x
        height: body.tall
        HoverHandler {
            onHoveredChanged: Island.dropHover = hovered
        }
    }

    Item {
        id: body
        property real reach: 0 // how far down it comes
        property real flare: 0 // how far each shoulder reaches past the head
        readonly property int tall: Math.max(0, Math.round(body.reach))
        anchors.fill: parent

        // ONE outline, begun and ended at the head's two sides on the window's top edge, which is
        // left open: there the body meets the head in a straight line. With no flare it is a
        // column as wide as the head; with it, a shoulder leaves each side a little under the bar
        // and joins the head by a curve. Every edge sits on a half pixel, so the hairline is sharp.
        Shape {
            id: outline
            visible: body.tall > 0
            anchors.fill: parent
            preferredRendererType: Shape.CurveRenderer
            readonly property real h: body.tall - 0.5
            readonly property real f: Math.max(0, Math.min(drop.shoulder, body.flare))
            // The head's sides, and the body's.
            readonly property real hl: drop.shoulder + 0.5
            readonly property real hr: drop.wide - drop.shoulder - 0.5
            readonly property real l: outline.hl - outline.f
            readonly property real r: outline.hr + outline.f
            // The shoulder's drop under the bar, the curve that joins it to the head, its own
            // corner and the foot's: each no larger than the room there is for it.
            readonly property real s: Math.min(Theme.sp2, outline.f / 2, outline.h / 3)
            readonly property real corner: Math.min(Theme.radiusSurface, outline.f / 2, Math.max(0, (outline.h - outline.s) / 2))
            readonly property real foot: Math.min(Theme.radiusSurface, Math.max(0, (outline.h - outline.s) / 2))
            ShapePath {
                fillColor: Theme.colIsland
                strokeColor: Theme.colIslandEdge
                strokeWidth: Theme.hairline
                capStyle: ShapePath.FlatCap
                joinStyle: ShapePath.RoundJoin
                startX: outline.hl
                startY: 0
                PathArc {
                    x: outline.hl - outline.s
                    y: outline.s
                    radiusX: outline.s
                    radiusY: outline.s
                    direction: PathArc.Clockwise
                }
                PathLine {
                    x: outline.l + outline.corner
                    y: outline.s
                }
                PathArc {
                    x: outline.l
                    y: outline.s + outline.corner
                    radiusX: outline.corner
                    radiusY: outline.corner
                    direction: PathArc.Counterclockwise
                }
                PathLine {
                    x: outline.l
                    y: outline.h - outline.foot
                }
                PathArc {
                    x: outline.l + outline.foot
                    y: outline.h
                    radiusX: outline.foot
                    radiusY: outline.foot
                    direction: PathArc.Counterclockwise
                }
                PathLine {
                    x: outline.r - outline.foot
                    y: outline.h
                }
                PathArc {
                    x: outline.r
                    y: outline.h - outline.foot
                    radiusX: outline.foot
                    radiusY: outline.foot
                    direction: PathArc.Counterclockwise
                }
                PathLine {
                    x: outline.r
                    y: outline.s + outline.corner
                }
                PathArc {
                    x: outline.r - outline.corner
                    y: outline.s
                    radiusX: outline.corner
                    radiusY: outline.corner
                    direction: PathArc.Counterclockwise
                }
                PathLine {
                    x: outline.hr + outline.s
                    y: outline.s
                }
                PathArc {
                    x: outline.hr
                    y: 0
                    radiusX: outline.s
                    radiusY: outline.s
                    direction: PathArc.Clockwise
                }
            }
        }

        // What it holds is revealed by the body coming down, never squeezed: each has its full
        // size from the start, and the two trade places by a fade.
        Item {
            id: holds
            width: parent.width
            height: body.tall
            clip: true

            // The keys, while the Center has the keyboard: the Center first, then Escape closes.
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

            // ── The summary: what plays, then what was not seen yet ──
            ColumnLayout {
                id: summary
                x: drop.shoulder + Theme.sp4
                y: Theme.sp3
                width: 2 * Theme.islandHalf - 2 * Theme.sp4
                spacing: Theme.sp3
                visible: opacity > 0
                opacity: Island.full ? 0 : 1
                Behavior on opacity {
                    NumberAnimation {
                        duration: Theme.motionFast
                    }
                }

                MediaCard {
                    Layout.fillWidth: true
                    visible: Island.hasMedia
                    opacity: drop.beat0
                    active: Island.open && !Island.full && Island.hasMedia
                    wave: Audio.waveOpen && !Island.full
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

            // ── Full: the NixOS Center, made the first time it is asked for ──
            Loader {
                id: center
                x: Theme.sp4
                y: Theme.sp3
                width: drop.wide - 2 * Theme.sp4
                active: drop.everFull
                visible: opacity > 0
                opacity: Island.full ? drop.beat0 : 0
                Behavior on opacity {
                    enabled: !Island.full
                    NumberAnimation {
                        duration: Theme.motionFast
                    }
                }
                sourceComponent: CenterCard {
                    bar: drop.bar
                    screen: drop.screen
                    shown: Island.full
                    onKeysWanted: keys.forceActiveFocus()
                }
            }
        }
    }
    property bool everFull: false
}
