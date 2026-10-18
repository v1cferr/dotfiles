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
    function left(t) { // seconds until t, as "3h 49m" or "3d 6h"
        const s = Math.max(0, t - root.now);
        if (!t)
            return "";
        if (s >= 86400)
            return Math.floor(s / 86400) + "d " + Math.floor(s % 86400 / 3600) + "h";
        if (s >= 3600)
            return Math.floor(s / 3600) + "h " + Math.floor(s % 3600 / 60) + "m";
        return Math.ceil(s / 60) + "m";
    }
    // The window's own color while normal (peach unless the caller names one), the ladder past it.
    function color(w, normal) {
        if (w.severity === "critical" || w.pct >= 90)
            return Theme.colRed;
        if (w.severity === "warning" || w.pct >= 75)
            return Theme.colYellow;
        return normal || Theme.colPeach;
    }
    // The last 24 h as an evenly spaced series (one point per 15 min), each holding the last value.
    // It starts at the first sample: hours before the feed knew anything are not zeros.
    function series(key) {
        const h = root.history;
        const out = [];
        let j = 0, v = NaN;
        for (let t = root.now - 86400; t <= root.now; t += 900) {
            while (j < h.length && h[j].ts <= t) {
                const x = h[j++][key];
                v = x === null || x === undefined ? NaN : x;
            }
            if (!isNaN(v))
                out.push(v);
        }
        return out;
    }

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
