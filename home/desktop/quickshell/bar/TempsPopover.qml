// The TEMPERATURES panel (hover): the verdict, 2 minutes of the hottest sensor, and every sensor
// against ITS OWN ceiling. Why the ceiling and not /100: docs/notes/desktop/bar.md
import Quickshell
import QtQuick
import QtQuick.Layouts
import "root:/"
import "root:/widgets"

PanelWindow {
    id: pop
    required property var bar

    visible: bar.metricPopVisible && bar.metricShown === "temp"
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

    // The window's extremes: a temperature that only matters when it PEAKED is invisible in an
    // average, and the peak is exactly what you open this panel to find.
    readonly property var histRange: {
        const h = pop.bar.tempHist || [];
        if (h.length === 0)
            return null;
        let lo = h[0], hi = h[0];
        for (let i = 1; i < h.length; i++) {
            if (h[i] < lo)
                lo = h[i];
            if (h[i] > hi)
                hi = h[i];
        }
        return {
            lo: Math.round(lo),
            hi: Math.round(hi)
        };
    }

    PopCard {
        id: card
        onHoveredChanged: pop.bar.metricPopHovered = card.hovered

        PopHeader {
            title: "Temperatures"
            verdict: pop.bar.tempQuality.label
            verdictColor: pop.bar.tempQuality.color
        }

        // The scale is FIXED at 0 to 100 °C and does not follow the hottest sensor's ceiling: a
        // scale that moves under the drawing turns a steady line into a scare.
        Sparkline {
            Layout.fillWidth: true
            series: pop.bar.tempHist
            scaleTop: 100
            fill: Theme.colSapphire
            placeholder: "measuring…"
        }
        RowLayout {
            Layout.fillWidth: true
            spacing: 10
            Text {
                Layout.fillWidth: true
                text: "last " + Math.round((pop.bar.tempHist || []).length * pop.bar.sysInterval / 1000) + "s · the hottest sensor · 0 to 100 °C"
                color: Theme.colDim
                font.family: Theme.uiFont
                font.pixelSize: 9
            }
            Text {
                visible: pop.histRange !== null
                text: pop.histRange ? "min " + pop.histRange.lo + " · max " + pop.histRange.hi + "°" : ""
                color: Theme.colDim
                font.family: Theme.uiFont
                font.pixelSize: 9
            }
        }

        // One block per chip: the primary sensor with its bar, and the chip's remaining sensors
        // condensed below it.
        Repeater {
            model: pop.bar.tempList

            delegate: ColumnLayout {
                id: blk
                required property var modelData
                readonly property string detail: pop.bar.tempDetail(blk.modelData.chip, blk.modelData.label)

                Layout.fillWidth: true
                Layout.topMargin: 3
                spacing: 2

                MeterRow {
                    label: blk.modelData.name
                    labelWidth: 52
                    // The ceiling comes from the sensor itself: `crit` is where the hardware gives
                    // up, `max` is where it starts throttling.
                    hint: blk.modelData.crit > 0 ? "of " + Math.round(blk.modelData.crit) + "° crit" + (blk.modelData.max > 0 ? " · throttles at " + Math.round(blk.modelData.max) + "°" : "") : (blk.modelData.max > 0 ? "of " + Math.round(blk.modelData.max) + "° max" : "no limit published")
                    value: blk.modelData.temp + "°C"
                    frac: pop.bar.tempFrac(blk.modelData)
                    barColor: pop.bar.tempColor(blk.modelData)
                }
                Text {
                    visible: blk.detail !== ""
                    Layout.fillWidth: true
                    text: blk.modelData.label + " · " + blk.detail
                    color: Theme.colDim
                    font.family: Theme.uiFont
                    font.pixelSize: 9
                    elide: Text.ElideRight
                }
            }
        }

        Hairline {
            Layout.topMargin: 3
        }

        // A stopped fan is NOT a broken fan on this card: it idles at zero RPM and only spins up
        // under load, so the row says so instead of showing an alarming 0.
        StatRow {
            visible: pop.bar.gpuFan >= 0
            label: "GPU fan"
            labelWidth: 62
            hint: pop.bar.gpuFan === 0 ? "zero-RPM idle, it spins up under load" : ""
            value: pop.bar.gpuFan === 0 ? "stopped" : Math.round(pop.bar.gpuFan) + " rpm"
            valueColor: Theme.colText
        }
        StatRow {
            visible: pop.bar.gpuWattsCap > 0
            label: "GPU power"
            labelWidth: 62
            hint: "what the board draws right now"
            value: pop.bar.gpuWatts.toFixed(1) + " W"
        }

        Hairline {
            Layout.topMargin: 3
        }

        Text {
            Layout.fillWidth: true
            text: pop.bar.hwTemps.length + " sensors · " + pop.bar.tempChips.join(" · ")
            color: Theme.colDim
            font.family: Theme.uiFont
            font.pixelSize: 10
            elide: Text.ElideRight
        }
    }
}
