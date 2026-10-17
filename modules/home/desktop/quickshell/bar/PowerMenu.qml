// A taskbar-style Start button: the official NixOS logo, opening lock/log out/suspend/reboot/shut
// down. No sudo (logind authorizes an active session). The lock's history: docs/notes/desktop/bar.md
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import QtQuick
import QtQuick.Layouts
import "root:/"
import "root:/widgets"

Pill {
    id: powerBtn
    // nixos-artwork's snowflake, installed by nixos-icons into hicolor; the glyph only if it is missing.
    image: Quickshell.iconPath("nix-snowflake", true)
    icon: "" // nf-linux-nixos
    accent: Theme.colSapphire
    selected: powerBtn.menuOpen
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
        WlrLayershell.namespace: "qs-panel"
        anchors {
            top: true
            left: true
        }
        // Placed from the screen's edge, under the bar, flush with the left cluster.
        exclusionMode: ExclusionMode.Ignore
        margins {
            top: Theme.bandTop
            left: Theme.barTop
        }
        color: "transparent"
        implicitWidth: 210
        implicitHeight: menuCard.implicitHeight

        // It disappears on its own when the mouse leaves (the same as the VPN panel).
        Timer {
            running: powerBtn.menuOpen && !menuHover.hovered
            interval: 2500
            onTriggered: powerBtn.menuOpen = false
        }

        GlassSurface {
            id: menuCard
            anchors.fill: parent
            implicitHeight: col.implicitHeight + 20
            level: "pop"

            transform: Translate {
                id: drop
            }
            PopIn {
                target: drop
                shown: menu.visible
            }

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
                            // It starts hyprlock's UNIT and only then marks LockedHint: `loginctl lock-session` alone only
                            // EMITS the signal, so with hypridle stopped the click was a silent no-op. `start` is idempotent.
                            cmd: ["sh", "-c", "systemctl --user start hyprlock.service; loginctl lock-session"],
                            danger: false
                        },
                        {
                            // Darken now: gamma 0 through hyprsunset, NEVER dpms. It restores on input or on the brightness
                            // slider. Useful for sleeping with no light in the room.
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
                        // the red comes from my.theme now; the 30% tokens exist because a menu row has no border.
                        color: itemArea.containsMouse ? (modelData.danger ? Theme.colMenuHoverBgDanger : Theme.colMenuHoverBg) : "transparent"
                        Behavior on color {
                            ColorAnimation {
                                duration: Theme.motionHover
                                easing.type: Easing.OutQuad
                            }
                        }

                        // the same accent bar as the tray's menu: the shell speaks ONE hover language.
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
                                    duration: Theme.motionHover
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
                            cursorShape: Qt.PointingHandCursor
                            hoverEnabled: true
                            onClicked: powerBtn.run(modelData.cmd)
                        }
                    }
                }
            }
        }
    }
}
