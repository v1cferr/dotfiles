// The desktop's bar, the only one, loaded by shell.qml; the popovers are files next to it.
// The probe, the holidays and the tray traps: docs/notes/desktop/bar.md
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import Quickshell.Wayland
import Quickshell.Services.Pipewire
import Quickshell.Services.Mpris
import QtQuick
import QtQuick.Layouts
import "root:/"
import "root:/widgets"
import "root:/dash"

Scope {
    id: root

    property int barExclusiveZone: 30
    // It hides the bar on demand (IPC), because a normal window never covers a `top` layer and
    // Flameshot's frozen overlay would show a DUPLICATED bar. `visible:false` also frees the clicks.
    property bool hidden: false
    // A screen wide enough for the full bar is up. Without one (the main monitor unplugged), the band
    // screen's bar takes the tray, so it never disappears with the monitor that held it.
    readonly property bool wideUp: Quickshell.screens.some(x => x.width >= Theme.compactWidth)
    readonly property string vpnBin: "vpn" // the CLI on the PATH (modules/nixos/network/vpn.nix)

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

        // Open a panel PINNED, by its coordinator key, so a check needs no mouse: the operational
        // ones on the standing monitor's bar, the rest on the main one, hung from the logo (its
        // content and its glass, not its anchor under the pill). `close` closes whatever is open.
        function panel(key: string): void {
            root.openForTest(key);
        }
        // The calendar focused on a day ("YYYY-MM-DD"): its month, the day selected, its detail.
        function calendar(iso: string): void {
            root.openForTest("cal");
            calPopover.viewYear = +iso.slice(0, 4) === root.calYear ? 0 : +iso.slice(0, 4);
            calPopover.focusOn(+iso.slice(5, 7), iso);
        }
        // Flip one calendar filter (sc, sp, br, un, holiday, optional, observance), or "reset".
        function calendarFilter(key: string): void {
            key === "reset" ? Holidays.resetFilters() : Holidays.toggle(key);
        }
        // The same on a named screen (the calendar's narrow layout on the standing monitor).
        function panelOn(key: string, screen: string): void {
            root.openForTest(key, screen);
        }
        function close(): void {
            root.closePanels();
            root.vpnPopVisible = false;
            root.hideHint();
        }
    }

    // The clock. timeStr keeps the seconds for the band's big clock (dash/Dashboard.qml); the bar
    // shows HH:mm and dd/MM beside the logo, both numeric, so no locale can change them.
    property string dateStr: ""
    property string timeStr: ""
    property string barTimeStr: ""
    property string barDateStr: ""
    SystemClock {
        id: sysClock
        precision: SystemClock.Seconds
    }
    function updateClock() {
        const d = sysClock.date;
        root.dateStr = root.dowAbbr[d.getDay()] + " " + Qt.formatDateTime(d, "dd/MM");
        root.timeStr = Qt.formatDateTime(d, "HH:mm:ss");
        root.barTimeStr = Qt.formatDateTime(d, "HH:mm"); // the same string all minute: no change signal
        root.barDateStr = Qt.formatDate(d, "dd/MM");
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
    readonly property string sysCmd: "head -n 200 -v /proc/stat /proc/loadavg /proc/uptime /proc/meminfo /proc/diskstats /proc/net/dev /proc/pressure/cpu /proc/pressure/memory /proc/pressure/io /sys/class/hwmon/hwmon*/name /sys/class/hwmon/hwmon*/temp*_input /sys/class/hwmon/hwmon*/temp*_label /sys/class/hwmon/hwmon*/temp*_max /sys/class/hwmon/hwmon*/temp*_crit /sys/class/hwmon/hwmon*/fan*_input /sys/class/hwmon/hwmon*/energy*_input /sys/class/hwmon/hwmon*/power*_cap /sys/class/drm/card*/device/tile*/gt*/freq0/act_freq /sys/class/drm/card*/device/tile*/gt*/freq0/max_freq /sys/devices/system/cpu/cpu*/cpufreq/scaling_cur_freq /sys/block/zram*/mm_stat /proc/swaps 2>/dev/null || true"

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
        root.parseSwap(sec);
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

    // ===== Swap, split by tier: zram in RAM first, the NVMe file as the fallback =====
    property real zramOrig: 0 // what the pages weigh uncompressed
    property real zramUsed: 0 // the RAM zram really takes (mm_stat's mem_used_total)
    property real diskSwapUsed: 0
    function parseSwap(sec) {
        let orig = 0, used = 0;
        for (const path in sec) {
            if (!/^\/sys\/block\/zram\d+\/mm_stat$/.test(path))
                continue;
            const f = (sec[path] || "").trim().split(/\s+/).map(Number);
            orig += f[0] || 0;
            used += f[2] || 0;
        }
        root.zramOrig = orig;
        root.zramUsed = used;
        // /proc/swaps is in KiB; anything that is not a zram device is the disk tier.
        let disk = 0;
        const lines = (sec["/proc/swaps"] || "").split("\n");
        for (let i = 1; i < lines.length; i++) {
            const p = lines[i].trim().split(/\s+/);
            if (p.length >= 4 && p[0].indexOf("/dev/zram") !== 0)
                disk += Number(p[3]) * 1024;
        }
        root.diskSwapUsed = disk;
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

    // TOR: a purple badge on the VPN pill plus rows in its popover, never the green: it is a proxy for
    // the apps pointed at it, not a tunnel for the machine. What each signal means: docs/notes/desktop/bar.md
    property bool torSystem: false
    property bool torBisq: false
    function parseTor(text) {
        const lines = text.split("\n");
        root.torSystem = lines.indexOf("system") !== -1;
        root.torBisq = lines.some(l => l.indexOf("/Bisq2/") !== -1);
    }
    // Start/stop asks for the password through the polkit agent: no rule grants it silently.
    property bool torBusy: false
    function runTor(action) {
        root.torBusy = true;
        torActionProc.command = ["systemctl", action, "tor.service"];
        torActionProc.running = true;
    }
    Process {
        id: torActionProc
        onRunningChanged: {
            if (!running) {
                root.torBusy = false;
                torProc.running = true;
            }
        }
    }
    Process {
        id: torProc
        // A user-owned `tor` is an app's own; Bisq's runs from its data dir, the system one as `tor`.
        command: ["sh", "-c", "systemctl is-active --quiet tor.service && echo system; pgrep -u \"$(id -u)\" -a -x tor || true"]
        stdout: StdioCollector {
            onStreamFinished: root.parseTor(text)
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

    // One probe per VPN, the same two the CLI knows about (modules/nixos/network/vpn.nix). The component is
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
    Timer {
        interval: root.panelOpen === "vpn" ? 3000 : 20000
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

    // ===== The HINT on hover, for the pills with no panel (bar/HintPopover.qml) =====
    // A KEY and not the text, so hintFor() stays a binding and the hint follows the state live.
    property string hintKey: ""
    property bool hintVisible: false
    property var hintTray: null
    // A hint waits Theme.tipDelay before it shows, so a sweep across the bar opens nothing; once one is
    // up, a neighbor takes over at once (the grace keeps it up across the gap between two pills).
    property bool hintArmed: false
    property int hintWs: 0 // the workspace a "ws" hint describes
    function hideHint() {
        root.hintArmed = false;
        hintDelay.stop();
        hintGrace.stop();
        root.hintVisible = false;
    }
    function hoverHint(key, item, barContentItem, barWin, on) {
        if (on) {
            if (root.pinned !== "")
                return; // a hint never draws over a pinned panel; a hovered one hands over at once
            panelOpenTimer.stop();
            root.panelShown = "";
            root.anchorPopover(item, barContentItem, barWin);
            root.hintKey = key;
            root.hintArmed = true;
            hintGrace.stop();
            if (!root.hintVisible)
                hintDelay.restart();
        } else if (root.hintKey === key) {
            root.hintArmed = false;
            hintDelay.stop();
            hintGrace.restart();
        }
    }
    Timer {
        id: hintDelay
        interval: Theme.tipDelay
        onTriggered: if (root.hintArmed)
            root.hintVisible = true
    }
    Timer {
        id: hintGrace
        interval: 120
        onTriggered: if (!root.hintArmed)
            root.hintVisible = false
    }
    // Every hint answers three things: what it is (title), how it is now (lines), what a click does
    // (action). Short; a pill with a panel of its own has no hint, its panel is the answer.
    function hintFor(key) {
        if (key === "win")
            return {
                title: root.rawTitle,
                lines: ["The focused window"],
                action: ""
            };
        if (key === "ws")
            return root.wsHint(root.hintWs);
        if (key === "music")
            return {
                title: root.spTitle || "Spotifast",
                lines: [root.spArtist, root.spPlaying ? "Playing" : "Paused"].filter(l => l !== ""),
                action: "Click for the player · right-click to " + (root.spPlaying ? "pause" : "play") + " · scroll to skip"
            };
        if (key === "vol")
            return {
                title: "Volume",
                lines: [(root.sinkMuted ? "Muted" : Math.round(root.volume * 100) + "%") + (root.sink ? " · " + (root.sink.description || root.sink.name || "") : "")],
                action: (root.sinkMuted ? "Click to unmute" : "Click to mute") + " · scroll ±5% · right-click for the mixer"
            };
        if (key === "idle")
            return {
                title: "Idle timeouts",
                lines: [root.hypridleOn ? "Enabled: the screens lock and sleep on idle" : "Disabled: nothing happens on idle"],
                action: root.hypridleOn ? "Click to disable" : "Click to enable"
            };
        if (key === "lol")
            return {
                title: "League (Darling)",
                lines: [({ off: "Not running", starting: "Starting Darling", client: "Client open", hidden: "Running, no window", game: "In a match" })[root.lolState]],
                action: ({ off: "Click to start", starting: "The client window is on its way", client: "Click for the client · right-click to shut Darling down", hidden: "Click to reopen (restarts Darling) · right-click to shut it down", game: "Stopping waits for the match to end" })[root.lolState]
            };
        if (key === "away")
            return {
                title: "Away screen",
                lines: ["Screens and LEDs dark, the PC keeps working"],
                action: "Click to go away · Enter comes back"
            };
        if (key === "disk")
            return {
                title: "Disk " + root.diskPct + "% used",
                lines: [root.fmtBytes(root.diskFree) + " free of " + root.fmtBytes(root.diskTotal) + (root.diskDev ? " · " + root.diskDev : "")],
                action: "Click for the CPU and memory panel"
            };
        if (key === "tray" && root.hintTray) {
            const t = root.hintTray;
            const desc = (t.tooltipDescription || "").replace(/<[^>]*>/g, "").trim();
            return {
                title: t.tooltipTitle || t.title || t.id || "",
                lines: [desc].filter(l => l !== ""),
                action: "Click to open · right-click for its menu"
            };
        }
        return null;
    }
    // A workspace: its number, how many windows, and which (Hyprland's own toplevels, read on hover).
    function wsHint(id) {
        const wins = (Hyprland.toplevels ? Hyprland.toplevels.values : []).filter(t => t.workspace && t.workspace.id === id);
        const names = wins.map(t => {
            const o = t.lastIpcObject || {};
            return o.class || t.title || "";
        }).filter(n => n !== "");
        const n = root.wsWindows[id] || wins.length;
        const lines = [n === 0 ? "Empty" : n + (n === 1 ? " window" : " windows")].concat(names.slice(0, 5));
        if (names.length > 5)
            lines.push("+" + (names.length - 5) + " more");
        if (root.wsUrgent[id])
            lines.push("A window asks for attention");
        else if (root.wsActivity[id])
            lines.push("A window opened here");
        const active = Object.keys(root.wsActive).some(m => root.wsActive[m] === id);
        return {
            title: "Workspace " + root.wsLabel(id),
            lines: lines,
            action: active ? "" : "Click to switch"
        };
    }
    function wsLabel(id) {
        return (id < 10 ? "0" : "") + id;
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
        // hypridle runs as a systemd --user service (modules/home/desktop/lockscreen/default.nix).
        command: ["sh", "-c", "systemctl --user is-active --quiet hypridle.service && echo on || echo off"]
        stdout: StdioCollector {
            onStreamFinished: root.parseHypridle(text)
        }
    }

    // ===== League through Darling (darling-lol.service, docs/notes/apps/darling-lol.md) =====
    // off, starting (no window yet, 90 s), client, hidden (the client closed its window: only a restart
    // reopens it) or game.
    property string lolState: "off"
    Process {
        id: lolProc
        command: ["sh", "-c", "systemctl --user is-active --quiet darling-lol.service || { echo off; exit; }; pgrep -f '[M]acOS/LeagueofLegends ' >/dev/null && { echo game; exit; }; hyprctl clients | grep -qE 'class: (LeagueClientUx|Riot Client)$' && { echo client; exit; }; up=$(date -d \"$(systemctl --user show -P ActiveEnterTimestamp darling-lol.service)\" +%s); [ $(($(date +%s) - up)) -lt 90 ] && echo starting || echo hidden"]
        stdout: StdioCollector {
            onStreamFinished: root.lolState = text.trim() || "off"
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
    // For the glance band: the whole week keyed by ISO date (today included, for the month grid and
    // the weather page), and the next 24 hours (temperature, rain chance, sky, day or night).
    property var wDaily: ({})
    property var wHourly: []
    readonly property bool wHas: root.wTemp !== ""
    readonly property string wText: root.wmoText(root.wCode)

    // The coordinates and the WMO -> pt-BR table come from Nix (my.weather), the SAME source the
    // lock screen's fetch reads, so the two surfaces cannot disagree about the same minute. Same
    // FileView pattern as Theme.qml: a generated JSON is the only path into a hot-reload tree.
    property var wConf: ({})
    FileView {
        id: weatherFile
        path: Quickshell.env("HOME") + "/.config/theme/weather.json"
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
    // What was actually fetched ("open-meteo:ecmwf_ifs" -> "ecmwf_ifs"), from the cache's own record.
    readonly property string wModel: ((weatherFeed.source || "").split(":")[1] || "ecmwf_ifs")
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
        // The table is my.weather.icons (weather.nix), shared with the lock screen; the code below is
        // only the fallback for a missing or older weather.json (rule 11).
        const t = root.wConf.icons;
        if (t && t[code])
            return isDay ? t[code].day : t[code].night;
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
    // The forecast is glance-feed's (modules/home/desktop/glance-feed): ONE fetch per model run, shared
    // with the lock screen, painted from the cache at once after a boot. "Now" is derived from the
    // run's own hours and re-derived every 5 minutes, so nothing here touches the network.
    Feed {
        id: weatherFeed
        name: "weather"
        onChanged: root.parseWeather()
    }
    Timer {
        interval: 300000
        running: true
        repeat: true
        onTriggered: root.parseWeather()
    }
    function parseWeather() {
        const data = weatherFeed.data;
        const hr = data ? data.hourly : null;
        if (!hr || !hr.time || !hr.time.length)
            return;
        // The current hour in the forecast's own local clock ("2026-10-08T09:00").
        const now = new Date();
        const pad = n => ("0" + n).slice(-2);
        const key = now.getFullYear() + "-" + pad(now.getMonth() + 1) + "-" + pad(now.getDate()) + "T" + pad(now.getHours()) + ":00";
        let i = hr.time.indexOf(key);
        if (i < 0)
            i = Math.max(0, hr.time.filter(t => t <= key).length - 1);
        // Between two hourly samples, by the minutes past the hour.
        const f = now.getMinutes() / 60;
        const at = a => a ? (a[i + 1] === undefined || a[i + 1] === null ? a[i] : a[i] + (a[i + 1] - a[i]) * f) : NaN;
        root.wTemp = "" + Math.round(at(hr.temperature_2m));
        root.wCode = hr.weather_code[i];
        root.wFeels = "" + Math.round(at(hr.apparent_temperature));
        root.wHumidity = "" + Math.round(at(hr.relative_humidity_2m));
        root.wWind = Math.round(at(hr.wind_speed_10m)) + " km/h " + root.windDir(hr.wind_direction_10m ? hr.wind_direction_10m[i] : 0);

        const dy = data.daily;
        const today = key.slice(0, 10);
        const fc = [];
        const byDate = ({});
        if (dy && dy.time) {
            for (let d = 0; d < dy.time.length; d++) {
                byDate[dy.time[d]] = {
                    low: Math.round(dy.temperature_2m_min[d]),
                    high: Math.round(dy.temperature_2m_max[d]),
                    code: dy.weather_code[d],
                    precip: dy.precipitation_probability_max[d],
                    sunrise: dy.sunrise ? dy.sunrise[d] : "",
                    sunset: dy.sunset ? dy.sunset[d] : ""
                };
                // The pill's popover lists the days AFTER today (today is already in the pill).
                if (dy.time[d] <= today)
                    continue;
                const dt = new Date(dy.time[d] + "T00:00:00");
                const pp = dy.precipitation_probability_max[d];
                fc.push({
                    day: root.dowAbbr[dt.getDay()],
                    low: "" + Math.round(dy.temperature_2m_min[d]),
                    high: "" + Math.round(dy.temperature_2m_max[d]),
                    code: dy.weather_code[d],
                    precip: (pp === null || pp === undefined) ? "" : "" + pp
                });
            }
        }
        root.wForecast = fc;
        root.wDaily = byDate;

        // The next 25 hours from the current one, as the weather page draws them.
        const hours = [];
        for (let h = i; h < Math.min(hr.time.length, i + 25); h++)
            hours.push({
                time: hr.time[h],
                hour: Number(hr.time[h].slice(11, 13)),
                temp: hr.temperature_2m[h],
                precip: hr.precipitation_probability[h],
                code: hr.weather_code[h],
                day: hr.is_day ? hr.is_day[h] === 1 : true
            });
        root.wHourly = hours;
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

    // ===== Spotifast (Mpris) =====
    readonly property var player: {
        const m = Mpris.players;
        const list = (m && m.values) ? m.values : [];
        for (let i = 0; i < list.length; i++) {
            const p = list[i];
            if (p && (p.identity === "Spotifast" || (p.dbusName || "").toLowerCase().indexOf("spotifast") >= 0))
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

    // A live number padded to a fixed count of columns: the font is mono, so the pill keeps its width
    // and its neighbors stop shifting every 2 s as the digits come and go.
    function tab(v, n) {
        return ("" + v).padStart(n, " ");
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
    property var popBar: null // the bar window the open panel hangs from (part of its focus grab)
    property real popCenterX: 0   // the anchored element's center, in the bar window's coordinates
    // mapToItem into a REAL Item (barContent) is reliable; only mapToItem(null) is not
    function anchorPopover(pillItem, barContentItem, barWin) {
        if (pillItem && barContentItem) {
            const p = pillItem.mapToItem(barContentItem, 0, 0);
            root.popCenterX = p.x + pillItem.width / 2;
        }
        if (barWin) {
            root.popBar = barWin;
            root.popScreen = barWin.screen;
        }
    }
    // margin.left to center the popover under the element, clamped inside the screen by sp1
    function popLeft(popW) {
        const scr = root.popScreen || root.screenPrimary;
        const sw = scr ? scr.width : 1920;
        return Math.round(Math.max(Theme.barTop, Math.min(root.popCenterX + Theme.barTop - popW / 2, sw - popW - Theme.barTop)));
    }

    // ===== Contextual expansion: ONE coordinator for every panel the bar opens =====
    // Hover rests `Theme.hoverIntent` before a panel opens (a sweep opens nothing) and a neighbor
    // takes over at once; a click PINS it until a second click, a click outside or Escape. One
    // panel at a time, so two can never draw over each other. The rules: docs/notes/desktop/bar.md
    property string panelHover: "" // the pill under the pointer
    property bool panelPopHovered: false // the pointer is on the open panel
    property string panelShown: "" // opened by hover
    property string pinned: "" // opened by a click
    readonly property string panelOpen: root.pinned !== "" ? root.pinned : root.panelShown
    function hoverPanel(key, item, barContentItem, barWin, on) {
        if (!on) {
            if (root.panelHover === key) {
                root.panelHover = "";
                panelOpenTimer.stop();
                panelCloseTimer.restart();
            }
            return;
        }
        // A pinned panel owns the bar, and the VPN's stats yield to its own actions menu.
        if (root.pinned !== "" || (key === "vpn" && root.vpnPopVisible))
            return;
        root.panelHover = key;
        panelCloseTimer.stop();
        root.anchorPopover(item, barContentItem, barWin);
        if (root.panelShown !== "")
            root.panelShown = key;
        else
            panelOpenTimer.restart();
    }
    function togglePanel(key, item, barContentItem, barWin) {
        root.hideHint();
        root.vpnPopVisible = false;
        panelOpenTimer.stop();
        // The same pill again closes; the same panel from ANOTHER monitor's bar moves it there.
        if (root.pinned === key && root.popBar === barWin) {
            root.closePanels();
            return;
        }
        root.anchorPopover(item, barContentItem, barWin);
        root.panelShown = "";
        root.pinned = key;
        root.hideMedia();
    }
    // The media panel lives in shell.qml, outside this coordinator: a pin closes it over its IPC
    // (a no-op when it is already closed), so the one-panel rule holds for it too.
    function hideMedia() {
        root.launch(["qs", "ipc", "call", "mpris", "hide"]);
    }
    function closePanels() {
        root.pinned = "";
        root.panelShown = "";
        root.panelHover = "";
    }

    // The bar windows, by screen name: the IPC toggle opens the Center on the main monitor's bar, and
    // a screen that leaves takes its open panel with it (no window left holding the keyboard).
    property var bars: ({})
    function registerBar(b) {
        if (!b.screen)
            return;
        const m = Object.assign({}, root.bars);
        m[b.screen.name] = b;
        root.bars = m;
    }
    function unregisterBar(b) {
        if (root.popBar === b)
            root.closePanels();
        const m = Object.assign({}, root.bars);
        for (const k in m)
            if (m[k] === b)
                delete m[k];
        root.bars = m;
    }
    // The NixOS Center from IPC (`qs ipc call notif toggle`): hung from the main monitor's logo.
    Connections {
        target: Notifs
        function onCenterToggleRequested() {
            const scr = Theme.screenPrimary;
            const b = scr ? root.bars[scr.name] : null;
            if (root.pinned === "center" || !b) {
                root.closePanels();
                return;
            }
            root.hideHint();
            root.vpnPopVisible = false;
            root.popBar = b;
            root.popScreen = scr;
            root.popCenterX = Math.floor(b.width / 2);
            root.pinned = "center";
            root.hideMedia();
        }
    }
    Binding {
        target: Notifs
        property: "centerOpen"
        value: root.pinned === "center"
    }
    function openForTest(key, screenName) {
        const name = screenName || (key.startsWith("ops") ? Theme.secondaryMonitor : "");
        const scr = name ? Quickshell.screens.find(x => x.name === name) : Theme.screenPrimary;
        const b = scr ? root.bars[scr.name] : null;
        if (!b)
            return;
        root.hideHint();
        root.vpnPopVisible = false;
        root.popBar = b;
        root.popScreen = scr;
        root.popCenterX = Math.floor(b.width / 2);
        root.panelShown = "";
        root.pinned = key;
        root.hideMedia();
    }
    // A click on an operational alert in the standing monitor's bar: the band shows its detail.
    signal dashRequested(string what)
    onPanelPopHoveredChanged: root.panelPopHovered ? panelCloseTimer.stop() : panelCloseTimer.restart()
    onPanelOpenChanged: {
        if (root.panelOpen !== "")
            root.hideHint();
        if (root.panelOpen === "vpn")
            vpnStatsProc.running = true; // a fresh sample when it opens
    }
    Timer {
        id: panelOpenTimer
        interval: Theme.hoverIntent
        onTriggered: if (root.panelHover !== "" && root.pinned === "")
            root.panelShown = root.panelHover
    }
    // 300 ms of slack: the pointer can cross the gap between the pill and the panel.
    Timer {
        id: panelCloseTimer
        interval: 300
        onTriggered: if (root.panelHover === "" && !root.panelPopHovered)
            root.panelShown = ""
    }

    readonly property var monthNames: ["Janeiro", "Fevereiro", "Março", "Abril", "Maio", "Junho", "Julho", "Agosto", "Setembro", "Outubro", "Novembro", "Dezembro"]
    readonly property var weekHeads: ["D", "S", "T", "Q", "Q", "S", "S"]
    readonly property var dowAbbr: ["dom", "seg", "ter", "qua", "qui", "sex", "sáb"]
    readonly property var dowNames: ["domingo", "segunda-feira", "terça-feira", "quarta-feira", "quinta-feira", "sexta-feira", "sábado"]
    readonly property var monAbbr: ["jan", "fev", "mar", "abr", "mai", "jun", "jul", "ago", "set", "out", "nov", "dez"]
    // The holidays come from the verified registry (Holidays.qml, docs/notes/desktop/calendar.md);
    // a scope's color is the one signal the bar, the calendar and the band share.
    function scopeColor(scope) {
        return scope === "br" ? Theme.colRed : (scope === "sp" ? Theme.colBlue : (scope === "sc" ? Theme.colMauve : Theme.colTeal));
    }
    // The calendar's state (recomputed only when the day turns)
    property int calYear: 0
    property int calTodayM: 0
    property int calTodayD: 0
    property int calTodayW: 0 // today's weekday, 0 = Sunday, for the spelled-out name
    // Today's year under the DEFAULT filters (the band's month card); the calendar panel keeps its
    // own year and filters. A binding: it follows the day turning and a rebuilt registry.
    readonly property var calMap: Holidays.mapFor(root.calYear, Holidays.defaults)
    property string calDayKey: ""
    // The year rolls over on the first SystemClock beat after midnight (measured across 2026-2027).
    function refreshCalendar() {
        const d = sysClock.date;
        root.calYear = d.getFullYear();
        root.calTodayM = d.getMonth() + 1;
        root.calTodayD = d.getDate();
        root.calTodayW = d.getDay();
    }
    // ISO-8601 week number: the week's THURSDAY decides the year it counts against, which is what
    // makes 01/01 land on week 53 of the year before when it falls on a Friday.
    function isoWeek(y, m, d) {
        const dt = new Date(Date.UTC(y, m - 1, d));
        const dow = dt.getUTCDay() || 7;
        dt.setUTCDate(dt.getUTCDate() + 4 - dow);
        const jan1 = new Date(Date.UTC(dt.getUTCFullYear(), 0, 1));
        return Math.ceil(((dt - jan1) / 86400000 + 1) / 7);
    }
    function monthCells(m) {
        const cells = [];
        for (let i = 0; i < 7; i++)
            cells.push({
                head: root.weekHeads[i]
            });
        const first = new Date(root.calYear, m - 1, 1).getDay();
        for (let i = 0; i < first; i++)
            cells.push({
                d: 0
            });
        const dim = new Date(root.calYear, m, 0).getDate();
        for (let d = 1; d <= dim; d++) {
            const o = Holidays.primary(root.calMap[("0" + m).slice(-2) + "-" + ("0" + d).slice(-2)]);
            cells.push({
                d: d,
                // The band's shape: a name, the scope's color, and `fac` for an outline instead of a fill.
                holiday: o ? {
                    name: o.display,
                    scope: Holidays.scopeOf(o),
                    // An outline for an optional day AND for a holiday that is not everyone's.
                    fac: Holidays.classOf(o) !== "holiday" || o.applicability.indexOf("general") < 0
                } : null,
                today: (m === root.calTodayM && d === root.calTodayD)
            });
        }
        return cells;
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
        onTriggered: {
            vpnProc.running = true;
            torProc.running = true;
            lolProc.running = true;
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
    // The process list costs a walk over all of /proc, so it only runs with the panel OPEN, the
    // same rule as the VPN probe.
    Timer {
        interval: 3000
        running: root.panelOpen === "usage"
        repeat: true
        triggeredOnStart: true
        onTriggered: procsProc.running = true
    }

    // ===== Hyprland: the workspaces (hyprctl plus events) plus the window's title =====
    property var wsActive: ({})
    property var wsExist: ({})
    property var wsWindows: ({})   // the window count per ws (it detects a new window)
    property var wsActivity: ({})  // a window opened on a background ws (the yellow mark)
    property var wsUrgent: ({})    // a window on a background ws asked for attention (the orange mark)
    property string focusedMon: ""
    // The workspaces THIS bar shows: its monitor's own, plus the ORPHANS of a disconnected
    // secondary, which Hyprland gathers onto the primary and which had no button at all.
    function wsModelFor(monName) {
        if (monName === Theme.secondaryMonitor)
            return [5, 6, 7, 8];
        if (Theme.secondaryConnected)
            return [1, 2, 3, 4];
        return [1, 2, 3, 4].concat([5, 6, 7, 8].filter(id => root.wsExist[id] === true));
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
            if (root.wsUrgent[focusedWsId]) {
                const urg = Object.assign({}, root.wsUrgent);
                urg[focusedWsId] = false;
                root.wsUrgent = urg;
            }
        } catch (e) {}
    }
    Process {
        id: hyprProc
        command: ["sh", "-c", "hyprctl -j monitors; echo '@@@'; hyprctl -j workspaces"]
        stdout: StdioCollector {
            onStreamFinished: root.parseHypr(text)
        }
    }
    // An urgent ws (a window that asked for attention, a tab, say) is its OWN mark, apart from a
    // window that merely opened: one is news, the other a request.
    function markUrgentActivity() {
        const wl = Hyprland.workspaces ? Hyprland.workspaces.values : [];
        const focusedWsId = root.wsActive[root.focusedMon];
        const act = Object.assign({}, root.wsUrgent);
        let changed = false;
        for (let i = 0; i < wl.length; i++)
            if (wl[i].urgent === true && wl[i].id !== focusedWsId) {
                act[wl[i].id] = true;
                changed = true;
            }
        if (changed)
            root.wsUrgent = act;
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
        if ((m = t.match(/^(.*) - Spotifast$/)))
            return "󰝚 " + m[1];
        if ((m = t.match(/^(.*) - (Code|Visual Studio Code)$/)))
            return "󰨞 " + m[1];
        return t;
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
        id: calPopover
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

    // ===== The NixOS Center (the logo's panel): notifications, do-not-disturb and the session =====
    // The standing monitor's operational chips open these on hover (bar/OpsIndicator.qml).
    OpsPanel {
        bar: root
        key: "ops-ci"
    }
    OpsPanel {
        bar: root
        key: "ops-svc"
    }
    OpsPanel {
        bar: root
        key: "ops"
    }
    NixosCenter {
        bar: root
    }

    // ===== The hover hint, the view is in bar/HintPopover.qml =====
    HintPopover {
        bar: root
    }

    // ===== One bar per monitor =====
    // The GLANCE band, on the screens too narrow for the full bar. Same model as the bar below, so
    // it follows the hotplug; the component is in dash/Dashboard.qml.
    Variants {
        model: Quickshell.screens

        Dashboard {
            host: root
            visible: !root.hidden && modelData && modelData.width < Theme.compactWidth
        }
    }

    Variants {
        model: Quickshell.screens

        PanelWindow {
            id: bar
            required property var modelData
            screen: modelData
            WlrLayershell.namespace: "qs-bar" // the glass blur rule matches it (appearance.lua)

            // ONE continuous Powerline, edge to edge: no margin, no gap, the same surface end to end.
            anchors {
                top: true
                left: true
                right: true
            }
            implicitHeight: Theme.barHeight
            visible: !root.hidden
            // On a band screen the BAR reserves the whole top share and the band draws inside it,
            // so the order the two layers map in can never stack the bar under the band.
            exclusiveZone: bar.compact && bar.screen ? Theme.bandReserve(bar.screen.height) : Theme.barHeight

            // COMPACT: a screen too narrow for the full set (the standing LG) keeps the workspaces and
            // its context on the left and the operational alerts on the right; the band has the rest.
            readonly property bool compact: bar.width < Theme.compactWidth
            color: "transparent"

            // ── The geometry: every region from the screen's width and fixed tokens, never from content ──
            // The logo's compartment sits on the screen's EXACT center: its x comes from the width alone.
            readonly property int centerX: Math.floor(bar.width / 2)
            readonly property int slotX: bar.centerX - Theme.barCenterWidth / 2
            // The full bar puts the time left of the compartment and the date right of it, in two MIRRORED
            // slots of one width measured from a template ("00:00" and "00/00" are both five mono
            // columns), so the pair is symmetric about the logo and a new minute or day moves nothing.
            readonly property int clockW: Math.ceil(tmClock.advanceWidth) + 2 * Theme.sp2
            readonly property int dateW: bar.clockW
            readonly property int clockX: bar.slotX - Theme.barSlant - Theme.sp1 - bar.clockW
            readonly property int dateX: bar.slotX + Theme.barCenterWidth + Theme.barSlant + Theme.sp1
            // The center group's outer edges, its dividers included; the compact bar's is the compartment.
            readonly property int centerLeft: bar.compact ? bar.slotX - Theme.barSlant : bar.clockX - Theme.sp1 - Theme.barSlant
            readonly property int centerRight: bar.compact ? bar.slotX + Theme.barCenterWidth + Theme.barSlant : bar.dateX + bar.dateW + Theme.sp1 + Theme.barSlant
            // What each side may fill: its edge margin and a gap before the center group.
            readonly property int leftRoom: bar.centerLeft - 2 * Theme.sp2
            readonly property int rightRoom: bar.width - bar.centerRight - 2 * Theme.sp2

            // ── LEFT: workspaces, title, media. Shares from the room alone, never from the texts ──
            // In order: media from 220 down to 120, media to its icon, then the title (a floor of 120,
            // under which it hides). A song or a focus change can never flip a level.
            readonly property int chevW: Theme.barSlant + 2 * Theme.sp2
            readonly property int titleMin: 240
            readonly property bool mediaHere: !bar.compact && root.spHasPlayer
            readonly property int leftAvail: bar.leftRoom - leftRow.wsWidth - bar.chevW - (bar.mediaHere ? bar.chevW : 0)
            readonly property int mediaIconW: Math.ceil(tmMediaIcon.advanceWidth) + 2 * Theme.sp2
            readonly property int mediaW: !bar.mediaHere ? 0 : Math.max(bar.mediaIconW, Math.min(220, bar.leftAvail - bar.titleMin))
            readonly property bool mediaIconOnly: bar.mediaHere && bar.mediaW < 120
            readonly property int mediaUsed: !bar.mediaHere ? 0 : (bar.mediaIconOnly ? bar.mediaIconW : bar.mediaW)
            readonly property int titleMax: Math.min(520, bar.leftAvail - bar.mediaUsed)

            // ── RIGHT: the system and its tray. The tray is pinned to the edge; the rest folds by priority
            // when it would cross the center: the network's numbers and the VPN's name, then the weather.
            readonly property bool trayHere: !bar.compact || !root.wideUp
            readonly property int trayW: bar.trayHere && tray.count > 0 ? tray.stableWidth + Theme.sp1 : 0
            readonly property int squeeze: rightRow.measure(0) <= bar.rightRoom ? 0 : (rightRow.measure(1) <= bar.rightRoom ? 1 : 2)

            Component.onCompleted: root.registerBar(bar)
            Component.onDestruction: root.unregisterBar(bar)

            // A full-width Item used as the coordinate reference for the popovers (mapToItem
            // into a real Item is reliable; mapToItem(null) is not).
            Item {
                id: barContent
                anchors.fill: parent

                // ── The surface: one glass strip, a hairline at its foot ──
                Rectangle {
                    anchors.fill: parent
                    gradient: Gradient {
                        GradientStop {
                            position: 0
                            color: Theme.colSurfaceBar
                        }
                        GradientStop {
                            position: 1
                            color: Theme.colSurfaceBarFoot
                        }
                    }
                }
                Rectangle {
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.bottom: parent.bottom
                    height: Theme.hairline
                    color: Theme.colEdge
                }

                // ── The center: the official logo in its compartment, the NixOS Center on a click ──
                LogoSlot {
                    id: logoSlot
                    x: bar.slotX
                    host: root
                    barContent: barContent
                    barWindow: bar
                }
                // Templates for the fixed widths: a mono face, so every minute and every date is this wide.
                TextMetrics {
                    id: tmClock
                    font.family: Theme.uiFont
                    font.pixelSize: Theme.fontBody
                    font.bold: true
                    text: "00:00"
                }
                // The time, the logo, the date: placed from the compartment's edges, never centered as a
                // group, so the logo stays on the screen's center whatever the strings hold.
                Chevron {
                    visible: !bar.compact
                    rising: false
                    x: bar.clockX - Theme.sp1 - Theme.barSlant
                }
                Pill {
                    id: clockPill
                    visible: !bar.compact
                    x: bar.clockX
                    anchors.verticalCenter: parent.verticalCenter
                    width: bar.clockW
                    label: root.barTimeStr
                    labelColor: Theme.colText
                    bold: true
                    selected: root.pinned === "cal"
                    // Both open the ONE calendar, hung from the logo, so it never jumps between them.
                    onHoveredChanged: root.hoverPanel("cal", logoSlot, barContent, bar, hovered)
                    onClicked: root.togglePanel("cal", logoSlot, barContent, bar)
                }
                Pill {
                    id: datePill
                    visible: !bar.compact
                    x: bar.dateX
                    anchors.verticalCenter: parent.verticalCenter
                    width: bar.dateW
                    label: root.barDateStr
                    labelColor: Theme.colText
                    bold: true
                    selected: root.pinned === "cal"
                    onHoveredChanged: root.hoverPanel("cal", logoSlot, barContent, bar, hovered)
                    onClicked: root.togglePanel("cal", logoSlot, barContent, bar)
                }
                Chevron {
                    visible: !bar.compact
                    x: bar.dateX + bar.dateW + Theme.sp1
                }

                // ── LEFT: this monitor's workspaces, the focused window's title, then the media ──
                TextMetrics {
                    id: tmTitle
                    font.family: Theme.uiFont
                    font.pixelSize: Theme.fontBody
                    font.italic: true
                    text: root.winTitle
                }
                TextMetrics {
                    id: tmMediaIcon
                    font.family: Theme.uiFont
                    font.pixelSize: Theme.iconBar
                    text: "󰝚"
                }
                RowLayout {
                    id: leftRow
                    readonly property int wsWidth: wsStrip.implicitWidth
                    anchors.left: parent.left
                    anchors.leftMargin: Theme.sp2
                    height: parent.height
                    spacing: Theme.sp2
                    WorkspaceStrip {
                        id: wsStrip
                        host: root
                        monitor: bar.modelData ? bar.modelData.name : ""
                        barContent: barContent
                        barWindow: bar
                    }
                    Chevron {
                        rising: false
                        visible: winPill.visible || spPill.visible
                    }
                    Pill {
                        id: winPill
                        visible: bar.modelData && bar.modelData.name === root.focusedMon && root.winTitle !== "" && bar.titleMax >= 120
                        label: root.winTitle
                        accent: Theme.colSky
                        italic: true
                        leftAligned: true
                        maxWidth: bar.titleMax
                        // In 64 px steps from the text's own metrics, so a focus change rarely moves the media.
                        Layout.preferredWidth: Math.min(bar.titleMax, Math.max(120, Math.ceil((tmTitle.advanceWidth + 2 * Theme.sp2 + 1) / 64) * 64))
                        onHoveredChanged: root.hoverHint("win", winPill, barContent, bar, hovered)
                    }
                    Chevron {
                        rising: false
                        visible: spPill.visible && winPill.visible
                    }
                    Pill {
                        id: spPill
                        visible: bar.mediaHere
                        icon: "󰝚"
                        label: bar.mediaIconOnly ? "" : root.spText
                        accent: root.spColor
                        maxWidth: bar.mediaUsed
                        onHoveredChanged: root.hoverHint("music", spPill, barContent, bar, hovered)
                        onClicked: {
                            root.closePanels();
                            root.hideHint();
                            root.anchorPopover(spPill, barContent, bar);
                            root.launch(["qs", "ipc", "call", "mpris", "toggleAt", "" + root.popLeft(360)]);
                        }
                        onRightClicked: root.launch(["playerctl", "--player=spotifast", "play-pause"])
                        onScrolledUp: root.launch(["playerctl", "--player=spotifast", "next"])
                        onScrolledDown: root.launch(["playerctl", "--player=spotifast", "previous"])
                    }
                }

                // ── RIGHT EDGE: the tray, pinned there and growing left (also the band screen's, alone) ──
                TrayStrip {
                    id: tray
                    visible: bar.trayHere
                    anchors.right: parent.right
                    anchors.rightMargin: Theme.sp2
                    anchors.verticalCenter: parent.verticalCenter
                    host: root
                    barContent: barContent
                    barWindow: bar
                }

                // ── RIGHT, compact screen: the operational alerts, nothing the band already shows ──
                OpsIndicator {
                    visible: bar.compact
                    anchors.right: parent.right
                    anchors.rightMargin: Theme.sp2 + bar.trayW
                    anchors.verticalCenter: parent.verticalCenter
                    host: root
                    barContent: barContent
                    barWindow: bar
                    maxWidth: bar.rightRoom - bar.trayW
                }

                // ── RIGHT, full: weather, CPU, network, VPN, sound, the session; the tray after it ──
                // Colors follow the states catalog (Theme.qml): neutral unless a condition is verifiable.
                RowLayout {
                    id: rightRow
                    visible: !bar.compact
                    anchors.right: parent.right
                    anchors.rightMargin: Theme.sp2 + bar.trayW
                    height: parent.height
                    spacing: Theme.sp1
                    // The row's width at a squeeze level, the tray included, from the controls' own implicit
                    // widths, which do not depend on what is visible: so the level never feeds back into itself.
                    TextMetrics {
                        id: tmNet
                        font.family: Theme.uiFont
                        font.pixelSize: Theme.fontBody
                        text: "↓" + root.tab(root.fmtRate(root.netMainRx), 5) + " ↑" + root.tab(root.fmtRate(root.netMainTx), 5)
                    }
                    TextMetrics {
                        id: tmVpn
                        font.family: Theme.uiFont
                        font.pixelSize: Theme.fontBody
                        text: root.vpnConnected ? root.vpnName : ""
                    }
                    function measure(level) {
                        const sep = Theme.barSlant + 2 * Theme.sp1;
                        let w = usagePill.implicitWidth + volPill.implicitWidth + idlePill.implicitWidth + awayPill.implicitWidth + 3 * sep + 5 * Theme.sp1;
                        if (diskPill.visible)
                            w += diskPill.implicitWidth + Theme.sp1;
                        w += lolPill.implicitWidth + Theme.sp1;
                        // VPN and network change their own labels with the level, so they are measured in full
                        // from text metrics, never from the pills: that is what keeps this free of a loop.
                        w += 2 * (Theme.barControl + Theme.sp1) + (level >= 1 ? 0 : tmNet.advanceWidth + tmVpn.advanceWidth + 2 * Theme.sp1);
                        if (level < 2)
                            w += weatherPill.implicitWidth + sep;
                        w += bar.trayW + (bar.trayW > 0 ? sep : 0);
                        return w;
                    }
                    Pill {
                        visible: bar.squeeze < 2
                        id: weatherPill
                        icon: root.wHas ? root.weatherIcon(root.wCode, root.isDayNow()) : "󰖐"
                        label: root.wHas ? root.wTemp + "°C" : "--°C"
                        accent: root.wHas ? Theme.colSubtext : Theme.colUnknown
                        labelColor: root.wHas ? Theme.colText : Theme.colUnknown
                        selected: root.pinned === "weather"
                        onHoveredChanged: if (root.wHas)
                            root.hoverPanel("weather", weatherPill, barContent, bar, hovered)
                        onClicked: if (root.wHas)
                            root.togglePanel("weather", weatherPill, barContent, bar)
                        // The forecast site moved here when the click became the panel's pin.
                        onRightClicked: root.launch(["xdg-open", "https://www.msn.com/en-us/weather/forecast/in-S%C3%A3o-Carlos,S%C3%A3o-Paulo"])
                    }
                    Chevron {
                        visible: weatherPill.visible
                    }
                    Pill {
                        // CPU use. A busy CPU is not a fault: it turns to attention only when pegged.
                        id: usagePill
                        icon: "󰓅"
                        label: root.tab(root.cpuPct, 3) + "%"
                        accent: root.cpuPct >= 90 ? Theme.colWarn : Theme.colSubtext
                        labelColor: Theme.colText
                        selected: root.pinned === "usage"
                        onHoveredChanged: root.hoverPanel("usage", usagePill, barContent, bar, hovered)
                        onClicked: root.togglePanel("usage", usagePill, barContent, bar)
                    }
                    Pill {
                        // Storage, ONLY when it needs a look: the root filesystem past 90% or under 20 GB
                        // free (attention), past 95% or under 5 GB (critical). df every 30 s is the source.
                        id: diskPill
                        readonly property bool crit: root.diskTotal > 0 && (root.diskPct >= 95 || root.diskFree < 5 * 1073741824)
                        visible: root.diskTotal > 0 && (diskPill.crit || root.diskPct >= 90 || root.diskFree < 20 * 1073741824)
                        icon: "󰋊"
                        label: root.diskPct + "%"
                        accent: diskPill.crit ? Theme.colCrit : Theme.colWarn
                        labelColor: diskPill.accent
                        onHoveredChanged: root.hoverHint("disk", diskPill, barContent, bar, hovered)
                        onClicked: root.togglePanel("usage", diskPill, barContent, bar)
                    }
                    Chevron {}
                    Pill {
                        id: netPill
                        icon: "󰛳"
                        label: bar.squeeze >= 1 ? "" : "↓" + root.tab(root.fmtRate(root.netMainRx), 5) + " ↑" + root.tab(root.fmtRate(root.netMainTx), 5)
                        accent: root.netQuality.color
                        labelColor: Theme.colText
                        selected: root.pinned === "net"
                        onHoveredChanged: root.hoverPanel("net", netPill, barContent, bar, hovered)
                        onClicked: root.togglePanel("net", netPill, barContent, bar)
                        onRightClicked: root.launch(["nm-connection-editor"]) // was the left click before the pin
                    }
                    Pill {
                        // VPN: click opens the actions popover, HOVER shows the statistics, right click drops everything.
                        // Off by choice is neutral, never a failure. Information on hover, ACTION on click: docs/notes/desktop/bar.md
                        id: vpnPill
                        icon: "󰦝"
                        label: root.vpnConnected && bar.squeeze < 1 ? root.vpnName : ""
                        accent: root.vpnConnected ? Theme.colOk : Theme.colUnknown
                        labelColor: Theme.colText
                        // Tor rides along in its own purple: a VPN and Tor can be up at once.
                        badge: (root.torSystem || root.torBisq) ? "" + (root.torBisq ? " Bisq" : "") : ""
                        badgeColor: Theme.colLavender
                        maxWidth: 190
                        selected: root.vpnPopVisible
                        onHoveredChanged: root.hoverPanel("vpn", vpnPill, barContent, bar, hovered)
                        onClicked: {
                            const open = !root.vpnPopVisible;
                            root.closePanels(); // its actions menu is the one panel now
                            root.anchorPopover(vpnPill, barContent, bar);
                            root.vpnPopVisible = open;
                            if (root.vpnPopVisible) {
                                vpnProc.running = true; // a fresh state when it opens
                                torProc.running = true;
                            }
                        }
                        onRightClicked: root.runVpn("disconnect", "all")
                    }
                    Chevron {}
                    Pill {
                        id: volPill
                        icon: root.volIcon()
                        label: root.tab(Math.round(root.volume * 100), 3) + "%"
                        accent: root.sinkMuted ? Theme.colUnknown : Theme.colSubtext
                        labelColor: root.sinkMuted ? Theme.colUnknown : Theme.colText
                        onHoveredChanged: root.hoverHint("vol", volPill, barContent, bar, hovered)
                        onClicked: root.toggleMute()
                        onRightClicked: root.launch(["pavucontrol"])
                        onScrolledUp: root.setVol(0.05)
                        onScrolledDown: root.setVol(-0.05)
                    }
                    Chevron {}
                    Pill {
                        // darling-lol: the launcher, always there. A stop or restart mid-match is refused here.
                        id: lolPill
                        icon: "󰊴"
                        accent: root.lolState === "game" ? Theme.colText : (root.lolState === "off" ? Theme.colUnknown : Theme.colSubtext)
                        onHoveredChanged: root.hoverHint("lol", lolPill, barContent, bar, hovered)
                        onClicked: {
                            if (root.lolState === "off")
                                root.launch(["systemctl", "--user", "start", "darling-lol.service"]);
                            else if (root.lolState === "hidden")
                                root.launch(["systemctl", "--user", "restart", "darling-lol.service"]);
                            else if (root.lolState === "client")
                                root.launch(["hyprctl", "dispatch", "focuswindow", "class:^(LeagueClientUx|Riot Client)$"]);
                        }
                        onRightClicked: {
                            if (root.lolState === "client" || root.lolState === "hidden")
                                root.launch(["systemctl", "--user", "stop", "darling-lol.service"]);
                        }
                    }
                    Pill {
                        // hypridle: on is the normal state; off by choice is neutral, dimmed.
                        id: idlePill
                        icon: root.hypridleIcon
                        accent: root.hypridleOn ? Theme.colSubtext : Theme.colUnknown
                        onHoveredChanged: root.hoverHint("idle", idlePill, barContent, bar, hovered)
                        onClicked: root.launch(["sh", "-c", "systemctl --user is-active --quiet hypridle.service && systemctl --user stop hypridle.service || systemctl --user start hypridle.service"])
                    }
                    Pill {
                        // The away screen (Away.qml): it covers the bar too, so this only ever turns it on.
                        id: awayPill
                        icon: "󰽥"
                        accent: Theme.colSubtext
                        onHoveredChanged: root.hoverHint("away", awayPill, barContent, bar, hovered)
                        onClicked: {
                            root.hideHint();
                            Away.enter();
                        }
                    }
                    Chevron {
                        visible: bar.trayW > 0
                    }
                }
            }
        }
    }
}
