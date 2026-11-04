// The speed test inside the network panel: the last result in bits, a live gauge while a test runs,
// and the last runs as bars. The runner, its history and the three latencies: docs/notes/desktop/bar.md
import Quickshell
import Quickshell.Io
import QtQuick
import QtQuick.Layouts
import "root:/"
import "root:/widgets"

ColumnLayout {
    id: st
    property var rate: v => "" // the panel's bits formatter
    property var history: []
    readonly property var last: st.history.length > 0 ? st.history[st.history.length - 1] : null
    readonly property bool running: run.running
    property string phase: "" // starting, ping, download, upload
    property real progress: 0
    property real live: 0 // the phase's bandwidth so far, bytes/s
    property real liveMs: 0
    property string note: ""

    Layout.fillWidth: true
    spacing: Theme.sp1

    function ago(iso) {
        const m = Math.round((Date.now() - Date.parse(iso)) / 60000);
        if (m < 1)
            return "just now";
        if (m < 60)
            return m + " min ago";
        if (m < 48 * 60)
            return Math.round(m / 60) + " h ago";
        return Math.round(m / 1440) + " d ago";
    }
    // Latency the test ADDED by saturating the link: past 30 ms the router is queueing (bufferbloat).
    function added(r) {
        return Math.max(r.downLoaded || 0, r.upLoaded || 0) - (r.ping || 0);
    }

    // The timer and the button append to the same file; a watch picks up either.
    FileView {
        id: file
        path: Quickshell.env("HOME") + "/.local/state/net-speedtest/history.jsonl"
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: {
            const out = [];
            for (const l of file.text().split("\n")) {
                if (l.trim() === "")
                    continue;
                try {
                    out.push(JSON.parse(l));
                } catch (e) {}
            }
            st.history = out;
        }
        onLoadFailed: st.history = []
    }

    Process {
        id: run
        command: ["net-speedtest", "--progress"]
        onRunningChanged: if (running) {
            st.phase = "starting";
            st.progress = 0;
            st.live = 0;
            st.note = "";
        }
        onExited: code => {
            st.phase = "";
            // 75 = the timer's test holds the lock; 143 = cancelled here.
            st.note = code === 75 ? "a scheduled test is running, its result lands here" : (code !== 0 && code !== 143 ? "the test failed, Ookla gave no result" : "");
        }
        stdout: SplitParser {
            splitMarker: "\n"
            onRead: line => {
                let j;
                try {
                    j = JSON.parse(line);
                } catch (e) {
                    return;
                }
                if (j.type === "ping") {
                    st.phase = "ping";
                    st.progress = j.ping.progress || 0;
                    st.liveMs = j.ping.latency || 0;
                } else if (j.type === "download" || j.type === "upload") {
                    st.phase = j.type;
                    st.progress = j[j.type].progress || 0;
                    st.live = j[j.type].bandwidth || 0;
                }
            }
        }
    }

    RowLayout {
        Layout.fillWidth: true
        spacing: Theme.sp2
        Text {
            text: "Speed test"
            color: Theme.colSubtext
            font.family: Theme.uiFont
            font.pixelSize: Theme.fontSmall
        }
        Text {
            Layout.fillWidth: true
            text: st.running ? "saturating the link, ~20 s" : (st.last ? st.ago(st.last.timestamp) + " · " + st.last.isp : "")
            color: Theme.colDim
            font.family: Theme.uiFont
            font.pixelSize: Theme.fontMicro
            horizontalAlignment: Text.AlignRight
            elide: Text.ElideRight
        }
        IconButton {
            implicitWidth: 22
            implicitHeight: 22
            glyph: st.running ? "󰓛" : "󰐊"
            tint: st.running ? Theme.colPeach : Theme.colAccent
            name: st.running ? "Cancel the speed test" : "Run a speed test"
            onClicked: run.running = !run.running
        }
    }

    // Running: the phase, its bar and what it measures so far.
    ColumnLayout {
        visible: st.running
        Layout.fillWidth: true
        spacing: 3
        RowLayout {
            Layout.fillWidth: true
            Text {
                Layout.fillWidth: true
                text: st.phase === "download" ? "↓ download" : (st.phase === "upload" ? "↑ upload" : (st.phase === "ping" ? "latency" : "finding a server…"))
                color: st.phase === "upload" ? Theme.colPeach : (st.phase === "download" ? Theme.colTeal : Theme.colSubtext)
                font.family: Theme.uiFont
                font.pixelSize: Theme.fontBody
            }
            Text {
                text: st.phase === "ping" ? st.liveMs.toFixed(1) + " ms" : (st.phase === "download" || st.phase === "upload" ? st.rate(st.live) : "")
                color: Theme.colText
                font.family: Theme.uiFont
                font.pixelSize: Theme.fontLabel
                font.bold: true
            }
        }
        Rectangle {
            Layout.fillWidth: true
            implicitHeight: 5
            radius: 2.5
            color: Theme.colTrack
            Rectangle {
                // ping, download and upload as thirds of one bar, so it never runs backwards.
                readonly property real base: st.phase === "download" ? 1 : (st.phase === "upload" ? 2 : 0)
                width: parent.width * Math.min(1, (base + (st.phase === "starting" ? 0 : st.progress)) / 3)
                height: parent.height
                radius: parent.radius
                color: st.phase === "upload" ? Theme.colPeach : Theme.colTeal
                Behavior on width {
                    NumberAnimation {
                        duration: 250
                    }
                }
            }
        }
    }

    // Idle: the last result, its latencies, and the runs before it.
    RowLayout {
        visible: !st.running && !!st.last
        Layout.fillWidth: true
        spacing: Theme.sp3
        Text {
            text: st.last ? "↓ " + st.rate(st.last.down) : ""
            color: Theme.colTeal
            font.family: Theme.uiFont
            font.pixelSize: Theme.fontLabel
            font.bold: true
        }
        Text {
            text: st.last ? "↑ " + st.rate(st.last.up) : ""
            color: Theme.colPeach
            font.family: Theme.uiFont
            font.pixelSize: Theme.fontLabel
            font.bold: true
        }
        Item {
            Layout.fillWidth: true
        }
        Sparkline {
            implicitWidth: 72
            implicitHeight: 16
            series: st.history.slice(-12).map(h => h.down)
            scaleTop: Math.max(...st.history.slice(-12).map(h => h.down), 1)
            fill: Theme.colTeal
            placeholder: ""
            format: (v, v2, i) => {
                const h = st.history.slice(-12)[i];
                return h ? Qt.formatDateTime(new Date(h.timestamp), "dd/MM HH:mm") + "  ↓" + st.rate(h.down) + " ↑" + st.rate(h.up) : "";
            }
        }
    }
    Text {
        visible: !st.running && !!st.last
        Layout.fillWidth: true
        text: st.last ? "ping " + st.last.ping.toFixed(0) + " ms · loaded ↓" + Math.round(st.last.downLoaded) + " ↑" + Math.round(st.last.upLoaded) + " ms · loss " + (st.last.loss || 0) + "% · " + st.last.server : ""
        color: st.last && st.added(st.last) > 30 ? Theme.colPeach : Theme.colDim
        font.family: Theme.uiFont
        font.pixelSize: Theme.fontMicro
        elide: Text.ElideRight
    }
    Text {
        visible: !st.running && (!st.last || st.note !== "")
        Layout.fillWidth: true
        text: st.note !== "" ? st.note : "no test yet · ▶ measures the link (~20 s, it saturates it)"
        color: st.note.indexOf("failed") >= 0 ? Theme.colRed : Theme.colDim
        font.family: Theme.uiFont
        font.pixelSize: Theme.fontMicro
        wrapMode: Text.WordWrap
    }
}
