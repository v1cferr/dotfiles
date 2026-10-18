// The NIXOS CENTER: the logo's panel, the one place for notifications, do-not-disturb and the
// session (lock to shut down). It replaced the bell and the power menu: docs/notes/desktop/nixos-center.md
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

    readonly property int sw: center.screen ? center.screen.width : 1920
    readonly property int sh: center.screen ? center.screen.height : 1080
    implicitWidth: Math.min(520, center.sw - 2 * Theme.screenInset)
    implicitHeight: card.implicitHeight
    // The list grows with the history up to what the screen leaves, then scrolls.
    readonly property int listMax: Math.max(160, Math.min(560, center.sh - Theme.bandTop - Theme.screenInset - 220))

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
    onVisibleChanged: center.armed = -1
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
                tint: Notifs.dnd ? Theme.colPeach : Theme.colSubtext
                active: Notifs.dnd
                name: Notifs.dnd ? "Do not disturb is on: toasts are held, critical ones still show" : "Do not disturb is off"
                onClicked: Notifs.toggleDnd()
            }
            IconButton {
                glyph: "󰎟"
                tint: Theme.colSubtext
                enabled: Notifs.count > 0
                name: Notifs.count > 0 ? "Clear all " + Notifs.count + " notifications" : "Nothing to clear"
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
            // Newest first. A ScriptModel diffs the array, so an arrival adds ONE delegate and the rest stay.
            model: ScriptModel {
                values: Notifs.history ? Notifs.history.values.slice().reverse() : []
            }
            delegate: NotifCard {
                required property var modelData
                width: ListView.view.width
                notif: modelData
                isPopup: false
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
