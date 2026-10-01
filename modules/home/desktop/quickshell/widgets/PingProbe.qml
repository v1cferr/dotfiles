// A CONTINUOUS ping probe, 1 packet/s over a rolling window, plus the watchdog that keeps silence
// from reading as stability. Why continuous and not a burst per read: docs/notes/desktop/bar.md
import Quickshell
import Quickshell.Io
import QtQuick

Scope {
    id: probe
    property bool enabled: false
    property string iface: ""
    property string target: ""
    property string session: ""  // the IP, or anything whose change means a NEW link
    property int window: 60      // 1 minute at 1 packet/s
    property var series: []      // ms per sample; null = a packet with no answer

    // A new link, a new address or a new target is a NEW series. Splicing two sessions would draw
    // a step that never happened, and an interface NAME repeats across reconnects.
    readonly property string key: probe.enabled && probe.target !== "" ? probe.iface + "@" + probe.session + "@" + probe.target : ""
    onKeyChanged: {
        probe.series = [];
        pingProc.running = false;
        if (probe.key !== "") {
            // -O emits "no answer yet" at timeout: without it a lost packet is SILENCE and the series
            // would hold only the ones that came back, an eternal 0% loss. -n no DNS, -W 1 = the interval.
            pingProc.command = probe.iface !== "" ? ["ping", "-n", "-O", "-i", "1", "-W", "1", "-I", probe.iface, probe.target] : ["ping", "-n", "-O", "-i", "1", "-W", "1", probe.target];
            probe.lastAt = Date.now();
            pingProc.running = true;
        }
    }
    function push(v) {
        const s = probe.series.slice(-(probe.window - 1));
        s.push(v);
        probe.series = s;
    }
    function feed(line) {
        probe.lastAt = Date.now(); // any line proves the probe is alive
        const m = line.match(/time=([0-9.]+) ms/);
        if (m)
            probe.push(Number(m[1]));
        else if (line.indexOf("no answer yet") >= 0)
            probe.push(null);
        // the header and the noise do not become samples, but they do count as a sign of life
    }
    // The WATCHDOG: with -O, silence is NOT loss, it is the probe broken. Without this the panel
    // freezes on the last good window looking "stable", the exact lie it exists not to tell.
    property double lastAt: 0
    Timer {
        interval: 5000
        repeat: true
        running: probe.key !== ""
        onTriggered: {
            if (Date.now() - probe.lastAt < 5000)
                return;
            probe.push(null);
            probe.lastAt = Date.now();
            pingProc.running = false;
            reviveTimer.restart();
        }
    }
    Timer {
        id: reviveTimer
        interval: 300 // it lets the process die before being reborn
        onTriggered: if (probe.key !== "")
            pingProc.running = true
    }
    // The window's statistics. `mdev` is the standard deviation of the answered ones, the same
    // calculation iputils does, so this number matches `ping` in the terminal.
    readonly property var stat: {
        const s = probe.series;
        let n = 0, sum = 0, sum2 = 0, mn = 0, mx = 0, lost = 0;
        for (let i = 0; i < s.length; i++) {
            const v = s[i];
            if (v === null) {
                lost++;
                continue;
            }
            if (n === 0 || v < mn)
                mn = v;
            if (v > mx)
                mx = v;
            n++;
            sum += v;
            sum2 += v * v;
        }
        const avg = n ? sum / n : 0;
        return {
            n: s.length,
            answered: n,
            lost: lost,
            loss: s.length ? lost * 100 / s.length : 0,
            avg: avg,
            min: mn,
            max: mx,
            mdev: n ? Math.sqrt(Math.max(0, sum2 / n - avg * avg)) : 0
        };
    }
    Process {
        id: pingProc
        stdout: SplitParser {
            splitMarker: "\n"
            onRead: data => probe.feed(data)
        }
    }
}
