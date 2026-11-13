// The ISLAND's capsule: it grows out from behind the logo, the same on both sides, and says one
// thing at a time. The logo is not in it and never moves; Island.qml decides what it shows.
// docs/notes/desktop/island.md
import Quickshell.Widgets
import QtQuick
import QtQuick.Layouts
import "root:/"
import "root:/widgets"

Item {
    id: isle
    required property var host // the Bar's Scope: where a click on the capsule leads
    property var barContent: null
    property var barWindow: null

    // Whether the island rests on this strip: only the main monitor's full bar.
    property bool resting: false
    // The open island hangs from this strip's logo: here it is the head of the shape.
    readonly property bool here: !!isle.barWindow && !!isle.barWindow.screen && isle.barWindow.screen.name === Island.where
    readonly property bool wide: Island.wide && isle.here

    readonly property var ev: isle.resting ? Island.current : null
    readonly property bool shown: isle.ev !== null
    // What it showed last, so the content does not blink out while the capsule closes.
    property var last: null
    onEvChanged: if (isle.ev)
        isle.last = isle.ev
    readonly property var v: isle.view(isle.last)

    width: 2 * Theme.islandHalf
    height: Theme.barHeight

    readonly property var vpnWords: ({
            connecting: "Connecting…",
            connected: "Connected",
            disconnecting: "Disconnecting…",
            disconnected: "Off",
            error: "Did not connect"
        })
    // One event as the capsule's four fields: an icon and a name left of the logo, a level and a
    // word right of it.
    function view(e) {
        const none = {
            icon: "",
            left: "",
            right: "",
            level: -1,
            tone: Theme.colText,
            art: "",
            app: "", // an app's own icon in the icon's place: whose notification this is
            appIcon: "", // the icon that notification brought, when no entry answers for the app
            badges: false // the apps with unseen notifications, at the far end of a resting capsule
        };
        if (!e)
            return none;
        const d = e.data;
        const pct = f => Math.round(f * 100) + "%";
        switch (e.kind) {
        case "volume":
            return Object.assign(none, {
                icon: d.muted || d.level <= 0 ? "volume_off" : (d.level <= 0.5 ? "volume_down" : "volume_up"),
                left: "Volume",
                right: d.muted ? "Muted" : pct(d.level),
                level: d.muted ? 0 : d.level
            });
        case "mic":
            return Object.assign(none, {
                icon: d.muted ? "mic_off" : "mic",
                left: "Microphone",
                right: d.muted ? "Muted" : "On"
            });
        case "brightness":
            return Object.assign(none, {
                icon: "brightness_medium",
                left: "Brightness",
                right: pct(d.level),
                level: Math.min(1, d.level)
            });
        case "dpi":
            return Object.assign(none, {
                icon: "mouse",
                left: "Mouse",
                right: d.value + " DPI"
            });
        case "vpn":
            return Object.assign(none, {
                icon: d.state === "connected" ? "shield_lock" : "shield",
                left: d.name,
                right: isle.vpnWords[d.state] || "",
                tone: d.state === "error" ? Theme.colCrit : Theme.colText
            });
        case "notification":
            return Object.assign(none, {
                icon: "notifications",
                app: d.icon,
                appIcon: d.fallback || "",
                left: d.app,
                right: d.summary
            });
        case "unseen":
            return Object.assign(none, {
                icon: "notifications",
                left: d.count + " new",
                badges: true
            });
        case "bluetooth":
            return Object.assign(none, {
                icon: d.on ? "bluetooth_connected" : "bluetooth_disabled",
                left: d.name,
                right: d.on ? "Connected" : "Disconnected"
            });
        case "media":
            return Object.assign(none, {
                icon: "music_note",
                left: d.artist,
                right: d.title,
                art: d.art || "",
                badges: true
            });
        case "critical":
            return Object.assign(none, {
                icon: "warning",
                left: d.title,
                right: d.text,
                tone: Theme.colCrit
            });
        }
        return none;
    }
    // A click opens the island all the way, the NixOS Center, when it rests on what plays or on
    // what waits (and shuts it when it is open); else it leads to the surface that holds the rest.
    function act() {
        const k = isle.last ? isle.last.kind : "";
        if (Island.canOpen || Island.full)
            isle.host.togglePanel("center", isle, isle.barContent, isle.barWindow);
        else if (k === "critical")
            Island.dismiss();
        else
            isle.host.openForTest("control");
    }

    // Half the logo's slot, then the wider side, then the padding: the same on both sides.
    readonly property int inner: Theme.barCenterWidth / 2
    // While media rests there, what the wider side leaves empty on the left is the wave's, and it
    // never gets fewer than five bars.
    readonly property bool waving: Audio.waveIsland && Audio.bands.length > 0 && isle.last !== null && isle.last.kind === "media"
    readonly property int waveMin: isle.waving ? 5 * wave.bar + 4 * wave.gap + Theme.sp2 : 0
    readonly property int side: Math.min(Theme.islandHalf - isle.inner - Theme.sp3, Math.ceil(Math.max(leftRow.implicitWidth + isle.waveMin, rightRow.implicitWidth)))
    // Open, it is as wide as it gets: what comes down under it has that width.
    readonly property int half: isle.wide ? Theme.islandHalf : (isle.shown ? isle.inner + isle.side + Theme.sp3 : isle.inner)

    function resize() {
        grow.stop();
        shrink.stop();
        if (Theme.motionReduced) {
            capsule.reach = isle.half;
        } else if (isle.shown || isle.wide) {
            grow.to = isle.half;
            grow.restart();
        } else {
            shrink.to = isle.half;
            shrink.restart();
        }
    }
    onHalfChanged: isle.resize()
    Component.onCompleted: capsule.reach = isle.half
    SpringAnimation {
        id: grow
        target: capsule
        property: "reach"
        spring: Theme.islandSpring
        damping: Theme.islandDamping
        epsilon: 0.25
    }
    NumberAnimation {
        id: shrink
        target: capsule
        property: "reach"
        duration: Theme.motionHover
        easing.type: Easing.OutCubic
    }

    // A NEW event enters in three beats, out from the logo: the icon, the name, the value. The
    // same event changing its content does not replay this (its texts fade through instead).
    property real beat0: 1
    property real beat1: 1
    property real beat2: 1
    readonly property real slide: Theme.sp1 * 1.5
    Connections {
        target: Island
        function onSeqChanged() {
            if (!Island.current || Theme.motionReduced)
                return;
            isle.beat0 = 0;
            isle.beat1 = 0;
            isle.beat2 = 0;
            enter.restart();
        }
    }
    component Beat: NumberAnimation {
        target: isle
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
                duration: Theme.motionStagger
            }
            Beat {
                property: "beat1"
            }
        }
        SequentialAnimation {
            PauseAnimation {
                duration: Theme.motionStagger * 2
            }
            Beat {
                property: "beat2"
            }
        }
    }

    // Open, the capsule is the head of one shape: opaque, down to the bar's foot, its lower corners
    // squaring as the body comes down under them (bar/IslandDrop.qml starts where the bar ends).
    Item {
        visible: isle.wide
        x: capsule.x
        y: capsule.y
        width: capsule.width
        height: Theme.barHeight - capsule.y
        clip: true
        Rectangle {
            width: parent.width
            // Taller than its window by the radius: the foot's edge and corners fall outside it.
            height: parent.height + Math.min(capsule.radius, Island.dropReach)
            radius: capsule.radius
            color: Theme.colIsland
            border.width: Theme.hairline
            border.color: Theme.colIslandEdge
        }
        // What the head covers on a strip with no room kept for it takes no click through it.
        MouseArea {
            anchors.fill: parent
        }
    }
    Rectangle {
        id: capsule
        // Opening or changing size it is pulled by a spring and overshoots a little; closing it
        // just eases out, faster. It never gets smaller than the logo's own slot, nor wider than
        // the island's.
        property real reach: isle.inner
        readonly property real span: Math.min(Theme.islandHalf, Math.max(isle.inner, capsule.reach))
        x: Math.round(isle.width / 2 - capsule.span)
        y: Theme.barCellY
        width: Math.round(2 * capsule.span)
        height: Theme.barCell
        radius: height / 2
        color: isle.wide ? "transparent" : Theme.colCellHoverFill
        opacity: isle.shown ? 1 : 0
        Behavior on opacity {
            NumberAnimation {
                duration: Theme.motionFast
            }
        }
        clip: true

        Wave {
            id: wave
            visible: isle.waving
            x: Math.round(capsule.width / 2 - isle.inner - isle.side)
            width: Math.max(0, isle.side - leftRow.width - Theme.sp2)
            height: Theme.barLogo - Theme.sp1
            anchors.verticalCenter: parent.verticalCenter
            opacity: isle.beat1
            bands: Audio.bands
        }
        RowLayout {
            id: leftRow
            x: Math.round(capsule.width / 2 - isle.inner - leftRow.width)
            width: Math.min(leftRow.implicitWidth, isle.side - isle.waveMin)
            height: parent.height
            spacing: Theme.sp1
            // The cover while media plays; the event's icon otherwise, and when a cover fails to load.
            ClippingRectangle {
                opacity: isle.beat0
                scale: 0.8 + 0.2 * isle.beat0
                visible: isle.v.art !== "" && cover.status === Image.Ready
                implicitWidth: Theme.barLogo
                implicitHeight: Theme.barLogo
                radius: Theme.sp1
                color: Theme.colCellPressFill
                Image {
                    id: cover
                    anchors.fill: parent
                    source: isle.v.art
                    sourceSize.width: Theme.barLogo * 2
                    sourceSize.height: Theme.barLogo * 2
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                }
            }
            // The app a notification came from, by its own icon.
            AppIcon {
                visible: isle.v.app !== ""
                opacity: isle.beat0
                scale: 0.8 + 0.2 * isle.beat0
                name: isle.v.app
                fallback: isle.v.appIcon
                size: Theme.iconBar
            }
            Text {
                visible: isle.v.app === "" && !(isle.v.art !== "" && cover.status === Image.Ready)
                opacity: isle.beat0
                scale: 0.8 + 0.2 * isle.beat0
                text: isle.v.icon
                color: isle.v.tone
                font.family: Theme.iconFont
                font.pixelSize: Theme.iconBar
                font.variableAxes: Theme.iconAxes
            }
            SwapText {
                Layout.fillWidth: true
                Layout.fillHeight: true
                text: isle.v.left
                epoch: Island.seq
                color: Theme.colSubtext
                opacity: isle.beat1
                transform: Translate {
                    x: (1 - isle.beat1) * isle.slide
                }
            }
        }
        RowLayout {
            id: rightRow
            x: Math.round(capsule.width / 2 + isle.inner)
            width: Math.min(rightRow.implicitWidth, isle.side)
            height: parent.height
            spacing: Theme.sp2
            Rectangle {
                visible: isle.v.level >= 0
                opacity: isle.beat2
                implicitWidth: Theme.sp6 * 2
                implicitHeight: Theme.sp1
                radius: height / 2
                color: Theme.colCellPressFill
                Rectangle {
                    width: Math.round(parent.width * Math.max(0, Math.min(1, isle.v.level)))
                    height: parent.height
                    radius: parent.radius
                    color: Theme.colText
                    Behavior on width {
                        NumberAnimation {
                            duration: Theme.motionFast
                        }
                    }
                }
            }
            SwapText {
                Layout.fillWidth: true
                Layout.fillHeight: true
                text: isle.v.right
                epoch: Island.seq
                // A level's number ticks with the key: it changes, it does not fade.
                animate: isle.v.level < 0
                color: isle.v.tone
                features: Theme.fontTabular
                opacity: isle.beat2
                transform: Translate {
                    x: -(1 - isle.beat2) * isle.slide
                }
            }
            // Apps with notifications not seen yet: their icons rest here, up to three.
            Row {
                id: badges
                visible: isle.v.badges && Notifs.unseenApps.length > 0
                opacity: isle.beat2
                spacing: Theme.sp1
                Repeater {
                    model: isle.v.badges ? Notifs.unseenApps.slice(0, 3) : []
                    AppIcon {
                        required property var modelData
                        name: modelData.name
                        fallback: modelData.icon
                        size: Theme.iconBar
                    }
                }
                Text {
                    visible: Notifs.unseenApps.length > 3
                    anchors.verticalCenter: parent.verticalCenter
                    text: "+" + (Notifs.unseenApps.length - 3)
                    color: Theme.colDim
                    font.family: Theme.uiFont
                    font.pixelSize: Theme.fontSmall
                }
            }
        }
    }
    // The pointer on it holds it; resting there opens the summary, and a click opens it all. The whole
    // capsule is one zone, up to the screen's edge and down to the bar's foot, so a pointer thrown
    // at the top of the screen lands on it. Never the keyboard: it is not a window.
    MouseArea {
        x: capsule.x
        width: capsule.width
        height: Theme.barHeight
        enabled: isle.shown
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        // A pinned panel owns the bar: a hover does not open the island over it.
        onContainsMouseChanged: Island.capsuleHover = containsMouse && isle.host.pinned === ""
        onClicked: isle.act()
    }
}
