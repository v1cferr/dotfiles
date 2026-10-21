// ENERGY, always in sight: the measured CPU + GPU watts, their split, the profile and the last 30 min.
// Never "the PC's power": the board, RAM, disks, PSU and monitors have no sensor. docs/notes/desktop/dash.md
import QtQuick
import QtQuick.Layouts
import "root:/"
import "root:/widgets"
import "root:/data"

ColumnLayout {
    id: panel
    spacing: 8

    readonly property real scaleMax: Math.max(10, Math.ceil(Energy.peak / 10) * 10)
    function w(v, d) {
        return isNaN(v) ? "–" : v.toFixed(d) + " W";
    }

    // One share of the measured total: its name, its watts and a bar of its part.
    component Share: RowLayout {
        id: sh
        property string label
        property real watts: NaN
        Layout.fillWidth: true
        spacing: 10
        Text {
            Layout.preferredWidth: 36
            text: sh.label
            color: Theme.colSubtext
            font.family: Theme.uiFont
            font.pixelSize: 13
            font.bold: true
        }
        Text {
            Layout.preferredWidth: 74
            horizontalAlignment: Text.AlignRight
            text: panel.w(sh.watts, 1)
            color: Theme.colText
            font.family: Theme.uiFont
            font.pixelSize: 14
        }
        Rectangle {
            Layout.fillWidth: true
            implicitHeight: 5
            radius: 2.5
            color: Theme.colTrack
            Rectangle {
                width: parent.width * (Energy.ok && Energy.measured > 0 && !isNaN(sh.watts) ? Math.min(1, sh.watts / Energy.measured) : 0)
                height: parent.height
                radius: parent.radius
                color: Theme.colPeach
            }
        }
    }

    Text {
        text: "󱐋  ENERGY"
        color: Theme.colPeach
        font.family: Theme.uiFont
        font.pixelSize: 13
        font.bold: true
        font.letterSpacing: 3
    }
    RowLayout {
        Layout.fillWidth: true
        spacing: 22
        Row {
            Text {
                id: bigWatts
                Tip {
                    title: "CPU package + GPU board, measured"
                    lines: ["power-log, one sample a minute", "the rest of the PC (board, RAM, disks, PSU, monitors) has no sensor", Energy.doc.baseline ? "Eco at rest: " + Energy.baseline.toFixed(1) + " W (" + Energy.doc.baseline.condition + ")" : "no Eco rest baseline yet"]
                }
                text: Energy.ok ? Math.round(Energy.measured) : "–"
                color: Energy.stale ? Theme.colDim : Theme.colText
                font.family: Theme.uiFont
                font.pixelSize: 52
                font.bold: true
                font.letterSpacing: -2
            }
            Text {
                anchors.baseline: bigWatts.baseline
                text: " W"
                color: Theme.colSubtext
                font.family: Theme.uiFont
                font.pixelSize: 22
            }
        }
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 6
            Share {
                label: "CPU"
                watts: Energy.cpu
            }
            Share {
                label: "GPU"
                watts: Energy.gpu
            }
            Text {
                text: (Energy.profile || "–") + "  ·  render idle " + (isNaN(Energy.renderIdle) ? "–" : Math.round(Energy.renderIdle) + "%")
                color: Theme.colDim
                font.family: Theme.uiFont
                font.pixelSize: 12
            }
        }
    }
    Sparkline {
        Layout.fillWidth: true
        Layout.fillHeight: true
        Layout.minimumHeight: 36
        series: Energy.history
        scaleTop: panel.scaleMax
        fill: Theme.colPeach
        placeholder: Energy.ok ? "collecting…" : "no power-log samples"
    }
    Text {
        Layout.fillWidth: true
        elide: Text.ElideRight
        text: "CPU + GPU measured  ·  30 min, 0 to " + panel.scaleMax + " W" + (isNaN(Energy.baseline) ? "" : "  ·  Eco at rest " + Math.round(Energy.baseline) + " W") + (Energy.stale ? "  ·  STALE" : "")
        color: Energy.stale ? Theme.colWarn : Theme.colDim
        font.family: Theme.uiFont
        font.pixelSize: 12
    }
}
