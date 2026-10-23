pragma Singleton
// The FAI Claude account's limits, as Claude Code's /usage shows them: the 5 h session and the
// week, with when each resets. glance-feed's `claude_usage` document (the OAuth usage endpoint),
// so this file never touches the network or the token. Why: docs/notes/desktop/glance-feed.md
import Quickshell
import QtQuick
import "root:/"

Singleton {
    id: root

    readonly property var doc: feed.data || ({})
    readonly property bool ok: !!root.doc.ok
    readonly property string error: root.doc.error || feed.error || (feed.data === null ? "loading" : "")
    readonly property string plan: root.doc.plan || ""
    readonly property var session: root.live(root.doc.session)
    readonly property var weekly: root.live(root.doc.weekly)
    readonly property var scoped: root.doc.scoped || []
    readonly property var extra: root.doc.extra || ({})
    readonly property var history: root.doc.history || []
    property real now: Date.now() / 1000

    // A window whose reset already passed is EMPTY until the feed says otherwise: the old number lies.
    function live(w) {
        if (!w)
            return {
                pct: NaN,
                resets: 0,
                severity: "normal"
            };
        return w.resets && w.resets <= root.now ? {
            pct: 0,
            resets: 0,
            severity: "normal"
        } : w;
    }
    function left(t) { // time until t down to the minute, as "3d 06h 49m", "3h 09m" or "9m"
        if (!t)
            return "";
        const m = Math.ceil(Math.max(0, t - root.now) / 60);
        const d = Math.floor(m / 1440), h = Math.floor(m % 1440 / 60), min = m % 60;
        const two = n => (n < 10 ? "0" : "") + n; // padded after the first unit, so the line keeps its width
        if (d > 0)
            return d + "d " + two(h) + "h " + two(min) + "m";
        if (h > 0)
            return h + "h " + two(min) + "m";
        return min + "m";
    }
    // The window's own color while normal (peach unless the caller names one), the ladder past it.
    function color(w, normal) {
        if (w.severity === "critical" || w.pct >= 90)
            return Theme.colRed;
        if (w.severity === "warning" || w.pct >= 75)
            return Theme.colYellow;
        return normal || Theme.colPeach;
    }
    // The history as an evenly spaced series (one point per `step` over the last `span` seconds), each
    // HOLDING the last value: a step chart, so a weekly reset reads as the drop it was. It starts at
    // the first sample: hours before the feed knew anything are not zeros. The feed keeps 7 days.
    function series(key, span, step) {
        const h = root.history;
        const out = [];
        let j = 0, v = NaN;
        for (let t = root.now - (span || 86400); t <= root.now; t += (step || 900)) {
            while (j < h.length && h[j].ts <= t) {
                const x = h[j++][key];
                v = x === null || x === undefined ? NaN : x;
            }
            if (!isNaN(v))
                out.push(v);
        }
        return out;
    }

    // When the history the series can show begins: 7 days ago, or the first sample if that is later.
    readonly property real historyStart: root.history.length ? Math.max(root.now - 7 * 86400, root.history[0].ts) : root.now

    Feed {
        id: feed
        name: "claude_usage"
    }
    // The countdowns move with the clock; the numbers only with the feed.
    Timer {
        interval: 30000
        running: true
        repeat: true
        onTriggered: root.now = Date.now() / 1000
    }
}
