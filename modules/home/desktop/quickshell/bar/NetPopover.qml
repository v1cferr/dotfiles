// The NETWORK panel (hover): the verdict, 2 minutes of throughput mirrored on a log scale, the
// link's latency over time, the apps moving traffic, the address and the other interfaces. The state
// lives in the Bar (bar.md).
import Quickshell
import Quickshell.Io
import QtQuick
import QtQuick.Layouts
import "root:/"
import "root:/widgets"

BarPanel {
    id: pop
    key: "net"

    implicitWidth: 380
    implicitHeight: card.implicitHeight

    readonly property var link: bar.netLink[bar.netMain] || ({})
    readonly property var stats: bar.netStats[bar.netMain] || ({})
    readonly property var probe: bar.netProbeStat
    readonly property bool answered: !!pop.probe && pop.probe.answered > 0
    readonly property real stepS: bar.sysInterval / 1000

    // The window's peak and volume per direction, from the samples already kept: no new sampling.
    function sum(a) {
        let t = 0;
        for (const v of a || [])
            t += v;
        return t;
    }
    function peak(a) {
        let m = 0;
        for (const v of a || [])
            if (v > m)
                m = v;
        return m;
    }
    readonly property real peakRx: pop.peak(bar.netRxHist)
    readonly property real peakTx: pop.peak(bar.netTxHist)
    // ONE log scale for both halves, or the mirror lies about which direction is bigger. Log because
    // a link idles at kilobytes and bursts at tens of megabytes: on a linear axis the burst flattens
    // every other sample to nothing. The ceiling is the next step above the peak, never under 1 MB/s.
    readonly property real logFloor: 1024
    readonly property real scaleTop: {
        const mx = Math.max(pop.peakRx, pop.peakTx);
        for (const t of [1, 10, 100, 1000])
            if (mx <= t * 1048576)
                return t * 1048576;
        return 10000 * 1048576;
    }
    function rate(v) {
        return pop.bar.fmtRate(v).replace(".0M", "M");
    }

    // Who is moving the bytes: nethogs (a capability wrapper, never root) runs ONLY while the panel
    // is open, and its trace mode prints one block per refresh, KB/s sent and received per program.
    property var apps: []
    property var appsNext: []
    Process {
        id: hogs
        running: pop.visible && pop.bar.netMain !== ""
        command: ["/run/wrappers/bin/nethogs", "-t", "-C", "-d", "2", pop.bar.netMain]
        onRunningChanged: if (!running)
            pop.apps = []
        stdout: SplitParser {
            splitMarker: "\n"
            onRead: line => {
                if (line.startsWith("Refreshing")) {
                    const by = {};
                    for (const a of pop.appsNext) {
                        const k = a.name;
                        by[k] = by[k] || {
                            name: k,
                            rx: 0,
                            tx: 0
                        };
                        by[k].rx += a.rx;
                        by[k].tx += a.tx;
                    }
                    pop.apps = Object.values(by).filter(a => a.rx + a.tx >= 1024).sort((a, b) => b.rx + b.tx - (a.rx + a.tx)).slice(0, 5);
                    pop.appsNext = [];
                    return;
                }
                const m = line.match(/^(.*)\/(\d+)\/(\d+)\t([0-9.]+)\t([0-9.]+)$/);
                if (!m)
                    return;
                const path = m[1].split(" ")[0];
                const name = m[2] === "0" ? "unattributed" : path.slice(path.lastIndexOf("/") + 1);
                pop.appsNext = pop.appsNext.concat([{
                        name: name,
                        tx: Number(m[4]) * 1024,
                        rx: Number(m[5]) * 1024
                    }]);
            }
        }
    }

    // The address the internet sees, asked to the same anycast anchor as the probe. Only on open, at
    // most once per 5 min or when the local address changes: it is one HTTPS request per family.
    property var pub: ({})
    property real pubAt: 0
    property string pubKey: ""
    readonly property string pubNow: (bar.netAddr[bar.netMain] || "") + "@" + bar.netGw
    onVisibleChanged: if (pop.visible && !pubProc.running && (pop.pubKey !== pop.pubNow || Date.now() - pop.pubAt > 300000)) {
        pop.pubKey = pop.pubNow;
        pop.pubNext = {};
        pubProc.running = true;
    }
    property var pubNext: ({})
    Process {
        id: pubProc
        command: ["sh", "-c", "curl -4 -s -m 4 https://1.1.1.1/cdn-cgi/trace; echo; curl -6 -s -m 4 'https://[2606:4700:4700::1111]/cdn-cgi/trace'"]
        stdout: SplitParser {
            splitMarker: "\n"
            onRead: line => {
                const m = line.match(/^(ip|colo)=(.+)$/);
                if (!m)
                    return;
                const n = Object.assign({}, pop.pubNext);
                if (m[1] === "colo")
                    n.colo = m[2];
                else
                    n[m[2].indexOf(":") >= 0 ? "v6" : "v4"] = m[2];
                pop.pubNext = n;
            }
        }
        onExited: {
            pop.pub = pop.pubNext;
            pop.pubAt = Date.now();
        }
    }

    component Caption: Text {
        color: Theme.colDim
        font.family: Theme.uiFont
        font.pixelSize: Theme.fontMicro
    }
    // One cell of the facts grid: a label over a value, the context in the label's line.
    component Fact: ColumnLayout {
        id: fact
        property string label: ""
        property string hint: ""
        property string value: ""
        property string sub: ""
        Layout.fillWidth: true
        Layout.preferredWidth: 1
        spacing: 1
        Caption {
            Layout.fillWidth: true
            text: fact.label + (fact.hint !== "" ? "  ·  " + fact.hint : "")
            elide: Text.ElideRight
        }
        Text {
            Layout.fillWidth: true
            text: fact.value
            color: Theme.colText
            font.family: Theme.uiFont
            font.pixelSize: Theme.fontBody
            font.bold: true
            elide: Text.ElideRight
        }
        Caption {
            Layout.fillWidth: true
            visible: fact.sub !== ""
            text: fact.sub
            elide: Text.ElideMiddle
        }
    }

    PopCard {
        shown: pop.visible
        id: card
        onHoveredChanged: pop.bar.panelPopHovered = card.hovered

        PopHeader {
            title: "Network"
            verdict: pop.bar.netQuality.label
            verdictColor: pop.bar.netQuality.color
        }

        // Throughput, mirrored around one axis: download grows up, upload down, the same log scale.
        RowLayout {
            Layout.fillWidth: true
            spacing: Theme.sp2
            Text {
                text: "↓" + pop.rate(pop.bar.netMainRx) + "/s"
                color: Theme.colTeal
                font.family: Theme.uiFont
                font.pixelSize: Theme.fontLabel
                font.bold: true
            }
            Text {
                text: "↑" + pop.rate(pop.bar.netMainTx) + "/s"
                color: Theme.colPeach
                font.family: Theme.uiFont
                font.pixelSize: Theme.fontLabel
                font.bold: true
            }
            Item {
                Layout.fillWidth: true
            }
            Caption {
                text: "peak ↓" + pop.rate(pop.peakRx) + " ↑" + pop.rate(pop.peakTx)
            }
        }
        Sparkline {
            Layout.fillWidth: true
            implicitHeight: 80
            series: pop.bar.netRxHist
            series2: pop.bar.netTxHist
            fill: Theme.colTeal
            fill2: Theme.colPeach
            style: "area"
            scale: "log"
            logFloor: pop.logFloor
            scaleTop: pop.scaleTop
            // One line per half: more than that crowds a 40 px half once the ceiling climbs.
            gridValues: pop.scaleTop > 1048576 ? [1048576] : [32768]
            gridLabel: v => pop.rate(v)
            stepS: pop.stepS
            format: (rx, tx) => "↓" + pop.rate(rx) + "/s  ↑" + pop.rate(tx) + "/s"
            placeholder: "measuring…"
        }
        RowLayout {
            Layout.fillWidth: true
            Caption {
                Layout.fillWidth: true
                readonly property int secs: Math.round((pop.bar.netRxHist || []).length * pop.stepS)
                readonly property int full: Math.round(pop.bar.histWindow * pop.stepS)
                text: (secs < full ? "filling · " + secs + "s of " + full / 60 + " min" : "last " + full / 60 + " min") + " · log scale"
            }
            Caption {
                text: "moved ↓" + pop.bar.fmtBytes(pop.sum(pop.bar.netRxHist) * pop.stepS) + " ↑" + pop.bar.fmtBytes(pop.sum(pop.bar.netTxHist) * pop.stepS)
            }
        }

        Hairline {
            Layout.topMargin: 2
        }

        // Latency over the probe's whole window: the mean alone hides a link that swings.
        RowLayout {
            Layout.fillWidth: true
            spacing: Theme.sp2
            Text {
                text: pop.answered ? Math.round(pop.probe.avg) + " ms" : "no answer"
                color: pop.answered ? Theme.colText : Theme.colRed
                font.family: Theme.uiFont
                font.pixelSize: Theme.fontLabel
                font.bold: true
            }
            Caption {
                Layout.fillWidth: true
                text: "to " + pop.bar.netProbeTarget + " · 1 packet/s"
                elide: Text.ElideRight
            }
            Caption {
                // The variation, not the mean: what freezes a call is the jitter.
                text: pop.answered ? "jitter " + pop.probe.mdev.toFixed(1) + " · loss " + pop.probe.lost + "/" + pop.probe.n : ""
                color: pop.probe && pop.probe.loss > 0 ? (pop.probe.loss >= 20 ? Theme.colRed : Theme.colPeach) : (pop.probe && pop.probe.mdev > 10 ? Theme.colPeach : Theme.colDim)
            }
        }
        Sparkline {
            Layout.fillWidth: true
            implicitHeight: 22
            series: pop.bar.netProbeSeries
            scaleTop: Math.max(60, (pop.probe ? pop.probe.max : 0) * 1.15)
            fill: Theme.colAccent
            stepS: 1
            unit: " ms"
            placeholder: "measuring…"
        }

        Hairline {
            Layout.topMargin: 2
        }

        GridLayout {
            Layout.fillWidth: true
            columns: 2
            columnSpacing: Theme.sp3
            rowSpacing: Theme.sp2
            Fact {
                label: "Link"
                hint: (pop.link.duplex && pop.link.duplex !== "unknown" ? pop.link.duplex + " · " : "") + "MTU " + (pop.link.mtu || "?")
                value: pop.bar.netSpeed !== "" ? pop.bar.netSpeed : (pop.link.carrier === "1" ? "up" : "down")
            }
            Fact {
                label: "Address"
                hint: pop.bar.netEthernet ? "ethernet" : "wifi"
                value: pop.bar.netAddr[pop.bar.netMain] || "—"
            }
            Fact {
                label: "Gateway"
                value: pop.bar.netGw !== "" ? pop.bar.netGw : "—"
            }
            Fact {
                label: "Since boot"
                value: "↓" + pop.bar.fmtBytes(pop.stats.rx || 0) + " ↑" + pop.bar.fmtBytes(pop.stats.tx || 0)
            }
            Fact {
                Layout.columnSpan: 2
                label: "Public"
                hint: pubProc.running && !pop.pub.v4 ? "asking…" : (pop.pub.colo ? "seen by Cloudflare " + pop.pub.colo : "")
                value: pop.pub.v4 || (pubProc.running ? "…" : "no answer")
                sub: pop.pub.v6 || ""
            }
        }
        // Errors and drops only appear when they exist: a row pinned at zero teaches the eye to
        // skip it, and this is the one row that has to be noticed the day it moves.
        StatRow {
            visible: (pop.stats.rxErr || 0) + (pop.stats.txErr || 0) + (pop.stats.rxDrop || 0) + (pop.stats.txDrop || 0) > 0
            label: "Errors"
            hint: "rx · tx"
            value: ((pop.stats.rxErr || 0) + (pop.stats.txErr || 0)) + " errors · " + ((pop.stats.rxDrop || 0) + (pop.stats.txDrop || 0)) + " drops"
            valueColor: Theme.colPeach
        }

        // The apps moving traffic right now, and everything else carrying it: the tunnel, the
        // container bridges. Both only list what MOVED, so idle entries do not pad the panel.
        Hairline {
            Layout.topMargin: 2
        }
        Caption {
            text: hogs.running ? (pop.apps.length > 0 ? "apps" : "apps · nothing moving") : "apps · nethogs unavailable"
        }
        Repeater {
            model: pop.apps
            delegate: StatRow {
                required property var modelData
                label: modelData.name
                labelWidth: 120
                value: "↓" + pop.rate(modelData.rx) + "  ↑" + pop.rate(modelData.tx)
            }
        }

        Hairline {
            visible: pop.others.length > 0
            Layout.topMargin: 2
        }
        Repeater {
            model: pop.others
            delegate: StatRow {
                required property var modelData
                label: modelData.iface
                hint: pop.bar.netAddr[modelData.iface] || ""
                value: "↓" + pop.rate(modelData.rx) + "  ↑" + pop.rate(modelData.tx)
            }
        }

        Hairline {
            Layout.topMargin: 2
        }

        Caption {
            Layout.fillWidth: true
            text: pop.bar.netMain + " · " + ((pop.bar.netDevs[pop.bar.netMain] || {}).type || "?") + " · " + (pop.bar.netConnected ? "managed by NetworkManager" : "not managed")
            elide: Text.ElideRight
        }
    }

    readonly property var others: (bar.netRates || []).filter(n => n.iface !== bar.netMain)
}
