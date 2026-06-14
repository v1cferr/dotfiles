// ============================================================================
//  Greeter quickshell para o greetd
// ----------------------------------------------------------------------------
//  DP-1 (primário): wallpaper borrado + relógio + login + quote + painel de
//  serviços ao vivo. HDMI-A-1 (TV): GIF em tela cheia. Os dados ao vivo vêm de
//  /run/greeter-status/status.json (escrito pelo coletor root); o greeter só lê.
//  Autenticação via Quickshell.Services.Greetd; ao logar, lança a sessão uwsm.
//
//  Roda como usuário `greeter`. Paleta Tokyo Night (igual Waybar/quickshell VPN).
// ============================================================================
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Services.Greetd
import QtQuick
import QtQuick.Layouts

ShellRoot {
    id: root

    property var status: ({})
    readonly property string username: "v1cferr"
    property string errorMsg: ""
    property bool awaitingResponse: false
    property bool launching: false

    // Paleta Tokyo Night
    readonly property color colBg: "#1a1b26"
    readonly property color colPanel: "#dd1f2335"
    readonly property color colBorder: "#414868"
    readonly property color colText: "#c0caf5"
    readonly property color colDim: "#565f89"
    readonly property color colGreen: "#9ece6a"
    readonly property color colRed: "#f7768e"
    readonly property color colYellow: "#e0af68"
    readonly property color colAccent: "#7aa2f7"

    // ---- feed de status: lê o JSON do coletor a cada 2s ---------------------
    Process {
        id: statusProc
        command: ["cat", "/run/greeter-status/status.json"]
        stdout: StdioCollector {
            onStreamFinished: {
                try { root.status = JSON.parse(text); } catch (e) {}
            }
        }
    }
    Timer {
        interval: 2000; repeat: true; running: true; triggeredOnStart: true
        onTriggered: statusProc.running = true
    }

    // ---- autenticação greetd ------------------------------------------------
    function startAuth() {
        if (!Greetd.available)
            return;
        root.errorMsg = "";
        root.awaitingResponse = false;
        Greetd.createSession(root.username);
    }
    function submitPassword(pw) {
        if (!Greetd.available) {
            root.errorMsg = "greetd indisponível (modo teste)";
            return;
        }
        if (root.launching)
            return;
        if (root.awaitingResponse) {
            root.awaitingResponse = false;
            Greetd.respond(pw);
        }
    }

    Component.onCompleted: startAuth()

    Connections {
        target: Greetd

        function onAuthMessage(message, error, responseRequired, echoResponse) {
            if (responseRequired)
                root.awaitingResponse = true;
            if (error)
                root.errorMsg = message;
        }
        function onReadyToLaunch() {
            root.launching = true;
            // Mesma Exec do hyprland-uwsm.desktop -> sessão segue uwsm-managed.
            Greetd.launch(["uwsm", "start", "-e", "-D", "Hyprland", "hyprland.desktop"], [], true);
        }
        function onAuthFailure(message) {
            root.errorMsg = (message && message.length) ? message : "Autenticação falhou";
            root.awaitingResponse = false;
            restartTimer.restart();
        }
        function onError(e) {
            root.errorMsg = e;
            root.awaitingResponse = false;
            restartTimer.restart();
        }
    }
    Timer { id: restartTimer; interval: 500; onTriggered: root.startAuth() }

    // ---- uma superfície fullscreen por monitor ------------------------------
    Variants {
        model: Quickshell.screens

        PanelWindow {
            id: win
            required property var modelData
            screen: modelData

            readonly property bool isPrimary: modelData.name === "DP-1"

            anchors { top: true; bottom: true; left: true; right: true }
            exclusiveZone: -1
            color: root.colBg

            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.keyboardFocus: isPrimary ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

            Loader {
                anchors.fill: parent
                sourceComponent: win.isPrimary ? primaryComp : gifComp
            }
        }
    }

    // ========================================================================
    //  Monitor secundário (HDMI-A-1) — GIF em tela cheia, rotaciona ~12s
    // ========================================================================
    Component {
        id: gifComp
        Item {
            id: gifRoot
            property int idx: 0
            readonly property var gifs: root.status.gifs || []

            Rectangle { anchors.fill: parent; color: root.colBg }

            AnimatedImage {
                anchors.fill: parent
                fillMode: Image.PreserveAspectCrop
                cache: false
                playing: true
                asynchronous: true
                source: gifRoot.gifs.length
                        ? "file://" + gifRoot.gifs[gifRoot.idx % gifRoot.gifs.length]
                        : ""
            }
            Timer {
                interval: 12000; repeat: true
                running: gifRoot.gifs.length > 1
                onTriggered: gifRoot.idx++
            }
        }
    }

    // ========================================================================
    //  Monitor primário (DP-1) — wallpaper + login + quote + painel
    // ========================================================================
    Component {
        id: primaryComp
        Item {
            anchors.fill: parent

            // fundo: wallpaper fixo do Arch (instalado em /etc/greetd pelo deploy)
            Rectangle { anchors.fill: parent; color: root.colBg }
            Image {
                anchors.fill: parent
                fillMode: Image.PreserveAspectCrop
                cache: true
                asynchronous: true
                source: "file:///etc/greetd/wallpaper.png"
            }
            Rectangle { anchors.fill: parent; color: "#80000000" }  // dim p/ legibilidade

            // ----- coluna de login (centro-esquerda) -----
            ColumnLayout {
                anchors.left: parent.left
                anchors.leftMargin: parent.width * 0.10
                anchors.verticalCenter: parent.verticalCenter
                width: 360
                spacing: 18

                // relógio
                Text {
                    id: clock
                    color: root.colText
                    font.pixelSize: 64
                    font.bold: true
                    property var now: new Date()
                    text: Qt.formatDateTime(now, "HH:mm")
                    Timer {
                        interval: 1000; repeat: true; running: true; triggeredOnStart: true
                        onTriggered: clock.now = new Date()
                    }
                }
                Text {
                    color: root.colDim
                    font.pixelSize: 18
                    text: Qt.formatDateTime(clock.now, "dddd, d 'de' MMMM")
                }

                Item { height: 8 }

                Text {
                    color: root.colText
                    font.pixelSize: 20
                    text: "Bem-vindo de volta, " + root.username
                }

                // campo de senha
                Rectangle {
                    Layout.fillWidth: true
                    height: 46
                    radius: 10
                    color: "#33000000"
                    border.color: pwInput.activeFocus ? root.colAccent : root.colBorder
                    border.width: 2

                    TextInput {
                        id: pwInput
                        anchors.fill: parent
                        anchors.leftMargin: 14
                        anchors.rightMargin: 14
                        verticalAlignment: TextInput.AlignVCenter
                        echoMode: TextInput.Password
                        passwordCharacter: "•"
                        color: root.colText
                        font.pixelSize: 18
                        clip: true
                        focus: true
                        enabled: !root.launching
                        onAccepted: {
                            root.submitPassword(text);
                            text = "";
                        }
                        Component.onCompleted: forceActiveFocus()

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: "Senha"
                            color: root.colDim
                            font.pixelSize: 18
                            visible: pwInput.text.length === 0 && !pwInput.activeFocus
                        }
                    }
                }

                Text {
                    Layout.fillWidth: true
                    visible: root.errorMsg.length > 0
                    text: root.errorMsg
                    color: root.colRed
                    font.pixelSize: 14
                    wrapMode: Text.WordWrap
                }
                Text {
                    visible: root.launching
                    text: "Entrando…"
                    color: root.colGreen
                    font.pixelSize: 14
                }

                Item { height: 12 }

                // quote PT-BR
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 4
                    visible: (root.status.quote || "").length > 0
                    Text {
                        Layout.fillWidth: true
                        text: "“" + (root.status.quote || "") + "”"
                        color: root.colText
                        font.pixelSize: 14
                        font.italic: true
                        wrapMode: Text.WordWrap
                    }
                    Text {
                        text: "— " + (root.status.author || "")
                        color: root.colDim
                        font.pixelSize: 12
                        font.bold: true
                    }
                }
            }

            // ----- painel de serviços (direita) -----
            Rectangle {
                anchors.right: parent.right
                anchors.rightMargin: parent.width * 0.06
                anchors.verticalCenter: parent.verticalCenter
                width: 400
                height: Math.min(parent.height * 0.82, panelCol.implicitHeight + 36)
                radius: 14
                color: root.colPanel
                border.color: root.colBorder
                border.width: 1

                ColumnLayout {
                    id: panelCol
                    anchors.fill: parent
                    anchors.margins: 18
                    spacing: 10

                    // cabeçalho: containers UP, IP, uptime
                    RowLayout {
                        Layout.fillWidth: true
                        Text {
                            text: "󰡨  Serviços"
                            color: root.colAccent
                            font.pixelSize: 17
                            font.bold: true
                        }
                        Item { Layout.fillWidth: true }
                        Text {
                            text: (root.status.up || 0) + "/" + (root.status.total || 0) + " UP"
                            color: (root.status.up || 0) === (root.status.total || 0) ? root.colGreen : root.colYellow
                            font.pixelSize: 14
                            font.bold: true
                        }
                    }
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 14
                        Text {
                            text: "󰩟 " + (root.status.ip || "—")
                            color: root.colDim; font.pixelSize: 12
                        }
                        Text {
                            text: "󰔏 " + (root.status.cpu_temp ? root.status.cpu_temp + "°C" : "—")
                            color: root.colDim; font.pixelSize: 12
                        }
                        Text {
                            text: "󰢮 " + (root.status.gpu_temp ? root.status.gpu_temp + "°C" : "—")
                            color: root.colDim; font.pixelSize: 12
                        }
                    }
                    Text {
                        Layout.fillWidth: true
                        text: root.status.uptime || ""
                        color: root.colDim; font.pixelSize: 11; font.italic: true
                        elide: Text.ElideRight
                    }

                    Rectangle { Layout.fillWidth: true; height: 1; color: root.colBorder; opacity: 0.5 }

                    // alertas (só aparece quando há)
                    Repeater {
                        model: root.status.alerts || []
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 8
                            Text { text: "󰀦"; color: root.colRed; font.pixelSize: 13 }
                            Text {
                                Layout.fillWidth: true
                                text: modelData
                                color: root.colRed; font.pixelSize: 12
                                wrapMode: Text.WordWrap
                            }
                        }
                    }

                    // lista de containers por consumo de CPU
                    Repeater {
                        model: root.status.containers || []
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 8
                            Rectangle {
                                width: 8; height: 8; radius: 4
                                color: modelData.up ? root.colGreen : root.colRed
                                Layout.alignment: Qt.AlignVCenter
                            }
                            Text {
                                Layout.fillWidth: true
                                text: modelData.name
                                color: root.colText; font.pixelSize: 12
                                elide: Text.ElideRight
                            }
                            Text {
                                text: (modelData.cpu !== undefined ? modelData.cpu.toFixed(1) : "0.0") + "%"
                                color: root.colYellow; font.pixelSize: 12
                                horizontalAlignment: Text.AlignRight
                                Layout.preferredWidth: 52
                            }
                            Text {
                                text: modelData.mem || ""
                                color: root.colDim; font.pixelSize: 11
                                horizontalAlignment: Text.AlignRight
                                Layout.preferredWidth: 54
                            }
                        }
                    }

                    Item { Layout.fillHeight: true }
                }
            }
        }
    }
}
