// Popover de VPN, aberto pelo CLIQUE no pill 󰦝 da barra. Uma linha por VPN
// (FAI/UFSCar), com bolinha de estado e botão que alterna Conectar/Desconectar,
// mais "Desconectar tudo" no pé. Estado e ações ficam no Bar e chegam por
// referência via `bar` (mesmo contrato dos outros popovers desta pasta).
//
// SUBSTITUI o menu do rofi (`vpn menu`): era uma janela SOLTA no meio da tela,
// sem relação visual com a barra e fora do tema do shell. A lista vem do mesmo
// `vpn status-json` que o pill já consulta a cada 5s — uma fonte de verdade só,
// em vez de o rofi remontar os rótulos por conta própria com `systemctl
// is-active` (que, como o comentário do vpn.nix avisa, MENTE: durante o
// crash-loop do nxBender ele diz "active" sem existir túnel).
//
// É CLIQUE e não hover, ao contrário do calendário/weather: aqui se clica em
// botões dentro do painel, e painel que abre no hover fecha na primeira
// distração. Mesma escolha do PowerMenu, que também tem ações dentro.
import Quickshell
import QtQuick
import QtQuick.Layouts
import "root:/"

PanelWindow {
    id: vpnPop
    required property var bar

    visible: bar.vpnPopVisible
    screen: bar.popScreen || bar.screenPrimary
    anchors {
        top: true
        left: true
    }
    margins {
        top: 4 // = gaps_out do Hyprland (o barExclusiveZone 30 já está descontado)
        left: bar.popLeft(vpnPop.implicitWidth)
    }
    exclusiveZone: 0
    implicitWidth: 268
    implicitHeight: card.implicitHeight
    color: "transparent"

    // Fecha sozinho quando o mouse sai — mas NUNCA no meio de uma ação, senão o
    // painel evapora justamente enquanto se espera o resultado do clique.
    Timer {
        interval: 2500
        running: vpnPop.visible && !popHover.hovered && !vpnPop.bar.vpnBusy
        onTriggered: vpnPop.bar.vpnPopVisible = false
    }

    Rectangle {
        id: card
        anchors.fill: parent
        implicitHeight: col.implicitHeight + 24
        radius: 12
        color: Theme.colBg
        border.color: Theme.colBorder
        border.width: 1

        HoverHandler {
            id: popHover
        }

        ColumnLayout {
            id: col
            anchors.fill: parent
            anchors.margins: 12
            spacing: 8

            Text {
                text: "󰦝  VPN"
                color: Theme.colAccent
                font.family: Theme.uiFont
                font.pixelSize: 13
                font.bold: true
            }

            Rectangle {
                Layout.fillWidth: true
                height: 1
                color: Theme.colBorder
                opacity: 0.5
            }

            // Só aparece se o status-json vier vazio/ilegível — normalmente nunca.
            Text {
                visible: (vpnPop.bar.vpnList || []).length === 0
                text: "sem resposta do `vpn status-json`"
                color: Theme.colDim
                font.family: Theme.uiFont
                font.pixelSize: 11
            }

            Repeater {
                model: vpnPop.bar.vpnList || []
                delegate: RowLayout {
                    id: row
                    required property var modelData
                    readonly property bool connected: row.modelData.connected === true
                    Layout.fillWidth: true
                    spacing: 9

                    Rectangle {
                        width: 9
                        height: 9
                        radius: 4.5
                        Layout.alignment: Qt.AlignVCenter
                        color: row.connected ? Theme.colGreen : Theme.colDim
                        Behavior on color {
                            ColorAnimation {
                                duration: Theme.hoverAnim
                            }
                        }
                    }

                    Text {
                        Layout.fillWidth: true
                        text: "" + row.modelData.name
                        color: Theme.colText
                        font.family: Theme.uiFont
                        font.pixelSize: 12
                    }

                    Rectangle {
                        implicitWidth: btnLabel.implicitWidth + 20
                        implicitHeight: 24
                        radius: 7
                        color: btnArea.containsMouse ? (row.connected ? Theme.colHoverBgDanger : Theme.colHoverBgOk) : "transparent"
                        border.color: row.connected ? Theme.colRed : Theme.colGreen
                        border.width: 1
                        opacity: vpnPop.bar.vpnBusy ? 0.4 : 1
                        Behavior on color {
                            ColorAnimation {
                                duration: Theme.hoverAnim
                                easing.type: Easing.OutQuad
                            }
                        }

                        Text {
                            id: btnLabel
                            anchors.centerIn: parent
                            text: row.connected ? "Desconectar" : "Conectar"
                            color: row.connected ? Theme.colRed : Theme.colGreen
                            font.family: Theme.uiFont
                            font.pixelSize: 11
                        }

                        MouseArea {
                            id: btnArea
                            anchors.fill: parent
                            hoverEnabled: true
                            enabled: !vpnPop.bar.vpnBusy
                            onClicked: vpnPop.bar.runVpn(row.connected ? "disconnect" : "connect", row.modelData.id)
                        }
                    }
                }
            }

            Rectangle {
                Layout.fillWidth: true
                height: 1
                color: Theme.colBorder
                opacity: 0.5
                // some quando não há nenhuma conectada: separador de nada é ruído
                visible: (vpnPop.bar.vpnList || []).some(v => v.connected === true)
            }

            // Atalho p/ derrubar as duas de uma vez (o mesmo que o clique-direito no pill).
            Rectangle {
                Layout.fillWidth: true
                implicitHeight: 26
                radius: 7
                visible: (vpnPop.bar.vpnList || []).some(v => v.connected === true)
                color: allArea.containsMouse ? Theme.colMenuHoverBgDanger : "transparent"
                Behavior on color {
                    ColorAnimation {
                        duration: Theme.hoverAnim
                        easing.type: Easing.OutQuad
                    }
                }

                Text {
                    anchors.centerIn: parent
                    text: "󰗼  Desconectar tudo"
                    color: allArea.containsMouse ? Theme.colRed : Theme.colDim
                    font.family: Theme.uiFont
                    font.pixelSize: 11
                    Behavior on color {
                        ColorAnimation {
                            duration: Theme.hoverAnim
                        }
                    }
                }

                MouseArea {
                    id: allArea
                    anchors.fill: parent
                    hoverEnabled: true
                    enabled: !vpnPop.bar.vpnBusy
                    onClicked: vpnPop.bar.runVpn("disconnect", "all")
                }
            }

            Text {
                visible: vpnPop.bar.vpnBusy
                text: "executando…"
                color: Theme.colDim
                font.family: Theme.uiFont
                font.pixelSize: 10
                font.italic: true
            }
        }
    }
}
