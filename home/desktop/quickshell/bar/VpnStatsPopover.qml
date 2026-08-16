// The VPN STATISTICS popover (hover): verdict, a 60s graph, latency, jitter, loss, traffic,
// uptime. Why the scale starts at ZERO and why 360 wide: docs/notes/bar.md
import Quickshell
import QtQuick
import QtQuick.Layouts
import "root:/"

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

    component StatRow: RowLayout {
        id: sr
        property string label: ""
        property string value: ""
        property string hint: ""
        property color valueColor: Theme.colText

        Layout.fillWidth: true
        spacing: 10

        Text {
            Layout.minimumWidth: 62 // aligned labels: the value column does not dance
            text: sr.label
            color: Theme.colDim
            font.family: Theme.uiFont
            font.pixelSize: 11
        }
        Text {
            Layout.fillWidth: true
            text: sr.hint
            color: Theme.colDim
            font.family: Theme.uiFont
            font.pixelSize: 10
            horizontalAlignment: Text.AlignRight
        }
        Text {
            text: sr.value
            color: sr.valueColor
            font.family: Theme.uiFont
            font.pixelSize: 12
            font.bold: true
        }
    }

    Rectangle {
        id: card
        anchors.fill: parent
        implicitHeight: col.implicitHeight + 28
        radius: 12
        color: Theme.colBg
        border.color: Theme.colBorder
        border.width: 1

        HoverHandler {
            onHoveredChanged: statsPop.bar.vpnStatsPopHovered = hovered
        }

        ColumnLayout {
            id: col
            anchors.fill: parent
            anchors.margins: 14
            spacing: 10

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
                    Rectangle {
                        visible: blk.index > 0
                        Layout.fillWidth: true
                        Layout.topMargin: 4
                        Layout.bottomMargin: 4
                        implicitHeight: 1
                        color: Theme.colBorder
                        opacity: 0.5
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 10
                        Text {
                            text: "󰦝  " + blk.s.name
                            color: Theme.colAccent
                            font.family: Theme.uiFont
                            font.pixelSize: 13
                            font.bold: true
                        }
                        Item {
                            Layout.fillWidth: true
                        }
                        // The verdict: the line that answers "is it good?" without reading the rest.
                        Rectangle {
                            implicitWidth: verdict.implicitWidth + 18
                            implicitHeight: 20
                            radius: 6
                            color: "transparent"
                            border.color: blk.q.color
                            border.width: 1
                            Text {
                                id: verdict
                                anchors.centerIn: parent
                                text: blk.q.label
                                color: blk.q.color
                                font.family: Theme.uiFont
                                font.pixelSize: 10
                            }
                        }
                    }

                    // The graph: one bar per second, the most recent on the right.
                    Item {
                        Layout.fillWidth: true
                        Layout.topMargin: 3
                        implicitHeight: 40

                        Text {
                            anchors.centerIn: parent
                            visible: blk.series.length < 2
                            text: blk.s.probe ? "measuring…" : "no probe target inside the tunnel"
                            color: Theme.colDim
                            font.family: Theme.uiFont
                            font.pixelSize: 11
                            font.italic: true
                        }

                        RowLayout {
                            anchors.fill: parent
                            visible: blk.series.length >= 2
                            spacing: 1

                            Repeater {
                                model: blk.series
                                delegate: Item {
                                    id: sample
                                    required property var modelData
                                    // a lost packet = a full bar in faded red: the hole must JUMP OUT. The test is broad because the
                                    // series' null can arrive as undefined.
                                    readonly property bool dead: sample.modelData === null || sample.modelData === undefined || isNaN(sample.modelData)

                                    Layout.fillWidth: true
                                    Layout.fillHeight: true

                                    Rectangle {
                                        anchors.bottom: parent.bottom
                                        width: parent.width
                                        height: sample.dead ? parent.height : Math.max(2, parent.height * Math.min(1, sample.modelData / blk.scaleTop))
                                        radius: 1
                                        opacity: sample.dead ? 0.45 : 1
                                        color: sample.dead ? Theme.colRed : Theme.colTeal
                                    }
                                }
                            }
                        }
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

                    Rectangle {
                        Layout.fillWidth: true
                        Layout.topMargin: 5
                        implicitHeight: 1
                        color: Theme.colBorder
                        opacity: 0.5
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
}
