// The NIXOS CENTER: the logo's panel. Notifications (grouped for reading), a hardware summary,
// screenshots and the session, in that order. It replaced the bell and the power menu:
// docs/notes/desktop/nixos-center.md
import Quickshell
import Quickshell.Io
import Quickshell.Services.Notifications
import QtQuick
import QtQuick.Layouts
import "root:/"
import "root:/widgets"
import "root:/notifications"

BarPanel {
    id: center
    key: "center"
    layerNamespace: "qs-center" // shell-screenshot waits for exactly this layer to leave the frame

    readonly property int sw: center.screen ? center.screen.width : 1920
    readonly property int sh: center.screen ? center.screen.height : 1080
    implicitWidth: Math.min(520, center.sw - 2 * Theme.screenInset)
    implicitHeight: card.implicitHeight
    // The list grows with the history up to what the screen leaves, then scrolls on its own, so the
    // hardware, the screenshots and the session below it always stay in reach.
    readonly property int listMax: Math.max(160, Math.min(480, center.sh - Theme.bandTop - Theme.screenInset - 360))

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
                value: cpu ? cpu.temp + "°C" : "n/a",
                caption: cpu ? cpu.chip : "no sensor",
                tone: cpu ? center.tempTone(cpu) : Theme.colUnknown,
                panel: "temp"
            },
            {
                label: "GPU",
                value: gpu ? gpu.temp + "°C" : "n/a",
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
                label: "DISK",
                value: b.diskTotal > 0 ? b.diskPct + "%" : "n/a",
                caption: b.diskTotal > 0 ? b.fmtBytes(b.diskFree) + " free" : "no data",
                tone: b.diskTotal <= 0 ? Theme.colUnknown : (diskCrit ? Theme.colCrit : (diskWarn ? Theme.colWarn : Theme.colText)),
                panel: "usage"
            }
        ];
    }

    // ── The session: the power menu's six actions, its commands unchanged ──
    Process {
        id: actionProc
    }
    property int armed: -1 // the destructive action waiting for its confirming click
    function run(i, a) {
        if (a.confirm && center.armed !== i) {
            center.armed = i;
            disarm.restart();
            return;
        }
        center.armed = -1;
        actionProc.command = a.cmd;
        actionProc.running = true;
        center.bar.closePanels();
    }
    Timer {
        id: disarm
        interval: 4000
        onTriggered: center.armed = -1
    }
    onVisibleChanged: {
        center.armed = -1;
        center.expanded = ({}); // groups open folded, every time
    }

    // ── Screenshots: shell-screenshot (flameshot.nix) waits for this panel to leave the frame ──
    property bool shotSave: false // the clipboard first, as the keybinds do; a file on demand
    readonly property bool primaryUp: Quickshell.screens.some(x => x.name === Theme.primaryMonitor)
    function shoot(target) {
        center.bar.closePanels();
        Quickshell.execDetached(["shell-screenshot", target, center.shotSave ? "save" : "copy"]);
    }
    readonly property var actions: [
        {
            icon: "󰌾",
            label: "Lock",
            // hyprlock's UNIT first, then the LockedHint: `loginctl lock-session` alone only EMITS the signal.
            cmd: ["sh", "-c", "systemctl --user start hyprlock.service; loginctl lock-session"]
        },
        {
            icon: "󰖔",
            label: "Darken",
            cmd: ["hyprctl", "hyprsunset", "gamma", "0"] // gamma 0 through hyprsunset, NEVER dpms; input restores it
        },
        {
            icon: "󰗽",
            label: "Log out",
            cmd: ["sh", "-c", "loginctl terminate-user \"$USER\""], // LightDM launches a bare Hyprland (no uwsm)
            confirm: true
        },
        {
            icon: "󰒲",
            label: "Suspend",
            cmd: ["systemctl", "suspend"]
        },
        {
            icon: "󰜉",
            label: "Reboot",
            cmd: ["systemctl", "reboot"],
            confirm: true
        },
        {
            icon: "󰐥",
            label: "Shut down",
            cmd: ["systemctl", "poweroff"],
            confirm: true
        }
    ]

    // The tips of the icon controls, over the card in this panel's own window.
    GlassTip {
        id: tips
        anchors.fill: card
    }

    PopCard {
        id: card
        shown: center.visible
        pad: Theme.sp4
        gap: Theme.sp3
        onHoveredChanged: center.bar.panelPopHovered = card.hovered

        // ── Header: the title, then do-not-disturb and clear as icons ──
        RowLayout {
            Layout.fillWidth: true
            spacing: Theme.sp2
            Text {
                Layout.fillWidth: true
                text: "NixOS Center"
                color: Theme.colSubtext
                font.family: Theme.uiFont
                font.pixelSize: Theme.fontLabel
                font.letterSpacing: 1
            }
            IconButton {
                glyph: Notifs.dnd ? "󰂛" : "󰂚"
                tint: Notifs.dnd ? Theme.colAlert : Theme.colSubtext
                active: Notifs.dnd
                tips: tips
                name: "Do Not Disturb"
                stateText: Notifs.dnd ? "Enabled: toasts are held, critical ones still show" : "Disabled"
                action: Notifs.dnd ? "Click to disable" : "Click to enable"
                onClicked: Notifs.toggleDnd()
            }
            IconButton {
                glyph: "󰎟"
                tint: Theme.colSubtext
                enabled: Notifs.count > 0
                tips: tips
                name: "Clear notifications"
                stateText: Notifs.count > 0 ? Notifs.count + " in the history" : "Nothing to clear"
                action: Notifs.count > 0 ? "Click to clear them all" : ""
                onClicked: Notifs.clearAll()
            }
        }

        // ── Body: the history, newest first, only the visible cards instantiated ──
        Text {
            visible: Notifs.count === 0
            Layout.fillWidth: true
            Layout.topMargin: Theme.sp2
            Layout.bottomMargin: Theme.sp2
            horizontalAlignment: Text.AlignHCenter
            text: "No notifications"
            color: Theme.colDim
            font.family: Theme.uiFont
            font.pixelSize: Theme.fontBody
        }
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

        // ── Hardware ──
        Rectangle {
            Layout.fillWidth: true
            implicitHeight: Theme.hairline
            color: Theme.colEdge
        }
        Text {
            text: "HARDWARE"
            color: Theme.colDim
            font.family: Theme.uiFont
            font.pixelSize: Theme.fontSmall
            font.letterSpacing: 1
        }
        RowLayout {
            Layout.fillWidth: true
            spacing: Theme.sp2
            Repeater {
                model: center.hw
                delegate: Rectangle {
                    id: hwCard
                    required property var modelData
                    Layout.fillWidth: true
                    Layout.preferredWidth: 0
                    implicitHeight: hwCol.implicitHeight + 2 * Theme.sp2
                    radius: Theme.radiusControl
                    color: hwArea.containsMouse ? Theme.colHoverFill : Qt.alpha(Theme.colText, 0.04)
                    Accessible.role: Accessible.Button
                    Accessible.name: hwCard.modelData.label + " " + hwCard.modelData.value + ", " + hwCard.modelData.caption
                    ColumnLayout {
                        id: hwCol
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.margins: Theme.sp2
                        spacing: 0
                        Text {
                            text: hwCard.modelData.label
                            color: Theme.colDim
                            font.family: Theme.uiFont
                            font.pixelSize: Theme.fontMicro
                            font.letterSpacing: 1
                        }
                        Text {
                            text: hwCard.modelData.value
                            color: hwCard.modelData.tone
                            font.family: Theme.uiFont
                            font.pixelSize: Theme.fontTitle
                            font.bold: true
                        }
                        Text {
                            Layout.fillWidth: true
                            text: hwCard.modelData.caption
                            color: Theme.colDim
                            font.family: Theme.uiFont
                            font.pixelSize: Theme.fontMicro
                            elide: Text.ElideRight
                        }
                    }
                    MouseArea {
                        id: hwArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        // The detail panel, from the same bar and still under the logo (no new anchor).
                        onClicked: center.bar.togglePanel(hwCard.modelData.panel, null, null, center.bar.popBar)
                    }
                }
            }
        }

        Rectangle {
            Layout.fillWidth: true
            implicitHeight: Theme.hairline
            color: Theme.colEdge
        }

        // ── Screenshots: always open, the three targets and where the shot goes ──
        RowLayout {
            Layout.fillWidth: true
            spacing: Theme.sp2
            Text {
                Layout.fillWidth: true
                text: "SCREENSHOTS"
                color: Theme.colDim
                font.family: Theme.uiFont
                font.pixelSize: Theme.fontSmall
                font.letterSpacing: 1
            }
            Text {
                text: center.shotSave ? "Save PNG" : "Clipboard"
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
        RowLayout {
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
                    implicitHeight: 44
                    radius: Theme.radiusControl
                    enabled: shot.up
                    opacity: shot.up ? 1 : Theme.opacityDisabled
                    color: shotArea.containsMouse ? Theme.colHoverFill : "transparent"
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
                }
            }
        }

        Rectangle {
            Layout.fillWidth: true
            implicitHeight: Theme.hairline
            color: Theme.colEdge
        }

        // ── Footer: the session, the three that end it ask for a second click ──
        RowLayout {
            Layout.fillWidth: true
            spacing: Theme.sp1
            Repeater {
                model: center.actions
                delegate: Rectangle {
                    id: act
                    required property var modelData
                    required property int index
                    readonly property bool armed: center.armed === act.index
                    Layout.fillWidth: true
                    Layout.preferredWidth: 0
                    implicitHeight: 52
                    radius: Theme.radiusControl
                    color: act.armed ? Theme.colMenuHoverBgDanger : (actArea.containsMouse ? (act.modelData.confirm ? Theme.colHoverBgDanger : Theme.colHoverFill) : "transparent")
                    Behavior on color {
                        ColorAnimation {
                            duration: Theme.motionHover
                        }
                    }
                    Accessible.role: Accessible.Button
                    Accessible.name: act.armed ? "Confirm " + act.modelData.label : act.modelData.label
                    ColumnLayout {
                        anchors.centerIn: parent
                        spacing: 2
                        Text {
                            Layout.alignment: Qt.AlignHCenter
                            text: act.modelData.icon
                            color: act.modelData.confirm ? Theme.colRed : Theme.colText
                            font.family: Theme.uiFont
                            font.pixelSize: 18
                        }
                        Text {
                            Layout.alignment: Qt.AlignHCenter
                            text: act.armed ? "Confirm?" : act.modelData.label
                            color: act.armed ? Theme.colRed : Theme.colSubtext
                            font.family: Theme.uiFont
                            font.pixelSize: Theme.fontSmall
                            font.bold: act.armed
                        }
                    }
                    MouseArea {
                        id: actArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: center.run(act.index, act.modelData)
                    }
                }
            }
        }
    }
}
