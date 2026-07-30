// "Botão Iniciar" estilo taskbar: logo do NixOS no canto sup. esquerdo da barra.
// Clique abre um menu de energia (bloquear/sair/suspender/reiniciar/desligar).
// Nada de sudo: poweroff/reboot/suspend via systemd-logind (sessão ativa =
// autorizado sem senha); lock via loginctl (dispara o hyprlock); sair via uwsm.
import Quickshell
import Quickshell.Io
import QtQuick
import QtQuick.Layouts
import "root:/"
import "root:/widgets"

Pill {
    id: powerBtn
    icon: ""      // nf-linux-nixos (logo do NixOS)
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
            top: 4 // = gaps_out do Hyprland: alinha o popover com o topo das janelas (barExclusiveZone 30 já somada)
            left: 8
        }
        exclusiveZone: 0
        color: "transparent"
        implicitWidth: 210
        implicitHeight: menuCard.implicitHeight

        // Some sozinho quando o mouse sai (igual ao painel de VPN).
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
                            label: "Bloquear",
                            cmd: ["loginctl", "lock-session"],
                            danger: false
                        },
                        {
                            // Escurece a tela na hora (gamma 0 via hyprsunset, NUNCA
                            // dpms — ver idle-dim.sh / hyprlock-dpms-freeze). Restaura
                            // sozinho ao mexer no mouse/teclado (on-resume do hypridle)
                            // ou ao deslizar o brilho. Útil pra dormir sem luz no quarto.
                            icon: "󰖔",
                            label: "Escurecer",
                            cmd: ["hyprctl", "hyprsunset", "gamma", "0"], // gamma 0 = preto; restaura no brilho/resume
                            danger: false
                        },
                        {
                            icon: "󰗽",
                            label: "Sair",
                            cmd: ["sh", "-c", "loginctl terminate-user \"$USER\""], // LightDM lança o Hypr cru (sem uwsm)
                            danger: false
                        },
                        {
                            icon: "󰒲",
                            label: "Suspender",
                            cmd: ["systemctl", "suspend"],
                            danger: false
                        },
                        {
                            icon: "󰜉",
                            label: "Reiniciar",
                            cmd: ["systemctl", "reboot"],
                            danger: true
                        },
                        {
                            icon: "󰐥",
                            label: "Desligar",
                            cmd: ["systemctl", "poweroff"],
                            danger: true
                        }
                    ]
                    delegate: Rectangle {
                        required property var modelData
                        Layout.fillWidth: true
                        implicitHeight: 32
                        radius: 8
                        // o vermelho aqui era #f38ba8, do Catppuccin ANTIGO — agora sai do my.theme
                        color: itemArea.containsMouse ? (modelData.danger ? Theme.colHoverBgDanger : Theme.colHoverBg) : "transparent"
                        Behavior on color {
                            ColorAnimation {
                                duration: Theme.hoverAnim
                                easing.type: Easing.OutQuad
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
