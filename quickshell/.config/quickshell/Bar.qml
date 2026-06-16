// Barra Quickshell (substituta da Waybar).
// FASE 1: shell + relógio + cpu/ram/disco.
// FASE 2: áudio (Pipewire) + Spotify (Mpris) + rede (nmcli).
// FASE 3a: cpu-temp + gpu-uso/temp (nvidia-smi) + vpn + hypridle + swaync.
// FASE 3b: weather (MSN/Foreca XML) + popover de previsão 5 dias.
// FASE 4: workspaces (hyprctl + eventos, por monitor) + título da janela.
// FASE 5: system tray (StatusNotifier; popula quando o qs é o watcher).
// Falta: ligar no shell.qml e aposentar a Waybar (fase 6).
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import Quickshell.Services.Pipewire
import Quickshell.Services.Mpris
import Quickshell.Services.SystemTray
import QtQuick
import QtQuick.Layouts

Scope {
    id: root

    property int barExclusiveZone: 30
    readonly property int trayCount: SystemTray.items ? SystemTray.items.values.length : 0
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
    readonly property color colWsInactive: "#a9b1d6"
    readonly property color colWsActiveBg: "#d97aa2f7"
    readonly property color colWsActiveBorder: "#e67aa2f7"
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
    Component.onCompleted: {
        root.updateClock();
        hyprProc.running = true;
    }

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

    // ===== Temperaturas (sensors -j) + GPU uso/temp (nvidia-smi) =====
    property real cpuTempC: 0
    property real moboTempC: 0
    property var nvmeTempsC: []
    property int gpuUsage: 0
    property real gpuTempC: 0
    function parseSensors(text) {
        try {
            const d = JSON.parse(text);
            const nvmes = [];
            for (const chip in d) {
                const s = d[chip];
                if (typeof s !== "object")
                    continue;
                let pick = null, key = "";
                if (chip.indexOf("coretemp") === 0) {
                    pick = s["Package id 0"];
                    key = "cpu";
                } else if (chip.indexOf("nct") === 0) {
                    pick = s["SYSTIN"];
                    key = "mobo";
                } else if (chip.indexOf("nvme") === 0) {
                    pick = s["Composite"];
                    key = "nvme";
                }
                if (!pick || typeof pick !== "object")
                    continue;
                let val = 0;
                for (const k in pick)
                    if (k.indexOf("_input") >= 0) {
                        val = pick[k];
                        break;
                    }
                if (key === "cpu")
                    root.cpuTempC = val;
                else if (key === "mobo")
                    root.moboTempC = val;
                else if (key === "nvme")
                    nvmes.push(val);
            }
            root.nvmeTempsC = nvmes;
        } catch (e) {}
    }
    Process {
        id: sensorsProc
        command: ["sh", "-c", "sensors -j 2>/dev/null"]
        stdout: StdioCollector {
            onStreamFinished: root.parseSensors(text)
        }
    }
    function parseGpu(text) {
        const m = text.trim().split(",");
        if (m.length >= 2) {
            root.gpuUsage = parseInt(m[0]) || 0;
            root.gpuTempC = parseInt(m[1]) || 0;
        }
    }
    Process {
        id: gpuProc
        command: ["sh", "-c", "nvidia-smi --query-gpu=utilization.gpu,temperature.gpu --format=csv,noheader,nounits 2>/dev/null"]
        stdout: StdioCollector {
            onStreamFinished: root.parseGpu(text)
        }
    }
    // Lista curada de temperaturas + a mais quente (headline)
    readonly property var tempList: {
        const arr = [];
        if (root.cpuTempC > 0)
            arr.push({
                name: "CPU",
                temp: Math.round(root.cpuTempC)
            });
        if (root.gpuTempC > 0)
            arr.push({
                name: "GPU",
                temp: Math.round(root.gpuTempC)
            });
        if (root.moboTempC > 0)
            arr.push({
                name: "Placa",
                temp: Math.round(root.moboTempC)
            });
        const nv = root.nvmeTempsC;
        for (let i = 0; i < nv.length; i++)
            arr.push({
                name: nv.length > 1 ? "NVMe " + (i + 1) : "NVMe",
                temp: Math.round(nv[i])
            });
        return arr;
    }
    readonly property int tempMax: {
        let m = 0;
        for (let i = 0; i < root.tempList.length; i++)
            if (root.tempList[i].temp > m)
                m = root.tempList[i].temp;
        return m;
    }
    function tempColor(t) {
        return t >= 85 ? root.colRed : (t >= 70 ? root.colPeach : root.colSapphire);
    }
    // Uso consolidado (CPU/RAM/GPU/Disco), headline = CPU
    readonly property var usageList: [
        {
            name: "CPU",
            pct: root.cpuPct
        },
        {
            name: "RAM",
            pct: root.memPct
        },
        {
            name: "GPU",
            pct: root.gpuUsage
        },
        {
            name: "Disco",
            pct: root.diskPct
        }
    ]

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

    // ===== Weather (MSN / Foreca, endpoint legado XML) =====
    property string wTemp: ""
    property string wText: ""
    property string wFeels: ""
    property string wHumidity: ""
    property string wWind: ""
    property var wForecast: []
    readonly property bool wHas: root.wTemp !== ""
    function wattr(s, name) {
        const m = s.match(new RegExp('(?:^|\\s)' + name + '="([^"]*)"'));
        return m ? m[1] : "";
    }
    function weatherIcon(text, isDay) {
        const c = (text || "").toLowerCase();
        if (/ensolarad|limpo|\bsol\b|claro/.test(c))
            return isDay ? "󰖙" : "󰖔";
        if (/parcial|poucas nuvens/.test(c))
            return isDay ? "󰖕" : "󰼶";
        if (/nublad|encobert|nuvens|nuvem/.test(c))
            return "󰖐";
        if (/neblina|névoa|nevoeiro|bruma/.test(c))
            return "󰖑";
        if (/trovoad|tempestade|raio|relâmpag/.test(c))
            return "󰖓";
        if (/chuv|garoa|chuvisco|pancada|aguaceiro/.test(c))
            return "󰖗";
        if (/neve|gelo|granizo/.test(c))
            return "󰖘";
        return "󰖐";
    }
    function isDayNow() {
        const h = sysClock.date.getHours();
        return h >= 6 && h < 18;
    }
    function parseWeather(xml) {
        const cur = xml.match(/<current\b([^>]*)\/>/);
        if (cur) {
            const a = cur[1];
            root.wTemp = root.wattr(a, "temperature");
            root.wText = root.wattr(a, "skytext");
            root.wFeels = root.wattr(a, "feelslike");
            root.wHumidity = root.wattr(a, "humidity");
            root.wWind = root.wattr(a, "winddisplay");
        }
        const fc = [];
        const re = /<forecast\b([^>]*)\/>/g;
        let m;
        while ((m = re.exec(xml)) !== null) {
            const a = m[1];
            fc.push({
                day: root.wattr(a, "shortday"),
                low: root.wattr(a, "low"),
                high: root.wattr(a, "high"),
                text: root.wattr(a, "skytextday"),
                precip: root.wattr(a, "precip")
            });
        }
        root.wForecast = fc;
    }
    Process {
        id: weatherProc
        command: ["curl", "-sS", "-m", "10", "-A", "Mozilla/5.0", "https://weather.service.msn.com/find.aspx?src=msn&weadegreetype=C&culture=pt-BR&weasearchstr=-21.9977,-47.8827"]
        stdout: StdioCollector {
            onStreamFinished: root.parseWeather(text)
        }
    }
    Timer {
        interval: 900000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: weatherProc.running = true
    }
    // hover do popover de weather
    property bool wPillHovered: false
    property bool wPopHovered: false
    property bool wPopVisible: false
    onWPillHoveredChanged: root.updateWeatherPop()
    onWPopHoveredChanged: root.updateWeatherPop()
    function updateWeatherPop() {
        if (root.wPillHovered || root.wPopHovered) {
            wPopCloseTimer.stop();
            root.wPopVisible = true;
        } else {
            wPopCloseTimer.restart();
        }
    }
    Timer {
        id: wPopCloseTimer
        interval: 300
        onTriggered: if (!root.wPillHovered && !root.wPopHovered)
            root.wPopVisible = false
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

    // throughput por interface (/proc/net/dev); taxa = delta / 2s (intervalo do timer)
    property var netPrev: ({})
    property var netRates: []
    property real netMainRx: 0
    property real netMainTx: 0
    function parseNetDev(text) {
        const lines = text.split("\n");
        const cur = {};
        for (let i = 0; i < lines.length; i++) {
            const m = lines[i].trim().match(/^([\w-]+):\s*(\d+)(?:\s+\d+){7}\s+(\d+)/);
            if (!m)
                continue;
            const iface = m[1];
            if (iface === "lo" || iface.indexOf("veth") === 0)
                continue;
            cur[iface] = {
                rx: Number(m[2]),
                tx: Number(m[3])
            };
        }
        const rates = [];
        for (const iface in cur) {
            const prev = root.netPrev[iface];
            if (prev) {
                const rxr = Math.max(0, (cur[iface].rx - prev.rx) / 2);
                const txr = Math.max(0, (cur[iface].tx - prev.tx) / 2);
                if (iface === "enp4s0") {
                    root.netMainRx = rxr;
                    root.netMainTx = txr;
                }
                if (rxr > 0 || txr > 0 || iface === "enp4s0")
                    rates.push({
                        iface: iface,
                        rx: rxr,
                        tx: txr
                    });
            }
        }
        root.netPrev = cur;
        rates.sort((a, b) => (b.rx + b.tx) - (a.rx + a.tx));
        root.netRates = rates;
    }
    Process {
        id: netDevProc
        command: ["sh", "-c", "cat /proc/net/dev"]
        stdout: StdioCollector {
            onStreamFinished: root.parseNetDev(text)
        }
    }
    function fmtRate(bps) {
        if (bps >= 1048576)
            return (bps / 1048576).toFixed(1) + "M";
        if (bps >= 1024)
            return Math.round(bps / 1024) + "K";
        return Math.round(bps) + "B";
    }

    // ===== Hover do popover de métricas (temp / uso / rede) =====
    property string metricShown: ""   // "temp" | "usage" | "net"
    property bool metricHovering: false
    property bool metricPopHovered: false
    property bool metricPopVisible: false
    readonly property var metricRows: {
        const m = root.metricShown;
        if (m === "temp")
            return root.tempList.map(t => ({ label: t.name, value: t.temp + "\u00b0C" }));
        if (m === "usage")
            return root.usageList.map(u => ({ label: u.name, value: u.pct + "%" }));
        if (m === "net")
            return root.netRates.map(n => ({ label: n.iface, value: "\u2193" + root.fmtRate(n.rx) + " \u2191" + root.fmtRate(n.tx) }));
        return [];
    }
    function showMetric(which) {
        root.metricShown = which;
        root.metricHovering = true;
        metricCloseTimer.stop();
        root.metricPopVisible = true;
    }
    function unhoverMetric() {
        root.metricHovering = false;
        metricCloseTimer.restart();
    }
    onMetricPopHoveredChanged: {
        if (root.metricPopHovered)
            metricCloseTimer.stop();
        else
            metricCloseTimer.restart();
    }
    Timer {
        id: metricCloseTimer
        interval: 300
        onTriggered: if (!root.metricHovering && !root.metricPopHovered)
            root.metricPopVisible = false
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
            netDevProc.running = true;
        }
    }
    Timer {
        interval: 3000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            sensorsProc.running = true;
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

    // ===== Hyprland: workspaces (hyprctl + eventos) + título da janela =====
    property var wsActive: ({})
    property var wsExist: ({})
    property string focusedMon: ""
    readonly property var wsIcons: ({
            1: "󰲠",
            2: "󰲢",
            3: "󰲤",
            4: "󰲦",
            5: "󰲨",
            6: "󰲪",
            7: "󰲬",
            8: "󰲮"
        })
    function wsIcon(id) {
        return root.wsIcons[id] || "󰊠";
    }
    function parseHypr(text) {
        const parts = text.split("@@@");
        try {
            const mons = JSON.parse(parts[0]);
            const active = ({});
            let foc = "";
            for (let i = 0; i < mons.length; i++) {
                if (mons[i].activeWorkspace)
                    active[mons[i].name] = mons[i].activeWorkspace.id;
                if (mons[i].focused)
                    foc = mons[i].name;
            }
            root.wsActive = active;
            root.focusedMon = foc;
        } catch (e) {}
        try {
            const wss = JSON.parse(parts[1]);
            const ex = ({});
            for (let i = 0; i < wss.length; i++)
                ex[wss[i].id] = true;
            root.wsExist = ex;
        } catch (e) {}
    }
    Process {
        id: hyprProc
        command: ["sh", "-c", "hyprctl -j monitors; echo '@@@'; hyprctl -j workspaces"]
        stdout: StdioCollector {
            onStreamFinished: root.parseHypr(text)
        }
    }
    Connections {
        target: Hyprland
        function onRawEvent(event) {
            const n = event.name;
            if (n.indexOf("workspace") === 0 || n === "focusedmon" || n === "createworkspace" || n === "destroyworkspace" || n === "moveworkspace" || n === "openwindow" || n === "closewindow" || n === "urgent")
                hyprProc.running = true;
        }
    }
    // título da janela ativa (Hyprland nativo) + rewrite rules
    readonly property string rawTitle: Hyprland.activeToplevel ? (Hyprland.activeToplevel.title || "") : ""
    readonly property string winTitle: root.rewriteTitle(root.rawTitle)
    function rewriteTitle(t) {
        if (!t)
            return "";
        let m;
        if ((m = t.match(/^(.*) — Mozilla Firefox$/)))
            return "󰈹 " + m[1];
        if ((m = t.match(/^(.*) - (fish|zsh|bash)$/)))
            return "󰆍 [" + m[1] + "]";
        if ((m = t.match(/^(.*) - Spotify$/)))
            return "󰝚 " + m[1];
        if ((m = t.match(/^(.*) - (Code|Visual Studio Code)$/)))
            return "󰨞 " + m[1];
        return t;
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
        property alias hovered: area.containsMouse
        property bool italic: false

        implicitWidth: (pill.maxWidth > 0) ? Math.min(prow.implicitWidth + 22, pill.maxWidth) : prow.implicitWidth + 22
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
            anchors.leftMargin: 11
            anchors.rightMargin: 11
            spacing: 5
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
                font.italic: pill.italic
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

    component Group: Item {
        default property alias content: groupRow.data
        implicitWidth: groupRow.implicitWidth
        implicitHeight: 26
        RowLayout {
            id: groupRow
            anchors.centerIn: parent
            spacing: 4
        }
    }

    // ===== Botão de workspace =====
    component WsBtn: Rectangle {
        id: wsbtn
        property int wsid: 0
        property bool active: false
        property bool exists: false

        implicitWidth: Math.max(24, wlbl.implicitWidth + 14)
        implicitHeight: 22
        radius: 8
        color: wsbtn.active ? root.colWsActiveBg : (wsArea.containsMouse ? root.colPillHoverBg : root.colPillBg)
        border.color: wsbtn.active ? root.colWsActiveBorder : (wsArea.containsMouse ? root.colHoverBorder : root.colPillBorder)
        border.width: 1
        Behavior on color {
            ColorAnimation {
                duration: 200
            }
        }

        Text {
            id: wlbl
            anchors.centerIn: parent
            text: wsbtn.active ? "󰮯" : (wsbtn.exists ? root.wsIcon(wsbtn.wsid) : "󰧵")
            color: wsbtn.active ? "#1a1b26" : root.colWsInactive
            font.family: root.uiFont
            font.pixelSize: 13
            font.bold: wsbtn.active
        }
        MouseArea {
            id: wsArea
            anchors.fill: parent
            hoverEnabled: true
            onClicked: root.launch(["hyprctl", "dispatch", "workspace", "" + wsbtn.wsid])
        }
    }

    // ===== Popover de weather (hover) — DP-1, previsão de 5 dias =====
    PanelWindow {
        id: wPop
        visible: root.wPopVisible && root.wHas
        screen: {
            const screens = Quickshell.screens;
            for (let i = 0; i < screens.length; i++)
                if (screens[i].name === "DP-1")
                    return screens[i];
            return null;
        }
        anchors {
            top: true
        }
        margins {
            top: 36
        }
        exclusiveZone: 0
        implicitWidth: 440
        implicitHeight: 158
        color: "transparent"

        Rectangle {
            anchors.fill: parent
            radius: 12
            color: "#f21a1b26"
            border.color: "#414868"
            border.width: 1

            HoverHandler {
                id: wPopHover
                onHoveredChanged: root.wPopHovered = hovered
            }

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 14
                spacing: 10

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 12
                    Text {
                        text: root.weatherIcon(root.wText, root.isDayNow())
                        color: root.colSapphire
                        font.family: root.uiFont
                        font.pixelSize: 34
                    }
                    ColumnLayout {
                        spacing: 0
                        Text {
                            text: root.wTemp + "°C"
                            color: root.colText
                            font.family: root.uiFont
                            font.pixelSize: 22
                            font.bold: true
                        }
                        Text {
                            text: root.wText
                            color: root.colSapphire
                            font.family: root.uiFont
                            font.pixelSize: 12
                        }
                    }
                    Item {
                        Layout.fillWidth: true
                    }
                    ColumnLayout {
                        spacing: 1
                        Text {
                            text: "Sensação " + root.wFeels + "°"
                            color: root.colDim
                            font.family: root.uiFont
                            font.pixelSize: 10
                        }
                        Text {
                            text: "Umidade " + root.wHumidity + "%"
                            color: root.colDim
                            font.family: root.uiFont
                            font.pixelSize: 10
                        }
                        Text {
                            text: root.wWind
                            color: root.colDim
                            font.family: root.uiFont
                            font.pixelSize: 10
                        }
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    height: 1
                    color: "#414868"
                    opacity: 0.5
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 10
                    Repeater {
                        model: root.wForecast
                        ColumnLayout {
                            required property var modelData
                            Layout.fillWidth: true
                            spacing: 2
                            Text {
                                Layout.alignment: Qt.AlignHCenter
                                text: modelData.day
                                color: root.colText
                                font.family: root.uiFont
                                font.pixelSize: 11
                                font.bold: true
                            }
                            Text {
                                Layout.alignment: Qt.AlignHCenter
                                text: root.weatherIcon(modelData.text, true)
                                color: root.colSapphire
                                font.family: root.uiFont
                                font.pixelSize: 18
                            }
                            Text {
                                Layout.alignment: Qt.AlignHCenter
                                text: modelData.high + "° / " + modelData.low + "°"
                                color: root.colText
                                font.family: root.uiFont
                                font.pixelSize: 10
                            }
                            Text {
                                Layout.alignment: Qt.AlignHCenter
                                visible: modelData.precip !== ""
                                text: "󰖎 " + modelData.precip + "%"
                                color: root.colBlue
                                font.family: root.uiFont
                                font.pixelSize: 9
                            }
                        }
                    }
                }
            }
        }
    }

    // ===== Popover de metricas (temp / uso / rede) — DP-1, hover =====
    PanelWindow {
        id: metricPop
        visible: root.metricPopVisible
        screen: {
            const screens = Quickshell.screens;
            for (let i = 0; i < screens.length; i++)
                if (screens[i].name === "DP-1")
                    return screens[i];
            return null;
        }
        anchors {
            top: true
            right: true
        }
        margins {
            top: 33
            right: 4
        }
        exclusiveZone: 0
        implicitWidth: 290
        implicitHeight: 200
        color: "transparent"
        Rectangle {
            anchors.fill: parent
            radius: 12
            color: "#f21a1b26"
            border.color: "#414868"
            border.width: 1
            HoverHandler {
                onHoveredChanged: root.metricPopHovered = hovered
            }
            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 14
                spacing: 8
                Text {
                    text: root.metricShown === "temp" ? "Temperaturas" : (root.metricShown === "net" ? "Rede" : "Uso")
                    color: root.colAccent
                    font.family: root.uiFont
                    font.pixelSize: 14
                    font.bold: true
                }
                Rectangle {
                    Layout.fillWidth: true
                    height: 1
                    color: "#414868"
                    opacity: 0.5
                }
                Repeater {
                    model: root.metricRows
                    RowLayout {
                        required property var modelData
                        Layout.fillWidth: true
                        spacing: 12
                        Text {
                            Layout.fillWidth: true
                            text: modelData.label
                            color: root.colText
                            font.family: root.uiFont
                            font.pixelSize: 12
                        }
                        Text {
                            text: modelData.value
                            color: root.colText
                            font.family: root.uiFont
                            font.pixelSize: 12
                            font.bold: true
                        }
                    }
                }
                Item {
                    Layout.fillHeight: true
                }
            }
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

            // ESQUERDA: workspaces (do monitor) + título da janela + Spotify
            Group {
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                Repeater {
                    model: (bar.modelData && bar.modelData.name === "HDMI-A-1") ? [5, 6, 7, 8] : [1, 2, 3, 4]
                    WsBtn {
                        wsid: modelData
                        active: root.wsActive[bar.modelData.name] === modelData
                        exists: root.wsExist[modelData] === true
                    }
                }
                Pill {
                    visible: bar.modelData && bar.modelData.name === root.focusedMon && root.winTitle !== ""
                    label: root.winTitle
                    accent: root.colSky
                    italic: true
                    maxWidth: 340
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

            // CENTRO: weather + relógio + notificações (sempre no centro da tela)
            Group {
                anchors.centerIn: parent
                Pill {
                    visible: root.wHas
                    icon: root.weatherIcon(root.wText, root.isDayNow())
                    label: root.wTemp + "°C"
                    accent: root.colSapphire
                    onHoveredChanged: root.wPillHovered = hovered
                    onClicked: root.launch(["xdg-open", "https://www.msn.com/pt-br/clima/forecast/in-S%C3%A3o-Carlos,S%C3%A3o-Paulo"])
                }
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
                    icon: "󰔏"
                    label: root.tempMax + "°C"
                    accent: root.tempColor(root.tempMax)
                    onHoveredChanged: hovered ? root.showMetric("temp") : root.unhoverMetric()
                }
                Pill {
                    icon: "󰓅"
                    label: root.cpuPct + "%"
                    accent: root.stateColor(root.cpuPct, root.colYellow)
                    onHoveredChanged: hovered ? root.showMetric("usage") : root.unhoverMetric()
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
                    icon: "󰛳"
                    label: "↓" + root.fmtRate(root.netMainRx) + " ↑" + root.fmtRate(root.netMainTx)
                    accent: root.netConnected ? root.colTeal : root.colRed
                    onHoveredChanged: hovered ? root.showMetric("net") : root.unhoverMetric()
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
                // System tray (StatusNotifier). Popula quando o qs é o watcher
                // (i.e. com a Waybar fora — Fase 6 / login). Esquerda=activate,
                // meio=secondaryActivate, scroll, direita=menu nativo.
                Repeater {
                    model: SystemTray.items
                    Item {
                        id: trayDel
                        implicitWidth: 24
                        implicitHeight: 24
                        // Alguns SNI (ex.: Dropbox) publicam o ícone como
                        // image://icon/<nome>?path=<dir> num tema hicolor que o
                        // provedor do Quickshell não resolve. Busco o arquivo
                        // real no <dir> e aponto pra file://.
                        readonly property string rawIcon: "" + modelData.icon
                        readonly property bool isPathIcon: /^image:\/\/icon\/[^?]+\?path=/.test(trayDel.rawIcon)
                        property string resolvedIcon: ""
                        function resolveTrayIcon() {
                            trayDel.resolvedIcon = "";
                            const m = trayDel.rawIcon.match(/^image:\/\/icon\/([^?]+)\?path=(.+)$/);
                            if (m) {
                                iconFinder.command = ["find", m[2], "-name", m[1] + ".png", "-print", "-quit"];
                                iconFinder.running = true;
                            }
                        }
                        onRawIconChanged: trayDel.resolveTrayIcon()
                        Component.onCompleted: trayDel.resolveTrayIcon()
                        Process {
                            id: iconFinder
                            stdout: StdioCollector {
                                onStreamFinished: {
                                    const p = text.trim();
                                    if (p)
                                        trayDel.resolvedIcon = "file://" + p;
                                }
                            }
                        }
                        Image {
                            anchors.centerIn: parent
                            // path-icons: só mostra após resolver pro file:// (evita o load quebrado)
                            source: trayDel.isPathIcon ? trayDel.resolvedIcon : trayDel.rawIcon
                            sourceSize.width: 16
                            sourceSize.height: 16
                            width: 16
                            height: 16
                            opacity: modelData.status === 0 ? 0.55 : 1
                        }
                        MouseArea {
                            anchors.fill: parent
                            hoverEnabled: true
                            acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton
                            onClicked: m => {
                                if (m.button === Qt.LeftButton)
                                    modelData.activate();
                                else if (m.button === Qt.MiddleButton)
                                    modelData.secondaryActivate();
                                else if (modelData.hasMenu) {
                                    const p = parent.mapToItem(null, parent.width / 2, parent.height);
                                    modelData.display(bar, p.x, p.y);
                                }
                            }
                            onWheel: w => modelData.scroll(w.angleDelta.y, false)
                        }
                    }
                }
            }
        }
    }
}
