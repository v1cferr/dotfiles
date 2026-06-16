// Barra Quickshell (substituta da Waybar).
// FASE 1: shell + relógio + cpu/ram/disco.
// FASE 2: áudio (Pipewire) + Spotify (Mpris) + rede (nmcli).
// FASE 3a: cpu-temp + gpu-uso/temp (nvidia-smi) + vpn + hypridle + swaync.
// Faltam: weather(MSN, fase 3b), workspaces + título (fase 4), tray (fase 5).
import Quickshell
import Quickshell.Io
import Quickshell.Services.Pipewire
import Quickshell.Services.Mpris
import QtQuick
import QtQuick.Layouts

Scope {
    id: root

    property int barExclusiveZone: 30
    readonly property string scriptsDir: Quickshell.env("HOME") + "/.config/waybar/scripts"
    readonly property string vpnBin: Quickshell.env("HOME") + "/.local/bin/vpn"

    // ===== Paleta =====
    readonly property color colGroupBg: "#591a1b26"
    readonly property color colGroupBorder: "#2e414868"
    readonly property color colPillBg: "#db1a1b26"
    readonly property color colPillHoverBg: "#eb1a1b26"
    readonly property color colPillBorder: "#59414868"
    readonly property color colHoverBorder: "#807aa2f7"
    readonly property color colText: "#c0caf5"
    readonly property color colDim: "#565f89"
    readonly property color colAccent: "#7aa2f7"
    readonly property color colGreen: "#a6e3a1"
    readonly property color colRed: "#f38ba8"
    readonly property color colYellow: "#f9e2af"
    readonly property color colPeach: "#fab387"
    readonly property color colMauve: "#cba6f7"
    readonly property color colLavender: "#b4befe"
    readonly property color colSky: "#89dceb"
    readonly property color colBlue: "#89b4fa"
    readonly property color colSapphire: "#74c7ec"
    readonly property color colTeal: "#94e2d5"
    readonly property color colPink: "#f5c2e7"
    readonly property string uiFont: "JetBrainsMono Nerd Font"

    function stateColor(pct, base) {
        return pct >= 90 ? root.colRed : (pct >= 70 ? root.colPeach : base);
    }
    function launch(cmd) {
        Quickshell.execDetached(cmd);
    }

    // ===== Relógio =====
    property bool showDate: false
    property string timeStr: ""
    SystemClock {
        id: sysClock
        precision: SystemClock.Seconds
    }
    function updateClock() {
        const d = sysClock.date;
        root.timeStr = root.showDate ? "󰃭 " + Qt.formatDateTime(d, "dd/MM/yyyy") : "󰥔 " + Qt.formatDateTime(d, "HH:mm:ss");
    }
    Connections {
        target: sysClock
        function onDateChanged() {
            root.updateClock();
        }
    }
    Component.onCompleted: root.updateClock()

    // ===== CPU / RAM / Disco =====
    property int cpuPct: 0
    property int memPct: 0
    property int diskPct: 0
    property var cpuPrev: null
    function parseCpu(text) {
        const parts = text.trim().split(/\s+/);
        if (parts[0] !== "cpu")
            return;
        const n = parts.slice(1).map(Number);
        const total = n.reduce((a, b) => a + b, 0);
        const idle = (n[3] || 0) + (n[4] || 0);
        if (root.cpuPrev) {
            const dt = total - root.cpuPrev.total;
            const di = idle - root.cpuPrev.idle;
            if (dt > 0)
                root.cpuPct = Math.round((1 - di / dt) * 100);
        }
        root.cpuPrev = {
            total: total,
            idle: idle
        };
    }
    function parseMem(text) {
        let total = 0, avail = 0;
        const lines = text.split("\n");
        for (let i = 0; i < lines.length; i++) {
            const m = lines[i].match(/^(\w+):\s+(\d+)/);
            if (!m)
                continue;
            if (m[1] === "MemTotal")
                total = Number(m[2]);
            else if (m[1] === "MemAvailable")
                avail = Number(m[2]);
        }
        if (total > 0)
            root.memPct = Math.round((total - avail) / total * 100);
    }
    Process {
        id: cpuProc
        command: ["sh", "-c", "head -n1 /proc/stat"]
        stdout: StdioCollector {
            onStreamFinished: root.parseCpu(text)
        }
    }
    Process {
        id: memProc
        command: ["sh", "-c", "grep -E 'MemTotal|MemAvailable' /proc/meminfo"]
        stdout: StdioCollector {
            onStreamFinished: root.parseMem(text)
        }
    }
    Process {
        id: diskProc
        command: ["sh", "-c", "df -P / | awk 'NR==2{gsub(\"%\",\"\",$5); print $5}'"]
        stdout: StdioCollector {
            onStreamFinished: root.diskPct = parseInt(text.trim()) || 0
        }
    }

    // ===== Temperaturas / GPU (scripts + nvidia-smi) =====
    property string cpuTemp: "—"
    property int gpuUsage: 0
    property string gpuTemp: "—"
    Process {
        id: cpuTempProc
        command: ["bash", root.scriptsDir + "/cpu-temp.sh"]
        stdout: StdioCollector {
            onStreamFinished: root.cpuTemp = text.trim() || "—"
        }
    }
    function parseGpu(text) {
        const m = text.trim().split(",");
        if (m.length >= 2) {
            root.gpuUsage = parseInt(m[0]) || 0;
            root.gpuTemp = (parseInt(m[1]) || 0) + "°C";
        }
    }
    Process {
        id: gpuProc
        command: ["sh", "-c", "nvidia-smi --query-gpu=utilization.gpu,temperature.gpu --format=csv,noheader,nounits 2>/dev/null"]
        stdout: StdioCollector {
            onStreamFinished: root.parseGpu(text)
        }
    }

    // ===== VPN (vpn status-json) =====
    property bool vpnConnected: false
    property string vpnName: ""
    function parseVpn(text) {
        try {
            const j = JSON.parse(text);
            let c = false, n = "";
            (j.vpns || []).forEach(v => {
                if (v.connected) {
                    c = true;
                    n = v.name;
                }
            });
            root.vpnConnected = c;
            root.vpnName = n;
        } catch (e) {}
    }
    Process {
        id: vpnProc
        command: [root.vpnBin, "status-json"]
        stdout: StdioCollector {
            onStreamFinished: root.parseVpn(text)
        }
    }

    // ===== Hypridle (toggle-hypridle.sh) =====
    property string hypridleIcon: "󰒲"
    property bool hypridleOn: false
    function parseHypridle(text) {
        try {
            const j = JSON.parse(text);
            root.hypridleIcon = j.text || "󰒲";
            root.hypridleOn = (j.class === "enabled");
        } catch (e) {}
    }
    Process {
        id: hypridleProc
        command: ["bash", root.scriptsDir + "/toggle-hypridle.sh"]
        stdout: StdioCollector {
            onStreamFinished: root.parseHypridle(text)
        }
    }

    // ===== Notificações (swaync — stream) =====
    property string swayncIcon: "󰂜"
    function parseSwaync(line) {
        try {
            const j = JSON.parse(line);
            const a = j.alt || "";
            root.swayncIcon = a.indexOf("dnd") >= 0 ? (a.indexOf("notification") >= 0 ? "󰂛" : "󰪑") : (a.indexOf("notification") >= 0 ? "󰂚" : "󰂜");
        } catch (e) {}
    }
    Process {
        id: swayncProc
        running: true
        command: ["swaync-client", "-swb"]
        stdout: SplitParser {
            onRead: line => root.parseSwaync(line)
        }
    }

    // ===== Áudio (Pipewire) =====
    PwObjectTracker {
        objects: Pipewire.defaultAudioSink ? [Pipewire.defaultAudioSink] : []
    }
    readonly property var sink: Pipewire.defaultAudioSink
    readonly property real volume: (sink && sink.audio) ? sink.audio.volume : 0
    readonly property bool sinkMuted: (sink && sink.audio) ? sink.audio.muted : false
    function volIcon() {
        if (root.sinkMuted || root.volume <= 0)
            return "󰝟";
        if (root.volume <= 0.33)
            return "󰕿";
        if (root.volume <= 0.66)
            return "󰖀";
        return "󰕾";
    }
    function setVol(delta) {
        if (root.sink && root.sink.audio)
            root.sink.audio.volume = Math.max(0, Math.min(1, root.sink.audio.volume + delta));
    }
    function toggleMute() {
        if (root.sink && root.sink.audio)
            root.sink.audio.muted = !root.sink.audio.muted;
    }

    // ===== Spotify (Mpris) =====
    readonly property var player: {
        const m = Mpris.players;
        const list = (m && m.values) ? m.values : [];
        for (let i = 0; i < list.length; i++) {
            const p = list[i];
            if (p && (p.identity === "Spotify" || (p.dbusName || "").toLowerCase().indexOf("spotify") >= 0))
                return p;
        }
        for (let i = 0; i < list.length; i++)
            if (list[i] && list[i].isPlaying)
                return list[i];
        return list.length ? list[0] : null;
    }
    readonly property bool spHasPlayer: !!root.player
    readonly property string spTitle: (root.player && root.player.trackTitle) ? root.player.trackTitle : ""
    readonly property string spArtist: {
        if (!root.player || !root.player.trackArtists)
            return "";
        const a = root.player.trackArtists;
        return Array.isArray(a) ? a.join(", ") : ("" + a);
    }
    readonly property bool spPlaying: !!(root.player && root.player.isPlaying)
    readonly property string spText: root.spHasPlayer ? (root.spArtist ? root.spArtist + " - " + root.spTitle : root.spTitle) : ""
    readonly property color spColor: root.spPlaying ? root.colGreen : (root.spHasPlayer ? root.colYellow : root.colDim)

    // ===== Rede (nmcli) =====
    property bool netConnected: false
    property bool netEthernet: false
    function parseNet(text) {
        let conn = false, eth = false;
        const lines = text.split("\n");
        for (let i = 0; i < lines.length; i++) {
            const p = lines[i].split(":");
            if (p.length < 3)
                continue;
            const type = p[1], state = p[2];
            if ((type === "ethernet" || type === "wifi") && state.indexOf("connected") === 0 && state.indexOf("externally") < 0) {
                conn = true;
                if (type === "ethernet")
                    eth = true;
            }
        }
        root.netConnected = conn;
        root.netEthernet = eth;
    }
    Process {
        id: netProc
        command: ["sh", "-c", "nmcli -t -f DEVICE,TYPE,STATE device status"]
        stdout: StdioCollector {
            onStreamFinished: root.parseNet(text)
        }
    }

    // ===== Timers de polling =====
    Timer {
        interval: 2000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            cpuProc.running = true;
            hypridleProc.running = true;
        }
    }
    Timer {
        interval: 3000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            cpuTempProc.running = true;
            gpuProc.running = true;
        }
    }
    Timer {
        interval: 5000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            memProc.running = true;
            vpnProc.running = true;
        }
    }
    Timer {
        interval: 10000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: netProc.running = true
    }
    Timer {
        interval: 30000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: diskProc.running = true
    }

    // ===== Pílula reutilizável =====
    component Pill: Rectangle {
        id: pill
        property string icon: ""
        property string label: ""
        property color accent: root.colText
        property int maxWidth: 0
        signal clicked
        signal rightClicked
        signal scrolledUp
        signal scrolledDown

        implicitWidth: (pill.maxWidth > 0) ? Math.min(prow.implicitWidth + 20, pill.maxWidth) : prow.implicitWidth + 20
        implicitHeight: 22
        radius: 8
        color: area.containsMouse ? root.colPillHoverBg : root.colPillBg
        border.color: area.containsMouse ? root.colHoverBorder : root.colPillBorder
        border.width: 1
        Behavior on color {
            ColorAnimation {
                duration: 200
                easing.type: Easing.InOutQuad
            }
        }
        Behavior on border.color {
            ColorAnimation {
                duration: 200
            }
        }

        RowLayout {
            id: prow
            anchors.fill: parent
            anchors.leftMargin: 10
            anchors.rightMargin: 10
            spacing: 6
            Text {
                visible: pill.icon !== ""
                text: pill.icon
                color: pill.accent
                font.family: root.uiFont
                font.pixelSize: 13
            }
            Text {
                visible: pill.label !== ""
                Layout.fillWidth: pill.maxWidth > 0
                text: pill.label
                color: pill.accent
                font.family: root.uiFont
                font.pixelSize: 11
                elide: Text.ElideRight
            }
        }
        MouseArea {
            id: area
            anchors.fill: parent
            hoverEnabled: true
            acceptedButtons: Qt.LeftButton | Qt.RightButton
            onClicked: m => {
                if (m.button === Qt.RightButton)
                    pill.rightClicked();
                else
                    pill.clicked();
            }
            onWheel: w => {
                if (w.angleDelta.y > 0)
                    pill.scrolledUp();
                else
                    pill.scrolledDown();
            }
        }
    }

    component Group: Rectangle {
        default property alias content: groupRow.data
        radius: 12
        color: root.colGroupBg
        border.color: root.colGroupBorder
        border.width: 1
        implicitWidth: groupRow.implicitWidth + 8
        implicitHeight: 26
        RowLayout {
            id: groupRow
            anchors.centerIn: parent
            spacing: 6
        }
    }

    // ===== Barra por monitor =====
    Variants {
        model: Quickshell.screens

        PanelWindow {
            id: bar
            required property var modelData
            screen: modelData

            anchors {
                top: true
                left: true
                right: true
            }
            margins {
                top: 4
                left: 4
                right: 4
                bottom: 1
            }
            implicitHeight: 30
            exclusiveZone: root.barExclusiveZone
            color: "transparent"

            // ESQUERDA: placeholder + Spotify (workspaces/janela vêm na Fase 4)
            Group {
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                Pill {
                    icon: "󰣇"
                    label: "QS"
                    accent: root.colAccent
                }
                Pill {
                    visible: root.spHasPlayer
                    icon: "󰝚"
                    label: root.spText
                    accent: root.spColor
                    maxWidth: 240
                    onClicked: root.launch(["qs", "ipc", "call", "mpris", "toggle"])
                    onRightClicked: root.launch(["playerctl", "--player=spotify", "play-pause"])
                    onScrolledUp: root.launch(["playerctl", "--player=spotify", "next"])
                    onScrolledDown: root.launch(["playerctl", "--player=spotify", "previous"])
                }
            }

            // CENTRO: relógio + notificações (weather vem na Fase 3b, antes do relógio)
            Group {
                anchors.centerIn: parent
                Pill {
                    label: root.timeStr
                    accent: root.colMauve
                    onClicked: root.showDate = !root.showDate
                }
                Pill {
                    icon: root.swayncIcon
                    accent: root.colPeach
                    onClicked: root.launch(["swaync-client", "-t", "-sw"])
                    onRightClicked: root.launch(["swaync-client", "-d", "-sw"])
                }
            }

            // DIREITA (ordem da Waybar): cpu, cpu-temp, gpu-uso, gpu-temp, ram, disco, vpn, rede, áudio, hypridle
            Group {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                Pill {
                    icon: "󰻠"
                    label: root.cpuPct + "%"
                    accent: root.stateColor(root.cpuPct, root.colYellow)
                }
                Pill {
                    icon: "󰔏"
                    label: root.cpuTemp
                    accent: root.colPeach
                }
                Pill {
                    icon: "󰾲"
                    label: root.gpuUsage + "%"
                    accent: root.colMauve
                }
                Pill {
                    icon: "󰢮"
                    label: root.gpuTemp
                    accent: root.colLavender
                }
                Pill {
                    icon: "󰍛"
                    label: root.memPct + "%"
                    accent: root.stateColor(root.memPct, root.colPink)
                }
                Pill {
                    icon: "󰋊"
                    label: root.diskPct + "%"
                    accent: root.stateColor(root.diskPct, root.colTeal)
                }
                Pill {
                    icon: "󰦝"
                    label: root.vpnConnected ? root.vpnName : ""
                    accent: root.vpnConnected ? root.colGreen : root.colDim
                    maxWidth: 150
                    onClicked: root.launch(["qs", "ipc", "call", "vpn", "toggle"])
                    onRightClicked: root.launch([root.vpnBin, "menu"])
                }
                Pill {
                    icon: root.netConnected ? (root.netEthernet ? "󰈀" : "󰤨") : "󰤯"
                    accent: root.netConnected ? (root.netEthernet ? root.colTeal : root.colGreen) : root.colRed
                    onClicked: root.launch(["nm-connection-editor"])
                }
                Pill {
                    icon: root.volIcon()
                    label: Math.round(root.volume * 100) + "%"
                    accent: root.sinkMuted ? root.colDim : root.colBlue
                    onClicked: root.toggleMute()
                    onRightClicked: root.launch(["pavucontrol"])
                    onScrolledUp: root.setVol(0.05)
                    onScrolledDown: root.setVol(-0.05)
                }
                Pill {
                    icon: root.hypridleIcon
                    accent: root.hypridleOn ? root.colGreen : root.colRed
                    onClicked: root.launch(["bash", root.scriptsDir + "/toggle-hypridle.sh", "toggle"])
                }
            }
        }
    }
}
