pragma Singleton
// The OPERATIONAL verdict, once: what CI and the services say, read from the feeds the band already
// has (Ci, Services). The standing monitor's chips and their panels both read it, so a chip and its
// panel can never disagree. States and freshness: docs/notes/desktop/bar.md#operational-chips
import Quickshell
import QtQuick
import "root:/"

Singleton {
    id: root

    // One forge: what its LATEST runs say. The feed keeps the newest run of each workflow (or ref), so
    // a failure a later run fixed is already gone, and only a failure that still stands counts.
    function forge(name, src, expected) {
        const base = {
            name: name,
            fail: 0,
            run: 0,
            total: 0,
            failing: [],
            why: ""
        };
        if (!Ci.loaded)
            return Object.assign(base, {
                state: "unknown",
                why: "not read yet"
            });
        if (!src.ok && !src.stale)
            return Object.assign(base, {
                state: expected ? "unknown" : "absent",
                why: src.error || "no answer"
            });
        const runs = src.runs || [];
        const failing = runs.filter(r => r.state === "failure");
        const run = runs.filter(r => r.state === "running" || r.state === "queued").length;
        return Object.assign(base, {
            // Stale keeps the last known count, but never claims it is the present.
            state: src.stale ? "stale" : (failing.length > 0 ? "fail" : (run > 0 ? "run" : "ok")),
            fail: failing.length,
            run: run,
            total: runs.length,
            failing: failing,
            why: src.stale ? "unreachable since " + Ci.agoSec(src.staleSince) + " ago" : ""
        });
    }
    readonly property var gh: root.forge("GitHub", Ci.github, true)
    readonly property var gl: root.forge("FAI GitLab", Ci.gitlab, Ci.gitlabShown)
    readonly property var forges: [root.gh, root.gl].filter(f => f.state !== "absent")

    // CI as one source. A current failure wins; then a forge only known from the past (stale); then
    // one never read (unknown); then work in progress; healthy only when every forge answered clean.
    readonly property var ci: {
        const fs = root.forges;
        const fresh = fs.filter(f => f.state === "fail" || f.state === "run" || f.state === "ok");
        const fail = fresh.reduce((a, f) => a + f.fail, 0);
        const staleFail = fs.filter(f => f.state === "stale").reduce((a, f) => a + f.fail, 0);
        let state = "ok";
        if (fail > 0)
            state = "fail";
        else if (fs.some(f => f.state === "stale"))
            state = "stale";
        else if (fs.length === 0 || fs.some(f => f.state === "unknown"))
            state = "unknown";
        else if (fs.some(f => f.state === "run"))
            state = "run";
        return {
            state: state,
            count: state === "fail" ? fail : (state === "stale" ? staleFail : (state === "run" ? fs.reduce((a, f) => a + f.run, 0) : 0)),
            failing: [].concat(...fs.map(f => f.failing.map(r => Object.assign({
                        forge: f.name
                    }, r))))
        };
    }

    // Services: the meta script answers every 30 s, so two minutes of silence is stale, not healthy.
    readonly property real svcAge: Services.fetched > 0 ? Ci.now.getTime() / 1000 - Services.fetched : Infinity
    readonly property var svc: {
        const list = Services.meta || [];
        const bad = list.filter(s => s.state !== "up");
        const down = bad.filter(s => s.state === "down").length;
        const stale = list.length > 0 && root.svcAge > 120;
        let state = "ok";
        if (list.length === 0)
            state = "unknown";
        else if (stale)
            state = "stale";
        else if (down > 0)
            state = "fail";
        else if (bad.length > 0)
            state = "degraded";
        return {
            state: state,
            count: bad.length,
            total: list.length,
            bad: bad
        };
    }

    // The color of a state, from the catalog in Theme.qml; running is neutral, it is not news.
    function tone(state) {
        if (state === "fail")
            return Theme.colCrit;
        if (state === "degraded")
            return Theme.colAlert;
        if (state === "ok")
            return Theme.colOk;
        if (state === "run")
            return Theme.colSubtext;
        return Theme.colUnknown;
    }
    function icon(state) {
        return ({
                fail: "󰅚",
                degraded: "󰀪",
                stale: "󰥔",
                unknown: "󰋗",
                run: "󰑮",
                ok: "󰄬"
            })[state] || "󰋗";
    }
    function word(state) {
        return ({
                fail: "Failing",
                degraded: "Degraded",
                stale: "Stale",
                unknown: "Unknown",
                run: "Running",
                ok: "Healthy"
            })[state] || "Unknown";
    }
    // Something worth a chip: anything but a clean, current answer.
    function needsLook(s) {
        return s.state !== "ok";
    }
}
