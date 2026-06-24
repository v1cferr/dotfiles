//@ pragma UseQApplication
// Painel de controle de VPN — lista dinâmica (FAI via netExtender + todos os
// perfis vpn/wireguard do NetworkManager), cada uma com conectar/desconectar.
// Toggle externo:  qs ipc call vpn toggle   (usado pelo módulo custom/vpn da Waybar)
// Ações e status delegados ao script ~/.local/bin/vpn (vpn status-json).
import Quickshell
import Quickshell.Io
import QtQuick
import QtQuick.Layouts

ShellRoot {
    id: root

    property bool panelVisible: false
    property var vpnStatus: ({ neservice: false, vpns: [] })
    property bool busy: false

    readonly property string vpnBin: Quickshell.env("HOME") + "/.local/bin/vpn"


    function refresh() {
        statusProc.running = true;
    }

    function runVpn(action, target) {
        root.busy = true;
        actionProc.command = [root.vpnBin, action, target];
        actionProc.running = true;
    }

    IpcHandler {
        target: "vpn"

        function toggle(): void {
            root.panelVisible = !root.panelVisible;
            if (root.panelVisible)
                root.refresh();
        }

        // "open" e nao "show": "show" colide com o subcomando `qs ipc show`
        // e o CLI nunca chama a funcao.
        function open(): void {
            root.panelVisible = true;
            root.refresh();
        }

        function hide(): void {
            root.panelVisible = false;
        }
    }

    Process {
        id: statusProc
        command: [root.vpnBin, "status-json"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    root.vpnStatus = JSON.parse(text);
                } catch (e) {}
            }
        }
    }

    Process {
        id: actionProc
        onRunningChanged: {
            if (!running) {
                root.busy = false;
                root.refresh();
            }
        }
    }

    Timer {
        interval: 2000
        repeat: true
        running: root.panelVisible
        onTriggered: root.refresh()
    }

    // Auto-fechar: some sozinho quando o mouse fica fora do painel
    // (inclusive se nunca entrar). Nao fecha no meio de uma acao.
    Timer {
        interval: 2000
        running: root.panelVisible && !panelHover.hovered && !root.busy
        onTriggered: root.panelVisible = false
    }

    PanelWindow {
        id: panel
        visible: root.panelVisible

        anchors {
            top: true
            right: true
        }

        margins {
            top: 6
            right: 8
        }

        exclusiveZone: 0
        implicitWidth: 340
        implicitHeight: content.implicitHeight + 28
        color: "transparent"

        Rectangle {
            anchors.fill: parent
            radius: 12
            color: Theme.colBg
            border.color: Theme.colBorder
            border.width: 1

            HoverHandler {
                id: panelHover
            }

            ColumnLayout {
                id: content
                anchors.fill: parent
                anchors.margins: 14
                spacing: 10

                RowLayout {
                    Layout.fillWidth: true

                    Text {
                        text: "󰦝  VPN"
                        color: Theme.colAccent
                        font.pixelSize: 15
                        font.bold: true
                    }

                    Item { Layout.fillWidth: true }

                    Rectangle {
                        width: 22
                        height: 22
                        radius: 6
                        color: closeArea.containsMouse ? "#33f38ba8" : "transparent"

                        Text {
                            anchors.centerIn: parent
                            text: "✕"
                            color: closeArea.containsMouse ? Theme.colRed : Theme.colDim
                            font.pixelSize: 12
                        }

                        MouseArea {
                            id: closeArea
                            anchors.fill: parent
                            hoverEnabled: true
                            onClicked: root.panelVisible = false
                        }
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    height: 1
                    color: Theme.colBorder
                    opacity: 0.5
                }

                Text {
                    visible: (root.vpnStatus.vpns || []).length === 0
                    text: "Nenhuma VPN configurada"
                    color: Theme.colDim
                    font.pixelSize: 12
                }

                Repeater {
                    model: root.vpnStatus.vpns || []

                    VpnRow {
                        Layout.fillWidth: true
                    }
                }

                Text {
                    visible: root.busy
                    text: "executando..."
                    color: Theme.colDim
                    font.pixelSize: 11
                    font.italic: true
                }
            }
        }
    }

    component VpnRow: RowLayout {
        id: row

        required property var modelData

        readonly property bool connected: modelData.connected
        readonly property string subtitle: modelData.kind === "netextender"
            ? (root.vpnStatus.neservice
                ? "SonicWall NetExtender"
                : "SonicWall NetExtender (NEService parado)")
            : "NetworkManager"

        spacing: 10

        Rectangle {
            width: 10
            height: 10
            radius: 5
            color: row.connected ? Theme.colGreen : Theme.colRed
            Layout.alignment: Qt.AlignVCenter
        }

        ColumnLayout {
            spacing: 1
            Layout.fillWidth: true

            Text {
                text: row.modelData.name
                color: Theme.colText
                font.pixelSize: 13
                font.bold: true
            }

            Text {
                text: row.subtitle
                color: Theme.colDim
                font.pixelSize: 10
            }
        }

        Rectangle {
            implicitWidth: btnLabel.implicitWidth + 24
            implicitHeight: 28
            radius: 8
            color: btnArea.containsMouse
                ? (row.connected ? "#33f38ba8" : "#33a6e3a1")
                : "transparent"
            border.color: row.connected ? Theme.colRed : Theme.colGreen
            border.width: 1
            opacity: root.busy ? 0.4 : 1

            Text {
                id: btnLabel
                anchors.centerIn: parent
                text: row.connected ? "Desconectar" : "Conectar"
                color: row.connected ? Theme.colRed : Theme.colGreen
                font.pixelSize: 11
            }

            MouseArea {
                id: btnArea
                anchors.fill: parent
                hoverEnabled: true
                enabled: !root.busy
                onClicked: root.runVpn(row.connected ? "disconnect" : "connect", row.modelData.id)
            }
        }
    }

    // OSD (toast) de volume/mic, bottom-center no DP-1. Componente em Osd.qml.
    Osd {}

    // Painel de controle de mídia (Spotify), modelo do painel de VPN. Componente em Mpris.qml.
    Mpris {}

    // Barra principal — substitui a Waybar. Componente em Bar.qml.
    Bar {}

    // Notificações nativas (toasts + central) — substitui o swaync.
    // Serviço/daemon em Notifs.qml (singleton); UI em Notifications.qml.
    Notifications {}
}
