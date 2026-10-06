pragma Singleton
// The CI feed of the glance band: ci-status-json (ci-status.sh, packaged in quickshell.nix) polled
// ONCE, whatever the number of screens. The view is CiList.qml; the why: docs/notes/desktop/dash.md
import Quickshell
import Quickshell.Io
import QtQuick

Singleton {
    id: root

    readonly property string bin: "ci-status-json"

    property var github: ({
            ok: false,
            error: "loading",
            runs: []
        })
    property var gitlab: ({
            ok: false,
            error: "loading",
            runs: [],
            runners: null
        })
    property bool loaded: false
    // Ticks the "3 min ago" labels; the feed itself is far slower than this.
    property date now: new Date()

    // Off the VPN the FAI page leaves the rotation instead of showing an error every 15 s.
    readonly property bool gitlabShown: root.loaded && root.gitlab.error !== "unreachable"
    readonly property bool anyRunning: [].concat(root.github.runs || [], root.gitlab.runs || []).some(r => r.state === "running" || r.state === "queued")

    function parse(text) {
        try {
            const j = JSON.parse(text);
            root.github = j.github;
            root.gitlab = j.gitlab;
            root.loaded = true;
        } catch (e) {
            // A broken run keeps the last good picture: stale beats blank on a glance surface.
        }
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

    Process {
        id: proc
        command: [root.bin, "7"]
        stdout: StdioCollector {
            onStreamFinished: root.parse(text)
        }
    }
    // A minute while something runs, three otherwise: ~15 API calls a poll stays far from the limit.
    Timer {
        interval: root.anyRunning ? 60000 : 180000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: proc.running = true
    }
    Timer {
        interval: 30000
        running: true
        repeat: true
        onTriggered: root.now = new Date()
    }
}
