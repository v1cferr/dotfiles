// The USAGE panel (hover): the verdict, 2 minutes of CPU, per thread, memory, swap, the GPU, the
// disk and who is eating the machine. The state lives in the Bar: docs/notes/desktop/bar.md
import Quickshell
import QtQuick
import QtQuick.Layouts
import "root:/"
import "root:/widgets"

PanelWindow {
    id: pop
    required property var bar

    visible: bar.metricPopVisible && bar.metricShown === "usage"
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

    readonly property real gb: 1073741824
    function fmtGb(b) {
        return (b / pop.gb).toFixed(1);
    }
    // The window's average: the sparkline shows the SHAPE, this says what it settled around.
    readonly property int cpuAvg: {
        const h = pop.bar.cpuHist || [];
        if (h.length === 0)
            return 0;
        let s = 0;
        for (let i = 0; i < h.length; i++)
            s += h[i];
        return Math.round(s / h.length);
    }

    // One row of the "heaviest" table. It is a component and not a MeterRow because what matters
    // here is the NAME plus two percentages, with no bar to draw.
    component ProcRow: RowLayout {
        id: pr
        property var proc: null

        Layout.fillWidth: true
        spacing: 10
        Text {
            Layout.fillWidth: true
            text: pr.proc ? pr.proc.name : ""
            color: Theme.colText
            font.family: Theme.uiFont
            font.pixelSize: 11
            elide: Text.ElideRight
        }
        Text {
            text: pr.proc ? pr.proc.cpu.toFixed(1) + "%" : ""
            color: Theme.colDim
            font.family: Theme.uiFont
            font.pixelSize: 11
            horizontalAlignment: Text.AlignRight
            Layout.minimumWidth: 42
        }
        Text {
            text: pr.proc ? pr.proc.mem.toFixed(1) + "%" : ""
            color: Theme.colDim
            font.family: Theme.uiFont
            font.pixelSize: 11
            horizontalAlignment: Text.AlignRight
            Layout.minimumWidth: 42
        }
    }

    PopCard {
        id: card
        onHoveredChanged: pop.bar.metricPopHovered = card.hovered

        PopHeader {
            title: "Usage"
            verdict: pop.bar.usageQuality.label
            verdictColor: pop.bar.usageQuality.color
        }

        Sparkline {
            Layout.fillWidth: true
            series: pop.bar.cpuHist
            scaleTop: 100 // a percentage has a REAL ceiling, so the scale is fixed and two panels compare
            fill: Theme.colAccent
            placeholder: "measuring…"
        }
        RowLayout {
            Layout.fillWidth: true
            spacing: 10
            Text {
                Layout.fillWidth: true
                text: "last " + Math.round((pop.bar.cpuHist || []).length * pop.bar.sysInterval / 1000) + "s · 1 sample/" + (pop.bar.sysInterval / 1000) + "s"
                color: Theme.colDim
                font.family: Theme.uiFont
                font.pixelSize: 9
            }
            Text {
                text: "avg " + pop.cpuAvg + "%"
                color: Theme.colDim
                font.family: Theme.uiFont
                font.pixelSize: 9
            }
        }

        // One bar per THREAD: an average of 20% is a different machine when it is one core pinned
        // and when it is twelve at a fifth, and only the shape tells them apart.
        RowLayout {
            Layout.fillWidth: true
            Layout.topMargin: 2
            spacing: 2
            Repeater {
                model: pop.bar.cpuCoreP

                delegate: Item {
                    id: core
                    required property var modelData

                    Layout.fillWidth: true
                    implicitHeight: 16

                    Rectangle {
                        anchors.fill: parent
                        radius: 2
                        color: Theme.colTrack
                    }
                    Rectangle {
                        anchors.bottom: parent.bottom
                        width: parent.width
                        height: Math.max(2, parent.height * Math.min(1, core.modelData / 100))
                        radius: 2
                        color: pop.bar.stateColor(core.modelData, Theme.colAccent)
                        Behavior on height {
                            NumberAnimation {
                                duration: 300
                                easing.type: Easing.OutCubic
                            }
                        }
                    }
                }
            }
        }

        MeterRow {
            label: "CPU"
            labelWidth: 74
            hint: pop.bar.cpuMhz > 0 ? (pop.bar.cpuMhz / 1000).toFixed(2) + " of " + (pop.bar.cpuMhzMax / 1000).toFixed(2) + " GHz" : ""
            value: pop.bar.cpuPct + "%"
            frac: pop.bar.cpuPct / 100
            barColor: pop.bar.stateColor(pop.bar.cpuPct, Theme.colAccent)
        }
        StatRow {
            // Per THREAD and not raw: "load 8" means nothing without knowing there are 12 of them.
            label: "Load"
            labelWidth: 74
            hint: pop.bar.cpuThreads + " threads · " + (pop.bar.cpuThreads > 0 ? Math.round(pop.bar.loadAvg[0] / pop.bar.cpuThreads * 100) : 0) + "%"
            value: pop.bar.loadAvg[0].toFixed(2) + " · " + pop.bar.loadAvg[1].toFixed(2) + " · " + pop.bar.loadAvg[2].toFixed(2)
            valueColor: pop.bar.cpuThreads > 0 && pop.bar.loadAvg[0] / pop.bar.cpuThreads >= 0.7 ? Theme.colPeach : Theme.colText
        }
        MeterRow {
            // MemAvailable, so the cache does not read as "used": the cache is memory you HAVE.
            label: "RAM"
            labelWidth: 74
            hint: pop.fmtGb(pop.bar.memTotal - pop.bar.memAvail) + " of " + pop.fmtGb(pop.bar.memTotal) + " GB"
            value: pop.bar.memPct + "%"
            frac: pop.bar.memPct / 100
            barColor: pop.bar.stateColor(pop.bar.memPct, Theme.colAccent)
        }
        StatRow {
            label: "Cache"
            labelWidth: 74
            hint: "reclaimable, already counted as free"
            value: pop.fmtGb(pop.bar.memCached) + " GB"
        }
        MeterRow {
            visible: pop.bar.swapTotal > 0
            label: "Swap"
            labelWidth: 74
            hint: pop.fmtGb(pop.bar.swapUsed) + " of " + pop.fmtGb(pop.bar.swapTotal) + " GB"
            value: pop.bar.swapTotal > 0 ? Math.round(pop.bar.swapUsed / pop.bar.swapTotal * 100) + "%" : "0%"
            frac: pop.bar.swapTotal > 0 ? pop.bar.swapUsed / pop.bar.swapTotal : 0
            barColor: Theme.colMauve
        }
        // The kernel saying it OUT LOUD: only shows up when something actually stalled, because a
        // row pinned at 0.0 trains the eye to skip exactly the day it moves.
        StatRow {
            visible: pop.bar.psiCpu > 0 || pop.bar.psiMem > 0 || pop.bar.psiIo > 0
            label: "Stalls"
            labelWidth: 74
            hint: "cpu · memory · io, the last 10s"
            value: pop.bar.psiCpu.toFixed(1) + " · " + pop.bar.psiMem.toFixed(1) + " · " + pop.bar.psiIo.toFixed(1) + "%"
            valueColor: pop.bar.psiMem >= 10 || pop.bar.psiIo >= 20 ? Theme.colRed : Theme.colPeach
        }

        Hairline {
            Layout.topMargin: 2
        }

        // The GPU has NO usage percentage on xe (the driver does not publish one), so what stands
        // here is what the card actually measures: how fast it is running and what it is drawing.
        MeterRow {
            visible: pop.bar.gpuFreqMax > 0
            label: "GPU clock"
            labelWidth: 74
            hint: pop.bar.gpuFreq + " of " + pop.bar.gpuFreqMax + " MHz"
            value: Math.round(pop.bar.gpuFreq / Math.max(1, pop.bar.gpuFreqMax) * 100) + "%"
            frac: pop.bar.gpuFreq / Math.max(1, pop.bar.gpuFreqMax)
            barColor: Theme.colTeal
        }
        MeterRow {
            visible: pop.bar.gpuWattsCap > 0
            label: "GPU power"
            labelWidth: 74
            hint: "the whole board, cap " + Math.round(pop.bar.gpuWattsCap) + " W"
            value: pop.bar.gpuWatts.toFixed(1) + " W"
            frac: pop.bar.gpuWatts / Math.max(1, pop.bar.gpuWattsCap)
            barColor: Theme.colSky
        }
        MeterRow {
            label: "Disk"
            labelWidth: 74
            hint: pop.fmtGb(pop.bar.diskUsed) + " of " + pop.fmtGb(pop.bar.diskTotal) + " GB " + pop.bar.diskFs
            value: pop.bar.diskPct + "%"
            frac: pop.bar.diskPct / 100
            barColor: pop.bar.stateColor(pop.bar.diskPct, Theme.colAccent)
        }
        StatRow {
            label: "Disk I/O"
            labelWidth: 74
            hint: pop.bar.diskDev
            value: "↓" + pop.bar.fmtRate(pop.bar.diskReadBps) + "/s   ↑" + pop.bar.fmtRate(pop.bar.diskWriteBps) + "/s"
        }

        Hairline {
            Layout.topMargin: 2
        }

        // "Who is eating it" is the question the aggregate cannot answer, and the reason this panel
        // beats staring at a number. It is only polled while the panel is open.
        RowLayout {
            Layout.fillWidth: true
            spacing: 10
            Text {
                Layout.fillWidth: true
                text: "Heaviest"
                color: Theme.colDim
                font.family: Theme.uiFont
                font.pixelSize: 10
            }
            Text {
                text: "cpu"
                color: Theme.colDim
                font.family: Theme.uiFont
                font.pixelSize: 9
                horizontalAlignment: Text.AlignRight
                Layout.minimumWidth: 42
            }
            Text {
                text: "ram"
                color: Theme.colDim
                font.family: Theme.uiFont
                font.pixelSize: 9
                horizontalAlignment: Text.AlignRight
                Layout.minimumWidth: 42
            }
        }
        Repeater {
            model: pop.bar.topCpu

            delegate: ProcRow {
                required property var modelData
                proc: modelData
            }
        }
        Text {
            visible: (pop.bar.topMem || []).length > 0
            Layout.topMargin: 2
            text: "by memory"
            color: Theme.colDim
            font.family: Theme.uiFont
            font.pixelSize: 9
        }
        Repeater {
            model: pop.bar.topMem

            delegate: ProcRow {
                required property var modelData
                proc: modelData
            }
        }

        Hairline {
            Layout.topMargin: 2
        }

        Text {
            Layout.fillWidth: true
            text: pop.bar.cpuModel + " · " + pop.bar.cpuCores + "c/" + pop.bar.cpuThreads + "t"
            color: Theme.colDim
            font.family: Theme.uiFont
            font.pixelSize: 10
            elide: Text.ElideRight
        }
        Text {
            Layout.fillWidth: true
            text: "up " + pop.bar.fmtDur(pop.bar.uptimeSec)
            color: Theme.colDim
            font.family: Theme.uiFont
            font.pixelSize: 10
        }
    }
}
