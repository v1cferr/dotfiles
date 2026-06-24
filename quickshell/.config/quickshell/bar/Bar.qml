// Barra Quickshell (substituta da Waybar).
// FASE 1: shell + relógio + cpu/ram/disco.
// FASE 2: áudio (Pipewire) + Spotify (Mpris) + rede (nmcli).
// FASE 3a: cpu-temp + gpu-uso/temp (nvidia-smi) + vpn + hypridle + swaync.
// FASE 3b: weather (Open-Meteo JSON) + popover de previsão 7 dias.
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
import "root:/"
import "root:/widgets"

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
        const dk = Qt.formatDate(d, "yyyy-MM-dd");
        if (dk !== root.calDayKey) {
            root.calDayKey = dk;
            root.refreshCalendar();
        }
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

    // ===== Notificações =====
    // O Quickshell é o daemon (serviço Notifs.qml + UI Notifications.qml). O sino
    // abaixo lê Notifs.barIcon/dnd e chama os toggles direto no singleton.

    // ===== Weather (Open-Meteo, JSON; lat/long de São Carlos) =====
    property string wTemp: ""
    property string wText: ""
    property string wFeels: ""
    property string wHumidity: ""
    property string wWind: ""
    property var wForecast: []
    readonly property bool wHas: root.wTemp !== ""
    // Código WMO (Open-Meteo) -> texto PT-BR. As strings batem com os regex do
    // weatherIcon() abaixo, então o ícone é derivado do texto sem mexer no mapa.
    function wmoText(code) {
        const c = code;
        if (c === 0 || c === 1) return "Ensolarado";
        if (c === 2) return "Parcialmente nublado";
        if (c === 3) return "Nublado";
        if (c === 45 || c === 48) return "Nevoeiro";
        if (c >= 51 && c <= 57) return "Garoa";
        if (c >= 61 && c <= 67) return "Chuva";
        if ((c >= 71 && c <= 77) || c === 85 || c === 86) return "Neve";
        if (c >= 80 && c <= 82) return "Pancadas de chuva";
        if (c === 95) return "Trovoada";
        if (c === 96 || c === 99) return "Trovoada com granizo";
        return "—";
    }
    // Direção do vento (graus -> rosa-dos-ventos PT-BR, 8 pontos).
    function windDir(deg) {
        const dirs = ["N", "NE", "L", "SE", "S", "SO", "O", "NO"];
        return dirs[Math.round(deg / 45) % 8];
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
    function parseWeather(jsonText) {
        let data;
        try {
            data = JSON.parse(jsonText);
        } catch (e) {
            return;
        }
        const cur = data.current;
        if (cur) {
            root.wTemp = "" + Math.round(cur.temperature_2m);
            root.wText = root.wmoText(cur.weather_code);
            root.wFeels = "" + Math.round(cur.apparent_temperature);
            root.wHumidity = "" + cur.relative_humidity_2m;
            root.wWind = Math.round(cur.wind_speed_10m) + " km/h " + root.windDir(cur.wind_direction_10m);
        }
        const dy = data.daily;
        const fc = [];
        // Índice 0 é hoje (já está na pílula); mostro do dia seguinte em diante
        // (próximos 7 dias = até o mesmo dia da semana na semana que vem).
        if (dy && dy.time) {
            for (let i = 1; i < dy.time.length; i++) {
                const dt = new Date(dy.time[i] + "T00:00:00");
                const pp = dy.precipitation_probability_max[i];
                fc.push({
                    day: root.dowAbbr[dt.getDay()],
                    low: "" + Math.round(dy.temperature_2m_min[i]),
                    high: "" + Math.round(dy.temperature_2m_max[i]),
                    text: root.wmoText(dy.weather_code[i]),
                    precip: (pp === null || pp === undefined) ? "" : "" + pp
                });
            }
        }
        root.wForecast = fc;
    }
    Process {
        id: weatherProc
        command: ["curl", "-sS", "-m", "10", "https://api.open-meteo.com/v1/forecast?latitude=-21.9977&longitude=-47.8827&current=temperature_2m,relative_humidity_2m,apparent_temperature,weather_code,wind_speed_10m,wind_direction_10m&daily=weather_code,temperature_2m_max,temperature_2m_min,precipitation_probability_max&timezone=auto&forecast_days=8"]
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

    // ===== Posicionamento de popovers (sempre logo abaixo do elemento) =====
    readonly property var screenDP1: {
        const s = Quickshell.screens;
        for (let i = 0; i < s.length; i++)
            if (s[i].name === "DP-1")
                return s[i];
        return s.length ? s[0] : null;
    }
    property var popScreen: null
    property real popCenterX: 0   // centro do elemento ancorado, em coords da janela da barra
    // mapToItem pra um Item REAL (barContent) é confiável; só mapToItem(null) não é
    function anchorPopover(pillItem, barContentItem, scr) {
        if (pillItem && barContentItem) {
            const p = pillItem.mapToItem(barContentItem, 0, 0);
            root.popCenterX = p.x + pillItem.width / 2;
        }
        if (scr)
            root.popScreen = scr;
    }
    // margin.left pra centralizar o popover sob o elemento (+4 = margin.left da barra)
    function popLeft(popW) {
        const scr = root.popScreen || root.screenDP1;
        const sw = scr ? scr.width : 1920;
        return Math.round(Math.max(4, Math.min(root.popCenterX + 4 - popW / 2, sw - popW - 4)));
    }

    // ===== Feriados (nacional + SP + São Carlos) — pesquisa verificada jun/2026 =====
    // Bases legais nas notas do workflow; scope: "nac" | "sp" | "sc".
    // off = offset em dias do DOMINGO de Páscoa (datas móveis); senão m/d fixos.
    // fac = ponto facultativo (não dá folga garantida) -> mostrado mais discreto.
    readonly property var holidayDefs: [
        { name: "Ano-Novo", scope: "nac", m: 1, d: 1 },
        { name: "Carnaval (segunda)", scope: "nac", off: -48, fac: true },
        { name: "Carnaval (terça)", scope: "nac", off: -47, fac: true },
        { name: "Quarta-feira de Cinzas", scope: "nac", off: -46, fac: true },
        { name: "Sexta-feira Santa", scope: "nac", off: -2 },
        { name: "Tiradentes", scope: "nac", m: 4, d: 21 },
        { name: "Dia do Trabalho", scope: "nac", m: 5, d: 1 },
        { name: "Corpus Christi", scope: "sc", off: 60 },
        { name: "Revolução Constitucionalista", scope: "sp", m: 7, d: 9 },
        { name: "N. Sra. da Babilônia", scope: "sc", m: 8, d: 15 },
        { name: "Independência", scope: "nac", m: 9, d: 7 },
        { name: "N. Sra. Aparecida", scope: "nac", m: 10, d: 12 },
        { name: "Finados", scope: "nac", m: 11, d: 2 },
        { name: "Aniversário de São Carlos", scope: "sc", m: 11, d: 4 },
        { name: "Proclamação da República", scope: "nac", m: 11, d: 15 },
        { name: "Consciência Negra", scope: "nac", m: 11, d: 20 },
        { name: "Natal", scope: "nac", m: 12, d: 25 }
    ]
    readonly property var monthNames: ["Janeiro", "Fevereiro", "Março", "Abril", "Maio", "Junho", "Julho", "Agosto", "Setembro", "Outubro", "Novembro", "Dezembro"]
    readonly property var weekHeads: ["D", "S", "T", "Q", "Q", "S", "S"]
    readonly property var dowAbbr: ["dom", "seg", "ter", "qua", "qui", "sex", "sáb"]
    readonly property var monAbbr: ["jan", "fev", "mar", "abr", "mai", "jun", "jul", "ago", "set", "out", "nov", "dez"]
    function easterDate(y) {
        const a = y % 19, b = Math.floor(y / 100), c = y % 100;
        const dd = Math.floor(b / 4), e = b % 4, f = Math.floor((b + 8) / 25);
        const g = Math.floor((b - f + 1) / 3);
        const h = (19 * a + b - dd - g + 15) % 30;
        const i = Math.floor(c / 4), k = c % 4;
        const l = (32 + 2 * e + 2 * i - h - k) % 7;
        const mm = Math.floor((a + 11 * h + 22 * l) / 451);
        const month = Math.floor((h + l - 7 * mm + 114) / 31);
        const day = ((h + l - 7 * mm + 114) % 31) + 1;
        return new Date(y, month - 1, day);
    }
    function holidaysOfYear(y) {
        const e = root.easterDate(y);
        const defs = root.holidayDefs;
        const out = [];
        for (let i = 0; i < defs.length; i++) {
            const def = defs[i];
            const dt = (def.off !== undefined) ? new Date(y, e.getMonth(), e.getDate() + def.off) : new Date(y, def.m - 1, def.d);
            out.push({
                date: dt,
                name: def.name,
                scope: def.scope,
                fac: def.fac === true
            });
        }
        return out;
    }
    function scopeColor(scope) {
        return scope === "nac" ? root.colRed : (scope === "sp" ? root.colBlue : root.colMauve);
    }
    function scopeLabel(scope) {
        return scope === "nac" ? "Nacional" : (scope === "sp" ? "Estado SP" : "São Carlos");
    }
    // Estado do calendário (recomputado só na virada do dia)
    property int calYear: 0
    property int calTodayM: 0
    property int calTodayD: 0
    property var calMap: ({})
    property var calUpcoming: []
    property string calDayKey: ""
    function buildCalMap(y) {
        const map = ({});
        const hs = root.holidaysOfYear(y);
        for (let i = 0; i < hs.length; i++) {
            const h = hs[i];
            const key = (h.date.getMonth() + 1) * 100 + h.date.getDate();
            if (!map[key])
                map[key] = [];
            map[key].push(h);
        }
        return map;
    }
    function computeUpcoming(now, n) {
        const t0 = new Date(now.getFullYear(), now.getMonth(), now.getDate()).getTime();
        let all = root.holidaysOfYear(now.getFullYear()).concat(root.holidaysOfYear(now.getFullYear() + 1));
        all = all.filter(h => !h.fac && h.date.getTime() >= t0);
        all.sort((a, b) => a.date.getTime() - b.date.getTime());
        return all.slice(0, n);
    }
    function refreshCalendar() {
        const d = sysClock.date;
        root.calYear = d.getFullYear();
        root.calTodayM = d.getMonth() + 1;
        root.calTodayD = d.getDate();
        root.calMap = root.buildCalMap(root.calYear);
        root.calUpcoming = root.computeUpcoming(d, 7);
    }
    function monthCells(m) {
        const cells = [];
        for (let i = 0; i < 7; i++)
            cells.push({ head: root.weekHeads[i] });
        const first = new Date(root.calYear, m - 1, 1).getDay();
        for (let i = 0; i < first; i++)
            cells.push({ d: 0 });
        const dim = new Date(root.calYear, m, 0).getDate();
        for (let d = 1; d <= dim; d++) {
            const arr = root.calMap[m * 100 + d];
            let hol = null;
            if (arr && arr.length) {
                hol = arr[0];
                for (let j = 0; j < arr.length; j++)
                    if (!arr[j].fac) {
                        hol = arr[j];
                        break;
                    }
            }
            cells.push({
                d: d,
                holiday: hol,
                today: (m === root.calTodayM && d === root.calTodayD)
            });
        }
        return cells;
    }
    function fmtHolidayDate(dt) {
        const dd = ("0" + dt.getDate()).slice(-2);
        return root.dowAbbr[dt.getDay()] + " " + dd + "/" + root.monAbbr[dt.getMonth()];
    }
    function daysUntilLabel(dt) {
        const t0 = new Date(root.calYear, root.calTodayM - 1, root.calTodayD).getTime();
        const h0 = new Date(dt.getFullYear(), dt.getMonth(), dt.getDate()).getTime();
        const n = Math.round((h0 - t0) / 86400000);
        if (n <= 0)
            return "hoje";
        if (n === 1)
            return "amanhã";
        return "em " + n + "d";
    }
    // hover-keep do calendário (igual ao weather)
    property bool calPillHovered: false
    property bool calPopHovered: false
    property bool calPopVisible: false
    onCalPillHoveredChanged: root.updateCalPop()
    onCalPopHoveredChanged: root.updateCalPop()
    function updateCalPop() {
        if (root.calPillHovered || root.calPopHovered) {
            calPopCloseTimer.stop();
            root.calPopVisible = true;
        } else {
            calPopCloseTimer.restart();
        }
    }
    Timer {
        id: calPopCloseTimer
        interval: 300
        onTriggered: if (!root.calPillHovered && !root.calPopHovered)
            root.calPopVisible = false
    }

    // ===== Hover do popover de métricas (temp / uso / rede) =====
    property string metricShown: ""   // "temp" | "usage" | "net"
    property bool metricHovering: false
    property bool metricPopHovered: false
    property bool metricPopVisible: false
    readonly property var metricRows: {
        const m = root.metricShown;
        if (m === "temp")
            return root.tempList.map(t => ({
                        label: t.name,
                        value: t.temp + "\u00b0C",
                        frac: Math.max(0, Math.min(1, t.temp / 100)),
                        barColor: root.tempColor(t.temp)
                    }));
        if (m === "usage")
            return root.usageList.map(u => ({
                        label: u.name,
                        value: u.pct + "%",
                        frac: Math.max(0, Math.min(1, u.pct / 100)),
                        barColor: root.stateColor(u.pct, root.colAccent)
                    }));
        if (m === "net")
            return root.netRates.map(n => ({
                        label: n.iface,
                        value: "\u2193" + root.fmtRate(n.rx) + " \u2191" + root.fmtRate(n.tx)
                    }));
        return [];
    }
    function showMetric(which, pillItem, barContentItem, scr) {
        root.metricShown = which;
        root.metricHovering = true;
        root.anchorPopover(pillItem, barContentItem, scr);
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
    property var wsWindows: ({})   // contagem de janelas por ws (detecta janela nova)
    property var wsActivity: ({})  // algo abriu/urgente numa ws de fundo (badge)
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
            const win = ({});
            const prev = root.wsWindows;
            const act = Object.assign({}, root.wsActivity);
            const focusedWsId = root.wsActive[root.focusedMon];
            for (let i = 0; i < wss.length; i++) {
                const w = wss[i];
                ex[w.id] = true;
                const wc = w.windows || 0;
                win[w.id] = wc;
                const before = prev[w.id];
                // janela nova numa ws que NÃO é a focada -> marca atividade
                if (before !== undefined && wc > before && w.id !== focusedWsId)
                    act[w.id] = true;
                // visitei a ws -> limpa o aviso
                if (w.id === focusedWsId)
                    act[w.id] = false;
            }
            root.wsExist = ex;
            root.wsWindows = win;
            root.wsActivity = act;
        } catch (e) {}
    }
    Process {
        id: hyprProc
        command: ["sh", "-c", "hyprctl -j monitors; echo '@@@'; hyprctl -j workspaces"]
        stdout: StdioCollector {
            onStreamFinished: root.parseHypr(text)
        }
    }
    // marca atividade na ws urgente (caso "demanda atenção" sem janela nova, ex.: aba)
    function markUrgentActivity() {
        const wl = Hyprland.workspaces ? Hyprland.workspaces.values : [];
        const focusedWsId = root.wsActive[root.focusedMon];
        const act = Object.assign({}, root.wsActivity);
        let changed = false;
        for (let i = 0; i < wl.length; i++)
            if (wl[i].urgent === true && wl[i].id !== focusedWsId) {
                act[wl[i].id] = true;
                changed = true;
            }
        if (changed)
            root.wsActivity = act;
    }
    Connections {
        target: Hyprland
        function onRawEvent(event) {
            const n = event.name;
            if (n.indexOf("workspace") === 0 || n === "focusedmon" || n === "createworkspace" || n === "destroyworkspace" || n === "moveworkspace" || n === "openwindow" || n === "closewindow" || n === "urgent")
                hyprProc.running = true;
            if (n === "urgent")
                root.markUrgentActivity();
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
    // Pílula/chip extraída para widgets/Pill.qml (import "root:/widgets").

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
        property bool activity: false

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
        // badge: algo abriu / ficou urgente nessa ws enquanto eu estava em outra
        Rectangle {
            visible: wsbtn.activity && !wsbtn.active
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.rightMargin: 2
            anchors.topMargin: 2
            width: 7
            height: 7
            radius: 3.5
            color: root.colPeach
            border.color: "#1a1b26"
            border.width: 1
            SequentialAnimation on opacity {
                running: wsbtn.activity && !wsbtn.active
                loops: Animation.Infinite
                NumberAnimation {
                    from: 1
                    to: 0.35
                    duration: 700
                    easing.type: Easing.InOutQuad
                }
                NumberAnimation {
                    from: 0.35
                    to: 1
                    duration: 700
                    easing.type: Easing.InOutQuad
                }
            }
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
        screen: root.popScreen || root.screenDP1
        anchors {
            top: true
            left: true
        }
        margins {
            top: 33
            left: root.popLeft(wPop.implicitWidth)
        }
        exclusiveZone: 0
        // Card se ajusta ao conteúdo (+28 = margens 14*2). Sem largura fixa,
        // não sobra espaço vazio à direita: a grade de 7 dias define a largura.
        implicitWidth: wContent.implicitWidth + 28
        implicitHeight: wContent.implicitHeight + 28
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
                id: wContent
                anchors.fill: parent
                anchors.margins: 14
                spacing: 10

                // Cabeçalho centralizado: hero (ícone + temperatura grande) e condição
                // no topo; métricas numa linha única separadas por "·". Tudo no centro.
                // AlignHCenter (e não fillWidth) centraliza o bloco dentro da largura
                // da grade — fillWidth não estica neste contexto do Quickshell.
                ColumnLayout {
                    Layout.alignment: Qt.AlignHCenter
                    spacing: 8

                    // Hero — ícone + temperatura grande, condição logo abaixo
                    ColumnLayout {
                        Layout.alignment: Qt.AlignHCenter
                        spacing: 0
                        RowLayout {
                            Layout.alignment: Qt.AlignHCenter
                            spacing: 10
                            Text {
                                text: root.weatherIcon(root.wText, root.isDayNow())
                                color: root.colSapphire
                                font.family: root.uiFont
                                font.pixelSize: 34
                            }
                            Text {
                                text: root.wTemp + "°C"
                                color: root.colText
                                font.family: root.uiFont
                                font.pixelSize: 28
                                font.bold: true
                            }
                        }
                        Text {
                            Layout.alignment: Qt.AlignHCenter
                            text: root.wText
                            color: root.colSapphire
                            font.family: root.uiFont
                            font.pixelSize: 12
                        }
                    }

                    // Métricas em uma linha, centralizadas, separadas por "·"
                    RowLayout {
                        Layout.alignment: Qt.AlignHCenter
                        spacing: 6
                        Repeater {
                            model: [
                                {
                                    label: "Sensação",
                                    value: root.wFeels + "°"
                                },
                                {
                                    label: "Umidade",
                                    value: root.wHumidity + "%"
                                },
                                {
                                    label: "Vento",
                                    value: root.wWind
                                }
                            ]
                            RowLayout {
                                required property var modelData
                                required property int index
                                spacing: 6
                                Text {
                                    visible: index > 0
                                    text: "·"
                                    color: root.colDim
                                    font.family: root.uiFont
                                    font.pixelSize: 12
                                }
                                Text {
                                    text: modelData.label
                                    color: root.colDim
                                    font.family: root.uiFont
                                    font.pixelSize: 11
                                }
                                Text {
                                    text: modelData.value
                                    color: root.colText
                                    font.family: root.uiFont
                                    font.pixelSize: 11
                                    font.bold: true
                                }
                            }
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
                    spacing: 6
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
        screen: root.popScreen || root.screenDP1
        anchors {
            top: true
            left: true
        }
        margins {
            top: 33
            left: root.popLeft(metricPop.implicitWidth)
        }
        exclusiveZone: 0
        implicitWidth: 300
        implicitHeight: 240
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
                    ColumnLayout {
                        required property var modelData
                        Layout.fillWidth: true
                        spacing: 3
                        RowLayout {
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
                        Rectangle {
                            visible: modelData.frac !== undefined
                            Layout.fillWidth: true
                            implicitHeight: 5
                            radius: 2.5
                            color: "#33414868"
                            Rectangle {
                                anchors.left: parent.left
                                anchors.verticalCenter: parent.verticalCenter
                                width: parent.width * (modelData.frac !== undefined ? modelData.frac : 0)
                                height: parent.height
                                radius: parent.radius
                                color: modelData.barColor !== undefined ? modelData.barColor : root.colAccent
                                Behavior on width {
                                    NumberAnimation {
                                        duration: 300
                                        easing.type: Easing.OutCubic
                                    }
                                }
                            }
                        }
                    }
                }
                Item {
                    Layout.fillHeight: true
                }
            }
        }
    }

    // ===== Popover de calendário (hover no relógio) — ano inteiro + feriados =====
    PanelWindow {
        id: calPop
        visible: root.calPopVisible
        screen: root.popScreen || root.screenDP1
        anchors {
            top: true
            left: true
        }
        margins {
            top: 33
            left: root.popLeft(calPop.implicitWidth)
        }
        exclusiveZone: 0
        implicitWidth: 880
        implicitHeight: 470
        color: "transparent"
        Rectangle {
            anchors.fill: parent
            radius: 12
            color: "#f21a1b26"
            border.color: "#414868"
            border.width: 1
            HoverHandler {
                onHoveredChanged: root.calPopHovered = hovered
            }
            RowLayout {
                anchors.fill: parent
                anchors.margins: 14
                spacing: 14

                // ---- Próximos feriados (coluna esquerda) ----
                ColumnLayout {
                    Layout.preferredWidth: 234
                    Layout.fillHeight: true
                    spacing: 7
                    Text {
                        text: "Próximos feriados"
                        color: root.colAccent
                        font.family: root.uiFont
                        font.pixelSize: 15
                        font.bold: true
                    }
                    Rectangle {
                        Layout.fillWidth: true
                        height: 1
                        color: "#414868"
                        opacity: 0.5
                    }
                    Repeater {
                        model: root.calUpcoming
                        RowLayout {
                            required property var modelData
                            Layout.fillWidth: true
                            spacing: 8
                            Rectangle {
                                width: 8
                                height: 8
                                radius: 4
                                color: root.scopeColor(modelData.scope)
                                Layout.alignment: Qt.AlignVCenter
                            }
                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 0
                                Text {
                                    Layout.fillWidth: true
                                    text: modelData.name
                                    color: root.colText
                                    font.family: root.uiFont
                                    font.pixelSize: 12
                                    font.bold: true
                                    elide: Text.ElideRight
                                }
                                Text {
                                    text: root.fmtHolidayDate(modelData.date) + "  ·  " + root.scopeLabel(modelData.scope)
                                    color: root.colDim
                                    font.family: root.uiFont
                                    font.pixelSize: 10
                                }
                            }
                            Text {
                                text: root.daysUntilLabel(modelData.date)
                                color: root.colSky
                                font.family: root.uiFont
                                font.pixelSize: 10
                                font.bold: true
                            }
                        }
                    }
                    Item {
                        Layout.fillHeight: true
                    }
                    RowLayout {
                        spacing: 10
                        Repeater {
                            model: [{ c: "nac", t: "Nacional" }, { c: "sp", t: "SP" }, { c: "sc", t: "S.Carlos" }]
                            RowLayout {
                                required property var modelData
                                spacing: 4
                                Rectangle {
                                    width: 8
                                    height: 8
                                    radius: 4
                                    color: root.scopeColor(modelData.c)
                                }
                                Text {
                                    text: modelData.t
                                    color: root.colDim
                                    font.family: root.uiFont
                                    font.pixelSize: 9
                                }
                            }
                        }
                    }
                }

                Rectangle {
                    Layout.fillHeight: true
                    width: 1
                    color: "#414868"
                    opacity: 0.5
                }

                // ---- Grade de 12 meses ----
                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    spacing: 6
                    Text {
                        text: "Calendário " + root.calYear
                        color: root.colText
                        font.family: root.uiFont
                        font.pixelSize: 15
                        font.bold: true
                        Layout.alignment: Qt.AlignHCenter
                    }
                    GridLayout {
                        Layout.fillWidth: true
                        columns: 4
                        rowSpacing: 8
                        columnSpacing: 12
                        Repeater {
                            model: 12
                            ColumnLayout {
                                required property int index
                                spacing: 1
                                Layout.alignment: Qt.AlignTop | Qt.AlignHCenter
                                Text {
                                    text: root.monthNames[index]
                                    color: (index + 1 === root.calTodayM) ? root.colAccent : root.colText
                                    font.family: root.uiFont
                                    font.pixelSize: 11
                                    font.bold: true
                                    Layout.alignment: Qt.AlignHCenter
                                }
                                Grid {
                                    columns: 7
                                    Layout.alignment: Qt.AlignHCenter
                                    Repeater {
                                        model: root.monthCells(index + 1)
                                        Item {
                                            required property var modelData
                                            readonly property var hol: modelData.holiday
                                            readonly property bool isToday: modelData.today === true
                                            readonly property bool isHead: modelData.head !== undefined
                                            width: 19
                                            height: 15
                                            Rectangle {
                                                anchors.centerIn: parent
                                                width: 16
                                                height: 13
                                                radius: 3
                                                color: parent.isToday ? root.colAccent : (parent.hol && !parent.hol.fac ? root.scopeColor(parent.hol.scope) : "transparent")
                                                border.width: (!parent.isToday && parent.hol && parent.hol.fac) ? 1 : 0
                                                border.color: parent.hol ? root.scopeColor(parent.hol.scope) : "transparent"
                                            }
                                            Text {
                                                anchors.centerIn: parent
                                                text: parent.isHead ? parent.modelData.head : (parent.modelData.d > 0 ? ("" + parent.modelData.d) : "")
                                                color: parent.isHead ? root.colDim : (parent.isToday ? "#1a1b26" : (parent.hol && !parent.hol.fac ? "#1a1b26" : (parent.hol && parent.hol.fac ? root.scopeColor(parent.hol.scope) : root.colWsInactive)))
                                                font.family: root.uiFont
                                                font.pixelSize: parent.isHead ? 8 : 9
                                                font.bold: parent.isToday || (parent.hol && !parent.hol.fac) || parent.isHead
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                    Item {
                        Layout.fillHeight: true
                    }
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

            // Item full-width usado como referência de coordenadas pros popovers
            // (mapToItem pra um Item real é confiável; mapToItem(null) não é).
            Item {
                id: barContent
                anchors.fill: parent

                // ESQUERDA: launcher (Arch) + workspaces (do monitor) + título + Spotify
                Group {
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    // Botão "Iniciar" estilo taskbar — só no monitor principal (DP-1),
                    // que é onde o popover de energia abre.
                    PowerMenu {
                        visible: bar.modelData && bar.modelData.name === "DP-1"
                    }
                    Repeater {
                        model: (bar.modelData && bar.modelData.name === "HDMI-A-1") ? [5, 6, 7, 8] : [1, 2, 3, 4]
                        WsBtn {
                            wsid: modelData
                            active: root.wsActive[bar.modelData.name] === modelData
                            exists: root.wsExist[modelData] === true
                            activity: root.wsActivity[modelData] === true
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
                        id: weatherPill
                        visible: root.wHas
                        icon: root.weatherIcon(root.wText, root.isDayNow())
                        label: root.wTemp + "°C"
                        accent: root.colSapphire
                        onHoveredChanged: {
                            root.wPillHovered = hovered;
                            if (hovered)
                                root.anchorPopover(weatherPill, barContent, bar.screen);
                        }
                        onClicked: root.launch(["xdg-open", "https://www.msn.com/pt-br/clima/forecast/in-S%C3%A3o-Carlos,S%C3%A3o-Paulo"])
                    }
                    Pill {
                        id: clockPill
                        label: root.timeStr
                        accent: root.colMauve
                        onClicked: root.showDate = !root.showDate
                        onHoveredChanged: {
                            if (hovered) {
                                root.anchorPopover(clockPill, barContent, bar.screen);
                                root.calPillHovered = true;
                            } else {
                                root.calPillHovered = false;
                            }
                        }
                    }
                    Pill {
                        // || cobre o instante de init do singleton no reload
                        icon: Notifs.barIcon || "󰂜"
                        // contagem quando há notificações; cor adaptativa:
                        // dim quando vazio, peach quando há, vermelho no DND.
                        label: Notifs.count > 0 ? "" + Notifs.count : ""
                        accent: Notifs.dnd ? root.colRed : (Notifs.count > 0 ? root.colPeach : root.colDim)
                        onClicked: Notifs.toggleCenter()
                        onRightClicked: Notifs.toggleDnd()
                    }
                }

                // DIREITA: temp, uso, vpn, rede, áudio, hypridle, tray
                Group {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    Pill {
                        id: tempPill
                        icon: "󰔏"
                        label: root.tempMax + "°C"
                        accent: root.tempColor(root.tempMax)
                        onHoveredChanged: hovered ? root.showMetric("temp", tempPill, barContent, bar.screen) : root.unhoverMetric()
                    }
                    Pill {
                        id: usagePill
                        icon: "󰓅"
                        label: root.cpuPct + "%"
                        accent: root.stateColor(root.cpuPct, root.colYellow)
                        onHoveredChanged: hovered ? root.showMetric("usage", usagePill, barContent, bar.screen) : root.unhoverMetric()
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
                        id: netPill
                        icon: "󰛳"
                        label: "↓" + root.fmtRate(root.netMainRx) + " ↑" + root.fmtRate(root.netMainTx)
                        accent: root.netConnected ? root.colTeal : root.colRed
                        onHoveredChanged: hovered ? root.showMetric("net", netPill, barContent, bar.screen) : root.unhoverMetric()
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
                    // System tray (StatusNotifier) — fundo único pro grupo de ícones.
                    // Popula quando o qs é o watcher (Waybar fora). Esquerda=activate,
                    // meio=secondaryActivate, scroll, direita=menu nativo (QsMenuAnchor).
                    Rectangle {
                        visible: root.trayCount > 0
                        implicitHeight: 22
                        implicitWidth: trayRow.implicitWidth + 14
                        radius: 8
                        color: root.colPillBg
                        border.color: root.colPillBorder
                        border.width: 1
                        RowLayout {
                            id: trayRow
                            anchors.centerIn: parent
                            spacing: 7
                            Repeater {
                                model: SystemTray.items
                                Item {
                                    id: trayDel
                                    implicitWidth: 20
                                    implicitHeight: 22
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
                                    // Menu de contexto nativo do SNI, ancorado abaixo do ícone.
                                    QsMenuAnchor {
                                        id: trayMenu
                                        menu: modelData.menu
                                        // ancora na janela real (PanelWindow) — padrão robusto no wlroots
                                        anchor.window: bar
                                        anchor.rect: Qt.rect(trayDel.mapToItem(barContent, 0, 0).x, trayDel.mapToItem(barContent, 0, 0).y + trayDel.height, trayDel.width, 1)
                                        anchor.edges: Edges.Bottom
                                        anchor.gravity: Edges.Bottom
                                        anchor.adjustment: PopupAdjustment.Flip | PopupAdjustment.Slide
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
                                            else if (modelData.hasMenu)
                                                trayMenu.open();
                                        }
                                        onWheel: w => modelData.scroll(w.angleDelta.y, false)
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
