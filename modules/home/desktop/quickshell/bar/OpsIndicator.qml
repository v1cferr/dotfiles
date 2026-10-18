// The standing monitor's bar, right half: what needs a look, per source (CI, services), from the
// feeds the band already reads. Silent when healthy, never "fine" on missing data: docs/notes/desktop/bar.md
import QtQuick
import QtQuick.Layouts
import "root:/"
import "root:/dash"
import "root:/widgets"

RowLayout {
    id: ops
    required property var host // the Bar's Scope: hints, and the request that steers the band
    property var barContent: null
    property var barWindow: null
    property int maxWidth: 400 // past it the sources fold into one "N alerts"

    spacing: Theme.sp1

    // One forge: what its LATEST runs say. The feed keeps the newest run of each workflow (or ref),
    // so a failure a later run fixed is already gone, and only a failure that still stands counts.
    function forge(src, expected) {
        if (!Ci.loaded)
            return {
                state: "unknown",
                fail: 0,
                run: 0,
                why: "not read yet"
            };
        const runs = src.runs || [];
        const fail = runs.filter(r => r.state === "failure").length;
        const run = runs.filter(r => r.state === "running" || r.state === "queued").length;
        if (!src.ok && !src.stale)
            return {
                state: expected ? "unknown" : "absent",
                fail: 0,
                run: 0,
                why: src.error || "no answer"
            };
        return {
            state: src.stale ? "stale" : (fail > 0 ? "fail" : (run > 0 ? "run" : "ok")),
            fail: fail,
            run: run,
            why: src.stale ? "offline since " + Ci.agoSec(src.staleSince) : ""
        };
    }
    readonly property var gh: ops.forge(Ci.github, true)
    readonly property var gl: ops.forge(Ci.gitlab, Ci.gitlabShown)
    // CI as one source: a failure anywhere wins, then a forge we cannot read, then work in progress.
    readonly property var ci: {
        const f = ops.gh.fail + ops.gl.fail;
        const parts = [ops.gh, ops.gl].filter(x => x.state !== "absent");
        const blind = parts.some(x => x.state === "unknown" || x.state === "stale");
        return {
            fail: f,
            blind: blind,
            stale: parts.some(x => x.state === "stale"),
            run: f === 0 && !blind && parts.some(x => x.state === "run")
        };
    }
    // Services: the meta script answers every 30 s, so two minutes of silence is stale, not healthy.
    readonly property var svc: {
        const list = Services.meta || [];
        // Ci.now ticks every 30 s, which is what lets this binding notice the feed going quiet.
        const age = Services.fetched > 0 ? Ci.now.getTime() / 1000 - Services.fetched : Infinity;
        const bad = list.filter(s => s.state !== "up");
        return {
            fail: bad.length,
            down: bad.some(s => s.state === "down"),
            blind: list.length === 0 || age > 120,
            stale: list.length > 0 && age > 120
        };
    }
    readonly property int alerts: ops.ci.fail + ops.svc.fail + (ops.ci.blind ? 1 : 0) + (ops.svc.blind ? 1 : 0)
    // Folded to one line when the two would not fit the room the bar leaves.
    readonly property bool folded: ciPill.implicitWidth + svcPill.implicitWidth + ops.spacing > ops.maxWidth

    function label(name, s) {
        return s.fail > 0 ? name + " " + s.fail : (s.blind ? name + " ?" : name);
    }
    function tone(s, failTone) {
        return s.fail > 0 ? failTone : (s.stale ? Theme.colPeach : Theme.colDim);
    }

    Pill {
        id: ciPill
        visible: !ops.folded && (ops.ci.fail > 0 || ops.ci.blind || ops.ci.run)
        label: ops.ci.run ? "CI" : ops.label("CI", ops.ci)
        icon: ops.ci.run ? "󰑮" : ""
        accent: ops.ci.run ? Theme.colAccent : ops.tone(ops.ci, Theme.colRed)
        onHoveredChanged: ops.host.hoverHint("ops-ci", ciPill, ops.barContent, ops.barWindow, hovered)
        onClicked: ops.host.dashRequested("ci")
    }
    Pill {
        id: svcPill
        visible: !ops.folded && (ops.svc.fail > 0 || ops.svc.blind)
        label: ops.label("SVC", ops.svc)
        accent: ops.tone(ops.svc, ops.svc.down ? Theme.colRed : Theme.colPeach)
        onHoveredChanged: ops.host.hoverHint("ops-svc", svcPill, ops.barContent, ops.barWindow, hovered)
        onClicked: ops.host.dashRequested("svc")
    }
    Pill {
        id: foldPill
        visible: ops.folded && ops.alerts > 0
        label: ops.alerts + (ops.alerts === 1 ? " alert" : " alerts")
        accent: ops.ci.fail > 0 || ops.svc.down ? Theme.colRed : Theme.colPeach
        onHoveredChanged: ops.host.hoverHint("ops", foldPill, ops.barContent, ops.barWindow, hovered)
        onClicked: ops.host.dashRequested(ops.ci.fail > 0 || ops.ci.blind ? "ci" : "svc")
    }
    // Healthy: one dim check, so a quiet bar still says it is reading, and nothing asks for the eye.
    Text {
        visible: ops.alerts === 0 && !ops.ci.run
        text: "󰄬"
        color: Theme.colDim
        font.family: Theme.uiFont
        font.pixelSize: Theme.fontLabel
        Layout.rightMargin: Theme.sp2
    }
}
