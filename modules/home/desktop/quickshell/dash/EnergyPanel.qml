// ENERGY, always in sight: the measured CPU + GPU watts, their split, the profile and the last 30 min.
// Never "the PC's power": the board, RAM, disks, PSU and monitors have no sensor. docs/notes/desktop/dash.md
import QtQuick
import QtQuick.Layouts
import "root:/"
import "root:/widgets"

ColumnLayout {
    id: panel
    spacing: 6

    function w(v, d) {
        return isNaN(v) ? "–" : v.toFixed(d) + " W";
    }

    Text {
        text: "ENERGY"
        color: Theme.colSubtext
        font.family: Theme.uiFont
        font.pixelSize: 13
        font.bold: true
        font.letterSpacing: 3
    }
    RowLayout {
        Layout.fillWidth: true
        spacing: 16
        Text {
            Tip {
                title: "CPU package + GPU board, measured"
                lines: ["power-log, one sample a minute", "the rest of the PC (board, RAM, disks, PSU, monitors) has no sensor", EnergyLog.doc.baseline ? "Eco at rest: " + EnergyLog.baseline.toFixed(1) + " W (" + EnergyLog.doc.baseline.condition + ")" : "no Eco rest baseline yet"]
            }
            text: EnergyLog.ok ? Math.round(EnergyLog.measured) + " W" : "–"
            color: EnergyLog.stale ? Theme.colDim : Theme.colText
            font.family: Theme.uiFont
            font.pixelSize: 44
            font.bold: true
            font.letterSpacing: -1
        }
        ColumnLayout {
            spacing: 2
            Text {
                text: "CPU " + panel.w(EnergyLog.cpu, 1) + "  ·  GPU " + panel.w(EnergyLog.gpu, 1)
                color: Theme.colText
                font.family: Theme.uiFont
                font.pixelSize: 15
            }
            Text {
                text: (EnergyLog.profile || "–") + "  ·  render idle " + (isNaN(EnergyLog.renderIdle) ? "–" : Math.round(EnergyLog.renderIdle) + "%")
                color: Theme.colSubtext
                font.family: Theme.uiFont
                font.pixelSize: 13
            }
        }
    }
    Sparkline {
        Layout.fillWidth: true
        Layout.fillHeight: true
        Layout.minimumHeight: 36
        series: EnergyLog.history
        scaleTop: Math.max(10, Math.ceil(EnergyLog.peak / 10) * 10)
        fill: Theme.colPeach
        placeholder: EnergyLog.ok ? "collecting…" : "no power-log samples"
    }
    Text {
        Layout.fillWidth: true
        elide: Text.ElideRight
        text: "CPU + GPU measured  ·  30 min, 0 to " + Math.max(10, Math.ceil(EnergyLog.peak / 10) * 10) + " W" + (isNaN(EnergyLog.baseline) ? "" : "  ·  Eco at rest " + Math.round(EnergyLog.baseline) + " W") + (EnergyLog.stale ? "  ·  STALE" : "")
        color: EnergyLog.stale ? Theme.colWarn : Theme.colDim
        font.family: Theme.uiFont
        font.pixelSize: 12
    }
}
