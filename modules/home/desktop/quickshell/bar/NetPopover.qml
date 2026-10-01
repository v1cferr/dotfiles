// The NETWORK panel (hover): the verdict, 2 minutes of throughput mirrored, the link's latency,
// the address, the gateway and the other interfaces. The state lives in the Bar (bar.md).
import Quickshell
import QtQuick
import QtQuick.Layouts
import "root:/"
import "root:/widgets"

PanelWindow {
    id: pop
    required property var bar

    visible: bar.metricPopVisible && bar.metricShown === "net"
    screen: bar.popScreen || bar.screenPrimary
    anchors {
        top: true
        left: true
    }
    margins {
        top: 4 // = Hyprland's gaps_out (the barExclusiveZone 30 is already discounted)
        left: bar.popLeft(pop.implicitWidth)
    }
    exclusiveZone: 0
    implicitWidth: 380
    implicitHeight: card.implicitHeight
    color: "transparent"

    readonly property var link: bar.netLink[bar.netMain] || ({})
    readonly property var stats: bar.netStats[bar.netMain] || ({})
    readonly property var probe: bar.netProbeStat
    // ONE ceiling for both halves, or the mirror lies: a 5 KB/s upload drawn as tall as a 5 MB/s
    // download. The 128 KB/s floor keeps an idle link from becoming a sawtooth.
    readonly property real scaleTop: {
        let mx = 0;
        const a = pop.bar.netRxHist || [], b = pop.bar.netTxHist || [];
        for (let i = 0; i < a.length; i++)
            if (a[i] > mx)
                mx = a[i];
        for (let i = 0; i < b.length; i++)
            if (b[i] > mx)
                mx = b[i];
        return Math.max(131072, mx * 1.15);
    }

    PopCard {
        id: card
        onHoveredChanged: pop.bar.metricPopHovered = card.hovered

        PopHeader {
            title: "Network"
            verdict: pop.bar.netQuality.label
            verdictColor: pop.bar.netQuality.color
        }

        // Mirrored: download grows down from the top, upload up from the bottom, so the two
        // directions are read at a glance instead of two graphs you have to line up.
        Sparkline {
            Layout.fillWidth: true
            implicitHeight: 26
            series: pop.bar.netRxHist
            scaleTop: pop.scaleTop
            fill: Theme.colTeal
            downward: true
            placeholder: "measuring…"
        }
        Sparkline {
            Layout.fillWidth: true
            implicitHeight: 26
            series: pop.bar.netTxHist
            scaleTop: pop.scaleTop
            fill: Theme.colPeach
            placeholder: ""
        }
        RowLayout {
            Layout.fillWidth: true
            spacing: 10
            Text {
                Layout.fillWidth: true
                text: "last " + Math.round((pop.bar.netRxHist || []).length * pop.bar.sysInterval / 1000) + "s · ↓ above, ↑ below"
                color: Theme.colDim
                font.family: Theme.uiFont
                font.pixelSize: 9
            }
            Text {
                text: "top " + pop.bar.fmtRate(pop.scaleTop / 1.15) + "/s"
                color: Theme.colDim
                font.family: Theme.uiFont
                font.pixelSize: 9
            }
        }

        StatRow {
            label: "Rate"
            labelWidth: 62
            value: "↓" + pop.bar.fmtRate(pop.bar.netMainRx) + "/s   ↑" + pop.bar.fmtRate(pop.bar.netMainTx) + "/s"
        }
        StatRow {
            label: "Latency"
            labelWidth: 62
            hint: "probe " + pop.bar.netProbeTarget + " · 1 packet/s"
            value: pop.probe && pop.probe.answered > 0 ? Math.round(pop.probe.avg) + " ms" : "no answer"
            valueColor: pop.probe && pop.probe.answered > 0 ? Theme.colText : Theme.colRed
        }
        StatRow {
            // The variation, not the mean: what freezes a call is the jitter.
            label: "Jitter"
            labelWidth: 62
            hint: pop.probe && pop.probe.answered > 0 ? "min " + Math.round(pop.probe.min) + " · max " + Math.round(pop.probe.max) + " ms" : ""
            value: pop.probe && pop.probe.answered > 0 ? pop.probe.mdev.toFixed(1) + " ms" : "—"
            valueColor: pop.probe && pop.probe.mdev > 10 ? Theme.colPeach : Theme.colText
        }
        StatRow {
            label: "Loss"
            labelWidth: 62
            hint: pop.probe && pop.probe.n > 0 ? pop.probe.lost + " of " + pop.probe.n + " packets" : ""
            value: pop.probe && pop.probe.n > 0 ? pop.probe.loss.toFixed(pop.probe.loss > 0 && pop.probe.loss < 10 ? 1 : 0) + "%" : "—"
            valueColor: pop.probe && pop.probe.loss > 0 ? (pop.probe.loss >= 20 ? Theme.colRed : Theme.colPeach) : Theme.colText
        }

        Hairline {
            Layout.topMargin: 2
        }

        StatRow {
            label: "Link"
            labelWidth: 62
            hint: (pop.link.duplex && pop.link.duplex !== "unknown" ? pop.link.duplex + " duplex · " : "") + "MTU " + (pop.link.mtu || "?")
            value: pop.bar.netSpeed !== "" ? pop.bar.netSpeed : (pop.link.carrier === "1" ? "up" : "down")
        }
        StatRow {
            label: "Address"
            labelWidth: 62
            hint: pop.bar.netEthernet ? "ethernet" : "wifi"
            value: pop.bar.netAddr[pop.bar.netMain] || "—"
        }
        StatRow {
            label: "Gateway"
            labelWidth: 62
            value: pop.bar.netGw !== "" ? pop.bar.netGw : "—"
        }
        StatRow {
            label: "Traffic"
            labelWidth: 62
            hint: "since boot"
            value: "↓" + pop.bar.fmtBytes(pop.stats.rx || 0) + "   ↑" + pop.bar.fmtBytes(pop.stats.tx || 0)
        }
        // Errors and drops only appear when they exist: a row pinned at zero teaches the eye to
        // skip it, and this is the one row that has to be noticed the day it moves.
        StatRow {
            visible: (pop.stats.rxErr || 0) + (pop.stats.txErr || 0) + (pop.stats.rxDrop || 0) + (pop.stats.txDrop || 0) > 0
            label: "Errors"
            labelWidth: 62
            hint: "rx · tx"
            value: ((pop.stats.rxErr || 0) + (pop.stats.txErr || 0)) + " errors · " + ((pop.stats.rxDrop || 0) + (pop.stats.txDrop || 0)) + " drops"
            valueColor: Theme.colPeach
        }

        // Everything else carrying traffic right now: the tunnel, the container bridges. It only
        // lists what MOVED, so an idle bridge does not pad the panel.
        Hairline {
            visible: pop.others.length > 0
            Layout.topMargin: 2
        }
        Repeater {
            model: pop.others

            delegate: RowLayout {
                id: oth
                required property var modelData

                Layout.fillWidth: true
                spacing: 10
                Text {
                    Layout.minimumWidth: 62
                    text: oth.modelData.iface
                    color: Theme.colDim
                    font.family: Theme.uiFont
                    font.pixelSize: 11
                    elide: Text.ElideRight
                }
                Text {
                    Layout.fillWidth: true
                    text: pop.bar.netAddr[oth.modelData.iface] || ""
                    color: Theme.colDim
                    font.family: Theme.uiFont
                    font.pixelSize: 10
                    horizontalAlignment: Text.AlignRight
                }
                Text {
                    text: "↓" + pop.bar.fmtRate(oth.modelData.rx) + "  ↑" + pop.bar.fmtRate(oth.modelData.tx)
                    color: Theme.colText
                    font.family: Theme.uiFont
                    font.pixelSize: 11
                }
            }
        }

        Hairline {
            Layout.topMargin: 2
        }

        Text {
            Layout.fillWidth: true
            text: pop.bar.netMain + " · " + ((pop.bar.netDevs[pop.bar.netMain] || {}).type || "?") + " · " + (pop.bar.netConnected ? "managed by NetworkManager" : "not managed")
            color: Theme.colDim
            font.family: Theme.uiFont
            font.pixelSize: 10
            elide: Text.ElideRight
        }
    }

    readonly property var others: (bar.netRates || []).filter(n => n.iface !== bar.netMain)
}
