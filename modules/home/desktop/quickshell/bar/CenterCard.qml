// The NIXOS CENTER's content, the one panel of the shell: the day, the tiles (the everyday
// switches and what each is now), the levels, a line of status, what plays, then the notifications
// as its body and the session at its foot. A tile's detail is a PAGE that takes the card's place.
// It draws no surface and owns no window: its host does, and hands it the keys.
// docs/notes/desktop/nixos-center.md
import Quickshell
import Quickshell.Bluetooth
import Quickshell.Services.Notifications
import Quickshell.Services.UPower
import QtQuick
import QtQuick.Layouts
import "root:/"
import "root:/widgets"
import "root:/control"
import "root:/media"
import "root:/notifications"

Item {
    id: center
    required property var bar
    property var screen: null // the one it is shown on: its height bounds the history
    property bool shown: false // on screen right now
    // It wants the keyboard back at its host's own handler (after the question, on every open).
    signal keysWanted
    function takeKeys() {
        center.keysWanted();
    }

    readonly property int sh: center.screen ? center.screen.height : 1080
    implicitHeight: card.implicitHeight
    // The list grows with the history up to what the screen leaves, then scrolls on its own, so the
    // hardware, the screenshots and the session below it always stay in reach.
    readonly property int listMax: Math.max(160, Math.min(480, center.sh - Theme.bandTop - Theme.screenInset - 460))

    // ── Pages: "" is the main view; a tile with more to show swaps the card's content in place ──
    property string page: ""
    readonly property var pageTitles: ({
            net: "Network",
            bt: "Bluetooth",
            vpn: "VPN",
            sound: "Sound",
            power: "Power",
            shots: "Screenshots",
            system: "System"
        })
    function openPage(name) {
        tips.hide(tips.target);
        center.page = name;
        center.takeKeys();
    }
    Connections {
        target: center.bar
        function onCenterPageWantedChanged() {
            if (center.shown && center.bar.centerPageWanted !== "") {
                center.openPage(center.bar.centerPageWanted);
                center.bar.centerPageWanted = "";
            }
        }
    }
    property bool mediaOpen: false // the full media card, in the compact row's place
    Binding {
        target: Island
        property: "mediaCard"
        value: center.mediaOpen
    }

    // ── What the tiles say: each reads the service that owns its state, and sets nothing else ──
    readonly property var adapter: Bluetooth.defaultAdapter
    readonly property var btConnected: (center.adapter && center.adapter.devices ? center.adapter.devices.values : []).filter(d => d.connected)
    readonly property var vpnUp: center.bar.vpnList.filter(v => v.connected)
    readonly property string vpnPending: Object.keys(center.bar.vpnPhase).find(id => center.bar.vpnPhase[id] === "connecting") || ""
    readonly property var profileNow: ({
            [PowerProfile.Balanced]: ["Balanced", "speed"],
            [PowerProfile.Performance]: ["Gaming", "sports_esports"],
            [PowerProfile.PowerSaver]: ["Eco", "eco"]
        })[PowerProfiles.profile] || ["Power", "speed"]
    readonly property var profileHold: PowerProfiles.holds.length > 0 ? PowerProfiles.holds[0] : null
    readonly property bool memTight: center.bar.psiMem >= 10
    // The next date the calendar holds, after its filters, and how far it is.
    readonly property string todayIso: center.bar.calYear + "-" + ("0" + center.bar.calTodayM).slice(-2) + "-" + ("0" + center.bar.calTodayD).slice(-2)
    readonly property var nextDate: center.shown ? (Holidays.upcoming(center.bar.calYear, center.bar.calTodayM, center.bar.calTodayD, 1, Holidays.filters)[0] || null) : null
    function inDays(n) {
        return n <= 0 ? "today" : (n === 1 ? "tomorrow" : "in " + n + " days");
    }

    // ── The history as entries: one notification, or a GROUP of similar ones (a view; the server
    // keeps every notification). Similar = same app and summary, within 5 min of the previous one,
    // and nothing that must stand alone: a critical one, one with its own actions, a chat message. ──
    property var expanded: ({}) // group key -> open
    readonly property var entryMap: {
        const vals = Notifs.history ? Notifs.history.values.slice().reverse() : []; // newest first
        const groups = [];
        let g = null;
        for (const n of vals) {
            const acts = (n.actions || []).filter(a => a.identifier !== "default");
            const chat = n.hints && ("" + (n.hints.category || "")).startsWith("im.");
            const alone = n.urgency === NotificationUrgency.Critical || acts.length > 0 || chat;
            const t = Notifs.arrivedAt[n.id] !== undefined ? Notifs.arrivedAt[n.id] : 0;
            if (g && !alone && g.app === n.appName && g.summary === n.summary && Math.abs(g.lastT - t) <= 300000) {
                g.items.push(n);
                g.lastT = t;
                continue;
            }
            g = {
                app: n.appName,
                summary: n.summary,
                items: [n],
                lastT: t
            };
            groups.push(g);
            if (alone)
                g = null;
        }
        const map = ({});
        const keys = [];
        for (const x of groups) {
            // Keyed by its OLDEST member, which a newcomer never changes, so the delegate stays.
            const k = (x.items.length > 1 ? "g:" : "n:") + x.items[x.items.length - 1].id;
            map[k] = x;
            keys.push(k);
        }
        return {
            map: map,
            keys: keys
        };
    }
    Connections {
        target: Notifs
        function onGroupsRequested(open) {
            const e = ({});
            if (open)
                for (const k of center.entryMap.keys)
                    if (k.startsWith("g:"))
                        e[k] = true;
            center.expanded = e;
        }
    }
    function toggleGroup(k) {
        const e = Object.assign({}, center.expanded);
        e[k] = !e[k];
        center.expanded = e;
    }

    // ── Hardware: a summary of the bar's own snapshot (no read of its own); the band is the full view ──
    function tempTone(t) {
        const r = center.bar.tempFrac(t);
        return r >= 0.9 ? Theme.colCrit : (r >= 0.8 ? Theme.colAlert : (r >= 0.7 ? Theme.colWarn : Theme.colText));
    }
    readonly property var hw: {
        const b = center.bar;
        const cpu = b.tempList.find(t => t.name === "CPU");
        const gpu = b.tempList.find(t => t.name === "GPU");
        const diskCrit = b.diskTotal > 0 && (b.diskPct >= 95 || b.diskFree < 5 * 1073741824);
        const diskWarn = b.diskTotal > 0 && (b.diskPct >= 90 || b.diskFree < 20 * 1073741824);
        return [
            {
                label: "CPU",
                value: cpu ? cpu.temp + "°" : "n/a",
                caption: cpu ? cpu.chip : "no sensor",
                tone: cpu ? center.tempTone(cpu) : Theme.colUnknown,
                panel: "temp"
            },
            {
                label: "GPU",
                value: gpu ? gpu.temp + "°" : "n/a",
                caption: gpu ? gpu.chip : "no sensor",
                tone: gpu ? center.tempTone(gpu) : Theme.colUnknown,
                panel: "temp"
            },
            {
                label: "RAM",
                value: b.memTotal > 0 ? b.memPct + "%" : "n/a",
                caption: b.memTotal > 0 ? b.fmtBytes(b.memUsed) + " used" : "no data",
                tone: b.memTotal <= 0 ? Theme.colUnknown : (b.memPct >= 90 ? Theme.colWarn : Theme.colText),
                panel: "usage"
            },
            {
                label: "Disk",
                value: b.diskTotal > 0 ? b.diskPct + "%" : "n/a",
                caption: b.diskTotal > 0 ? b.fmtBytes(b.diskFree) + " free" : "no data",
                tone: b.diskTotal <= 0 ? Theme.colUnknown : (diskCrit ? Theme.colCrit : (diskWarn ? Theme.colWarn : Theme.colText)),
                panel: "usage"
            }
        ];
    }

    // ── The session: the five actions live in Power.qml, which asks before the three that end it ──
    function run(a) {
        // While one asks, a click on an action that does not ask is a no, not that action.
        if (Power.armed && !a.confirm) {
            Power.cancel();
            return;
        }
        if (!a.confirm)
            center.bar.closePanels(); // a safe action must not leave the panel over what it does
        Power.request(a.key);
    }
    // The action that is OUT of the row as a pill: armed (a second click on the pill is the yes,
    // before its ring empties), going, or failed. Nothing takes the card's place, and no line is
    // added: the pill says it all.
    readonly property string powerPhase: Power.state.phase
    onPowerPhaseChanged: if (center.powerPhase !== "idle")
        center.page = "" // the row that says it is on the main view
    readonly property bool powerGoing: !!Power.current && (center.powerPhase === "handoff" || (center.powerPhase === "busy" && !!Power.current.ends))
    readonly property string outKey: !Power.current ? "" : ((center.powerPhase === "confirm" || center.powerGoing || center.powerPhase === "error") ? Power.state.key : "")
    // What is left of the armed action's time, 1 to 0: the pill's ring. A value, not a motion, so it
    // runs with the motion off too, where the pill counts the seconds in words instead.
    property real armLeft: 1
    NumberAnimation {
        id: armClock
        target: center
        property: "armLeft"
        from: 1
        to: 0
        duration: Power.armLife
    }
    Connections {
        target: Power
        function onArmedKeyChanged() {
            armClock.stop();
            center.armLeft = 1;
            if (Power.armedKey !== "")
                armClock.start();
        }
    }
    // A question or a failure while the Center is closed (a failed suspend, `qs ipc call power ask`).
    Connections {
        target: Power
        function onAttention() {
            if (!Notifs.centerOpen)
                Notifs.toggleCenter();
        }
    }
    // The keyboard: the panel holds it with nothing focused (no ring after a click); an arrow
    // starts at the first control, Tab does by itself. Each control is a KeyTarget.
    // A key its host did not use: an arrow starts at the first control.
    function keyPressed(event) {
        // Escape answers "no" to an armed action first, then leaves a page, then the panel.
        if (event.key === Qt.Key_Escape && (center.powerPhase === "confirm" || center.powerPhase === "error")) {
            Power.cancel();
            event.accepted = true;
            return;
        }
        if (event.key === Qt.Key_Escape && center.page !== "") {
            center.page = "";
            event.accepted = true;
            return;
        }
        if ([Qt.Key_Down, Qt.Key_Right].includes(event.key)) {
            card.nextItemInFocusChain(true).forceActiveFocus(Qt.TabFocusReason);
            event.accepted = true;
        } else if ([Qt.Key_Up, Qt.Key_Left].includes(event.key)) {
            card.nextItemInFocusChain(false).forceActiveFocus(Qt.BacktabFocusReason);
            event.accepted = true;
        }
    }
    onShownChanged: {
        if (center.shown)
            center.takeKeys(); // every open starts from the panel, never from the last control
        // Closing the Center answers "no": a question is never left armed behind a closed panel.
        if (!center.shown && (Power.state.phase === "confirm" || Power.state.phase === "error"))
            Power.cancel();
        center.expanded = ({}); // groups open folded, every time
        // Every open starts on the main view, unless a page was asked for (Bar.openCenter).
        center.page = center.shown ? center.bar.centerPageWanted : "";
        center.bar.centerPageWanted = "";
        center.mediaOpen = false;
        if (center.shown) {
            powerSection.refresh(); // the sync's state, read on open instead of polled
            bootSection.refresh(); // boot-trust's record, same rule
        }
    }

    // ── Screenshots: shell-screenshot (flameshot.nix) waits for this panel to leave the frame ──
    property bool shotSave: false // the clipboard first, as the keybinds do; a file on demand
    readonly property bool primaryUp: Quickshell.screens.some(x => x.name === Theme.primaryMonitor)
    function shoot(target) {
        center.bar.closePanels();
        Quickshell.execDetached(["shell-screenshot", target, center.shotSave ? "save" : "copy"]);
    }
    // The tips of the icon controls, over the card in this panel's own window.
    GlassTip {
        id: tips
        anchors.fill: card
    }

    ColumnLayout {
        id: card
        width: parent.width
        spacing: Theme.sp3
        // Escape from a focused control bubbles up to here: "no" to an armed action first.
        Keys.onPressed: event => {
            if (event.key === Qt.Key_Escape) {
                if (center.powerPhase === "confirm" || center.powerPhase === "error")
                    Power.cancel();
                else
                    center.page !== "" ? center.page = "" : center.bar.closePanels();
                event.accepted = true;
            }
        }

        // A word of the day's line that leads somewhere.
        component Link: Text {
            id: link
            signal clicked
            color: linkArea.containsMouse ? Theme.colText : Theme.colSubtext
            font.family: Theme.uiFont
            font.pixelSize: Theme.fontBody
            elide: Text.ElideRight
            MouseArea {
                id: linkArea
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: link.clicked()
            }
        }
        // A section's name, in the small capitals every panel of the shell uses.
        component Label: Text {
            color: Theme.colDim
            font.family: Theme.uiFont
            font.pixelSize: Theme.fontSmall
            font.letterSpacing: 1
        }

        // ══ The main view; a page or the confirmation takes its place ══
        ColumnLayout {
            id: mainView
            Layout.fillWidth: true
            visible: center.page === ""
            spacing: Theme.sp3
            onVisibleChanged: if (visible && center.shown)
                mainIn.restart()
            FadeIn {
                id: mainIn
                target: mainView
                slide: -16 // back from a page: it comes from the left
            }

            // ── The day: the date, the weather, the next date the calendar holds ──
            RowLayout {
                Layout.fillWidth: true
                spacing: Theme.sp2
                Link {
                    text: center.bar.dateStr
                    color: Theme.colText
                    font.weight: Theme.weightStrong
                    onClicked: center.bar.togglePanel("cal", null, null, center.bar.popBar)
                }
                Link {
                    visible: center.bar.wHas
                    text: center.bar.wTemp + "° " + center.bar.wText
                    onClicked: center.bar.togglePanel("weather", null, null, center.bar.popBar)
                }
                Link {
                    Layout.fillWidth: true
                    horizontalAlignment: Text.AlignRight
                    visible: center.nextDate !== null
                    text: center.nextDate ? center.nextDate.display + " · " + center.inDays(Holidays.daysBetween(center.todayIso, center.nextDate.date)) : ""
                    color: Theme.colDim
                    onClicked: center.bar.togglePanel("cal", null, null, center.bar.popBar)
                }
            }

            // ── The tiles: the everyday switches, and the doors to what has more to show ──
            GridLayout {
                Layout.fillWidth: true
                columns: 4
                rowSpacing: Theme.sp2
                columnSpacing: Theme.sp2

                QuickTile {
                    icon: !center.bar.netConnected ? "signal_disconnected" : (center.bar.netEthernet ? "lan" : "wifi")
                    label: !center.bar.netConnected ? "Offline" : (center.bar.netEthernet ? "Ethernet" : "Wi-Fi")
                    name: "Network"
                    // The link's kind while it is steady; its trouble, in a word, when it is not.
                    stateText: !center.bar.netConnected ? "Offline" : (center.bar.netQuality.label === "steady" ? "Connected" : center.bar.netQuality.label)
                    action: "Click for the networks"
                    on: center.bar.netConnected
                    warn: !center.bar.netConnected
                    toggles: false
                    hasPage: true
                    tips: tips
                    onOpened: center.openPage("net")
                }
                QuickTile {
                    icon: center.adapter && center.adapter.enabled ? "bluetooth" : "bluetooth_disabled"
                    label: center.btConnected.length > 0 ? center.btConnected[0].name : "Bluetooth"
                    name: "Bluetooth"
                    available: !!center.adapter
                    stateText: !center.adapter ? "No adapter" : (!center.adapter.enabled ? "Off" : (center.btConnected.length === 0 ? "On, nothing connected" : center.btConnected.map(d => d.name).join(", ")))
                    action: "Click to turn it " + (center.adapter && center.adapter.enabled ? "off" : "on") + " · right-click for the devices"
                    on: !!center.adapter && center.adapter.enabled
                    hasPage: true
                    tips: tips
                    onToggled: center.adapter.enabled = !center.adapter.enabled
                    onOpened: center.openPage("bt")
                }
                QuickTile {
                    visible: Theme.hasVpn
                    icon: center.vpnUp.length > 0 ? "shield_lock" : "shield"
                    label: center.vpnUp.length > 0 ? center.vpnUp[0].name : "VPN"
                    name: "VPN"
                    stateText: center.vpnPending !== "" ? "Connecting…" : (center.vpnUp.length > 0 ? center.vpnUp.map(v => v.name).join(", ") : "Off")
                    action: (center.vpnUp.length > 0 ? "Click to take every tunnel down" : "Click to connect the one used last") + " · right-click for the tunnels"
                    on: center.vpnUp.length > 0
                    hasPage: true
                    tips: tips
                    onToggled: center.vpnUp.length > 0 ? center.bar.runVpn("disconnect", "all") : center.bar.runVpn("connect", center.bar.vpnLast)
                    onOpened: center.openPage("vpn")
                }
                QuickTile {
                    icon: Notifs.dnd ? "do_not_disturb_on" : "notifications"
                    label: "Focus"
                    name: "Do Not Disturb"
                    stateText: Notifs.dnd ? "Enabled: toasts are held, critical ones still show" : "Disabled"
                    action: Notifs.dnd ? "Click to disable" : "Click to enable"
                    on: Notifs.dnd
                    tips: tips
                    onToggled: Notifs.toggleDnd()
                }
                QuickTile {
                    icon: center.profileNow[1]
                    label: center.profileNow[0]
                    name: "Power profile"
                    stateText: center.profileNow[0] + (center.profileHold ? ", held by " + (center.profileHold.reason || center.profileHold.applicationId) : "")
                    action: "Click for the profiles"
                    on: PowerProfiles.profile !== PowerProfile.Balanced
                    toggles: false
                    hasPage: true
                    tips: tips
                    onOpened: center.openPage("power")
                }
                QuickTile {
                    // hypridle: on is the normal state. Off shows on the bar too, so it is never forgotten.
                    icon: center.bar.hypridleOn ? "bedtime" : "coffee"
                    label: center.bar.hypridleOn ? "Idle" : "Awake"
                    name: "Idle timeouts"
                    stateText: center.bar.hypridleOn ? "Enabled: the screens lock and sleep on idle" : "Disabled: nothing happens on idle"
                    action: center.bar.hypridleOn ? "Click to disable" : "Click to enable"
                    warn: !center.bar.hypridleOn
                    tips: tips
                    onToggled: center.bar.toggleIdle()
                }
                QuickTile {
                    icon: "screenshot_region"
                    label: "Capture"
                    name: "Screenshots"
                    stateText: center.shotSave ? "To a PNG in ~/Pictures/Screenshots" : "To the clipboard"
                    action: "Click for the targets"
                    toggles: false
                    hasPage: true
                    tips: tips
                    onOpened: center.openPage("shots")
                }
                QuickTile {
                    icon: bootSection.good && !center.memTight ? "verified_user" : "gpp_maybe"
                    label: "System"
                    name: "System"
                    // What the folded System row said: in the warning color while something is short of fine.
                    stateText: center.bar.fmtBytes(center.bar.memAvail) + " available · " + bootSection.summary
                    action: "Click for the memory and the boot's proof"
                    warn: !bootSection.good || center.memTight
                    toggles: false
                    hasPage: true
                    tips: tips
                    onOpened: center.openPage("system")
                }
            }

            // ── The levels ──
            RowLayout {
                Layout.fillWidth: true
                spacing: Theme.sp2
                Slider {
                    Layout.fillWidth: true
                    name: "Volume"
                    icon: Audio.muted || Audio.volume <= 0 ? "volume_off" : (Audio.volume <= 0.5 ? "volume_down" : "volume_up")
                    value: Audio.volume
                    dimmed: Audio.muted
                    onMoved: v => Audio.setVolume(v)
                    onIconClicked: Audio.toggleMute()
                }
                IconButton {
                    glyph: "chevron_right"
                    tint: Theme.colSubtext
                    tips: tips
                    name: "Sound"
                    stateText: Audio.sink ? (Audio.sink.description || Audio.sink.name || "") : ""
                    action: "Click for the outputs, the inputs and each app"
                    onClicked: center.openPage("sound")
                }
            }

            // The screen's level: a panel's backlight where there is one, else the compositor's gamma,
            // the same thing the brightness keys set (hypr.nix's brightness-osd).
            Slider {
                Layout.fillWidth: true
                Layout.rightMargin: Theme.barControl + Theme.sp2 // as long as the volume's, whose row ends in a chevron
                name: "Brightness"
                icon: Backlight.level <= 0.34 ? "brightness_low" : (Backlight.level <= 0.67 ? "brightness_medium" : "brightness_high")
                value: Backlight.level
                onMoved: v => Backlight.set(v)
            }

            // ── Status: four readings on one line; a click opens the panel behind each ──
            RowLayout {
                Layout.fillWidth: true
                spacing: Theme.sp2
                Repeater {
                    // By COUNT, each reading its own entry: the snapshot behind `hw` ticks every
                    // 2 s, and a model of objects would rebuild all four each time.
                    model: center.hw.length
                    delegate: Rectangle {
                        id: hwCard
                        required property int index
                        readonly property var modelData: center.hw[hwCard.index]
                        function open() {
                            center.bar.togglePanel(hwCard.modelData.panel, null, null, center.bar.popBar);
                        }
                        Layout.fillWidth: true
                        Layout.preferredWidth: 0
                        implicitHeight: Theme.barControl
                        radius: Theme.radiusControl
                        color: hwArea.containsMouse ? Theme.colHoverFill : "transparent"
                        Accessible.role: Accessible.Button
                        Accessible.name: hwCard.modelData.label + " " + hwCard.modelData.value + ", " + hwCard.modelData.caption
                        Row {
                            anchors.centerIn: parent
                            spacing: Theme.sp1
                            Text {
                                text: hwCard.modelData.label
                                color: Theme.colDim
                                font.family: Theme.uiFont
                                font.pixelSize: Theme.fontBody
                            }
                            Text {
                                text: hwCard.modelData.value
                                color: hwCard.modelData.tone
                                font.family: Theme.uiFont
                                font.pixelSize: Theme.fontBody
                                font.weight: Theme.weightStrong
                                font.features: Theme.fontTabular
                            }
                        }
                        MouseArea {
                            id: hwArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onContainsMouseChanged: containsMouse ? tips.show(hwCard, hwCard.modelData.label, hwCard.modelData.caption, "Click for the detail") : tips.hide(hwCard)
                            onClicked: hwCard.open()
                        }
                        KeyTarget {
                            onActivated: hwCard.open()
                        }
                    }
                }
            }

            // ── What plays: one row, or the whole card when asked for (media/MediaCard.qml) ──
            RowLayout {
                id: mediaRow
                visible: Media.hasPlayer && !center.mediaOpen
                Layout.fillWidth: true
                spacing: Theme.sp2
                onVisibleChanged: if (visible && center.shown)
                    mediaRowIn.restart()
                FadeIn {
                    id: mediaRowIn
                    target: mediaRow
                }
                MediaRow {
                    Layout.fillWidth: true
                }
                IconButton {
                    glyph: "expand_more"
                    tint: Theme.colSubtext
                    tips: tips
                    name: "Player"
                    stateText: Media.source
                    action: "Click for the seek bar, the wave and its volume"
                    onClicked: center.mediaOpen = true
                }
            }
            RowLayout {
                visible: Media.hasPlayer && center.mediaOpen
                Layout.fillWidth: true
                spacing: Theme.sp2
                Label {
                    Layout.fillWidth: true
                    text: "PLAYING"
                }
                IconButton {
                    glyph: "expand_less"
                    tint: Theme.colSubtext
                    tips: tips
                    name: "Player"
                    action: "Click to fold it back to one row"
                    onClicked: center.mediaOpen = false
                }
            }
            MediaCard {
                id: mediaCard
                Layout.fillWidth: true
                visible: Media.hasPlayer && center.mediaOpen
                active: center.shown && visible
                onVisibleChanged: if (visible && center.shown)
                    mediaCardIn.restart()
                FadeIn {
                    id: mediaCardIn
                    target: mediaCard
                }
                wave: Audio.waveOpen
                onRevealed: center.bar.closePanels()
            }

            // ── Notifications, the body: do-not-disturb is a tile above, clear is here ──
            RowLayout {
                Layout.fillWidth: true
                spacing: Theme.sp2
                Label {
                    Layout.fillWidth: true
                    text: "NOTIFICATIONS"
                }
                Text {
                    text: Notifs.dnd ? "Do not disturb" : (Notifs.count === 0 ? "None" : Notifs.count)
                    color: Notifs.dnd ? Theme.colAlert : Theme.colSubtext
                    font.family: Theme.uiFont
                    font.pixelSize: Theme.fontSmall
                }
                IconButton {
                    glyph: "clear_all"
                    tint: Theme.colSubtext
                    enabled: Notifs.count > 0
                    tips: tips
                    name: "Clear notifications"
                    stateText: Notifs.count > 0 ? Notifs.count + " in the history" : "Nothing to clear"
                    action: Notifs.count > 0 ? "Click to clear them all" : ""
                    onClicked: Notifs.clearAll()
                }
            }
            // The history, newest first, only the visible cards instantiated.
            ListView {
                id: list
                visible: Notifs.count > 0
                Layout.fillWidth: true
                Layout.preferredHeight: Math.min(list.contentHeight, center.listMax)
                clip: true
                spacing: Theme.sp2
                boundsBehavior: Flickable.StopAtBounds
                // Keys, newest first. A ScriptModel diffs them by value, so an arrival adds ONE delegate,
                // and a group that grows keeps its own (its content is read live from entryMap).
                model: ScriptModel {
                    values: center.entryMap.keys
                }
                delegate: ColumnLayout {
                    id: ent
                    required property string modelData
                    width: ListView.view.width
                    readonly property var entry: center.entryMap.map[ent.modelData] || null
                    readonly property bool isGroup: ent.modelData.startsWith("g:")
                    readonly property bool open: center.expanded[ent.modelData] === true
                    spacing: Theme.sp1
                    NotifCard {
                        visible: !ent.isGroup
                        Layout.fillWidth: true
                        notif: ent.entry && !ent.isGroup ? ent.entry.items[0] : null
                        isPopup: false
                    }
                    NotifGroup {
                        visible: ent.isGroup
                        Layout.fillWidth: true
                        items: ent.entry && ent.isGroup ? ent.entry.items : []
                        open: ent.open
                        onToggled: center.toggleGroup(ent.modelData)
                        onDismissAll: {
                            for (const n of ent.entry.items.slice())
                                Notifs.dismiss(n);
                        }
                    }
                    // Expanded: each one as itself, with its own time, text, actions and close.
                    Repeater {
                        model: ent.isGroup && ent.open && ent.entry ? ent.entry.items : []
                        delegate: NotifCard {
                            required property var modelData
                            Layout.fillWidth: true
                            Layout.leftMargin: Theme.sp4
                            notif: modelData
                            isPopup: false
                        }
                    }
                }
            }

            Hairline {}

            // ── The session, as icons. The three that end it ask first, in place: a click turns the
            // icon into a pill with its name and a ring that empties in 4 s, and a second click on the
            // pill is the yes. Escape, a click on another icon, the ring running out or the Center
            // closing is the no. Going or failed, the same pill says so. ──
            Item {
                id: sess
                Layout.fillWidth: true
                implicitHeight: Theme.sp6 + Theme.sp3
                readonly property int n: Power.actions.length
                readonly property real gap: Theme.sp1
                readonly property real base: (sess.width - (sess.n - 1) * sess.gap) / sess.n
                // The pill's width: its ring, its words and their padding, never under an icon's cell.
                readonly property real pillW: Math.max(sess.base, Math.min(sess.width / 2, pillWords.advanceWidth + Theme.iconSymbol + 3 * Theme.sp3))
                // How far the pill is out, 0 to 1, on the island's spring; in, a short ease.
                property real spread: 0
                readonly property real seen: Math.max(0, Math.min(1, sess.spread)) // for a color: the spring passes 1
                property string shown: "" // the key that is out, held while it goes back in
                readonly property string want: center.outKey
                onWantChanged: {
                    if (sess.want !== "")
                        sess.shown = sess.want;
                    out.stop();
                    back.stop();
                    if (Theme.motionReduced) {
                        sess.spread = sess.want !== "" ? 1 : 0;
                        if (sess.want === "")
                            sess.shown = "";
                    } else if (sess.want !== "") {
                        out.restart();
                    } else {
                        back.restart();
                    }
                }
                SpringAnimation {
                    id: out
                    target: sess
                    property: "spread"
                    to: 1
                    spring: Theme.islandSpring
                    damping: 0.45 // it settles inside the row, never past it
                    epsilon: 0.005
                }
                NumberAnimation {
                    id: back
                    target: sess
                    property: "spread"
                    to: 0
                    duration: Theme.motionHover
                    easing.type: Easing.OutCubic
                    onFinished: sess.shown = ""
                }
                readonly property var outAction: Power.actions.find(x => x.key === sess.shown) || null
                readonly property string words: !sess.outAction ? "" : (center.powerPhase === "error" ? "Failed" : (center.powerGoing ? sess.outAction.going + "…" : sess.outAction.label + (Theme.motionReduced ? " · " + Math.ceil(center.armLeft * Power.armLife / 1000) : "")))
                TextMetrics {
                    id: pillWords
                    font.family: Theme.uiFont
                    font.pixelSize: Theme.fontBody
                    font.weight: Theme.weightStrong
                    text: sess.outAction ? (sess.outAction.going + "…") : ""
                }

                Row {
                    anchors.fill: parent
                    spacing: sess.gap
                    Repeater {
                        model: Power.actions
                        delegate: Rectangle {
                            id: act
                            required property var modelData
                            readonly property bool isOut: sess.shown === act.modelData.key
                            readonly property real grow: sess.spread * (sess.pillW - sess.base)
                            readonly property bool failed: act.isOut && center.powerPhase === "error"
                            readonly property bool going: act.isOut && center.powerGoing
                            width: sess.shown === "" ? sess.base : (act.isOut ? sess.base + act.grow : sess.base - act.grow / (sess.n - 1))
                            height: parent.height
                            radius: act.isOut ? height / 2 : Theme.radiusControl
                            clip: true
                            color: act.isOut ? Qt.alpha(act.going ? Theme.colText : Theme.colRed, (act.going ? 0.08 : 0.2) * sess.seen) : (actArea.containsMouse ? (act.modelData.confirm ? Theme.colHoverBgDanger : Theme.colHoverFill) : "transparent")
                            border.width: act.isOut && !act.going ? Theme.hairline : 0
                            border.color: Qt.alpha(Theme.colRed, sess.seen)
                            Behavior on color {
                                ColorAnimation {
                                    duration: Theme.motionHover
                                }
                            }
                            Accessible.role: Accessible.Button
                            Accessible.name: act.isOut ? sess.words + (center.powerPhase === "confirm" ? ", click again to confirm" : "") : act.modelData.label

                            Row {
                                anchors.centerIn: parent
                                spacing: Theme.sp2 * sess.spread * (act.isOut ? 1 : 0)
                                Item {
                                    width: Theme.iconSymbol + Theme.sp2
                                    height: width
                                    anchors.verticalCenter: parent.verticalCenter
                                    ArmRing {
                                        anchors.fill: parent
                                        visible: act.isOut && center.powerPhase === "confirm" && !Theme.motionReduced
                                        opacity: sess.seen
                                        part: center.armLeft
                                    }
                                    Text {
                                        anchors.centerIn: parent
                                        text: act.modelData.icon
                                        color: act.going ? Theme.colSubtext : (act.modelData.confirm ? Theme.colRed : Theme.colText)
                                        font.family: Theme.uiFont
                                        font.pixelSize: act.isOut ? 14 : 18
                                    }
                                }
                                Text {
                                    visible: act.isOut && sess.spread > 0.05
                                    anchors.verticalCenter: parent.verticalCenter
                                    opacity: Math.max(0, (sess.seen - 0.4) / 0.6)
                                    text: sess.words
                                    color: act.failed ? Theme.colCrit : (act.going ? Theme.colSubtext : Theme.colText)
                                    font.family: Theme.uiFont
                                    font.pixelSize: Theme.fontBody
                                    font.weight: Theme.weightStrong
                                }
                            }
                            MouseArea {
                                id: actArea
                                anchors.fill: parent
                                hoverEnabled: true
                                enabled: !act.going
                                cursorShape: Qt.PointingHandCursor
                                onContainsMouseChanged: {
                                    if (!containsMouse)
                                        tips.hide(act);
                                    else if (act.failed)
                                        tips.show(act, act.modelData.label + " did not happen", Power.state.error, "Click to close");
                                    else if (!act.isOut)
                                        tips.show(act, act.modelData.label, "", act.modelData.confirm ? "Click, then click the pill to confirm" : "");
                                }
                                onClicked: act.failed ? Power.cancel() : center.run(act.modelData)
                            }
                            KeyTarget {
                                onActivated: act.failed ? Power.cancel() : center.run(act.modelData)
                            }
                        }
                    }
                }
            }
        }

        // ══ A page: the way back, then what the tile had more to show ══
        PageHeader {
            visible: center.page !== ""
            title: center.pageTitles[center.page] || ""
            onBack: center.page = ""
        }
        ColumnLayout {
            id: pageView
            Layout.fillWidth: true
            visible: center.page !== ""
            spacing: Theme.sp3
            // Each page comes in, from the main view and from another page alike.
            Connections {
                target: center
                function onPageChanged() {
                    if (center.page !== "" && center.shown)
                        pageIn.restart();
                }
            }
            FadeIn {
                id: pageIn
                target: pageView
                slide: 16 // a page is pushed in from the right
            }

            NetworkPage {
                visible: center.page === "net"
                active: center.shown && center.page === "net"
                Layout.fillWidth: true
                // The link's own panel: the rates, the latency, the speed test.
                onDetail: center.bar.togglePanel("net", null, null, center.bar.popBar)
            }
            BluetoothPage {
                visible: center.page === "bt"
                active: center.shown && center.page === "bt"
                Layout.fillWidth: true
                onLeave: cmd => {
                    center.bar.closePanels();
                    center.bar.launch(cmd);
                }
            }
            VpnPage {
                visible: center.page === "vpn"
                Layout.fillWidth: true
                host: center.bar
            }
            SoundPage {
                visible: center.page === "sound"
                active: center.shown && center.page === "sound"
                Layout.fillWidth: true
                onLeave: cmd => {
                    center.bar.closePanels();
                    center.bar.launch(cmd);
                }
            }

            // ── Power: the ppd profile; System: the memory behind it (one PowerSection, two halves) ──
            PowerSection {
                id: powerSection
                visible: center.page === "power" || center.page === "system"
                Layout.fillWidth: true
                bar: center.bar
                part: center.page === "system" ? "readings" : "profile"
            }
            // ── What the boot chain could prove this boot (BootTrustSection.qml) ──
            BootTrustSection {
                id: bootSection
                visible: center.page === "system"
                Layout.fillWidth: true
                tips: tips
            }

            // ── Screenshots: the three targets and where the shot goes ──
            RowLayout {
                visible: center.page === "shots"
                Layout.fillWidth: true
                spacing: Theme.sp1
                Repeater {
                    model: [
                        {
                            target: "primary",
                            icon: "󰍹",
                            label: Theme.primaryName,
                            name: Theme.primaryMonitor
                        },
                        {
                            target: "secondary",
                            icon: "󰍺",
                            label: Theme.secondaryName,
                            name: Theme.secondaryMonitor
                        },
                        {
                            target: "all",
                            icon: "󰹑",
                            label: "Both",
                            name: "the whole layout"
                        }
                    ]
                    delegate: Rectangle {
                        id: shot
                        required property var modelData
                        readonly property bool up: shot.modelData.target === "primary" ? center.primaryUp : (shot.modelData.target === "secondary" ? Theme.secondaryConnected : true)
                        Layout.fillWidth: true
                        Layout.preferredWidth: 0
                        implicitHeight: Theme.sp6 * 2 + Theme.sp2
                        radius: Theme.radiusSurface
                        enabled: shot.up
                        opacity: shot.up ? 1 : Theme.opacityDisabled
                        color: shotArea.containsMouse ? Theme.colHoverFill : Qt.alpha(Theme.colText, 0.04)
                        Accessible.role: Accessible.Button
                        Accessible.name: "Screenshot of " + shot.modelData.name + (shot.up ? "" : ", not connected")
                        ColumnLayout {
                            anchors.centerIn: parent
                            spacing: 2
                            Text {
                                Layout.alignment: Qt.AlignHCenter
                                text: shot.modelData.icon
                                color: Theme.colText
                                font.family: Theme.uiFont
                                font.pixelSize: 16
                            }
                            Text {
                                Layout.alignment: Qt.AlignHCenter
                                text: shot.modelData.label
                                color: Theme.colSubtext
                                font.family: Theme.uiFont
                                font.pixelSize: Theme.fontSmall
                            }
                        }
                        MouseArea {
                            id: shotArea
                            anchors.fill: parent
                            hoverEnabled: true
                            enabled: shot.up
                            cursorShape: Qt.PointingHandCursor
                            onClicked: center.shoot(shot.modelData.target)
                        }
                        KeyTarget {
                            activeFocusOnTab: shot.up
                            onActivated: center.shoot(shot.modelData.target)
                        }
                    }
                }
            }
            RowLayout {
                visible: center.page === "shots"
                Layout.fillWidth: true
                spacing: Theme.sp2
                Label {
                    Layout.fillWidth: true
                    text: "GOES TO"
                }
                Text {
                    text: center.shotSave ? "A PNG in ~/Pictures/Screenshots" : "The clipboard"
                    color: Theme.colSubtext
                    font.family: Theme.uiFont
                    font.pixelSize: Theme.fontSmall
                }
                IconButton {
                    glyph: center.shotSave ? "󰉉" : "󰅇"
                    tint: center.shotSave ? Theme.colAccent : Theme.colSubtext
                    active: center.shotSave
                    tips: tips
                    name: "Screenshot output"
                    stateText: center.shotSave ? "A PNG in ~/Pictures/Screenshots" : "The clipboard"
                    action: center.shotSave ? "Click to copy instead" : "Click to save a PNG instead"
                    onClicked: center.shotSave = !center.shotSave
                }
            }
        }
    }
}
