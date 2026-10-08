pragma Singleton
// The CI feed of the glance band, read from glance-feed's cache (modules/home/desktop/glance-feed),
// once whatever the number of screens. The view is CiList.qml; the why: docs/notes/desktop/dash.md
import Quickshell
import QtQuick
import "root:/"

Singleton {
    id: root

    property var github: ({
            ok: false,
            error: "loading",
            runs: []
        })
    property var gitlab: ({
            ok: false,
            error: "loading",
            runs: []
        })
    property bool loaded: false
    // Ticks the "3 min ago" labels; the feed itself is far slower than this.
    property date now: new Date()

    // Off the VPN the FAI page shows its last good picture (stale); it only leaves the rotation when
    // there is none yet, instead of showing an error every 15 s.
    readonly property bool gitlabShown: root.loaded && (root.gitlab.ok || root.gitlab.error !== "unreachable")
    readonly property bool anyRunning: [].concat(root.github.runs || [], root.gitlab.runs || []).some(r => r.state === "running" || r.state === "queued")

    // The document comes from glance-feed's cache (ETags against GitHub and GitLab, every 1 to 2
    // minutes) and is re-read only when a run changed; nothing here touches the network.
    Feed {
        id: ciFeed
        name: "ci"
        onChanged: {
            const j = ciFeed.data || {};
            if (j.github)
                root.github = j.github;
            if (j.gitlab)
                root.gitlab = j.gitlab;
            root.loaded = true;
        }
    }

    // "Stale since" is stored in seconds; the labels speak in the same "3 min" as everything else.
    function agoSec(sec) {
        return sec ? root.ago(new Date(sec * 1000).toISOString()) : "";
    }
    function ago(iso) {
        const s = Math.max(0, (root.now - new Date(iso)) / 1000);
        if (s < 60)
            return "now";
        if (s < 3600)
            return Math.floor(s / 60) + " min";
        if (s < 86400)
            return Math.floor(s / 3600) + " h";
        return Math.floor(s / 86400) + " d";
    }

    // How long a run took, or has been going: "45s", "3m 10s", "1h 5m".
    function dur(startIso, endIso, live) {
        if (!startIso)
            return "";
        const end = live ? root.now : new Date(endIso);
        const s = Math.max(0, Math.round((end - new Date(startIso)) / 1000));
        if (s < 60)
            return s + "s";
        if (s < 3600)
            return Math.floor(s / 60) + "m " + (s % 60) + "s";
        return Math.floor(s / 3600) + "h " + Math.floor((s % 3600) / 60) + "m";
    }

    Timer {
        interval: 30000
        running: true
        repeat: true
        onTriggered: root.now = new Date()
    }
}
