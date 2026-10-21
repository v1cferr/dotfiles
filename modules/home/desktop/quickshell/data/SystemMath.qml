// /proc and /sys text into CPU, memory, GPU and per-app numbers. Pure functions, no Quickshell
// imports, so qmltestrunner can test them. docs/notes/desktop/dash.md
import QtQml

QtObject {
    readonly property int hz: 100 // USER_HZ, fixed at 100 on Linux for every architecture we run
    readonly property int page: 4096

    // /proc/stat's first line: [total ticks, idle ticks] (idle + iowait), or null.
    function cpuTicks(stat) {
        const f = (stat || "").split("\n", 1)[0].trim().split(/\s+/);
        if (f[0] !== "cpu")
            return null;
        const v = f.slice(1).map(Number);
        let total = 0;
        for (let i = 0; i < Math.min(8, v.length); i++)
            total += v[i];
        return [total, v[3] + (v.length > 4 ? v[4] : 0)];
    }
    function cpuPct(prev, cur) {
        if (!prev || !cur || cur[0] <= prev[0])
            return NaN;
        const tot = cur[0] - prev[0];
        return Math.round(1000 * (tot - (cur[1] - prev[1])) / tot) / 10;
    }

    // Memory from MemAvailable: page cache is NOT used memory. Bytes.
    function mem(meminfo) {
        const m = {};
        for (const line of (meminfo || "").split("\n")) {
            const i = line.indexOf(":");
            if (i > 0)
                m[line.slice(0, i)] = Number(line.slice(i + 1).trim().split(/\s+/)[0]) * 1024;
        }
        if (!(m.MemTotal > 0) || isNaN(m.MemAvailable))
            return null;
        return { total: m.MemTotal, available: m.MemAvailable, used: m.MemTotal - m.MemAvailable };
    }

    // The GPU's render idle between two rc6 residency readings (ms), as a % of the interval.
    function renderIdle(rc0, rc1, dtS) {
        if (isNaN(rc0) || isNaN(rc1) || !(dtS > 0))
            return NaN;
        return Math.round(10 * Math.min(100, Math.max(0, 100 * (rc1 - rc0) / 1000 / dtS))) / 10;
    }

    // An APPLICATION name from the systemd unit in the cgroup (children grouped with their app), else
    // the process name. Never a command line: no arguments, paths or documents ever leave /proc.
    function groupOf(cgroup, comm) {
        const w = /^\.(.+?)-w(?:r(?:a(?:p(?:p(?:e(?:d)?)?)?)?)?)?$/.exec(comm);
        const name = w ? w[1] : comm;
        const u = /(?:^|\/)([^\/]+\.(?:service|scope))$/.exec((cgroup || "").trim());
        if (!u)
            return name;
        const unit = u[1];
        if (unit.startsWith("session-") || unit.startsWith("user@"))
            return name;
        const a = /^app-(?:Hyprland-|flatpak-|gnome-|kde-)?(.+?)(?:-[0-9a-f]{6,}|-\d+|@[^.]*)?\.(?:scope|service)$/.exec(unit);
        return (a ? a[1] : unit.replace(/\.[^.]+$/, "")).replace(/\\x2d/g, "-").replace(/\\x20/g, " ");
    }

    // `cat /proc/[0-9]*/stat`, a "---" line, then `grep -H '' /proc/[0-9]*/cgroup`: one sample,
    // keyed by "pid:starttime" so a reused PID never inherits another's ticks.
    function procs(text) {
        const parts = (text || "").split("\n---\n");
        const cg = {};
        for (const line of (parts[1] || "").split("\n")) {
            const m = /^\/proc\/(\d+)\/cgroup:0::(.*)$/.exec(line);
            if (m)
                cg[m[1]] = m[2];
        }
        const out = {};
        for (const line of (parts[0] || "").split("\n")) {
            const open = line.indexOf(" (");
            const close = line.lastIndexOf(")");
            if (open < 0 || close < open)
                continue;
            const pid = line.slice(0, open);
            const rest = line.slice(close + 2).split(" ");
            const ppid = rest[1];
            if (ppid === "2" || pid === "2")
                continue; // kernel threads: no app to name, no memory to rank
            const ticks = Number(rest[11]) + Number(rest[12]);
            const rss = Number(rest[21]) * page;
            if (isNaN(ticks) || isNaN(rss))
                continue;
            out[pid + ":" + rest[19]] = { name: groupOf(cg[pid] || "", line.slice(open + 2, close)), ticks: ticks, rss: rss };
        }
        return out;
    }

    // The heaviest apps now: CPU as % of ONE core from the tick delta, memory as summed RSS.
    function rank(prev, cur, dtS, top) {
        const cpu = {}, memBy = {};
        for (const k in cur) {
            const p = cur[k];
            memBy[p.name] = (memBy[p.name] || 0) + p.rss;
            const o = prev ? prev[k] : null;
            if (o && dtS > 0)
                cpu[p.name] = (cpu[p.name] || 0) + Math.max(0, p.ticks - o.ticks) / hz / dtS * 100;
        }
        const best = d => Object.keys(d).map(k => ({ name: k, value: d[k] })).sort((a, b) => b.value - a.value).slice(0, top);
        return {
            cpu: best(cpu).filter(e => e.value >= 0.1).map(e => ({ name: e.name, value: Math.round(e.value * 10) / 10 })),
            mem: best(memBy)
        };
    }
}
