// power-log's CSV into the energy document the band and the lock read. Pure functions, no
// Quickshell imports, so qmltestrunner can test them. docs/notes/desktop/dash.md
import QtQml

QtObject {
    readonly property int staleAfter: 180 // power-log writes every minute: three missed samples is stale

    function num(v) {
        if (v === undefined || v === null || v === "")
            return null;
        const n = Number(v);
        return isNaN(n) ? null : n;
    }

    // Rows of the CSV text (headers may repeat where two monthly files meet), oldest first.
    function rows(text) {
        const out = [];
        let head = null;
        for (const line of (text || "").split("\n")) {
            if (!line)
                continue;
            const f = line.split(",");
            if (f[0] === "time") {
                head = f;
                continue;
            }
            if (!head)
                continue;
            const t = Date.parse(f[0]) / 1000;
            if (isNaN(t))
                continue;
            const r = { _t: t };
            for (let i = 0; i < head.length; i++)
                r[head[i]] = f[i];
            out.push(r);
        }
        return out.sort((a, b) => a._t - b._t);
    }

    function median(v) {
        const s = v.slice().sort((a, b) => a - b);
        const m = Math.floor(s.length / 2);
        return s.length % 2 ? s[m] : (s[m - 1] + s[m]) / 2;
    }

    // The last 30 min of MEASURED CPU package + GPU board watts, one slot a minute (a hole is null,
    // never a zero), and the Eco-idle baseline over 7 days: power-saver, CPU < 10% busy, GPU render
    // idle > 70%, so a Moonlight stream (also Eco) never counts as rest.
    function energy(text, now, windowS) {
        const win = windowS || 1800;
        const all = rows(text).filter(r => r._t >= now - 7 * 86400 && r._t <= now + 60);
        const doc = { status: "missing", history: [], baseline: null };
        if (all.length) {
            const last = all[all.length - 1];
            const age = now - last._t;
            doc.status = age <= staleAfter ? "ok" : "stale";
            doc.timestamp = Math.round(last._t);
            doc.age = Math.round(age);
            doc.measured_w = num(last.measured_w);
            doc.cpu_w = num(last.cpu_package_w);
            doc.gpu_w = num(last.gpu_board_w);
            doc.profile = last.profile || null;
            doc.render_idle_pct = num(last.gpu_render_idle_pct);
            doc.cpu_busy_pct = num(last.cpu_busy_pct);
        }
        const slots = Math.floor(win / 60);
        const hist = new Array(slots).fill(null);
        for (const r of all) {
            const i = Math.floor((r._t - (now - win)) / 60);
            if (i >= 0 && i < slots)
                hist[i] = num(r.measured_w);
        }
        doc.history = hist;
        const idle = [];
        for (const r of all) {
            const w = num(r.measured_w);
            const busy = num(r.cpu_busy_pct);
            const rest = num(r.gpu_render_idle_pct);
            if (r.profile === "power-saver" && (busy === null ? 100 : busy) < 10 && (rest === null ? 0 : rest) > 70 && w !== null)
                idle.push(w);
        }
        if (idle.length >= 30)
            doc.baseline = { median_w: Math.round(median(idle) * 10) / 10, samples: idle.length, condition: "power-saver, CPU < 10% busy, GPU render idle > 70%, last 7 days" };
        return doc;
    }
}
