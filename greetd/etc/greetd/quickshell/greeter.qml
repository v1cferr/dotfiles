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

    readonly property bool ready: root.status.ready === true

    // ---- data em PT-BR, igual ao hyprlock (semana ISO + 1ª letra maiúscula) --
    function isoWeek(date) {
        var d = new Date(Date.UTC(date.getFullYear(), date.getMonth(), date.getDate()));
        var dayNum = (d.getUTCDay() + 6) % 7;
        d.setUTCDate(d.getUTCDate() - dayNum + 3);
        var firstThu = d.getTime();
        d.setUTCMonth(0, 1);
        if (d.getUTCDay() !== 4)
            d.setUTCMonth(0, 1 + ((4 - d.getUTCDay()) + 7) % 7);
        return 1 + Math.ceil((firstThu - d) / 604800000);
    }
    function fmtDate(d) {
        var s = Qt.locale("pt_BR").toString(d, "dddd, dd 'de' MMMM 'de' yyyy");
        s = s + "  ·  Semana " + root.isoWeek(d);
        return s.charAt(0).toUpperCase() + s.slice(1);
    }

    // memória absoluta: MiB e, a partir de 1024 MiB, GiB
    function fmtMem(mib) {
        if (mib === undefined || mib === null) return "—";
        if (mib >= 1024) return (mib / 1024).toFixed(2) + " GiB";
        return Math.round(mib) + " MiB";
    }

    // uptime adaptativo HH:MM:SS (+ dias quando passa de 24h)
    function fmtUptime(s) {
        s = Math.max(0, Math.floor(s));
        var d = Math.floor(s / 86400); s -= d * 86400;
        var h = Math.floor(s / 3600);  s -= h * 3600;
        var m = Math.floor(s / 60);    var sec = s - m * 60;
        function p(n) { return (n < 10 ? "0" : "") + n; }
        return (d > 0 ? d + "d " : "") + p(h) + ":" + p(m) + ":" + p(sec);
    }

    // uptime tickando localmente (1s), resincronizado pelo coletor
    property int upSecs: 0
    Timer {
        interval: 1000; repeat: true; running: true
        onTriggered: root.upSecs += 1
    }

    // ---- feed de status: lê o JSON do coletor a cada 1s ---------------------
    Process {
        id: statusProc
        command: ["cat", "/run/greeter-status/status.json"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    root.status = JSON.parse(text);
                    var u = root.status.uptime_secs || 0;
                    if (Math.abs(u - root.upSecs) > 2)   // resync se divergiu
                        root.upSecs = u;
                } catch (e) {}
            }
        }
    }
    Timer {
        interval: 1000; repeat: true; running: true; triggeredOnStart: true
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

            // esconde o cursor do mouse (nada é clicável; o foco é só teclado)
            MouseArea {
                anchors.fill: parent
                acceptedButtons: Qt.NoButton
                hoverEnabled: true
                cursorShape: Qt.BlankCursor
            }

            Loader {
                anchors.fill: parent
                sourceComponent: win.isPrimary ? primaryComp : gifComp
            }
        }
    }

    // ========================================================================
    //  Monitor secundário (HDMI-A-1) — GIF em tela cheia, rotaciona a cada 2.5min
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
                interval: 150000; repeat: true   // 2.5 min, igual ao ROTATE do hyprlock
                running: gifRoot.gifs.length > 1
                onTriggered: gifRoot.idx++
            }

            // loading enquanto os GIFs não foram copiados ainda
            Text {
                anchors.centerIn: parent
                visible: gifRoot.gifs.length === 0
                text: "carregando…"
                color: root.colDim
                font.pixelSize: 22
                SequentialAnimation on opacity {
                    running: gifRoot.gifs.length === 0
                    loops: Animation.Infinite
                    NumberAnimation { from: 0.3; to: 1.0; duration: 800 }
                    NumberAnimation { from: 1.0; to: 0.3; duration: 800 }
                }
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
            Rectangle { anchors.fill: parent; color: "#99000000" }  // dim p/ legibilidade (~60%)

            // ----- coluna de login (centro-esquerda) -----
            ColumnLayout {
                anchors.left: parent.left
                anchors.leftMargin: parent.width * 0.10
                anchors.verticalCenter: parent.verticalCenter
                width: 360
                spacing: 18

                // relógio (com segundos, igual hyprlock)
                Text {
                    id: clock
                    color: root.colText
                    font.pixelSize: 64
                    font.bold: true
                    property var now: new Date()
                    text: Qt.formatDateTime(now, "HH:mm:ss")
                    Timer {
                        interval: 1000; repeat: true; running: true; triggeredOnStart: true
                        onTriggered: clock.now = new Date()
                    }
                }
                Text {
                    color: root.colDim
                    font.pixelSize: 18
                    text: root.fmtDate(clock.now)   // Quarta-feira, 14 de junho de 2026 · Semana 24
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

                // loading da frase (some assim que o coletor escreve a quote)
                Text {
                    visible: (root.status.quote || "").length === 0
                    text: "carregando frase…"
                    color: root.colDim; font.pixelSize: 13; font.italic: true
                    SequentialAnimation on opacity {
                        running: (root.status.quote || "").length === 0
                        loops: Animation.Infinite
                        NumberAnimation { from: 0.3; to: 1.0; duration: 800 }
                        NumberAnimation { from: 1.0; to: 0.3; duration: 800 }
                    }
                }

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

            // ----- coluna de painéis (direita): Serviços (docker) + Processos -----
            ColumnLayout {
                anchors.right: parent.right
                anchors.rightMargin: parent.width * 0.05
                anchors.verticalCenter: parent.verticalCenter
                width: 410
                spacing: 14

                // ===================== PAINEL 1: Serviços (docker) + sistema =====
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: p1.implicitHeight + 32
                    radius: 14
                    color: root.colPanel
                    border.color: root.colBorder
                    border.width: 1

                ColumnLayout {
                    id: p1
                    anchors.fill: parent
                    anchors.margins: 16
                    spacing: 9

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
                            text: root.ready ? ((root.status.up || 0) + "/" + (root.status.total || 0) + " UP") : "…"
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
                    // medidores de sistema (CPU + RAM, estilo btop)
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 6
                        RowLayout {
                            Layout.fillWidth: true; spacing: 8
                            Text { text: "CPU"; color: root.colDim; font.pixelSize: 11; Layout.preferredWidth: 32 }
                            Rectangle {
                                Layout.fillWidth: true; height: 8; radius: 4; color: "#33000000"
                                Rectangle {
                                    height: parent.height; radius: 4
                                    width: parent.width * Math.min(1, (root.status.cpu_pct || 0) / 100)
                                    color: (root.status.cpu_pct || 0) > 85 ? root.colRed : root.colAccent
                                }
                            }
                            Text {
                                text: (root.status.cpu_pct || 0) + "%"
                                color: root.colText; font.pixelSize: 11
                                Layout.preferredWidth: 40; horizontalAlignment: Text.AlignRight
                            }
                        }
                        RowLayout {
                            Layout.fillWidth: true; spacing: 8
                            Text { text: "RAM"; color: root.colDim; font.pixelSize: 11; Layout.preferredWidth: 32 }
                            Rectangle {
                                Layout.fillWidth: true; height: 8; radius: 4; color: "#33000000"
                                Rectangle {
                                    height: parent.height; radius: 4
                                    width: parent.width * Math.min(1, (root.status.mem_pct || 0) / 100)
                                    color: (root.status.mem_pct || 0) > 85 ? root.colRed : root.colGreen
                                }
                            }
                            Text {
                                text: (root.status.mem_used || "–") + " / " + (root.status.mem_total || "–")
                                color: root.colText; font.pixelSize: 11
                                Layout.preferredWidth: 86; horizontalAlignment: Text.AlignRight
                            }
                        }
                    }

                    Text {
                        Layout.fillWidth: true
                        text: "uptime  " + root.fmtUptime(root.upSecs)
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

                    // loading enquanto o coletor não terminou a 1ª leitura do docker
                    RowLayout {
                        Layout.fillWidth: true
                        visible: !root.ready
                        spacing: 8
                        Text {
                            text: "carregando serviços…"
                            color: root.colDim; font.pixelSize: 12; font.italic: true
                            SequentialAnimation on opacity {
                                running: !root.ready
                                loops: Animation.Infinite
                                NumberAnimation { from: 0.3; to: 1.0; duration: 800 }
                                NumberAnimation { from: 1.0; to: 0.3; duration: 800 }
                            }
                        }
                    }

                    // cabeçalho de colunas (Docker, ordenado por memória)
                    RowLayout {
                        Layout.fillWidth: true
                        visible: root.ready && (root.status.containers || []).length > 0
                        spacing: 8
                        Text { Layout.fillWidth: true; text: "Container (docker)"; color: root.colDim; font.pixelSize: 10 }
                        Text { text: "MEM"; color: root.colDim; font.pixelSize: 10; Layout.preferredWidth: 70; horizontalAlignment: Text.AlignRight }
                        Text { text: "CPU"; color: root.colDim; font.pixelSize: 10; Layout.preferredWidth: 48; horizontalAlignment: Text.AlignRight }
                    }

                    // lista de containers ordenada por consumo de MEMÓRIA (top 7)
                    Repeater {
                        model: root.ready ? (root.status.containers || []).slice(0, 7) : []
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
                                text: root.fmtMem(modelData.mem_mib)
                                color: root.colGreen; font.pixelSize: 12
                                horizontalAlignment: Text.AlignRight
                                Layout.preferredWidth: 70
                            }
                            Text {
                                text: (modelData.cpu !== undefined ? modelData.cpu.toFixed(1) : "0.0") + "%"
                                color: root.colDim; font.pixelSize: 11
                                horizontalAlignment: Text.AlignRight
                                Layout.preferredWidth: 48
                            }
                        }
                    }

                    // +N containers além do top 7
                    Text {
                        visible: root.ready && (root.status.containers || []).length > 7
                        text: "+ " + ((root.status.containers || []).length - 7) + " outros"
                        color: root.colDim; font.pixelSize: 10; font.italic: true
                    }
                }
                }

                // ===================== PAINEL 2: Processos (mini-btop) =========
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: p2.implicitHeight + 32
                    radius: 14
                    color: root.colPanel
                    border.color: root.colBorder
                    border.width: 1

                ColumnLayout {
                    id: p2
                    anchors.fill: parent
                    anchors.margins: 16
                    spacing: 6

                    RowLayout {
                        Layout.fillWidth: true
                        Text {
                            text: "󰍛  Processos"
                            color: root.colAccent; font.pixelSize: 17; font.bold: true
                        }
                        Item { Layout.fillWidth: true }
                        Text { text: "por memória"; color: root.colDim; font.pixelSize: 11 }
                    }

                    RowLayout {
                        Layout.fillWidth: true; spacing: 8
                        visible: (root.status.processes || []).length > 0
                        Text { Layout.fillWidth: true; text: "Processo"; color: root.colDim; font.pixelSize: 10 }
                        Text { text: "MEM"; color: root.colDim; font.pixelSize: 10; Layout.preferredWidth: 70; horizontalAlignment: Text.AlignRight }
                        Text { text: "CPU"; color: root.colDim; font.pixelSize: 10; Layout.preferredWidth: 48; horizontalAlignment: Text.AlignRight }
                    }

                    Text {
                        visible: !root.ready
                        text: "carregando…"
                        color: root.colDim; font.pixelSize: 12; font.italic: true
                    }

                    Repeater {
                        model: root.ready ? (root.status.processes || []) : []
                        RowLayout {
                            Layout.fillWidth: true; spacing: 8
                            Text {
                                Layout.fillWidth: true
                                text: modelData.name
                                color: root.colText; font.pixelSize: 12; elide: Text.ElideRight
                            }
                            Text {
                                text: root.fmtMem(modelData.mem_mib)
                                color: root.colGreen; font.pixelSize: 12
                                horizontalAlignment: Text.AlignRight; Layout.preferredWidth: 70
                            }
                            Text {
                                text: (modelData.cpu !== undefined ? modelData.cpu.toFixed(1) : "0.0") + "%"
                                color: root.colDim; font.pixelSize: 11
                                horizontalAlignment: Text.AlignRight; Layout.preferredWidth: 48
                            }
                        }
                    }
                }
                }
            }
        }
    }
}
