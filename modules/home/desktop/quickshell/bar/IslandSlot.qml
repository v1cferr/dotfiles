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
    // The open island hangs from this strip's logo and draws itself, in its own window: here the
    // capsule steps aside while any of it is out.
    readonly property bool here: !!isle.barWindow && !!isle.barWindow.screen && isle.barWindow.screen.name === Island.where
    readonly property bool away: Island.wide && isle.here

    readonly property var ev: isle.resting ? Island.current : null
    readonly property bool shown: isle.ev !== null
    // What it showed last, so the content does not blink out while the capsule closes.
    property var last: null
    onEvChanged: if (isle.ev)
        isle.last = isle.ev
    // The wheel over the resting media is its volume: the capsule says the level while it turns,
    // itself, since the pointer on it holds what the island shows.
    property bool wheeling: false
    readonly property bool onMedia: isle.shown && isle.last !== null && isle.last.kind === "media"
    readonly property var v: isle.view(isle.wheeling ? {
        kind: "volume",
        data: {
            name: Audio.mediaIsPlayer ? Media.source : "",
            level: Audio.mediaVolume,
            muted: Audio.mediaMuted
        }
    } : isle.last)
    Timer {
        id: wheelRest
        interval: 1200
        onTriggered: isle.wheeling = false
    }
    function turn(up) {
        Island.hush();
        Audio.setMediaVolume(Math.round((Audio.mediaVolume + (up ? 0.05 : -0.05)) * 20) / 20);
        isle.wheeling = true;
        wheelRest.restart();
    }
    Binding {
        target: Audio
        property: "capsuleHeld"
        value: isle.onMedia && area.containsMouse
    }

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
            badges: false // what rests at the far end: what goes on in the background, the apps that wait
        };
        if (!e)
            return none;
        const d = e.data;
        const pct = f => Math.round(f * 100) + "%";
        switch (e.kind) {
        case "volume":
            return Object.assign(none, {
                icon: d.muted || d.level <= 0 ? "volume_off" : (d.level <= 0.5 ? "volume_down" : "volume_up"),
                left: d.name || "Volume",
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
                tone: d.state === "error" ? Theme.colCrit : Theme.colText,
                badges: e.ttl === 0
            });
        case "capture":
            return Object.assign(none, {
                icon: d.what === "mic" ? "mic" : (d.what === "screen" ? "screen_share" : "cast"),
                left: d.by,
                right: d.what === "mic" ? "Microphone in use" : (d.what === "screen" ? "Being captured" : "Streaming"),
                tone: Theme.colWarn,
                badges: true
            });
        case "task":
            return Object.assign(none, {
                icon: d.state === "start" ? "terminal" : (d.state === "ok" ? "check_circle" : "error"),
                left: d.name,
                right: d.state === "start" ? isle.span(Math.max(0, Math.round((isle.now - d.since) / 1000))) : (d.state === "ok" ? "Done" : "Failed") + " · " + isle.span(d.took),
                tone: d.state === "ok" || d.state === "start" ? Theme.colText : Theme.colCrit,
                badges: d.state === "start"
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
    // A running task counts its seconds, and only while the capsule shows it.
    property real now: Date.now()
    Timer {
        interval: 1000
        repeat: true
        triggeredOnStart: true
        running: isle.shown && isle.last !== null && isle.last.kind === "task" && isle.last.data.state === "start"
        onTriggered: isle.now = Date.now()
    }
    // 75 s as `1 min 15 s`.
    function span(sec) {
        const m = Math.floor(sec / 60);
        return (m > 0 ? m + " min " : "") + (sec % 60) + " s";
    }
    // A click pins the island open, the NixOS Center, except on the two things that have an answer
    // of their own: the disk warning is dismissed, and a level or a VPN leads to the Control Center.
    function act() {
        const k = isle.last ? isle.last.kind : "";
        // A notification's click goes where its card's arrow does; with nowhere to go, the Center.
        if (k === "notification" && Notifs.open(isle.last.data.id)) {
            Island.hush();
            Island.dismiss();
        } else if (k === "media" || k === "unseen" || k === "notification")
            isle.host.togglePanel("center", isle, isle.barContent, isle.barWindow);
        else if (k === "critical" || (k === "task" && isle.last.data.state !== "start"))
            Island.dismiss();
        else
            isle.host.openForTest("control");
    }

    // Half the logo's slot, then the wider side, then the padding: the same on both sides.
    readonly property int inner: Theme.barCenterWidth / 2
    // While media rests there, what the wider side leaves empty on the left is the wave's, and it
    // never gets fewer than five bars.
    readonly property bool waving: Audio.waveIsland && Audio.bands.length > 0 && isle.last !== null && isle.last.kind === "media" && !isle.wheeling
    readonly property int waveMin: isle.waving ? 5 * wave.bar + 4 * wave.gap + Theme.sp2 : 0
    readonly property int side: Math.min(Theme.islandHalf - isle.inner - Theme.sp3, Math.ceil(Math.max(leftRow.implicitWidth + isle.waveMin, rightRow.implicitWidth)))
    // Open, it is as wide as it gets: what comes down under it has that width.
    readonly property int half: isle.shown ? isle.inner + isle.side + Theme.sp3 : isle.inner

    function resize() {
        grow.stop();
        shrink.stop();
        if (Theme.motionReduced) {
            capsule.reach = isle.half;
        } else if (isle.shown) {
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

    // Where the island's opening starts from, and where its closing ends: this capsule's reach.
    Binding {
        when: isle.here
        target: Island
        property: "headHalf"
        value: capsule.span
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
        color: Theme.colBarGlass
        border.width: Theme.hairline
        border.color: Theme.colBarGlassEdge
        opacity: isle.shown && !isle.away ? 1 : 0
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
            // What goes on in the background while this has the capsule (Island.asides): its icon.
            Row {
                visible: isle.v.badges && Island.asides.length > 0
                opacity: isle.beat2
                spacing: Theme.sp1
                Repeater {
                    model: isle.v.badges ? Island.asides.length : 0
                    Text {
                        required property int index
                        readonly property var aside: isle.view(Island.asides[index] || null)
                        anchors.verticalCenter: parent.verticalCenter
                        text: aside.icon
                        color: aside.tone
                        font.family: Theme.iconFont
                        font.pixelSize: Theme.iconBar
                        font.variableAxes: Theme.iconAxes
                    }
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
    // The pointer on it holds it; resting there opens the island, and a click pins it (or goes to
    // the app a notification came from). On what plays the wheel and the middle button act instead. The whole
    // capsule is one zone, up to the screen's edge and down to the bar's foot, so a pointer thrown
    // at the top of the screen lands on it. Never the keyboard: it is not a window.
    MouseArea {
        id: area
        x: capsule.x
        width: capsule.width
        height: Theme.barHeight
        enabled: isle.shown
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        acceptedButtons: Qt.LeftButton | Qt.MiddleButton
        // On what plays: the wheel is its volume, and the middle button pauses it.
        onWheel: w => {
            if (isle.onMedia && w.angleDelta.y !== 0)
                isle.turn(w.angleDelta.y > 0);
        }
        // A pinned panel owns the bar: a hover does not open the island over it.
        onContainsMouseChanged: Island.capsuleHover = containsMouse && (isle.host.pinned === "" || isle.host.pinned === "center")
        onClicked: mouse => {
            if (mouse.button !== Qt.MiddleButton)
                isle.act();
            else if (isle.onMedia && Media.player && Media.player.canTogglePlaying) {
                Island.hush();
                Media.player.togglePlaying();
            }
        }
    }
}
