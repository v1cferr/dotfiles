// The desktop's bar, the only one, loaded by shell.qml; the popovers are files next to it.
// The probe, the holidays and the tray traps: docs/notes/desktop/bar.md
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
    // It hides the bar on demand (IPC), because a normal window never covers a `top` layer and
    // Flameshot's frozen overlay would show a DUPLICATED bar. `visible:false` also frees the clicks.
    property bool hidden: false
    readonly property int trayCount: SystemTray.items ? SystemTray.items.values.length : 0
    readonly property string vpnBin: "vpn" // the CLI on the PATH (system/net/vpn.nix)

    // The palette and the font come from the Theme singleton (Theme.colX / Theme.uiFont).

    function stateColor(pct, base) {
        return pct >= 90 ? Theme.colRed : (pct >= 70 ? Theme.colPeach : base);
    }
    function launch(cmd) {
        Quickshell.execDetached(cmd);
    }

    // Used by flameshot-screenshot. Do NOT name it "show": it collides with `qs ipc show` and the
    // CLI never calls the function (the same trap as shell.qml's vpn IpcHandler).
    IpcHandler {
        target: "bar"

        function hide(): void {
            root.hidden = true;
        }

        function unhide(): void {
            root.hidden = false;
        }
    }

    // The clock: time AND date always visible in one pill, the date in `sub` (a hierarchy, not a
    // toggle). The weekday is local, not Qt's "ddd", which follows the process locale.
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

    // ===== The system snapshot: ONE read of /proc and sysfs per tick =====
    // `head -v` prefixes every file with its own path, so a single fork replaces the five that used
    // to read the CPU, the memory, the sensors, the GPU and the links: docs/notes/desktop/bar.md
    readonly property int sysInterval: 2000
    readonly property int histWindow: 60 // 60 samples at 2 s = the last 2 minutes
    readonly property string sysCmd: "head -n 200 -v /proc/stat /proc/loadavg /proc/uptime /proc/meminfo /proc/diskstats /proc/net/dev /proc/pressure/cpu /proc/pressure/memory /proc/pressure/io /sys/class/hwmon/hwmon*/name /sys/class/hwmon/hwmon*/temp*_input /sys/class/hwmon/hwmon*/temp*_label /sys/class/hwmon/hwmon*/temp*_max /sys/class/hwmon/hwmon*/temp*_crit /sys/class/hwmon/hwmon*/fan*_input /sys/class/hwmon/hwmon*/energy*_input /sys/class/hwmon/hwmon*/power*_cap /sys/class/drm/card*/device/tile*/gt*/freq0/act_freq /sys/class/drm/card*/device/tile*/gt*/freq0/max_freq /sys/devices/system/cpu/cpu*/cpufreq/scaling_cur_freq 2>/dev/null || true"

    // A history series is REASSIGNED, never mutated: writing inside the array emits no change
    // signal, the same trap the calendar's year rollover documents.
    function pushed(arr, v) {
        const s = (arr || []).slice(-(root.histWindow - 1));
        s.push(v);
        return s;
    }
    function parseSys(text) {
        const sec = ({});
        const blocks = text.split("==> ");
        for (let i = 1; i < blocks.length; i++) {
            const cut = blocks[i].indexOf(" <==\n");
            if (cut > 0)
                sec[blocks[i].slice(0, cut)] = blocks[i].slice(cut + 5);
        }
        root.parseCpu(sec["/proc/stat"] || "");
        root.parseMem(sec["/proc/meminfo"] || "");
        root.parseLoad(sec["/proc/loadavg"] || "", sec["/proc/uptime"] || "");
        root.parsePsi(sec);
        root.parseCpuFreq(sec);
        root.parseHwmon(sec);
        root.parseGpuFreq(sec);
        root.parseDiskIo(sec["/proc/diskstats"] || "");
        root.parseNetDev(sec["/proc/net/dev"] || "");
    }
    Process {
        id: sysProc
        command: ["sh", "-c", root.sysCmd]
        stdout: StdioCollector {
            onStreamFinished: root.parseSys(text)
        }
    }

    // ===== CPU =====
    property int cpuPct: 0
    property var cpuCoreP: []      // one % per THREAD, in /proc/stat order
    property var cpuHist: []
    property var cpuPrev: ({})
    property real cpuMhz: 0
    property real cpuMhzMax: 0
    property string cpuModel: ""
    property int cpuThreads: 0
    property int cpuCores: 0
    property var loadAvg: [0, 0, 0]
    property real uptimeSec: 0
    // The kernel's own stall percentages. `some` is "somebody waited", `full` is "everybody did",
    // which is the difference between a busy machine and a stopped one.
    property real psiCpu: 0
    property real psiMem: 0
    property real psiIo: 0

    function parseCpu(text) {
        const lines = text.split("\n");
        const cur = ({});
        const cores = [];
        for (let i = 0; i < lines.length; i++) {
            const p = lines[i].trim().split(/\s+/);
            if (!p[0] || p[0].indexOf("cpu") !== 0)
                continue;
            const n = p.slice(1).map(Number);
            if (n.length < 5)
                continue;
            let total = 0;
            for (let k = 0; k < n.length; k++)
                total += n[k];
            const idle = (n[3] || 0) + (n[4] || 0);
            const prev = root.cpuPrev[p[0]];
            cur[p[0]] = {
                total: total,
                idle: idle
            };
            let pct = -1;
            if (prev) {
                const dt = total - prev.total;
                if (dt > 0)
                    pct = Math.round((1 - (idle - prev.idle) / dt) * 100);
            }
            if (p[0] === "cpu") {
                if (pct >= 0) {
                    root.cpuPct = pct;
                    root.cpuHist = root.pushed(root.cpuHist, pct);
                }
            } else if (pct >= 0) {
                cores.push(pct);
            }
        }
        root.cpuPrev = cur;
        if (cores.length > 0)
            root.cpuCoreP = cores;
    }
    function parseLoad(loadText, upText) {
        const p = loadText.trim().split(/\s+/);
        if (p.length >= 3)
            root.loadAvg = [Number(p[0]), Number(p[1]), Number(p[2])];
        const u = Number(upText.trim().split(/\s+/)[0]);
        if (u > 0)
            root.uptimeSec = u;
    }
    // avg10 and not avg60: the panel is opened to answer "is it stalling RIGHT NOW".
    function psiValue(text, kind) {
        const lines = (text || "").split("\n");
        for (let i = 0; i < lines.length; i++) {
            if (lines[i].indexOf(kind) !== 0)
                continue;
            const m = lines[i].match(/avg10=([0-9.]+)/);
            if (m)
                return Number(m[1]);
        }
        return 0;
    }
    function parsePsi(sec) {
        root.psiCpu = root.psiValue(sec["/proc/pressure/cpu"], "some");
        root.psiMem = root.psiValue(sec["/proc/pressure/memory"], "full");
        root.psiIo = root.psiValue(sec["/proc/pressure/io"], "full");
    }
    function parseCpuFreq(sec) {
        let sum = 0, n = 0;
        for (const path in sec) {
            if (path.indexOf("/cpufreq/scaling_cur_freq") < 0)
                continue;
            const v = Number((sec[path] || "").trim());
            if (v > 0) {
                sum += v;
                n++;
            }
        }
        if (n > 0) {
            root.cpuMhz = Math.round(sum / n / 1000);
            root.cpuThreads = n;
        }
    }
    // Read ONCE: the model, the core count and the ceiling do not change while the shell runs.
    function parseCpuInfo(text) {
        const parts = text.split("@@@");
        root.cpuModel = (parts[0] || "").trim().replace(/\(R\)|\(TM\)|CPU |Processor /g, "").replace(/\s+/g, " ");
        root.cpuCores = parseInt((parts[1] || "").trim()) || 0;
        root.cpuMhzMax = Math.round((parseInt((parts[2] || "").trim()) || 0) / 1000);
    }
    Process {
        id: cpuInfoProc
        command: ["sh", "-c", "grep -m1 'model name' /proc/cpuinfo | cut -d: -f2; echo @@@; grep '^core id' /proc/cpuinfo | sort -u | wc -l; echo @@@; cat /sys/devices/system/cpu/cpu0/cpufreq/cpuinfo_max_freq 2>/dev/null || echo 0"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: root.parseCpuInfo(text)
        }
    }

    // ===== Memory =====
    property int memPct: 0
    property var memHist: []
    property real memTotal: 0
    property real memAvail: 0
    property real memCached: 0
    property real swapTotal: 0
    property real swapFree: 0
    readonly property real memUsed: Math.max(0, root.memTotal - root.memAvail)
    readonly property real swapUsed: Math.max(0, root.swapTotal - root.swapFree)
    // MemAvailable and not MemFree: the cache is memory you HAVE, and reading MemFree is what makes
    // every "my RAM is full" panic start.
    function parseMem(text) {
        const lines = text.split("\n");
        const kb = ({});
        for (let i = 0; i < lines.length; i++) {
            const m = lines[i].match(/^(\w+):\s+(\d+)/);
            if (m)
                kb[m[1]] = Number(m[2]) * 1024;
        }
        root.memTotal = kb["MemTotal"] || 0;
        root.memAvail = kb["MemAvailable"] || 0;
        root.memCached = (kb["Cached"] || 0) + (kb["SReclaimable"] || 0);
        root.swapTotal = kb["SwapTotal"] || 0;
        root.swapFree = kb["SwapFree"] || 0;
        if (root.memTotal > 0) {
            root.memPct = Math.round(root.memUsed / root.memTotal * 100);
            root.memHist = root.pushed(root.memHist, root.memPct);
        }
    }

    // ===== Disk (the root filesystem plus its device's I/O) =====
    property int diskPct: 0
    property real diskTotal: 0
    property real diskUsed: 0
    property real diskFree: 0
    property string diskFs: ""
    property string diskDev: ""
    property real diskReadBps: 0
    property real diskWriteBps: 0
    property var diskPrev: null
    function parseDf(text) {
        const p = text.trim().split(/\s+/);
        if (p.length < 6)
            return;
        root.diskDev = p[0].replace(/^\/dev\//, "");
        root.diskFs = p[1];
        root.diskTotal = Number(p[2]);
        root.diskUsed = Number(p[3]);
        root.diskFree = Number(p[4]);
        root.diskPct = parseInt(p[5].replace("%", "")) || 0;
    }
    Process {
        id: diskProc
        command: ["sh", "-c", "df -PT -B1 / | awk 'NR==2{print $1, $2, $3, $4, $5, $6}'"]
        stdout: StdioCollector {
            onStreamFinished: root.parseDf(text)
        }
    }
    // A sector is 512 B in /proc/diskstats REGARDLESS of the disk's physical sector size, which is
    // the mistake that turns a correct read into a number 8 times too big.
    function parseDiskIo(text) {
        if (root.diskDev === "")
            return;
        const lines = text.split("\n");
        for (let i = 0; i < lines.length; i++) {
            const p = lines[i].trim().split(/\s+/);
            if (p.length < 10 || p[2] !== root.diskDev)
                continue;
            const rd = Number(p[5]) * 512, wr = Number(p[9]) * 512;
            if (root.diskPrev) {
                const dt = root.sysInterval / 1000;
                root.diskReadBps = Math.max(0, (rd - root.diskPrev.rd) / dt);
                root.diskWriteBps = Math.max(0, (wr - root.diskPrev.wr) / dt);
            }
            root.diskPrev = {
                rd: rd,
                wr: wr
            };
            return;
        }
    }

    // ===== The sensors, read from hwmon directly =====
    // Straight from hwmon and not from `sensors -j`: it brings each sensor's OWN limit, and the xe
    // chip repeats the key "card" in that JSON, so the power cap is lost on parse.
    property var hwTemps: []      // {chip, label, temp, max, crit}
    property real gpuFreq: 0
    property real gpuFreqMax: 0
    property real gpuWatts: 0
    property real gpuWattsCap: 0
    property real gpuFan: -1      // -1 = the card publishes no tachometer
    property real gpuEnergyPrev: 0
    property var tempHist: []

    // The chip's FAMILY, so another board does not need a new branch here (rule 3).
    function chipLabel(chip) {
        const c = (chip || "").toLowerCase();
        if (c.indexOf("coretemp") === 0 || c.indexOf("k10temp") === 0 || c.indexOf("zenpower") === 0)
            return "CPU";
        if (c.indexOf("xe") === 0 || c.indexOf("i915") === 0 || c.indexOf("amdgpu") === 0 || c.indexOf("nouveau") === 0)
            return "GPU";
        if (c.indexOf("nvme") === 0)
            return "NVMe";
        if (c.indexOf("acpitz") === 0 || c.indexOf("nct") === 0 || c.indexOf("it87") === 0)
            return "Board";
        return chip;
    }
    function parseHwmon(sec) {
        const names = ({});
        for (const path in sec) {
            const m = path.match(/^(\/sys\/class\/hwmon\/hwmon\d+)\/name$/);
            if (m)
                names[m[1]] = (sec[path] || "").trim();
        }
        const temps = [];
        let energy = 0, fan = -1, cap = 0;
        for (const path in sec) {
            const m = path.match(/^(\/sys\/class\/hwmon\/hwmon\d+)\/(temp|fan|energy|power)(\d+)_(input|cap)$/);
            if (!m)
                continue;
            const chip = names[m[1]] || "hwmon";
            const val = Number((sec[path] || "").trim());
            if (isNaN(val))
                continue;
            if (m[2] === "temp" && m[4] === "input") {
                const base = m[1] + "/temp" + m[3] + "_";
                temps.push({
                    chip: chip,
                    label: (sec[base + "label"] || "").trim() || ("temp" + m[3]),
                    temp: val / 1000,
                    max: Number((sec[base + "max"] || "0").trim()) / 1000,
                    crit: Number((sec[base + "crit"] || "0").trim()) / 1000
                });
            } else if (root.chipLabel(chip) === "GPU") {
                // The card's counters. energy1/power1 is the whole BOARD, energy2 is the chip alone,
                // and the board is what the PSU actually delivers.
                if (m[2] === "fan" && val >= 0)
                    fan = val;
                else if (m[2] === "energy" && m[3] === "1")
                    energy = val;
                else if (m[2] === "power" && m[4] === "cap")
                    cap = val / 1000000;
            }
        }
        // A temperature of exactly 0 is a sensor that is not wired (the xe pcie one), not a cold one.
        root.hwTemps = temps.filter(t => t.temp > 0);
        root.gpuFan = fan;
        if (cap > 0)
            root.gpuWattsCap = cap;
        if (energy > 0) {
            if (root.gpuEnergyPrev > 0 && energy > root.gpuEnergyPrev)
                root.gpuWatts = (energy - root.gpuEnergyPrev) / 1000000 / (root.sysInterval / 1000);
            root.gpuEnergyPrev = energy;
        }
        if (root.tempMax > 0)
            root.tempHist = root.pushed(root.tempHist, root.tempMax);
    }
    function parseGpuFreq(sec) {
        let act = 0, mx = 0;
        for (const path in sec) {
            const v = Number((sec[path] || "").trim());
            if (isNaN(v))
                continue;
            if (path.indexOf("/freq0/act_freq") >= 0 && v > act)
                act = v;
            else if (path.indexOf("/freq0/max_freq") >= 0 && v > mx)
                mx = v;
        }
        root.gpuFreq = act;
        if (mx > 0)
            root.gpuFreqMax = mx;
    }

    // The PRIMARY sensor of each chip: the package or the composite, falling back to the first the
    // chip publishes. The rest (per core, VRAM, the NVMe's second sensor) is detail for the panel.
    readonly property var tempList: {
        const t = root.hwTemps;
        const byChip = ({});
        const order = [];
        for (let i = 0; i < t.length; i++) {
            const key = t[i].chip;
            const lbl = t[i].label.toLowerCase();
            const primary = lbl.indexOf("package") === 0 || lbl.indexOf("composite") === 0 || lbl === "pkg" || lbl.indexOf("tctl") === 0;
            if (order.indexOf(key) < 0)
                order.push(key);
            if (!byChip[key] || (primary && !byChip[key].primary))
                byChip[key] = {
                    s: t[i],
                    primary: primary
                };
        }
        const out = [];
        for (let i = 0; i < order.length; i++) {
            const s = byChip[order[i]].s;
            out.push({
                name: root.chipLabel(s.chip),
                chip: s.chip,
                label: s.label,
                temp: Math.round(s.temp),
                max: s.max,
                crit: s.crit
            });
        }
        return out;
    }
    readonly property int tempMax: {
        let m = 0;
        for (let i = 0; i < root.tempList.length; i++)
            if (root.tempList[i].temp > m)
                m = root.tempList[i].temp;
        return m;
    }
    // How close the sensor is to ITS OWN ceiling. It is the only honest way to compare a CPU that
    // dies at 100 with a GPU package whose limit is 60, which the old /100 bar did not.
    function tempLimit(t) {
        return t.crit > 0 ? t.crit : (t.max > 0 ? t.max : 100);
    }
    function tempFrac(t) {
        return Math.max(0, Math.min(1, t.temp / root.tempLimit(t)));
    }
    function tempColor(t) {
        const r = root.tempFrac(t);
        return r >= 0.9 ? Theme.colRed : (r >= 0.8 ? Theme.colPeach : (r >= 0.7 ? Theme.colYellow : Theme.colSapphire));
    }
    readonly property var tempQuality: {
        let worst = 0;
        for (let i = 0; i < root.tempList.length; i++)
            worst = Math.max(worst, root.tempFrac(root.tempList[i]));
        if (worst <= 0)
            return {
                label: "no sensors",
                color: Theme.colDim
            };
        if (worst >= 0.9)
            return {
                label: "critical",
                color: Theme.colRed
            };
        if (worst >= 0.8)
            return {
                label: "hot",
                color: Theme.colPeach
            };
        if (worst >= 0.7)
            return {
                label: "warm",
                color: Theme.colYellow
            };
        return {
            label: "cool",
            color: Theme.colGreen
        };
    }

    // The chip's OTHER sensors, condensed into one line. Families are collapsed by stripping the
    // trailing number, so 6 cores and 12 VRAM channels do not become 18 rows.
    function tempDetail(chip, primaryLabel) {
        const fams = ({});
        const order = [];
        const t = root.hwTemps;
        for (let i = 0; i < t.length; i++) {
            if (t[i].chip !== chip || t[i].label === primaryLabel)
                continue;
            const fam = t[i].label.replace(/[\s_]*\d+$/, "") || t[i].label;
            if (!fams[fam]) {
                fams[fam] = {
                    n: 0,
                    min: 999,
                    max: -999
                };
                order.push(fam);
            }
            const f = fams[fam];
            f.n++;
            f.min = Math.min(f.min, t[i].temp);
            f.max = Math.max(f.max, t[i].temp);
        }
        const out = [];
        for (let i = 0; i < order.length; i++) {
            const f = fams[order[i]];
            const lo = Math.round(f.min), hi = Math.round(f.max);
            out.push((f.n > 1 ? f.n + " " + order[i] + " " : order[i] + " ") + (lo === hi ? hi + "°" : lo + "-" + hi + "°"));
        }
        return out.join(" · ");
    }
    // The chips actually publishing a temperature, for the panel's footer: it is where "which
    // driver said that" lives.
    readonly property var tempChips: {
        const seen = [];
        for (let i = 0; i < root.hwTemps.length; i++)
            if (seen.indexOf(root.hwTemps[i].chip) < 0)
                seen.push(root.hwTemps[i].chip);
        return seen;
    }

    // The USAGE verdict, in the ORDER OF THE DAMAGE: what stalls the machine comes before what is
    // merely busy, and PSI is the kernel saying it out loud instead of us inferring it.
    readonly property var usageQuality: {
        if (root.psiMem >= 10 || root.psiIo >= 20)
            return {
                label: "stalling",
                color: Theme.colRed
            };
        if (root.memPct >= 92)
            return {
                label: "memory tight",
                color: Theme.colRed
            };
        const per = root.cpuThreads > 0 ? root.loadAvg[0] / root.cpuThreads : 0;
        if (per >= 1)
            return {
                label: "saturated",
                color: Theme.colRed
            };
        if (per >= 0.7 || root.cpuPct >= 85)
            return {
                label: "loaded",
                color: Theme.colPeach
            };
        if (root.cpuPct >= 40 || root.memPct >= 80)
            return {
                label: "busy",
                color: Theme.colYellow
            };
        return {
            label: "idle",
            color: Theme.colGreen
        };
    }

    // The heaviest processes, polled ONLY while the usage panel is open: `ps -e` walks all of /proc
    // and there is no reason to pay for that with the panel closed.
    property var topCpu: []
    property var topMem: []
    function parseProcs(text) {
        const parts = text.split("@@@");
        const rows = s => (s || "").trim().split("\n").map(l => {
            const p = l.trim().split(/\s+/);
            return {
                cpu: Number(p[0]),
                mem: Number(p[1]),
                name: p.slice(2).join(" ")
            };
        }).filter(r => r.name && r.name !== "ps" && r.name !== "sh").slice(0, 3);
        root.topCpu = rows(parts[0]);
        root.topMem = rows(parts[1]);
    }
    Process {
        id: procsProc
        // `ps` itself always reads as 100%, since its cpu time covers its whole (tiny) life; the
        // filter is in parseProcs, where it does not fight with the shell quoting.
        command: ["sh", "-c", "ps -eo pcpu,pmem,comm --sort=-pcpu --no-headers | head -n 5; echo @@@; ps -eo pcpu,pmem,comm --sort=-pmem --no-headers | head -n 5"]
        stdout: StdioCollector {
            onStreamFinished: root.parseProcs(text)
        }
    }

    // VPN. vpnList is the RAW list (the popover needs a row per VPN); the aggregate paints the pill.
    // ONE read feeds both, because `systemctl is-active` LIES during nxBender's crash loop.
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
    // A Process and not launch(), so we know WHEN it finished and can reread instead of waiting the
    // 5s poll; vpnBusy holds the panel open and the buttons inert meanwhile.
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

    // VPN QUALITY. The pill answered "is there a tunnel?"; this answers "and is it any good?".
    // Two sources, and zero cost with no tunnel. The measurements: docs/notes/desktop/bar.md
    property var vpnStats: ({})   // id -> the object from `vpn stats-json`
    function parseVpnStats(text) {
        try {
            const j = JSON.parse(text);
            const st = ({});
            (j.vpns || []).forEach(v => st[v.id] = v);
            root.vpnStats = st;
        } catch (e) {}
    }

    // One probe per VPN, the same two the CLI knows about (system/net/vpn.nix). The component is
    // widgets/PingProbe.qml, shared with the link probe on the network panel.
    PingProbe {
        id: faiProbe
        readonly property var info: root.vpnStats["fai"] || ({})
        enabled: info.connected === true
        iface: info.iface || ""
        target: info.probe || ""
        session: info.ip || ""
    }
    PingProbe {
        id: ufscarProbe
        readonly property var info: root.vpnStats["ufscar"] || ({})
        enabled: info.connected === true
        iface: info.iface || ""
        target: info.probe || ""
        session: info.ip || ""
    }
    readonly property var vpnProbeStat: ({
            fai: faiProbe.stat,
            ufscar: ufscarProbe.stat
        })
    readonly property var vpnProbeSeries: ({
            fai: faiProbe.series,
            ufscar: ufscarProbe.series
        })

    // The verdict. The ORDER is the order of the damage (loss, then jitter, then the mean), and the
    // cutoffs are anchored to a MEASURED baseline, not guessed: docs/notes/desktop/bar.md
    function vpnQuality(s, pr) {
        if (!s || !s.connected)
            return {
                label: "—",
                color: Theme.colDim
            };
        if (!s.probe)
            return {
                label: "no probe",
                color: Theme.colDim
            };
        if (!pr || pr.n < 5)
            return {
                label: "measuring…",
                color: Theme.colDim
            };
        if (pr.loss >= 20)
            return {
                label: "bad",
                color: Theme.colRed
            };
        if (pr.loss >= 2 || pr.mdev > 10)
            return {
                label: "unstable",
                color: Theme.colPeach
            };
        if (pr.avg > 150)
            return {
                label: "slow",
                color: Theme.colYellow
            };
        return {
            label: "steady",
            color: Theme.colGreen
        };
    }
    // The tunnel's rate now, from the netRates the bar already computes every 2s. An idle interface
    // is absent from that list, and absent means 0 B/s.
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
    // Only the CONNECTED ones enter the panel: a row for a VPN that is off has no statistics,
    // and it is the ACTIONS popover (on click) that lists both to turn them on and off.
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
    // Statistics on HOVER, actions on CLICK, both anchored at the same point: this one hides while
    // the menu is open, or they would draw on top of each other.
    property bool vpnPillHovered: false
    property bool vpnStatsPopHovered: false
    property bool vpnStatsPopVisible: false
    readonly property bool vpnStatsWanted: (root.vpnPillHovered || root.vpnStatsPopHovered) && root.vpnConnected && !root.vpnPopVisible
    onVpnStatsWantedChanged: {
        if (root.vpnStatsWanted) {
            vpnStatsCloseTimer.stop();
            root.vpnStatsPopVisible = true;
            vpnStatsProc.running = true; // a fresh sample when it opens
        } else {
            vpnStatsCloseTimer.restart();
        }
    }
    // The same 300ms of slack as the other hover popovers: you can cross the gap between the
    // pill and the panel without it closing in your face.
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
        // hypridle runs as a systemd --user service (home/desktop/lockscreen.nix).
        command: ["sh", "-c", "systemctl --user is-active --quiet hypridle.service && echo on || echo off"]
        stdout: StdioCollector {
            onStreamFinished: root.parseHypridle(text)
        }
    }

    // Notifications: Quickshell is the daemon (Notifs.qml plus Notifications.qml). The bell reads
    // Notifs.barIcon/dnd and calls the toggles on the singleton.

    // ===== Weather (Open-Meteo; the coords and the pt-BR table are my.weather) =====
    property string wTemp: ""
    property int wCode: -1
    property string wFeels: ""
    property string wHumidity: ""
    property string wWind: ""
    property var wForecast: []
    readonly property bool wHas: root.wTemp !== ""
    readonly property string wText: root.wmoText(root.wCode)

    // The coordinates and the WMO -> pt-BR table come from Nix (my.weather), the SAME source the
    // lock screen's fetch reads, so the two surfaces cannot disagree about the same minute. Same
    // FileView pattern as Theme.qml: a generated JSON is the only path into a hot-reload tree.
    property var wConf: ({})
    FileView {
        id: weatherFile
        path: "/home/v1cferr/.config/theme/weather.json"
        watchChanges: true
        onFileChanged: reload()
        onLoaded: {
            try {
                root.wConf = JSON.parse(weatherFile.text());
            } catch (e) {
                root.wConf = {};
            }
        }
    }
    // The load is ASYNC (measured: the table is still empty at Component.onCompleted), so these
    // fallbacks are what keep the FIRST fetch valid, and what keeps a MISSING JSON harmless, the
    // same choice as Theme.qml's palette: the temperature and the icon still work, and only the
    // pt-BR label degrades to "—". They hold the same numbers as the SSOT, so nothing diverges.
    readonly property string wLat: root.wConf.latitude || "-22.0087"
    readonly property string wLon: root.wConf.longitude || "-47.8909"
    // The pt-BR status. An unknown code says so instead of inventing a condition.
    function wmoText(code) {
        const t = root.wConf.conditions;
        return (t && t[code] !== undefined) ? t[code] : "—";
    }
    // The wind's direction (degrees -> the compass rose, 8 points).
    function windDir(deg) {
        const dirs = ["N", "NE", "E", "SE", "S", "SW", "W", "NW"];
        return dirs[Math.round(deg / 45) % 8];
    }
    // The icon comes from the CODE, never from the label. It used to regex the en-US prose, so
    // translating the label would have turned EVERY icon into the default cloud, in silence.
    function weatherIcon(code, isDay) {
        const c = code;
        if (c === 0 || c === 1)
            return isDay ? "󰖙" : "󰖔";
        if (c === 2)
            return isDay ? "󰖕" : "󰼶";
        if (c === 3)
            return "󰖐";
        if (c === 45 || c === 48)
            return "󰖑";
        if (c === 95 || c === 96 || c === 99)
            return "󰖓";
        if ((c >= 71 && c <= 77) || c === 85 || c === 86)
            return "󰖘";
        if ((c >= 51 && c <= 67) || (c >= 80 && c <= 82))
            return "󰖗";
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
            root.wCode = cur.weather_code;
            root.wFeels = "" + Math.round(cur.apparent_temperature);
            root.wHumidity = "" + cur.relative_humidity_2m;
            root.wWind = Math.round(cur.wind_speed_10m) + " km/h " + root.windDir(cur.wind_direction_10m);
        }
        const dy = data.daily;
        const fc = [];
        // Index 0 is today (it is already in the pill); I show from the next day onward
        // (the next 7 days = up to the same weekday next week).
        if (dy && dy.time) {
            for (let i = 1; i < dy.time.length; i++) {
                const dt = new Date(dy.time[i] + "T00:00:00");
                const pp = dy.precipitation_probability_max[i];
                fc.push({
                    day: root.dowAbbr[dt.getDay()],
                    low: "" + Math.round(dy.temperature_2m_min[i]),
                    high: "" + Math.round(dy.temperature_2m_max[i]),
                    code: dy.weather_code[i],
                    precip: (pp === null || pp === undefined) ? "" : "" + pp
                });
            }
        }
        root.wForecast = fc;
    }
    Process {
        id: weatherProc
        command: ["curl", "-sS", "-m", "10", "https://api.open-meteo.com/v1/forecast?latitude=" + root.wLat + "&longitude=" + root.wLon + "&current=temperature_2m,relative_humidity_2m,apparent_temperature,weather_code,wind_speed_10m,wind_direction_10m&daily=weather_code,temperature_2m_max,temperature_2m_min,precipitation_probability_max&timezone=auto&forecast_days=8"]
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
    // the weather popover's hover
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

    // ===== Audio (Pipewire) =====
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

    // ===== Network =====
    // ONE read for the whole link: what NetworkManager thinks, the default route, the addresses and
    // the sysfs link files. The MAIN interface is the ROUTE's, never a name written in here.
    property bool netConnected: false
    property bool netEthernet: false
    property string netMain: ""
    property string netGw: ""
    property var netDevs: ({})    // iface -> {type, state}
    property var netAddr: ({})    // iface -> "ip/cidr"
    property var netLink: ({})    // iface -> {speed, duplex, mtu, carrier}

    function parseNetInfo(text) {
        const parts = text.split("@@@");
        let conn = false, eth = false;
        const devs = ({});
        (parts[0] || "").split("\n").forEach(l => {
            const p = l.split(":");
            if (p.length < 3 || !p[0])
                return;
            devs[p[0]] = {
                type: p[1],
                state: p[2]
            };
            if ((p[1] === "ethernet" || p[1] === "wifi") && p[2].indexOf("connected") === 0 && p[2].indexOf("externally") < 0) {
                conn = true;
                if (p[1] === "ethernet")
                    eth = true;
            }
        });
        root.netDevs = devs;
        root.netConnected = conn;
        root.netEthernet = eth;

        const rt = (parts[1] || "").match(/default\s+via\s+(\S+)\s+dev\s+(\S+)/);
        root.netGw = rt ? rt[1] : "";
        root.netMain = rt ? rt[2] : "";

        const addr = ({});
        (parts[2] || "").split("\n").forEach(l => {
            const m = l.match(/^\d+:\s+(\S+)\s+inet\s+(\S+)/);
            if (m && !addr[m[1]])
                addr[m[1]] = m[2];
        });
        root.netAddr = addr;

        const link = ({});
        const blocks = (parts[3] || "").split("==> ");
        for (let i = 1; i < blocks.length; i++) {
            const cut = blocks[i].indexOf(" <==\n");
            if (cut < 0)
                continue;
            const m = blocks[i].slice(0, cut).match(/\/sys\/class\/net\/([^/]+)\/(\w+)$/);
            if (!m)
                continue;
            if (!link[m[1]])
                link[m[1]] = ({});
            link[m[1]][m[2]] = blocks[i].slice(cut + 5).trim();
        }
        root.netLink = link;
    }
    Process {
        id: netProc
        command: ["sh", "-c", "nmcli -t -f DEVICE,TYPE,STATE device status; echo @@@; ip route show default; echo @@@; ip -o -4 addr show; echo @@@; head -n 1 -v /sys/class/net/*/speed /sys/class/net/*/duplex /sys/class/net/*/mtu /sys/class/net/*/carrier 2>/dev/null || true"]
        stdout: StdioCollector {
            onStreamFinished: root.parseNetInfo(text)
        }
    }

    // The counters and the rate per interface, from /proc/net/dev inside the system snapshot.
    // Columns 3 and 4 are the RX errors and drops, 11 and 12 the TX ones.
    property var netPrev: ({})
    property var netRates: []
    property var netStats: ({})
    property real netMainRx: 0
    property real netMainTx: 0
    property var netRxHist: []
    property var netTxHist: []
    function parseNetDev(text) {
        const lines = text.split("\n");
        const cur = ({});
        for (let i = 0; i < lines.length; i++) {
            const c = lines[i].indexOf(":");
            if (c < 0)
                continue;
            const iface = lines[i].slice(0, c).trim();
            if (iface === "" || iface === "lo" || iface.indexOf("veth") === 0)
                continue;
            const f = lines[i].slice(c + 1).trim().split(/\s+/).map(Number);
            if (f.length < 12 || isNaN(f[0]))
                continue;
            cur[iface] = {
                rx: f[0],
                tx: f[8],
                rxErr: f[2],
                rxDrop: f[3],
                txErr: f[10],
                txDrop: f[11]
            };
        }
        const dt = root.sysInterval / 1000;
        const rates = [];
        for (const iface in cur) {
            const prev = root.netPrev[iface];
            if (!prev)
                continue;
            const rxr = Math.max(0, (cur[iface].rx - prev.rx) / dt);
            const txr = Math.max(0, (cur[iface].tx - prev.tx) / dt);
            if (iface === root.netMain) {
                root.netMainRx = rxr;
                root.netMainTx = txr;
                root.netRxHist = root.pushed(root.netRxHist, rxr);
                root.netTxHist = root.pushed(root.netTxHist, txr);
            }
            if (rxr > 0 || txr > 0 || iface === root.netMain)
                rates.push({
                    iface: iface,
                    rx: rxr,
                    tx: txr
                });
        }
        root.netPrev = cur;
        root.netStats = cur;
        rates.sort((a, b) => (b.rx + b.tx) - (a.rx + a.tx));
        root.netRates = rates;
    }

    // The link's own probe. It aims at an anycast anchor OUTSIDE the ISP on purpose: "is the cable
    // plugged in" is already answered by the carrier and the gateway, and what is missing is the rest.
    readonly property string netProbeTarget: "1.1.1.1"
    PingProbe {
        id: netProbe
        enabled: root.netMain !== "" && root.netGw !== ""
        iface: root.netMain
        target: root.netProbeTarget
        session: root.netAddr[root.netMain] || ""
    }
    readonly property var netProbeStat: netProbe.stat
    readonly property var netProbeSeries: netProbe.series

    // The link's verdict, the SAME order of the damage as the VPN's: no carrier beats everything,
    // then no gateway, then loss, then jitter, then the mean.
    readonly property var netQuality: {
        const l = root.netLink[root.netMain] || ({});
        if (root.netMain === "" || l.carrier === "0")
            return {
                label: "offline",
                color: Theme.colRed
            };
        if (root.netGw === "")
            return {
                label: "no gateway",
                color: Theme.colPeach
            };
        const pr = root.netProbeStat;
        if (!pr || pr.n < 5)
            return {
                label: "measuring…",
                color: Theme.colDim
            };
        if (pr.loss >= 20)
            return {
                label: "bad",
                color: Theme.colRed
            };
        if (pr.loss >= 2 || pr.mdev > 10)
            return {
                label: "unstable",
                color: Theme.colPeach
            };
        if (pr.avg > 150)
            return {
                label: "slow",
                color: Theme.colYellow
            };
        return {
            label: "steady",
            color: Theme.colGreen
        };
    }
    // The link's speed, as the interface itself reports it. A bridge says 10000 and means nothing,
    // so it is only shown for the interface the route actually uses.
    readonly property string netSpeed: {
        const s = Number((root.netLink[root.netMain] || {}).speed || 0);
        if (!(s > 0))
            return "";
        return s >= 1000 ? (s / 1000) + " Gb/s" : s + " Mb/s";
    }

    function fmtRate(bps) {
        if (bps >= 1048576)
            return (bps / 1048576).toFixed(1) + "M";
        if (bps >= 1024)
            return Math.round(bps / 1024) + "K";
        return Math.round(bps) + "B";
    }

    // Popover positioning (always right below the element). An alias of Theme's, which used to be a
    // 2nd diverging implementation.
    readonly property var screenPrimary: Theme.screenPrimary
    property var popScreen: null
    property real popCenterX: 0   // the anchored element's center, in the bar window's coordinates
    // mapToItem into a REAL Item (barContent) is reliable; only mapToItem(null) is not
    function anchorPopover(pillItem, barContentItem, scr) {
        if (pillItem && barContentItem) {
            const p = pillItem.mapToItem(barContentItem, 0, 0);
            root.popCenterX = p.x + pillItem.width / 2;
        }
        if (scr)
            root.popScreen = scr;
    }
    // margin.left to center the popover under the element (+4 = the bar's margin.left)
    function popLeft(popW) {
        const scr = root.popScreen || root.screenPrimary;
        const sw = scr ? scr.width : 1920;
        return Math.round(Math.max(4, Math.min(root.popCenterX + 4 - popW / 2, sw - popW - 4)));
    }

    // Holidays (nac/sp/sc), rechecked 08/08/2026. THIS LIST DOES NOT UPDATE ITSELF: the movable ones
    // derive from Easter, the fixed ones are LAW by hand: docs/notes/desktop/bar.md
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
        return scope === "nac" ? "National" : (scope === "sp" ? "SP state" : "São Carlos");
    }
    // The calendar's state (recomputed only when the day turns)
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
    // The year rolls over on the first SystemClock beat after midnight (measured across 2026-2027).
    // DO NOT mutate calMap in place: a QML binding only reevaluates on REASSIGNMENT. See the notes.
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
            return "today";
        if (n === 1)
            return "tomorrow";
        return "in " + n + "d";
    }
    // the calendar's hover-keep (the same as the weather one)
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

    // ===== The system panels' hover (temp / usage / net) =====
    // The three share ONE hover state machine and one anchor: only one of them can be open, since
    // the cursor is on a single pill.
    property string metricShown: ""   // "temp" | "usage" | "net"
    property bool metricHovering: false
    property bool metricPopHovered: false
    property bool metricPopVisible: false
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

    // ===== The polling timers =====
    // The system snapshot carries the CPU, the memory, the sensors, the GPU and the interfaces in
    // ONE fork, so what used to be four timers at 2/3/5 s is this one.
    Timer {
        interval: root.sysInterval
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            sysProc.running = true;
            hypridleProc.running = true;
        }
    }
    Timer {
        interval: 5000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: vpnProc.running = true
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
    // The process list costs a walk over all of /proc, so it only runs with the panel OPEN, the
    // same rule as the VPN probe.
    Timer {
        interval: 3000
        running: root.metricPopVisible && root.metricShown === "usage"
        repeat: true
        triggeredOnStart: true
        onTriggered: procsProc.running = true
    }

    // ===== Hyprland: the workspaces (hyprctl plus events) plus the window's title =====
    property var wsActive: ({})
    property var wsExist: ({})
    property var wsWindows: ({})   // the window count per ws (it detects a new window)
    property var wsActivity: ({})  // something opened or went urgent on a background ws (the badge)
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
                // a new window on a ws that is NOT the focused one -> it marks activity
                if (before !== undefined && wc > before && w.id !== focusedWsId)
                    act[w.id] = true;
                // I visited the ws -> it clears the notice
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
    // it marks activity on an urgent ws (the "demands attention" case with no new window, a tab,
    // say)
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
    // the active window's title (Hyprland native) plus the rewrite rules
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

    // ===== The reusable pill =====
    // The pill/chip was extracted into widgets/Pill.qml (import "root:/widgets").

    component Group: Item {
        default property alias content: groupRow.data
        implicitWidth: groupRow.implicitWidth
        implicitHeight: 26
        RowLayout {
            id: groupRow
            anchors.centerIn: parent
            spacing: 4 // the gap between each group's pills/widgets (left/center/right)
        }
    }

    // ===== The workspace button =====
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
        // the badge: something opened or went urgent on that ws while I was on another
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
            border.color: Theme.colBgSolid
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
            // The 0.55 Lua syntax made `dispatch` a shortcut, so the old 3-arg form blows up in the parser
            // and the click died silently. `hl.dsp.workspace` is a TABLE; what switches is focus.
            onClicked: root.launch(["hyprctl", "dispatch", "hl.dsp.focus({ workspace = " + wsbtn.wsid + " })"])
        }
    }

    // ===== The weather popover, the view is in bar/WeatherPopover.qml =====
    WeatherPopover {
        bar: root
    }

    // ===== The usage panel, the view is in bar/UsagePopover.qml =====
    UsagePopover {
        bar: root
    }

    // ===== The temperatures panel, the view is in bar/TempsPopover.qml =====
    TempsPopover {
        bar: root
    }

    // ===== The network panel, the view is in bar/NetPopover.qml =====
    NetPopover {
        bar: root
    }

    // ===== The calendar popover, the view is in bar/CalendarPopover.qml =====
    CalendarPopover {
        bar: root
    }

    // ===== The VPN popover, the view is in bar/VpnPopover.qml =====
    VpnPopover {
        bar: root
    }

    // ===== The VPN statistics popover (hover), the view is in bar/VpnStatsPopover.qml =====
    VpnStatsPopover {
        bar: root
    }

    // ===== One bar per monitor =====
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

            // A full-width Item used as the coordinate reference for the popovers (mapToItem
            // into a real Item is reliable; mapToItem(null) is not).
            Item {
                id: barContent
                anchors.fill: parent

                // LEFT: the launcher plus the workspaces (of that monitor) plus the title plus Spotify
                Group {
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    // A taskbar-style "Start" button, only on the main monitor, which is
                    // where the power popover opens.
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

                // CENTER: the weather plus the clock plus the notifications (always at the screen's center)
                Group {
                    anchors.centerIn: parent
                    Pill {
                        id: weatherPill
                        visible: root.wHas
                        icon: root.weatherIcon(root.wCode, root.isDayNow())
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
                        // the || covers the singleton's init instant on a reload
                        icon: Notifs.barIcon || "󰂜"
                        // the count when there are notifications; an adaptive color:
                        // dim when empty, peach when there are some, red under DND.
                        label: Notifs.count > 0 ? "" + Notifs.count : ""
                        accent: Notifs.dnd ? Theme.colRed : (Notifs.count > 0 ? Theme.colPeach : Theme.colDim)
                        onClicked: Notifs.toggleCenter()
                        onRightClicked: Notifs.toggleDnd()
                    }
                }

                // RIGHT: temp, usage, vpn, network, audio, hypridle, the tray
                Group {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    Pill {
                        id: tempPill
                        icon: "󰔏"
                        label: root.tempMax + "°C"
                        accent: root.tempQuality.color
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
                        // VPN: click opens the actions popover, HOVER shows the statistics, right click drops everything.
                        // Information on hover, ACTION on click; it docs/notes/desktop/bar.md
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
                                vpnProc.running = true; // a fresh state when it opens
                        }
                        onRightClicked: root.runVpn("disconnect", "all")
                    }
                    Pill {
                        id: netPill
                        icon: "󰛳"
                        label: "↓" + root.fmtRate(root.netMainRx) + " ↑" + root.fmtRate(root.netMainTx)
                        accent: root.netQuality.color
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
                    // The system tray (StatusNotifier), one background for the group. Left=activate,
                    // middle=secondaryActivate, scroll, right=the native menu.
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
                                    // Some SNIs (Dropbox) publish image://icon/<name>?path=<dir> in a theme the provider does not
                                    // resolve, so we find the real file in <dir> and point at file://.
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
                                        // path icons: it only shows after resolving to file:// (which avoids the broken load)
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
                                                // A native SNI gets our themed menu. It is a LAYER SURFACE (Hyprland#6682 breaks a PopupWindow's
                                                // input region), docs/notes/desktop/quickshell.md
                                                const pt = trayDel.mapToItem(barContent, 0, trayDel.height);
                                                trayCtxMenu.openAt(modelData.menu, bar, pt.x + bar.margins.left);
                                            } else {
                                                // xembedsniproxy icons have NO DBusMenu, and display() refuses them, so we fire the SNI's own
                                                // ContextMenu() through a helper and the app draws its menu at the cursor.
                                                root.launch(["tray-native-menu", "" + modelData.id]);
                                            }
                                        }
                                        onWheel: w => modelData.scroll(w.angleDelta.y, false)
                                    }
                                }
                            }
                        }
                        // A single shared instance of the context menu: opening it on one icon
                        // switches or closes another's (which avoids stacking several menus).
                        TrayMenu {
                            id: trayCtxMenu
                        }
                    }
                }
            }
        }
    }
}
