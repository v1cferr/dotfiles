// Pílula de VPN na Waybar (ponta DIREITA, largura fixa) + painel de controle
// no hover. Passar o mouse na pílula OU no painel mantém aberto; sair dos dois
// fecha após uma folga. Status via ~/.local/bin/vpn status-json (poll).
// Ações/estado delegados ao script vpn. Estilo Tokyo Night.
import Quickshell
import Quickshell.Io
import QtQuick
import QtQuick.Layouts

Scope {
    id: root

    property var vpnStatus: ({
            neservice: false,
            vpns: []
        })
    property bool busy: false
    property bool panelVisible: false

    readonly property string vpnBin: Quickshell.env("HOME") + "/.local/bin/vpn"

    // Paleta Tokyo Night (mesma da Waybar)
    readonly property color colBg: "#f21a1b26"
    readonly property color colBorder: "#414868"
    readonly property color colText: "#c0caf5"
    readonly property color colDim: "#565f89"
    readonly property color colGreen: "#a6e3a1"
    readonly property color colRed: "#f38ba8"
    readonly property color colAccent: "#7aa2f7"
    readonly property color pillBg: "#db1a1b26"
    readonly property color pillBorder: "#59414868"
    readonly property string uiFont: "JetBrainsMono Nerd Font"

    readonly property var vpns: root.vpnStatus.vpns || []
    readonly property bool anyConnected: {
        for (let i = 0; i < root.vpns.length; i++)
            if (root.vpns[i].connected)
                return true;
        return false;
    }
    readonly property string connectedName: {
        for (let i = 0; i < root.vpns.length; i++)
            if (root.vpns[i].connected)
                return root.vpns[i].name;
        return "";
    }

    function refresh() {
        statusProc.running = true;
    }
    function runVpn(action, target) {
        root.busy = true;
        actionProc.command = [root.vpnBin, action, target];
        actionProc.running = true;
    }

    // hover-open (pílula OU painel)
    property bool pillHovered: false
    property bool panelHovered: false
    onPillHoveredChanged: root.updateOpen()
    onPanelHoveredChanged: root.updateOpen()
    function updateOpen() {
        if (root.pillHovered || root.panelHovered) {
            closeTimer.stop();
            root.panelVisible = true;
            root.refresh();
        } else {
            closeTimer.restart();
        }
    }
    Timer {
        id: closeTimer
        interval: 300
        onTriggered: if (!root.pillHovered && !root.panelHovered && !root.busy)
            root.panelVisible = false
    }

    // Mantido pra flexibilidade (keybind / waybar legado): qs ipc call vpn toggle
    IpcHandler {
        target: "vpn"
        function toggle(): void {
            root.panelVisible = !root.panelVisible;
            if (root.panelVisible)
                root.refresh();
        }
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

    // Poll de status pra pílula (sempre); mais rápido com painel aberto
    Timer {
        interval: root.panelVisible ? 2000 : 6000
        repeat: true
        running: true
        triggeredOnStart: true
        onTriggered: root.refresh()
    }

    function dp1OrNull() {
        const screens = Quickshell.screens;
        for (let i = 0; i < screens.length; i++)
            if (screens[i].name === "DP-1")
                return screens[i];
        return null;
    }

    // ===== PÍLULA (ponta direita da barra) =====
    PanelWindow {
        id: pill
        screen: root.dp1OrNull()
        anchors {
            top: true
            right: true
        }
        margins {
            top: 4
            right: 4
        }
        exclusiveZone: 0
        implicitWidth: 150
        implicitHeight: 26
        color: "transparent"

        Rectangle {
            anchors.fill: parent
            radius: 8
            color: root.pillBg
            border.color: root.pillBorder
            border.width: 1

            HoverHandler {
                id: pillHover
                onHoveredChanged: root.pillHovered = hovered
            }

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 10
                anchors.rightMargin: 10
                spacing: 6

                Text {
                    text: "󰦝"
                    color: root.anyConnected ? root.colGreen : root.colDim
                    font.family: root.uiFont
                    font.pixelSize: 13
                }
                Text {
                    Layout.fillWidth: true
                    text: root.anyConnected ? root.connectedName : "VPN"
                    color: root.anyConnected ? root.colText : root.colDim
                    font.family: root.uiFont
                    font.pixelSize: 11
                    elide: Text.ElideRight
                }
            }
        }
    }

    // ===== PAINEL (logo abaixo da pílula) =====
    PanelWindow {
        id: panel
        visible: root.panelVisible
        screen: root.dp1OrNull()
        anchors {
            top: true
            right: true
        }
        margins {
            top: 33
            right: 4
        }
        exclusiveZone: 0
        implicitWidth: 340
        implicitHeight: content.implicitHeight + 28
        color: "transparent"

        Rectangle {
            anchors.fill: parent
            radius: 12
            color: root.colBg
            border.color: root.colBorder
            border.width: 1

            HoverHandler {
                id: panelHover
                onHoveredChanged: root.panelHovered = hovered
            }

            ColumnLayout {
                id: content
                anchors.fill: parent
                anchors.margins: 14
                spacing: 10

                Text {
                    text: "󰦝  VPN"
                    color: root.colAccent
                    font.family: root.uiFont
                    font.pixelSize: 15
                    font.bold: true
                }

                Rectangle {
                    Layout.fillWidth: true
                    height: 1
                    color: root.colBorder
                    opacity: 0.5
                }

                Text {
                    visible: root.vpns.length === 0
                    text: "Nenhuma VPN configurada"
                    color: root.colDim
                    font.family: root.uiFont
                    font.pixelSize: 12
                }

                Repeater {
                    model: root.vpns

                    VpnRow {
                        Layout.fillWidth: true
                    }
                }

                Text {
                    visible: root.busy
                    text: "executando..."
                    color: root.colDim
                    font.family: root.uiFont
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
        readonly property string subtitle: modelData.kind === "netextender" ? (root.vpnStatus.neservice ? "SonicWall NetExtender" : "SonicWall NetExtender (NEService parado)") : "NetworkManager"

        spacing: 10

        Rectangle {
            width: 10
            height: 10
            radius: 5
            color: row.connected ? root.colGreen : root.colRed
            Layout.alignment: Qt.AlignVCenter
        }

        ColumnLayout {
            spacing: 1
            Layout.fillWidth: true

            Text {
                text: row.modelData.name
                color: root.colText
                font.family: root.uiFont
                font.pixelSize: 13
                font.bold: true
            }
            Text {
                text: row.subtitle
                color: root.colDim
                font.family: root.uiFont
                font.pixelSize: 10
            }
        }

        Rectangle {
            implicitWidth: btnLabel.implicitWidth + 24
            implicitHeight: 28
            radius: 8
            color: btnArea.containsMouse ? (row.connected ? "#33f38ba8" : "#33a6e3a1") : "transparent"
            border.color: row.connected ? root.colRed : root.colGreen
            border.width: 1
            opacity: root.busy ? 0.4 : 1

            Text {
                id: btnLabel
                anchors.centerIn: parent
                text: row.connected ? "Desconectar" : "Conectar"
                color: row.connected ? root.colRed : root.colGreen
                font.family: root.uiFont
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
}
