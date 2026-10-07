pragma Singleton
// The services feed of the band. Two speeds: dash-services-meta (dash/services.nix) every 30 s for
// state, uptime and cgroups; then every 3 s ONE read of those cgroups' counters for CPU, RAM, disk
// and tasks, deltas computed here. No daemon is asked anything per tick: docs/notes/desktop/dash.md
import Quickshell
import Quickshell.Io
import QtQuick

Singleton {
    id: root

    readonly property string bin: "dash-services-meta"
    readonly property int tick: 3000
    readonly property int histLen: 40 // 40 samples at 3 s = the last 2 minutes, per service

    property var meta: []      // the meta script's services, as last resolved
    property var stats: ({})   // key -> {cpu, mem, rd, wr, tasks, hist}
    property var prev: ({})    // cgroup -> {cpu, rd, wr, t}: the last counters, for the deltas
    property int cpus: 1
    property real now: Date.now() // the uptime labels' clock, advanced on every read
    property real fetched: 0
    property bool ranked: false // the first rank waits for the first real numbers

    // The ORDER is "most consuming first", by RAM (the default) or by CPU averaged over its 2 minutes.
    // At idle every service sits near 0.00% CPU and the instant reading is noise, so RAM is the
    // steady measure; and the order is re-ranked every 30 s, not every 3 s, so the cards do not jump
    // pages while being read. Trouble (down, degraded) always comes first: docs/notes/desktop/dash.md
    property string sortBy: "ram"
    property var order: []
    function avg(h) {
        return h && h.length ? h.reduce((a, b) => a + b, 0) / h.length : 0;
    }
    function rerank() {
        const rank = {
            down: 0,
            degraded: 1,
            up: 2
        };
        const st = root.stats;
        const weight = s => {
            const x = st[s.key];
            return !x ? 0 : (root.sortBy === "cpu" ? root.avg(x.hist) : x.mem);
        };
        root.order = root.meta.slice().sort((a, b) => (rank[a.state] - rank[b.state]) || (weight(b) - weight(a))).map(s => s.key);
    }
    onSortByChanged: root.rerank()
    onMetaChanged: root.rerank()
    Timer {
        interval: 30000
        running: true
        repeat: true
        onTriggered: root.rerank()
    }
    readonly property var list: {
        const byKey = ({});
        for (const s of root.meta)
            byKey[s.key] = s;
        const keys = root.order.filter(k => byKey[k]).concat(root.meta.map(s => s.key).filter(k => root.order.indexOf(k) < 0));
        return keys.map(k => Object.assign({}, byKey[k], root.stats[k] || {
                cpu: 0,
                mem: 0,
                rd: 0,
                wr: 0,
                tasks: 0,
                hist: []
            }));
    }
    readonly property int upCount: root.meta.filter(s => s.state === "up").length

    function cgroupFiles() {
        const files = [];
        for (const s of root.meta)
            for (const p of s.parts || [])
                if (p.cgroup)
                    for (const f of ["memory.current", "cpu.stat", "io.stat", "pids.current"])
                        files.push("/sys/fs/cgroup" + p.cgroup + "/" + f);
        return files;
    }

    function parseCounters(text) {
        // `head -v` prints "==> path <==" before each file; a vanished cgroup just has no section.
        const sec = ({});
        let cur = null;
        for (const line of text.split("\n")) {
            const m = line.match(/^==> (.*) <==$/);
            if (m) {
                cur = m[1];
                sec[cur] = "";
            } else if (cur !== null)
                sec[cur] += line + "\n";
        }
        const now = Date.now();
        const nextPrev = ({});
        const stats = ({});
        for (const s of root.meta) {
            let cpu = 0, mem = 0, rd = 0, wr = 0, tasks = 0;
            for (const p of s.parts || []) {
                if (!p.cgroup)
                    continue;
                const base = "/sys/fs/cgroup" + p.cgroup + "/";
                mem += Number((sec[base + "memory.current"] || "0").trim()) || 0;
                tasks += Number((sec[base + "pids.current"] || "0").trim()) || 0;
                const um = (sec[base + "cpu.stat"] || "").match(/usage_usec (\d+)/);
                const usec = um ? Number(um[1]) : 0;
                let r = 0, w = 0;
                for (const io of (sec[base + "io.stat"] || "").split("\n")) {
                    const rm = io.match(/rbytes=(\d+)/), wm = io.match(/wbytes=(\d+)/);
                    r += rm ? Number(rm[1]) : 0;
                    w += wm ? Number(wm[1]) : 0;
                }
                const last = root.prev[p.cgroup];
                if (last && now > last.t) {
                    const dt = (now - last.t) / 1000;
                    // CPU as a share of the WHOLE machine, like the CPU tile, not of one core.
                    cpu += Math.max(0, (usec - last.cpu) / 1e6 / dt / root.cpus * 100);
                    rd += Math.max(0, (r - last.rd) / dt);
                    wr += Math.max(0, (w - last.wr) / dt);
                }
                nextPrev[p.cgroup] = {
                    cpu: usec,
                    rd: r,
                    wr: w,
                    t: now
                };
            }
            const old = root.stats[s.key];
            const hist = (old ? old.hist : []).concat([cpu]).slice(-root.histLen);
            stats[s.key] = {
                cpu: cpu,
                mem: mem,
                rd: rd,
                wr: wr,
                tasks: tasks,
                hist: hist
            };
        }
        root.prev = nextPrev;
        root.stats = stats;
        if (!root.ranked) {
            root.ranked = true;
            root.rerank();
        }
        root.now = now;
    }

    // ── Click: the site when it has one, the live log otherwise ──
    function open(s) {
        if (s.url) {
            Qt.openUrlExternally(s.url);
            return;
        }
        if (s.logs && s.logs.compose)
            Quickshell.execDetached(["kitty", "--title", "logs: " + s.label, "docker", "compose", "-p", s.logs.compose, "logs", "-f", "--tail", "200"]);
        else if (s.logs && s.logs.unit)
            Quickshell.execDetached(["kitty", "--title", "logs: " + s.label, "journalctl", s.logs.user ? "--user-unit" : "-u", s.logs.unit, "-f", "-n", "200"]);
    }

    Process {
        id: nproc
        command: ["nproc"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: root.cpus = Math.max(1, Number(text.trim()) || 1)
        }
    }
    Process {
        id: metaProc
        command: [root.bin]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const j = JSON.parse(text);
                    root.meta = j.services || [];
                    root.fetched = j.fetched || 0;
                } catch (e) {
                    // Keep the last picture: a broken run must not empty the strip.
                }
            }
        }
    }
    Timer {
        interval: 30000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: metaProc.running = true
    }
    Process {
        id: counters
        command: ["sh", "-c", "head -v -n 40 " + root.cgroupFiles().map(f => "'" + f + "'").join(" ") + " 2>/dev/null; true"]
        stdout: StdioCollector {
            onStreamFinished: root.parseCounters(text)
        }
    }
    Timer {
        interval: root.tick
        running: root.meta.length > 0
        repeat: true
        triggeredOnStart: true
        onTriggered: counters.running = true
    }
}
