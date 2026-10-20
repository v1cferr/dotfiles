pragma Singleton
// The measured CPU + GPU watts from power-log, through the same adapter the lock screen reads
// (`observe json energy`), once a minute: power-log writes once a minute. docs/notes/desktop/dash.md
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

    Process {
        id: proc
        command: ["observe", "json", "energy"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    root.doc = JSON.parse(text);
                } catch (e) {
                    root.doc = {
                        status: "missing"
                    };
                }
            }
        }
    }
    Timer {
        interval: 60000
        running: true
        repeat: true
        onTriggered: proc.running = true
    }
}
