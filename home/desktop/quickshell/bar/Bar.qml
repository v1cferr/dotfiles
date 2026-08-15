// Barra do desktop — a única; a Waybar saiu na migração pro Quickshell.
// Carregada por shell.qml (`Bar {}`); os popovers moram em arquivos ao lado
// (Calendar/Metrics/Vpn/Weather/Tray/PowerMenu).
// Mostra: workspaces por monitor + título · relógio · cpu/ram/disco/temp · GPU ·
// áudio (Pipewire) · Spotify (Mpris) · rede · VPN · clima · tray · notificações.
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
    // Esconde a barra sob demanda (IPC). Existe por causa do overlay do Flameshot: no
    // Hyprland uma JANELA normal nunca cobre uma layer `top`, e a barra vive nela — o
    // overlay mostra um frame CONGELADO que já contém a barra e a barra VIVA desenha em
    // cima, dando o efeito de "barra duplicada". Não há window rule que resolva (é feature
    // request aberta: hyprwm/Hyprland#4847), então o único caminho é esconder.
    // `visible: false` desmapeia a layer surface — o strip de 30px para de capturar clique,
    // o que importa p/ conseguir selecionar região no topo da tela.
    property bool hidden: false
    readonly property int trayCount: SystemTray.items ? SystemTray.items.values.length : 0
    readonly property string vpnBin: "vpn" // CLI no PATH (system/net/vpn.nix)

    // Paleta e fonte vêm do Theme singleton (Theme.colX / Theme.uiFont).

    function stateColor(pct, base) {
        return pct >= 90 ? Theme.colRed : (pct >= 70 ? Theme.colPeach : base);
    }
    function launch(cmd) {
        Quickshell.execDetached(cmd);
    }

    // qs ipc call bar hide / unhide  → usado pelo flameshot-screenshot (home/apps/flameshot.nix).
    // NÃO nomear "show": colide com o subcomando `qs ipc show` e o CLI nunca chama a função
    // (mesma pegadinha já documentada no shell.qml, no IpcHandler do vpn).
    IpcHandler {
        target: "bar"

        function hide(): void {
            root.hidden = true;
        }

        function unhide(): void {
            root.hidden = false;
        }
    }

    // ===== Relógio =====
    // Hora E data SEMPRE visíveis, na mesma pílula. Era um toggle no clique (showDate): ou
    // uma ou outra, e pra ver a data tinha que clicar duas vezes (ida e volta). A hora vem
    // primeiro e a data vai no `sub` da Pill (cor discreta) — hierarquia, não separação.
    // Dia da semana pelo dowAbbr daqui, e não pelo "ddd" do Qt: o formato do Qt depende do
    // locale do processo, então "sáb" viraria "Sat" se a barra subir sem LC_TIME.
    // Sem ano — quem precisa dele tem o calendário no hover.
    property string dateStr: ""
    property string timeStr: ""
    SystemClock {
        id: sysClock
        precision: SystemClock.Seconds
    }
    function updateClock() {
        const d = sysClock.date;
        root.dateStr = root.dowAbbr[d.getDay()] + " " + Qt.formatDateTime(d, "dd/MM");
        root.timeStr = Qt.formatDateTime(d, "HH:mm:ss");
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

    // ===== Temperaturas (sensors -j) + GPU temp (hwmon do xe; ver gpuProc) =====
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
        // Intel Arc B580 (driver xe): temp via hwmon; uso% NÃO existe no xe → 0.
        // Saída "0,<temp>" p/ o parseGpu (era nvidia-smi "usage,temp" no Arch).
        command: ["sh", "-c", "for t in /sys/class/drm/card*/device/hwmon/hwmon*/temp*_input; do d=$(dirname \"$t\"); [ \"$(cat \"$d/name\" 2>/dev/null)\" = xe ] && echo \"0,$(($(cat \"$t\")/1000))\" && break; done"]
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
        return t >= 85 ? Theme.colRed : (t >= 70 ? Theme.colPeach : Theme.colSapphire);
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
    // vpnList guarda a lista CRUA [{id,name,connected}] porque o popover precisa de uma
    // linha por VPN; vpnConnected/vpnName seguem sendo o agregado que o pill mostra.
    // Uma leitura só alimenta os dois — o rofi remontava os rótulos por conta própria
    // com `systemctl is-active`, que MENTE no crash-loop do nxBender (ver vpn.nix).
    property bool vpnConnected: false
    property string vpnName: ""
    property var vpnList: []
    property bool vpnPopVisible: false
    property bool vpnBusy: false
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
            root.vpnList = j.vpns || [];
            root.vpnConnected = c;
            root.vpnName = n;
        } catch (e) {}
    }
    // Conectar/desconectar pelo popover. Process (e não launch()) p/ saber QUANDO
    // terminou: aí o estado é relido na hora, em vez de esperar o poll de 5s — e o
    // vpnBusy segura o painel aberto e os botões inertes durante a ação.
    function runVpn(action, target) {
        root.vpnBusy = true;
        vpnActionProc.command = [root.vpnBin, action, target];
        vpnActionProc.running = true;
    }
    Process {
        id: vpnActionProc
        onRunningChanged: {
            if (!running) {
                root.vpnBusy = false;
                vpnProc.running = true;
            }
        }
    }
    Process {
        id: vpnProc
        command: [root.vpnBin, "status-json"]
        stdout: StdioCollector {
            onStreamFinished: root.parseVpn(text)
        }
    }

    // ===== Qualidade da VPN — popover de HOVER do pill =====
    // O pill respondia só "tem túnel?"; faltava "e está bom?" — que é a pergunta de
    // quem está com uma sessão SSH ou uma chamada dependendo dele.
    // DUAS FONTES, de propósito: o `vpn stats-json` traz o ESTADO (iface, IP, MTU,
    // tempo no ar, bytes, e qual host serve de alvo) a cada 20s — 3s com o painel
    // aberto —, e a latência vem da sonda CONTÍNUA logo abaixo. Sem túnel nada disso
    // roda, então o custo em repouso é zero; é por isso que não entrou no status-json,
    // que roda a cada 5s o dia inteiro só p/ pintar o pill.
    property var vpnStats: ({})   // id -> objeto do `vpn stats-json`
    function parseVpnStats(text) {
        try {
            const j = JSON.parse(text);
            const st = ({});
            (j.vpns || []).forEach(v => st[v.id] = v);
            root.vpnStats = st;
        } catch (e) {}
    }

    // ── Sonda contínua: 1 pacote/s, janela de 60s ─────────────────────────────
    // POR QUE CONTÍNUA, e não uma rajada a cada leitura — MEDIDO em 14/08/2026 no
    // túnel da FAI, e foi o que condenou a 1ª versão: 3 pacotes em 0,6s davam mdev
    // 0,4ms enquanto uma janela de 20s dava mdev 3,3ms e PICO DE 54,7ms. Ou seja, a
    // rajada observava 3% do tempo e um engasgo de 2s era invisível em 97% dos casos;
    // pior, a perda tinha resolução de 33% (3 pacotes!), então 1-3% de perda real
    // aparecia como "0%". Número bonito e falso é pior que número ausente.
    // O CUSTO é irrisório e foi medido: 84 B/s, e 30 pacotes a 1/s deram 0% de perda —
    // o alvo não faz rate-limit nessa cadência. A janela de 60 amostras dá jitter de
    // verdade e resolução de perda de 1,7%.
    // O `ping` é LINE-BUFFERED mesmo escrevendo em pipe (verificado: uma linha por
    // segundo, sem stdbuf), então dá pra ler o fluxo em vez de esperar ele terminar.
    // QUEM DESCOBRE O ALVO é o CLI (system/net/vpn.nix): varrer rota e testar
    // candidato é trabalho de shell; observar o tempo todo é trabalho de quem fica
    // aberto. Sem alvo, esta sonda simplesmente não sobe e o painel diz "sem sonda".
    component VpnProbe: Scope {
        id: probe
        // `info` CHEGA de fora (o objeto desta VPN no vpn stats-json) em vez de ser
        // buscado aqui: inline component não enxerga o `id` do documento que o declara,
        // então um `root.vpnStats[...]` daqui de dentro estoura em ReferenceError e a
        // instância inteira não nasce — o sintoma foi `vpnProbeStat` virar undefined.
        required property var info
        readonly property string iface: probe.info.connected === true ? (probe.info.iface || "") : ""
        readonly property string target: probe.info.connected === true ? (probe.info.probe || "") : ""
        // Túnel novo (ou alvo novo) = série nova: emendar duas sessões desenharia um
        // degrau que nunca existiu. O IP entra na chave porque o NOME da interface se
        // repete: num reconnect o ppp0 volta a ser ppp0 (visto em 14/08/2026, o IP indo
        // de 192.168.50.2 p/ .3) e sem ele a série atravessaria a queda como se nada
        // tivesse acontecido.
        readonly property string key: probe.iface + "@" + probe.ip + "@" + probe.target
        readonly property string ip: probe.info.connected === true ? (probe.info.ip || "") : ""
        readonly property int window: 60 // 1 min a 1 pacote/s
        property var series: []          // ms por amostra; null = pacote sem resposta

        onKeyChanged: {
            probe.series = [];
            pingProc.running = false;
            if (probe.iface !== "" && probe.target !== "") {
                // -O emite "no answer yet" na hora do timeout: sem isso, pacote perdido
                // seria SILÊNCIO e a série ficaria só com os que voltaram (perda 0%
                // eterna). -n não resolve DNS; -W 1 casa com o intervalo de 1s.
                pingProc.command = ["ping", "-n", "-O", "-i", "1", "-W", "1", "-I", probe.iface, probe.target];
                probe.lastAt = Date.now();
                pingProc.running = true;
            }
        }
        function push(v) {
            const s = probe.series.slice(-(probe.window - 1));
            s.push(v);
            probe.series = s;
        }
        function feed(line) {
            probe.lastAt = Date.now(); // qualquer linha prova que a sonda está viva
            const m = line.match(/time=([0-9.]+) ms/);
            if (m)
                probe.push(Number(m[1]));
            else if (line.indexOf("no answer yet") >= 0)
                probe.push(null);
            // cabeçalho e ruído não viram amostra, mas contam como sinal de vida
        }
        // WATCHDOG. Com o -O o ping FALA a cada segundo mesmo quando o alvo some, então
        // SILÊNCIO não é perda de pacote: é a sonda quebrada (processo morto, interface
        // recriada debaixo dele). Sem isto o painel congelaria exibindo a última janela
        // boa, com cara de "estável" — exatamente a mentira que ele existe pra não
        // contar. Marca o buraco na série E ressuscita o processo.
        property double lastAt: 0
        Timer {
            interval: 5000
            repeat: true
            running: probe.iface !== "" && probe.target !== ""
            onTriggered: {
                if (Date.now() - probe.lastAt < 5000)
                    return;
                probe.push(null);
                probe.lastAt = Date.now();
                pingProc.running = false;
                reviveTimer.restart();
            }
        }
        Timer {
            id: reviveTimer
            interval: 300 // deixa o processo morrer antes de renascer
            onTriggered: if (probe.iface !== "" && probe.target !== "")
                pingProc.running = true
        }
        // Estatística da janela. O `mdev` é o desvio padrão das respondidas — a mesma
        // conta do iputils, p/ o número aqui bater com o do `ping` no terminal.
        readonly property var stat: {
            const s = probe.series;
            let n = 0, sum = 0, sum2 = 0, mn = 0, mx = 0, lost = 0;
            for (let i = 0; i < s.length; i++) {
                const v = s[i];
                if (v === null) {
                    lost++;
                    continue;
                }
                if (n === 0 || v < mn)
                    mn = v;
                if (v > mx)
                    mx = v;
                n++;
                sum += v;
                sum2 += v * v;
            }
            const avg = n ? sum / n : 0;
            return {
                n: s.length,
                answered: n,
                lost: lost,
                loss: s.length ? lost * 100 / s.length : 0,
                avg: avg,
                min: mn,
                max: mx,
                mdev: n ? Math.sqrt(Math.max(0, sum2 / n - avg * avg)) : 0
            };
        }
        Process {
            id: pingProc
            stdout: SplitParser {
                splitMarker: "\n"
                onRead: data => probe.feed(data)
            }
        }
    }
    // Uma sonda por VPN — as mesmas duas que o CLI conhece (system/net/vpn.nix).
    VpnProbe {
        id: faiProbe
        info: root.vpnStats["fai"] || ({})
    }
    VpnProbe {
        id: ufscarProbe
        info: root.vpnStats["ufscar"] || ({})
    }
    readonly property var vpnProbeStat: ({
            fai: faiProbe.stat,
            ufscar: ufscarProbe.stat
        })
    readonly property var vpnProbeSeries: ({
            fai: faiProbe.series,
            ufscar: ufscarProbe.series
        })

    // Veredito, com os cortes ancorados na baseline MEDIDA do túnel da FAI (14/08/2026,
    // 1 pacote/s: média ~34ms, mdev 0,8ms, 0% de perda). A ORDEM é a do estrago: perda
    // primeiro (mata sessão), jitter antes da média — 200ms estáveis se trabalha, 40ms
    // serrilhados travam SSH e chamada.
    // Os NÚMEROS não são chutados: 2% de perda = 2 pacotes perdidos na janela de 60, e
    // um pacote solto por minuto é rotina demais p/ acender alarme; mdev de 10ms é uma
    // ordem de grandeza acima do medido em túnel saudável.
    // "medindo…" antes de 5 amostras porque veredito com 2 pacotes é adivinhação.
    function vpnQuality(s, pr) {
        if (!s || !s.connected)
            return {
                label: "—",
                color: Theme.colDim
            };
        if (!s.probe)
            return {
                label: "sem sonda",
                color: Theme.colDim
            };
        if (!pr || pr.n < 5)
            return {
                label: "medindo…",
                color: Theme.colDim
            };
        if (pr.loss >= 20)
            return {
                label: "ruim",
                color: Theme.colRed
            };
        if (pr.loss >= 2 || pr.mdev > 10)
            return {
                label: "instável",
                color: Theme.colPeach
            };
        if (pr.avg > 150)
            return {
                label: "lenta",
                color: Theme.colYellow
            };
        return {
            label: "estável",
            color: Theme.colGreen
        };
    }
    // Taxa AGORA da interface do túnel: sai do netRates que a barra já calcula a cada
    // 2s (/proc/net/dev) — o stats-json não repete essa conta. Interface parada não
    // aparece naquela lista, e "não apareceu" quer dizer 0 B/s.
    function vpnRate(iface) {
        const r = (root.netRates || []).find(n => n.iface === iface);
        return r || {
            rx: 0,
            tx: 0
        };
    }
    function fmtBytes(b) {
        if (b >= 1073741824)
            return (b / 1073741824).toFixed(1) + " GB";
        if (b >= 1048576)
            return (b / 1048576).toFixed(1) + " MB";
        if (b >= 1024)
            return Math.round(b / 1024) + " KB";
        return Math.round(b) + " B";
    }
    function fmtDur(s) {
        if (s >= 86400)
            return Math.floor(s / 86400) + "d " + Math.floor((s % 86400) / 3600) + "h";
        if (s >= 3600)
            return Math.floor(s / 3600) + "h " + Math.floor((s % 3600) / 60) + "min";
        if (s >= 60)
            return Math.floor(s / 60) + "min";
        return Math.round(s) + "s";
    }
    // Só as CONECTADAS entram no painel: linha de VPN desligada não tem estatística,
    // e o popover de AÇÕES (clique) é que lista as duas p/ ligar/desligar.
    readonly property var vpnStatsList: {
        const out = [];
        const l = root.vpnList || [];
        for (let i = 0; i < l.length; i++) {
            if (l[i].connected !== true)
                continue;
            out.push(root.vpnStats[l[i].id] || {
                    id: l[i].id,
                    name: l[i].name,
                    connected: true
                });
        }
        return out;
    }
    // O painel de estatísticas é do HOVER; o de ações, do CLIQUE. Os dois ancoram no
    // MESMO ponto da barra, então enquanto o menu está aberto este some — senão um
    // desenharia por cima do outro (e o mouse continua sobre o pill o tempo todo).
    property bool vpnPillHovered: false
    property bool vpnStatsPopHovered: false
    property bool vpnStatsPopVisible: false
    readonly property bool vpnStatsWanted: (root.vpnPillHovered || root.vpnStatsPopHovered) && root.vpnConnected && !root.vpnPopVisible
    onVpnStatsWantedChanged: {
        if (root.vpnStatsWanted) {
            vpnStatsCloseTimer.stop();
            root.vpnStatsPopVisible = true;
            vpnStatsProc.running = true; // amostra fresca ao abrir
        } else {
            vpnStatsCloseTimer.restart();
        }
    }
    // Mesma folga de 300ms dos outros popovers de hover: dá pra atravessar o vão
    // entre o pill e o painel sem ele fechar na cara.
    Timer {
        id: vpnStatsCloseTimer
        interval: 300
        onTriggered: if (!root.vpnStatsWanted)
            root.vpnStatsPopVisible = false
    }
    Timer {
        interval: root.vpnStatsPopVisible ? 3000 : 20000
        running: root.vpnConnected
        repeat: true
        triggeredOnStart: true
        onTriggered: vpnStatsProc.running = true
    }
    Process {
        id: vpnStatsProc
        command: [root.vpnBin, "stats-json"]
        stdout: StdioCollector {
            onStreamFinished: root.parseVpnStats(text)
        }
    }

    // ===== Hypridle (toggle-hypridle.sh) =====
    property string hypridleIcon: "󰒲"
    property bool hypridleOn: false
    function parseHypridle(text) {
        const on = text.trim() === "on";
        root.hypridleOn = on;
        root.hypridleIcon = on ? "󰒳" : "󰒲";
    }
    Process {
        id: hypridleProc
        // hypridle roda como serviço systemd --user (home/desktop/lockscreen.nix).
        command: ["sh", "-c", "systemctl --user is-active --quiet hypridle.service && echo on || echo off"]
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
    // Código WMO (Open-Meteo) -> texto en-US. As strings batem com os regex do
    // weatherIcon() abaixo, então o ícone é derivado do texto sem mexer no mapa.
    function wmoText(code) {
        const c = code;
        if (c === 0 || c === 1) return "Clear";
        if (c === 2) return "Partly cloudy";
        if (c === 3) return "Cloudy";
        if (c === 45 || c === 48) return "Fog";
        if (c >= 51 && c <= 57) return "Drizzle";
        if (c >= 61 && c <= 67) return "Rain";
        if ((c >= 71 && c <= 77) || c === 85 || c === 86) return "Snow";
        if (c >= 80 && c <= 82) return "Showers";
        if (c === 95) return "Thunderstorm";
        if (c === 96 || c === 99) return "Thunderstorm w/ hail";
        return "—";
    }
    // Direção do vento (graus -> rosa-dos-ventos, 8 pontos).
    function windDir(deg) {
        const dirs = ["N", "NE", "E", "SE", "S", "SW", "W", "NW"];
        return dirs[Math.round(deg / 45) % 8];
    }
    function weatherIcon(text, isDay) {
        const c = (text || "").toLowerCase();
        if (/clear|sunny|\bsun\b/.test(c))
            return isDay ? "󰖙" : "󰖔";
        if (/partly/.test(c))
            return isDay ? "󰖕" : "󰼶";
        if (/cloud|overcast/.test(c))
            return "󰖐";
        if (/fog|mist|haze/.test(c))
            return "󰖑";
        if (/thunder|storm/.test(c))
            return "󰖓";
        if (/rain|drizzle|shower/.test(c))
            return "󰖗";
        if (/snow|ice|hail|sleet/.test(c))
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
    readonly property color spColor: root.spPlaying ? Theme.colGreen : (root.spHasPlayer ? Theme.colYellow : Theme.colDim)

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
                if (iface === "enp7s0") {
                    root.netMainRx = rxr;
                    root.netMainTx = txr;
                }
                if (rxr > 0 || txr > 0 || iface === "enp7s0")
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
    // Alias do Theme (era uma 2ª implementação, divergente da de lá — ver Theme.qml).
    readonly property var screenPrimary: Theme.screenPrimary
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
        const scr = root.popScreen || root.screenPrimary;
        const sw = scr ? scr.width : 1920;
        return Math.round(Math.max(4, Math.min(root.popCenterX + 4 - popW / 2, sw - popW - 4)));
    }

    // ===== Feriados (nacional + SP + São Carlos) — REVERIFICADO em 08/08/2026 =====
    // scope: "nac" | "sp" | "sc". off = offset em dias do DOMINGO de Páscoa (datas
    // móveis); senão m/d fixos. fac = ponto facultativo (não dá folga garantida) ->
    // fica discreto na grade e FORA de "próximos feriados" (computeUpcoming filtra).
    //
    // ⚠️ ESTA LISTA NÃO SE ATUALIZA SOZINHA — é a única parte do calendário que não.
    // Os MÓVEIS derivam da Páscoa (easterDate) e escalam pra sempre; os FIXOS são LEI
    // escrita à mão aqui. Lei nova, ou o município mexendo num feriado, deixa a grade
    // errada EM SILÊNCIO. Revisar quando aparecer notícia de feriado novo, não por
    // calendário — 2027 já está coberto, porque nada aqui depende do ano.
    //
    // BASES LEGAIS (antes era "ver notas do workflow", ponteiro pra fora do repo):
    //   nac  Lei 662/1949 + 6.802/1980 (Aparecida) + 9.093/1995 (Sexta-feira Santa)
    //        + 14.759/2023 (Consciência Negra, nacional desde 2024 — NÃO é mais só SP)
    //   sp   Lei estadual 9.497/1997 (Revolução Constitucionalista, 9 de julho)
    //   sc   Lei municipal 7.502/1974 (Corpus Christi) + Babilônia 15/08 + aniversário 04/11
    //
    // DUAS ARMADILHAS que os sites de calendário caem e esta lista não:
    // 1. CARNAVAL e CINZAS não são feriado nacional NEM municipal em São Carlos — são
    //    ponto facultativo (decreto estadual 70.273 + prefeitura). Daí o fac: true.
    // 2. CORPUS CHRISTI é ponto facultativo FEDERAL, mas feriado MUNICIPAL aqui (lei
    //    acima) — por isso entra como "sc" e SEM fac. Em outra cidade seria fac.
    // CONFERÊNCIA: os não-fac desta lista somam 14, que é o número que a prefeitura e a
    // imprensa local publicam para São Carlos. Se um dia divergir, é sinal de lei nova.
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
        return scope === "nac" ? Theme.colRed : (scope === "sp" ? Theme.colBlue : Theme.colMauve);
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
    // Quem faz o calendário virar o ano sozinho: updateClock() compara o yyyy-MM-dd com
    // calDayKey, e na primeira batida do SystemClock depois da meia-noite chama isto.
    // Vale pra 01/01 também — calYear muda e o popover inteiro (cabeçalho + as 12 grades)
    // reavalia, sem rebuild e sem reiniciar o shell. MEDIDO em 08/08/2026 simulando a
    // virada 31/12/2026 -> 01/01/2027: cabeçalho 2027, "hoje" em 01/01, Carnaval pintado
    // em 08-09/02. Se a máquina passar a virada suspensa, o resume cai no mesmo caminho.
    //
    // ⚠️ NÃO OTIMIZE ISTO PRA MUTAR OS OBJETOS NO LUGAR. O popover lê calMap por binding
    // (`Repeater { model: bar.monthCells(...) }`), e binding do QML só reavalia quando a
    // PROPRIEDADE é reatribuída — escrever dentro do objeto existente (calMap[k] = v) não
    // emite sinal nenhum. O calendário congelaria EM SILÊNCIO: nada quebra, nada loga, só
    // para de virar o ano. Medido no qml headless: reatribuir propaga, mutar não.
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
                        barColor: root.stateColor(u.pct, Theme.colAccent)
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
        if ((m = t.match(/^(.*) — Zen Browser$/)))
            return "󰺕 " + m[1];
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
            spacing: 4 // gap entre os pills/widgets de cada grupo (esq/centro/dir)
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
        color: wsbtn.active ? Theme.colWsActiveBg : (wsArea.containsMouse ? Theme.colPillHoverBg : Theme.colPillBg)
        border.color: wsbtn.active ? Theme.colWsActiveBorder : (wsArea.containsMouse ? Theme.colHoverBorder : Theme.colPillBorder)
        border.width: 1
        Behavior on color {
            ColorAnimation {
                duration: 200
            }
        }

        Text {
            id: wlbl
            anchors.centerIn: parent
            text: wsbtn.active ? "󰮯" : root.wsIcon(wsbtn.wsid)
            color: wsbtn.active ? Theme.colBgSolid : Theme.colWsInactive
            font.family: Theme.uiFont
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
            color: Theme.colPeach
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
            // Sintaxe LUA do 0.55: `dispatch` virou atalho p/ hl.dispatch(...), então a
            // forma antiga ("dispatch", "workspace", N) monta `hl.dispatch(workspace 3)` e
            // estoura no parser — clique morria em silêncio, sem nada na tela.
            // Cuidado: `hl.dsp.workspace` é TABELA, não função (vira "attempt to call a
            // table value"); quem troca de workspace é o focus, igual ao keybinds.lua.
            onClicked: root.launch(["hyprctl", "dispatch", "hl.dsp.focus({ workspace = " + wsbtn.wsid + " })"])
        }
    }

    // ===== Popover de weather — view em bar/WeatherPopover.qml =====
    WeatherPopover {
        bar: root
    }

    // ===== Popover de métricas — view em bar/MetricsPopover.qml =====
    MetricsPopover {
        bar: root
    }

    // ===== Popover de calendário — view em bar/CalendarPopover.qml =====
    CalendarPopover {
        bar: root
    }

    // ===== Popover de VPN — view em bar/VpnPopover.qml =====
    VpnPopover {
        bar: root
    }

    // ===== Popover de estatísticas da VPN (hover) — view em bar/VpnStatsPopover.qml =====
    VpnStatsPopover {
        bar: root
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
            visible: !root.hidden
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
                    // Botão "Iniciar" estilo taskbar — só no monitor principal,
                    // que é onde o popover de energia abre.
                    PowerMenu {
                        visible: bar.modelData && bar.modelData.name === Theme.primaryMonitor
                    }
                    Repeater {
                        model: (bar.modelData && bar.modelData.name === Theme.secondaryMonitor) ? [5, 6, 7, 8] : [1, 2, 3, 4]
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
                        accent: Theme.colSky
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
                        accent: Theme.colSapphire
                        onHoveredChanged: {
                            root.wPillHovered = hovered;
                            if (hovered)
                                root.anchorPopover(weatherPill, barContent, bar.screen);
                        }
                        onClicked: root.launch(["xdg-open", "https://www.msn.com/en-us/weather/forecast/in-S%C3%A3o-Carlos,S%C3%A3o-Paulo"])
                    }
                    Pill {
                        id: clockPill
                        icon: "󰥔"
                        label: root.timeStr
                        sub: root.dateStr
                        accent: Theme.colMauve
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
                        accent: Notifs.dnd ? Theme.colRed : (Notifs.count > 0 ? Theme.colPeach : Theme.colDim)
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
                        accent: root.stateColor(root.cpuPct, Theme.colYellow)
                        onHoveredChanged: hovered ? root.showMetric("usage", usagePill, barContent, bar.screen) : root.unhoverMetric()
                    }
                    Pill {
                        // VPN: verde + nome quando conectada, cinza quando off. Clique abre o
                        // popover ANCORADO na barra (bar/VpnPopover.qml) — antes lançava
                        // `vpn menu`, um rofi solto no meio da tela, fora do tema do shell.
                        // Clique-direito segue sendo o atalho de derrubar tudo.
                        // HOVER (com túnel de pé) mostra as estatísticas — VpnStatsPopover.qml.
                        // A divisão é intencional: informação no hover, AÇÃO no clique. Painel
                        // com botão que abre sozinho no hover some na primeira distração, e o
                        // de estatísticas não tem nada pra clicar (mesmo critério do calendário).
                        id: vpnPill
                        icon: "󰦝"
                        label: root.vpnConnected ? root.vpnName : ""
                        accent: root.vpnConnected ? Theme.colGreen : Theme.colDim
                        maxWidth: 150
                        onHoveredChanged: {
                            root.vpnPillHovered = hovered;
                            if (hovered)
                                root.anchorPopover(vpnPill, barContent, bar.screen);
                        }
                        onClicked: {
                            root.anchorPopover(vpnPill, barContent, bar.screen);
                            root.vpnPopVisible = !root.vpnPopVisible;
                            if (root.vpnPopVisible)
                                vpnProc.running = true; // estado fresco ao abrir
                        }
                        onRightClicked: root.runVpn("disconnect", "all")
                    }
                    Pill {
                        id: netPill
                        icon: "󰛳"
                        label: "↓" + root.fmtRate(root.netMainRx) + " ↑" + root.fmtRate(root.netMainTx)
                        accent: root.netConnected ? Theme.colTeal : Theme.colRed
                        onHoveredChanged: hovered ? root.showMetric("net", netPill, barContent, bar.screen) : root.unhoverMetric()
                        onClicked: root.launch(["nm-connection-editor"])
                    }
                    Pill {
                        icon: root.volIcon()
                        label: Math.round(root.volume * 100) + "%"
                        accent: root.sinkMuted ? Theme.colDim : Theme.colBlue
                        onClicked: root.toggleMute()
                        onRightClicked: root.launch(["pavucontrol"])
                        onScrolledUp: root.setVol(0.05)
                        onScrolledDown: root.setVol(-0.05)
                    }
                    Pill {
                        icon: root.hypridleIcon
                        accent: root.hypridleOn ? Theme.colGreen : Theme.colRed
                        onClicked: root.launch(["sh", "-c", "systemctl --user is-active --quiet hypridle.service && systemctl --user stop hypridle.service || systemctl --user start hypridle.service"])
                    }
                    // System tray (StatusNotifier) — fundo único pro grupo de ícones.
                    // Popula quando o qs é o watcher (Waybar fora). Esquerda=activate,
                    // meio=secondaryActivate, scroll, direita=menu nativo (QsMenuAnchor).
                    Rectangle {
                        visible: root.trayCount > 0
                        implicitHeight: 22
                        implicitWidth: trayRow.implicitWidth + 14
                        radius: 8
                        color: Theme.colPillBg
                        border.color: Theme.colPillBorder
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
                                                // SNI nativo: menu tematizado próprio. O menu é
                                                // layer surface (ver TrayMenu.qml: PopupWindow não
                                                // recebe ponteiro por causa do Hyprland#6682), então
                                                // ele se posiciona por X DE TELA, não por anchor.rect:
                                                // X do ícone dentro do barContent + a margem esquerda
                                                // da barra. O Y é implícito (fica sob a exclusiveZone).
                                                const pt = trayDel.mapToItem(barContent, 0, trayDel.height);
                                                trayCtxMenu.openAt(modelData.menu, bar, pt.x + bar.margins.left);
                                            } else {
                                                // xembedsniproxy (wine/Battle.net/pamac): sem DBusMenu. Este
                                                // caminho ficou MORTO até 30/07, porque o proxy não estava
                                                // instalado — nenhum ícone assim chegava a existir. Agora
                                                // ele é declarado em home/desktop/quickshell.nix. O display() do
                                                // Quickshell recusa itens sem menu ("No menu present"), então
                                                // disparamos o ContextMenu() nativo do SNI via helper — o proxy
                                                // repassa o clique e o app desenha o próprio menu no cursor.
                                                root.launch(["tray-native-menu", "" + modelData.id]);
                                            }
                                        }
                                        onWheel: w => modelData.scroll(w.angleDelta.y, false)
                                    }
                                }
                            }
                        }
                        // Uma única instância compartilhada do menu de contexto: abrir num
                        // ícone troca/fecha o de outro (evita empilhar vários menus).
                        TrayMenu {
                            id: trayCtxMenu
                        }
                    }
                }
            }
        }
    }
}
