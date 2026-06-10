// Painel de controle de VPN (FAI.UFSCAR + VPN_UFSCar_SCL).
// Toggle externo:  qs ipc call vpn toggle   (usado pelo módulo custom/vpn da Waybar)
// Ações delegadas ao script ~/.local/bin/vpn (mesma lógica do menu rofi).
import Quickshell
import Quickshell.Io
import QtQuick
import QtQuick.Layouts

ShellRoot {
    id: root

    property bool panelVisible: false
    property var vpnStatus: ({ ufscar: false, fai: false, neservice: false })
    property bool busy: false

    readonly property string vpnBin: Quickshell.env("HOME") + "/.local/bin/vpn"

    // Paleta Tokyo Night (mesma da Waybar)
    readonly property color colBg: "#f21a1b26"
    readonly property color colBorder: "#414868"
    readonly property color colText: "#c0caf5"
    readonly property color colDim: "#565f89"
    readonly property color colGreen: "#a6e3a1"
    readonly property color colRed: "#f38ba8"
    readonly property color colAccent: "#7aa2f7"

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

        function show(): void {
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
            color: root.colBg
            border.color: root.colBorder
            border.width: 1

            ColumnLayout {
                id: content
                anchors.fill: parent
                anchors.margins: 14
                spacing: 10

                RowLayout {
                    Layout.fillWidth: true

                    Text {
                        text: "󰦝  VPN"
                        color: root.colAccent
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
                            color: closeArea.containsMouse ? root.colRed : root.colDim
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
                    color: root.colBorder
                    opacity: 0.5
                }

                VpnRow {
                    Layout.fillWidth: true
                    name: "FAI.UFSCAR"
                    subtitle: root.vpnStatus.neservice
                        ? "SonicWall NetExtender"
                        : "SonicWall NetExtender (NEService parado)"
                    connected: root.vpnStatus.fai
                    enabled: !root.busy
                    onToggleRequested: root.runVpn(root.vpnStatus.fai ? "disconnect" : "connect", "fai")
                }

                VpnRow {
                    Layout.fillWidth: true
                    name: "VPN_UFSCar_SCL"
                    subtitle: "OpenConnect via NetworkManager"
                    connected: root.vpnStatus.ufscar
                    enabled: !root.busy
                    onToggleRequested: root.runVpn(root.vpnStatus.ufscar ? "disconnect" : "connect", "ufscar")
                }

                Text {
                    visible: root.busy
                    text: "executando..."
                    color: root.colDim
                    font.pixelSize: 11
                    font.italic: true
                }
            }
        }
    }

    component VpnRow: RowLayout {
        id: row

        property string name
        property string subtitle
        property bool connected: false

        signal toggleRequested()

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
                text: row.name
                color: root.colText
                font.pixelSize: 13
                font.bold: true
            }

            Text {
                text: row.subtitle
                color: root.colDim
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
            border.color: row.connected ? root.colRed : root.colGreen
            border.width: 1
            opacity: row.enabled ? 1 : 0.4

            Text {
                id: btnLabel
                anchors.centerIn: parent
                text: row.connected ? "Desconectar" : "Conectar"
                color: row.connected ? root.colRed : root.colGreen
                font.pixelSize: 11
            }

            MouseArea {
                id: btnArea
                anchors.fill: parent
                hoverEnabled: true
                enabled: row.enabled
                onClicked: row.toggleRequested()
            }
        }
    }
}
