// The VPN STATISTICS popover (hover): verdict, a 60s graph, latency, jitter, loss, traffic,
// uptime. Why the scale starts at ZERO and why 360 wide: docs/notes/desktop/bar.md
import Quickshell
import QtQuick
import QtQuick.Layouts
import "root:/"
import "root:/widgets"

PanelWindow {
    id: statsPop
    required property var bar

    visible: bar.vpnStatsPopVisible
    screen: bar.popScreen || bar.screenPrimary
    anchors {
        top: true
        left: true
    }
    margins {
        top: 4 // = Hyprland's gaps_out (the barExclusiveZone 30 is already discounted)
        left: bar.popLeft(statsPop.implicitWidth)
    }
    exclusiveZone: 0
    implicitWidth: 360
    implicitHeight: card.implicitHeight
    color: "transparent"

    // ms with decimals only when they matter: "34 ms" reads better than "34.00 ms", and 0.8 ms
    // of jitter would become "1 ms" rounded.
    function fmtMs(v, digits) {
        return v.toFixed(digits) + " ms";
    }

    PopCard {
        id: card
        onHoveredChanged: statsPop.bar.vpnStatsPopHovered = card.hovered

        Repeater {
            model: statsPop.bar.vpnStatsList

            delegate: ColumnLayout {
                id: blk
                required property var modelData
                required property int index
                readonly property var s: blk.modelData
                readonly property var pr: statsPop.bar.vpnProbeStat[blk.s.id] || null
                readonly property var q: statsPop.bar.vpnQuality(blk.s, blk.pr)
                readonly property var series: statsPop.bar.vpnProbeSeries[blk.s.id] || []
                readonly property var rate: statsPop.bar.vpnRate(blk.s.iface || "")
                // The ceiling: a 60ms floor so the normal case is not a sawtooth, and 15% above a higher peak.
                readonly property real scaleTop: Math.max(60, (blk.pr ? blk.pr.max : 0) * 1.15)

                Layout.fillWidth: true
                spacing: 7

                // the separator between VPNs (only when both are up)
                Hairline {
                    visible: blk.index > 0
                    Layout.topMargin: 4
                    Layout.bottomMargin: 4
                }

                PopHeader {
                    icon: "󰦝"
                    title: blk.s.name
                    verdict: blk.q.label
                    verdictColor: blk.q.color
                    rule: false
                }

                // The graph: one bar per second, the most recent on the right.
                Sparkline {
                    Layout.fillWidth: true
                    Layout.topMargin: 3
                    series: blk.series
                    scaleTop: blk.scaleTop
                    fill: Theme.colTeal
                    placeholder: blk.s.probe ? "measuring…" : "no probe target inside the tunnel"
                }

                // The legend: without it the drawing does not say what it covers, and "1 packet/s" is what
                // separates this panel from a guess.
                RowLayout {
                    Layout.fillWidth: true
                    Layout.bottomMargin: 3
                    spacing: 10
                    Text {
                        Layout.fillWidth: true
                        text: blk.pr && blk.pr.n > 0 ? "last " + blk.pr.n + "s · 1 packet/s" : "a continuous probe · 1 packet/s"
                        color: Theme.colDim
                        font.family: Theme.uiFont
                        font.pixelSize: 9
                    }
                    Text {
                        visible: blk.pr !== null && blk.pr.answered > 0
                        text: blk.pr ? "min " + Math.round(blk.pr.min) + " · max " + Math.round(blk.pr.max) + " ms" : ""
                        color: Theme.colDim
                        font.family: Theme.uiFont
                        font.pixelSize: 9
                    }
                }

                StatRow {
                    label: "Latency"
                    value: blk.pr && blk.pr.answered > 0 ? statsPop.fmtMs(blk.pr.avg, 0) : "no answer"
                    valueColor: blk.pr && blk.pr.answered > 0 ? Theme.colText : Theme.colRed
                }
                StatRow {
                    // The window's standard deviation: what freezes SSH and calls is not a
                    // high mean, it is the variation.
                    label: "Jitter"
                    value: blk.pr && blk.pr.answered > 0 ? statsPop.fmtMs(blk.pr.mdev, 1) : "—"
                    valueColor: blk.pr && blk.pr.mdev > 10 ? Theme.colPeach : Theme.colText
                }
                StatRow {
                    label: "Loss"
                    hint: blk.pr && blk.pr.n > 0 ? blk.pr.lost + " of " + blk.pr.n + " packets" : ""
                    value: blk.pr && blk.pr.n > 0 ? blk.pr.loss.toFixed(blk.pr.loss > 0 && blk.pr.loss < 10 ? 1 : 0) + "%" : "—"
                    valueColor: blk.pr && blk.pr.loss > 0 ? (blk.pr.loss >= 20 ? Theme.colRed : Theme.colPeach) : Theme.colText
                }
                StatRow {
                    label: "Uptime"
                    value: statsPop.bar.fmtDur(blk.s.uptime || 0)
                }
                StatRow {
                    label: "Traffic"
                    value: "↓" + statsPop.bar.fmtBytes(blk.s.rx || 0) + "   ↑" + statsPop.bar.fmtBytes(blk.s.tx || 0)
                }
                StatRow {
                    label: "Rate"
                    value: "↓" + statsPop.bar.fmtRate(blk.rate.rx) + "/s   ↑" + statsPop.bar.fmtRate(blk.rate.tx) + "/s"
                }
                // Errors/drops only show up when they exist: a row zeroed every day is
                // noise that trains the eye to ignore exactly the day it goes up.
                StatRow {
                    visible: (blk.s.errors || 0) + (blk.s.drops || 0) > 0
                    label: "Errors"
                    value: (blk.s.errors || 0) + " · " + (blk.s.drops || 0) + " drops"
                    valueColor: Theme.colPeach
                }

                Hairline {
                    Layout.topMargin: 5
                }

                // A TWO-line footer, with no elide: it is where "where that number came
                // from" lives, and cutting the probe's IP defeats the purpose.
                Text {
                    Layout.fillWidth: true
                    text: (blk.s.iface || "?") + " · " + (blk.s.ip || "?") + " · MTU " + (blk.s.mtu || 0)
                    color: Theme.colDim
                    font.family: Theme.uiFont
                    font.pixelSize: 10
                }
                Text {
                    Layout.fillWidth: true
                    text: blk.s.probe ? "probe " + blk.s.probe : "no probe target"
                    color: Theme.colDim
                    font.family: Theme.uiFont
                    font.pixelSize: 10
                }
            }
        }
    }
}
