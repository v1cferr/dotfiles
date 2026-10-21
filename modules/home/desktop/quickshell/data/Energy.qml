pragma Singleton
// The measured CPU + GPU watts from power-log, once a minute (power-log writes once a minute), for
// the band and the lock. The math is EnergyMath.qml; this only reads. docs/notes/desktop/dash.md
import Quickshell
import Quickshell.Io
import QtQuick

Singleton {
    id: root

    property var doc: ({})
    readonly property bool ok: root.doc.status === "ok" || root.doc.status === "stale"
    readonly property bool stale: root.doc.status === "stale"
    readonly property real measured: root.num(root.doc.measured_w)
    readonly property real cpu: root.num(root.doc.cpu_w)
    readonly property real gpu: root.num(root.doc.gpu_w)
    readonly property string profile: ({
            "power-saver": "Eco",
            balanced: "Balanced",
            performance: "Gaming"
        })[root.doc.profile] || (root.doc.profile || "")
    readonly property real renderIdle: root.num(root.doc.render_idle_pct)
    readonly property real cpuBusy: root.num(root.doc.cpu_busy_pct)
    readonly property real baseline: root.doc.baseline ? root.num(root.doc.baseline.median_w) : NaN
    readonly property int age: root.doc.age || 0
    // One point per minute; a minute with no sample stays a hole (Sparkline draws it as one).
    readonly property var history: (root.doc.history || []).map(v => v === null ? NaN : v)
    readonly property real peak: {
        const v = root.history.filter(x => !isNaN(x));
        return v.length ? Math.max.apply(null, v) : 0;
    }

    function num(v) {
        return v === null || v === undefined ? NaN : Number(v);
    }

    EnergyMath {
        id: math
    }

    // The last two monthly files (a week can straddle a month), 7 days of minutes at most.
    Process {
        id: proc
        command: ["sh", "-c", "cd \"${POWER_LOG_DIR:-/var/lib/power-log}\" 2>/dev/null || exit 0; f=$(ls -1 -- *.csv 2>/dev/null | tail -n 2); [ -n \"$f\" ] || exit 0; for x in $f; do head -n 1 -- \"$x\"; tail -n 10080 -- \"$x\"; done"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: root.doc = math.energy(text, Date.now() / 1000, 1800)
        }
    }
    Timer {
        interval: 60000
        running: true
        repeat: true
        onTriggered: proc.running = true
    }
}
