// The standing monitor's bar, right half: OPERATIONAL CHIPS, "CI · 2" and "SVC · 1", from the one
// verdict in dash/Ops.qml. Silent when healthy, never "fine" on missing data; a hover opens the
// status panel (OpsPanel.qml), a click steers the band. docs/notes/desktop/bar.md#operational-chips
import QtQuick
import QtQuick.Layouts
import "root:/"
import "root:/dash"
import "root:/widgets"

RowLayout {
    id: ops
    required property var host // the Bar's Scope: panels, and the request that steers the band
    property var barContent: null
    property var barWindow: null
    property int maxWidth: 400 // past it the chips fold into one "OPS · N"

    spacing: Theme.sp1

    readonly property bool ciShown: Ops.needsLook(Ops.ci)
    readonly property bool svcShown: Ops.needsLook(Ops.svc)
    readonly property int alerts: (ops.ciShown ? Math.max(1, Ops.ci.count) : 0) + (ops.svcShown ? Math.max(1, Ops.svc.count) : 0)
    // The two chips' widths from a template, so a count changing never moves them, and the fold
    // decision never reads the chips it hides.
    readonly property int chipW: Math.ceil(tmChip.advanceWidth) + Theme.iconBar + Theme.sp1 + 2 * Theme.sp2
    readonly property bool folded: ops.ciShown && ops.svcShown && 2 * ops.chipW + ops.spacing > ops.maxWidth
    // The worse of the two, for the folded chip.
    readonly property string worst: {
        const r = {
            fail: 0,
            degraded: 1,
            stale: 2,
            unknown: 3,
            run: 4,
            ok: 5
        };
        return r[Ops.ci.state] <= r[Ops.svc.state] ? Ops.ci.state : Ops.svc.state;
    }
    TextMetrics {
        id: tmChip
        font.family: Theme.uiFont
        font.pixelSize: Theme.fontBody
        font.bold: true
        text: "SVC · 00"
    }

    function label(name, s) {
        return name + " · " + (s.state === "unknown" ? "?" : s.count);
    }

    Pill {
        id: ciPill
        visible: !ops.folded && ops.ciShown
        Layout.preferredWidth: ops.chipW
        icon: Ops.icon(Ops.ci.state)
        label: ops.label("CI", Ops.ci)
        bold: true
        accent: Ops.tone(Ops.ci.state)
        labelColor: Ops.ci.state === "stale" || Ops.ci.state === "unknown" ? Theme.colSubtext : Ops.tone(Ops.ci.state)
        fill: Qt.alpha(Ops.tone(Ops.ci.state), 0.14)
        selected: ops.host.panelOpen === "ops-ci"
        onHoveredChanged: ops.host.hoverPanel("ops-ci", ciPill, ops.barContent, ops.barWindow, hovered)
        onClicked: {
            ops.host.closePanels();
            ops.host.dashRequested("ci");
        }
    }
    Pill {
        id: svcPill
        visible: !ops.folded && ops.svcShown
        Layout.preferredWidth: ops.chipW
        icon: Ops.icon(Ops.svc.state)
        label: ops.label("SVC", Ops.svc)
        bold: true
        accent: Ops.tone(Ops.svc.state)
        labelColor: Ops.svc.state === "stale" || Ops.svc.state === "unknown" ? Theme.colSubtext : Ops.tone(Ops.svc.state)
        fill: Qt.alpha(Ops.tone(Ops.svc.state), 0.14)
        selected: ops.host.panelOpen === "ops-svc"
        onHoveredChanged: ops.host.hoverPanel("ops-svc", svcPill, ops.barContent, ops.barWindow, hovered)
        onClicked: {
            ops.host.closePanels();
            ops.host.dashRequested("svc");
        }
    }
    Pill {
        id: foldPill
        visible: ops.folded
        Layout.preferredWidth: ops.chipW
        icon: Ops.icon(ops.worst)
        label: "OPS · " + ops.alerts
        bold: true
        accent: Ops.tone(ops.worst)
        labelColor: Ops.tone(ops.worst)
        fill: Qt.alpha(Ops.tone(ops.worst), 0.14)
        selected: ops.host.panelOpen === "ops"
        onHoveredChanged: ops.host.hoverPanel("ops", foldPill, ops.barContent, ops.barWindow, hovered)
        onClicked: {
            ops.host.closePanels();
            ops.host.dashRequested(Ops.ci.state !== "ok" ? "ci" : "svc");
        }
    }
    // Healthy, and confirmed by both feeds: one dim check, so a quiet bar still says it is reading.
    Text {
        visible: !ops.ciShown && !ops.svcShown
        text: "󰄬"
        color: Theme.colDim
        font.family: Theme.uiFont
        font.pixelSize: Theme.iconBar
        Layout.rightMargin: Theme.sp2
    }
}
