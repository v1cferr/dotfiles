// The ISLAND's capsule: it grows out from behind the logo, each side as wide as what it says, and says one
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
    // of their own: the disk warning is dismissed, and a level or a VPN leads to its page of the Center.
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
            isle.host.openCenter(k === "vpn" ? "vpn" : (k === "volume" || k === "mic" ? "sound" : ""));
    }

    // Half the logo's slot, then each side's own content, then the padding. The two sides need not
    // match: the logo never moves, and a side wider than what it says would only be empty glass
    // (22/11/2026: the symmetric capsule left a blank stretch after a short "30 s", and the owner
    // asked for it lopsided instead).
    readonly property int inner: Theme.barCenterWidth / 2
    // While media rests there, ONE short wave sits at the outer end of the shorter side, the bass by
    // the words, so the capsule leans less to one side. (22/11/2026: one on each side was asked away.)
    readonly property bool waving: Audio.waveIsland && Audio.bands.length > 0 && isle.last !== null && isle.last.kind === "media" && !isle.wheeling
    readonly property int waveBars: 6
    readonly property int waveWidth: isle.waveBars * wave.bar + (isle.waveBars - 1) * wave.gap
    readonly property int waveRoom: isle.waving ? isle.waveWidth + Theme.sp2 : 0
    readonly property real leftWords: leftRow.implicitWidth
    readonly property real rightWords: rightRow.implicitWidth
    readonly property bool waveRight: isle.rightWords < isle.leftWords
    readonly property int cap: Theme.islandHalf - isle.inner - Theme.sp3
    readonly property int leftSide: Math.min(isle.cap, Math.ceil(isle.leftWords + (isle.waveRight ? 0 : isle.waveRoom)))
    readonly property int rightSide: Math.min(isle.cap, Math.ceil(isle.rightWords + (isle.waveRight ? isle.waveRoom : 0)))
    readonly property int halfLeft: isle.shown ? isle.inner + isle.leftSide + Theme.sp3 : isle.inner
    readonly property int halfRight: isle.shown ? isle.inner + isle.rightSide + Theme.sp3 : isle.inner

    // Each side has its own pull: opening or changing size it is a spring that overshoots a
    // little; closing it just eases out, faster.
    function resize(pull, ease, what, to) {
        pull.stop();
        ease.stop();
        if (Theme.motionReduced) {
            capsule[what] = to;
        } else if (isle.shown) {
            pull.to = to;
            pull.restart();
        } else {
            ease.to = to;
            ease.restart();
        }
    }
    onHalfLeftChanged: isle.resize(growLeft, shrinkLeft, "reachLeft", isle.halfLeft)
    onHalfRightChanged: isle.resize(growRight, shrinkRight, "reachRight", isle.halfRight)
    Component.onCompleted: {
        capsule.reachLeft = isle.halfLeft;
        capsule.reachRight = isle.halfRight;
    }
    component Grow: SpringAnimation {
        target: capsule
        spring: Theme.islandSpring
        damping: Theme.islandDamping
        epsilon: 0.25
    }
    component Shrink: NumberAnimation {
        target: capsule
        duration: Theme.motionHover
        easing.type: Easing.OutCubic
    }
    Grow {
        id: growLeft
        property: "reachLeft"
    }
    Shrink {
        id: shrinkLeft
        property: "reachLeft"
    }
    Grow {
        id: growRight
        property: "reachRight"
    }
    Shrink {
        id: shrinkRight
        property: "reachRight"
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

    // Where the island's opening starts from, and where its closing ends: this capsule's reach,
    // as half its width and how far its middle sits right of the logo's.
    Binding {
        when: isle.here
        target: Island
        property: "headHalf"
        value: (capsule.spanLeft + capsule.spanRight) / 2
    }
    Binding {
        when: isle.here
        target: Island
        property: "headShift"
        value: (capsule.spanRight - capsule.spanLeft) / 2
    }
    Rectangle {
        id: capsule
        // Each side never gets smaller than the logo's own slot, nor wider than the island's.
        property real reachLeft: isle.inner
        property real reachRight: isle.inner
        readonly property real spanLeft: Math.min(Theme.islandHalf, Math.max(isle.inner, capsule.reachLeft))
        readonly property real spanRight: Math.min(Theme.islandHalf, Math.max(isle.inner, capsule.reachRight))
        // Where the logo's middle falls inside it.
        readonly property real mid: Math.round(capsule.spanLeft)
        x: Math.round(isle.width / 2 - capsule.spanLeft)
        y: Theme.barCellY
        width: Math.round(capsule.spanLeft + capsule.spanRight)
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
            visible: isle.waving && !isle.waveRight
            x: leftRow.x - Theme.sp2 - width
            width: isle.waveWidth
            height: Theme.barLogo - Theme.sp1
            anchors.verticalCenter: parent.verticalCenter
            opacity: isle.beat1
            bands: Audio.bands
        }
        Wave {
            id: waveRight
            visible: isle.waving && isle.waveRight
            bassLeft: true
            x: rightRow.x + rightRow.width + Theme.sp2
            width: isle.waveWidth
            height: Theme.barLogo - Theme.sp1
            anchors.verticalCenter: parent.verticalCenter
            opacity: isle.beat2
            bands: Audio.bands
        }
        RowLayout {
            id: leftRow
            x: capsule.mid - isle.inner - leftRow.width
            width: Math.min(leftRow.implicitWidth, isle.leftSide - (isle.waveRight ? 0 : isle.waveRoom))
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
            x: capsule.mid + isle.inner
            width: Math.min(rightRow.implicitWidth, isle.rightSide - (isle.waveRight ? isle.waveRoom : 0))
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
