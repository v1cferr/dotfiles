// A taskbar-style "Start button": the NixOS logo in the bar's top left corner.
// A click opens a power menu (lock/log out/suspend/reboot/shut down).
// No sudo: poweroff/reboot/suspend go through systemd-logind (an active session is authorized
// with no password); the lock goes through loginctl (which fires hyprlock); logging out through
// uwsm.
import Quickshell
import Quickshell.Io
import QtQuick
import QtQuick.Layouts
import "root:/"
import "root:/widgets"

Pill {
    id: powerBtn
    icon: ""      // nf-linux-nixos (the NixOS logo)
    accent: Theme.colSapphire
    property bool menuOpen: false
    onClicked: powerBtn.menuOpen = !powerBtn.menuOpen

    Process {
        id: actionProc
    }
    function run(cmd) {
        actionProc.command = cmd;
        actionProc.running = true;
        powerBtn.menuOpen = false;
    }

    PanelWindow {
        id: menu
        visible: powerBtn.menuOpen
        screen: Theme.screenPrimary
        anchors {
            top: true
            left: true
        }
        margins {
            top: 4 // = Hyprland's gaps_out: it aligns the popover with the top of the windows (barExclusiveZone 30 already added)
            left: 8
        }
        exclusiveZone: 0
        color: "transparent"
        implicitWidth: 210
        implicitHeight: menuCard.implicitHeight

        // It disappears on its own when the mouse leaves (the same as the VPN panel).
        Timer {
            running: powerBtn.menuOpen && !menuHover.hovered
            interval: 2500
            onTriggered: powerBtn.menuOpen = false
        }

        Rectangle {
            id: menuCard
            anchors.fill: parent
            implicitHeight: col.implicitHeight + 20
            radius: 12
            color: Theme.colBg
            border.color: Theme.colBorder
            border.width: 1

            HoverHandler {
                id: menuHover
            }

            ColumnLayout {
                id: col
                anchors.fill: parent
                anchors.margins: 10
                spacing: 2

                Repeater {
                    model: [
                        {
                            icon: "󰌾",
                            label: "Lock",
                            // It brings hyprlock up DIRECTLY (the unit declared in
                            // lockscreen.nix) and only then marks the LockedHint.
                            // `loginctl lock-session` on its own did NOT lock: it only emits
                            // the Lock signal, and what listened for it was hypridle, so with
                            // hypridle stopped (Sunshine's guard) the click became a silent
                            // no-op. The `start` is idempotent, so the lock_cmd hypridle fires
                            // on seeing the signal duplicates nothing.
                            cmd: ["sh", "-c", "systemctl --user start hyprlock.service; loginctl lock-session"],
                            danger: false
                        },
                        {
                            // It darkens the screen right away (gamma 0 through hyprsunset,
                            // NEVER dpms; see idle-dim.sh / hyprlock-dpms-freeze). It restores
                            // itself on mouse/keyboard movement (hypridle's on-resume) or when
                            // sliding the brightness. Useful for sleeping with no light in the
                            // room.
                            icon: "󰖔",
                            label: "Darken",
                            cmd: ["hyprctl", "hyprsunset", "gamma", "0"], // gamma 0 = black; it restores on brightness/resume
                            danger: false
                        },
                        {
                            icon: "󰗽",
                            label: "Log out",
                            cmd: ["sh", "-c", "loginctl terminate-user \"$USER\""], // LightDM launches a bare Hypr (no uwsm)
                            danger: false
                        },
                        {
                            icon: "󰒲",
                            label: "Suspend",
                            cmd: ["systemctl", "suspend"],
                            danger: false
                        },
                        {
                            icon: "󰜉",
                            label: "Reboot",
                            cmd: ["systemctl", "reboot"],
                            danger: true
                        },
                        {
                            icon: "󰐥",
                            label: "Shut down",
                            cmd: ["systemctl", "poweroff"],
                            danger: true
                        }
                    ]
                    delegate: Rectangle {
                        required property var modelData
                        Layout.fillWidth: true
                        implicitHeight: 32
                        radius: 8
                        // the red here used to be #f38ba8, from the OLD Catppuccin; now it
                        // comes from my.theme. The colMenuHoverBg* tokens (30%): a menu row has
                        // no border, so the 20% ones are invisible (1.11:1 of contrast,
                        // measured).
                        color: itemArea.containsMouse ? (modelData.danger ? Theme.colMenuHoverBgDanger : Theme.colMenuHoverBg) : "transparent"
                        Behavior on color {
                            ColorAnimation {
                                duration: Theme.hoverAnim
                                easing.type: Easing.OutQuad
                            }
                        }

                        // the same accent bar as the tray's menu (TrayMenu.qml): the shell
                        // speaks ONE hover language, a background plus a position mark on the
                        // left.
                        Rectangle {
                            anchors.left: parent.left
                            anchors.leftMargin: 3
                            anchors.verticalCenter: parent.verticalCenter
                            width: itemArea.containsMouse ? 3 : 0
                            height: parent.height - 10
                            radius: 1.5
                            color: modelData.danger ? Theme.colRed : Theme.colAccent
                            Behavior on width {
                                NumberAnimation {
                                    duration: Theme.hoverAnim
                                    easing.type: Easing.OutQuad
                                }
                            }
                        }

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 10
                            anchors.rightMargin: 10
                            spacing: 12
                            Text {
                                text: modelData.icon
                                color: modelData.danger ? Theme.colRed : Theme.colText
                                font.family: Theme.uiFont
                                font.pixelSize: 15
                            }
                            Text {
                                Layout.fillWidth: true
                                text: modelData.label
                                color: modelData.danger ? Theme.colRed : Theme.colText
                                font.family: Theme.uiFont
                                font.pixelSize: 12
                            }
                        }
                        MouseArea {
                            id: itemArea
                            anchors.fill: parent
                            hoverEnabled: true
                            onClicked: powerBtn.run(modelData.cmd)
                        }
                    }
                }
            }
        }
    }
}
