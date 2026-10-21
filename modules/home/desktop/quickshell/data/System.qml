pragma Singleton
// CPU, memory and GPU now, plus the heaviest apps, sampled only by whoever reads them (a singleton
// starts on first use: the lock, not the shell). The math is SystemMath.qml. docs/notes/desktop/dash.md
import Quickshell
import Quickshell.Io
import QtQuick

Singleton {
    id: root

    property real cpuPct: NaN
    property var mem: null // {total, available, used} in bytes
    property real gpuFreqMhz: NaN
    property real gpuRenderIdle: NaN // the xe driver has no utilization %, so render idle is the honest number
    property real gpuTempC: NaN
    property var topCpu: [] // [{name, value: % of one core}]
    property var topMem: [] // [{name, value: bytes}]

    property var _ticks: null
    property real _rc6: NaN
    property real _t: 0
    property var _procs: null
    property real _pt: 0
    property string _gt: "" // /sys/class/drm/card*/device/tile0/gt0
    property string _gpuTemp: "" // the xe hwmon channel labelled "pkg" (as power-log reads it)

    SystemMath {
        id: math
    }

    function sample() {
        stat.reload();
        meminfo.reload();
        const now = Date.now() / 1000;
        const ticks = math.cpuTicks(stat.text());
        root.cpuPct = math.cpuPct(root._ticks, ticks);
        root._ticks = ticks;
        root.mem = math.mem(meminfo.text());
        if (root._gt) {
            rc6.reload();
            freq.reload();
            const r = Number(rc6.text().trim());
            root.gpuRenderIdle = math.renderIdle(root._rc6, r, now - root._t);
            root._rc6 = r;
            root.gpuFreqMhz = Number(freq.text().trim());
        }
        if (root._gpuTemp) {
            temp.reload();
            root.gpuTempC = Math.round(Number(temp.text().trim()) / 1000);
        }
        root._t = now;
    }

    FileView {
        id: stat
        path: "/proc/stat"
        blockLoading: true
    }
    FileView {
        id: meminfo
        path: "/proc/meminfo"
        blockLoading: true
    }
    FileView {
        id: rc6
        path: root._gt ? root._gt + "/gtidle/idle_residency_ms" : ""
        blockLoading: true
        printErrors: false
    }
    FileView {
        id: freq
        path: root._gt ? root._gt + "/freq0/act_freq" : ""
        blockLoading: true
        printErrors: false
    }
    FileView {
        id: temp
        path: root._gpuTemp
        blockLoading: true
        printErrors: false
    }

    // Where the xe GPU lives, found once: hwmon numbers and card numbers move between boots.
    Process {
        running: true
        command: ["sh", "-c", "for d in /sys/class/hwmon/hwmon*; do [ \"$(cat \"$d/name\" 2>/dev/null)\" = xe ] || continue; for l in \"$d\"/temp*_label; do [ \"$(cat \"$l\")\" = pkg ] && echo \"temp ${l%_label}_input\"; done; done; for g in /sys/class/drm/card*/device/tile0/gt0; do [ -d \"$g\" ] && echo \"gt $g\" && break; done"]
        stdout: StdioCollector {
            onStreamFinished: {
                for (const line of text.split("\n")) {
                    const [k, v] = [line.slice(0, line.indexOf(" ")), line.slice(line.indexOf(" ") + 1)];
                    if (k === "temp")
                        root._gpuTemp = v;
                    else if (k === "gt")
                        root._gt = v;
                }
                root.sample();
            }
        }
    }

    // Every process's stat and cgroup in one shot: names only, never a command line.
    Process {
        id: procs
        command: ["sh", "-c", "cat /proc/[0-9]*/stat 2>/dev/null; echo ---; grep -s -H '' /proc/[0-9]*/cgroup"]
        stdout: StdioCollector {
            onStreamFinished: {
                const now = Date.now() / 1000;
                const cur = math.procs(text);
                const r = math.rank(root._procs, cur, now - root._pt, 3);
                if (root._procs)
                    root.topCpu = r.cpu;
                root.topMem = r.mem;
                root._procs = cur;
                root._pt = now;
            }
        }
    }

    Timer {
        interval: 2000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: root.sample()
    }
    Timer {
        interval: 5000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: procs.running = true
    }
}
