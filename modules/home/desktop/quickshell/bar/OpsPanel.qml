// The OPERATIONAL panel (hover on a standing-monitor chip): status first. The verdict and how fresh
// it is, then each source with what is failing, then the way to the band. Keys "ops-ci", "ops-svc"
// and "ops" (both, from the folded chip). One model with the chips: dash/Ops.qml. docs/notes/desktop/bar.md
import Quickshell
import QtQuick
import QtQuick.Layouts
import "root:/"
import "root:/dash"
import "root:/widgets"

BarPanel {
    id: pop
    readonly property bool showCi: pop.key !== "ops-svc"
    readonly property bool showSvc: pop.key !== "ops-ci"
    // The state the header speaks for: the worse of what this panel shows.
    readonly property var rank: ({
            fail: 0,
            degraded: 1,
            stale: 2,
            unknown: 3,
            run: 4,
            ok: 5
        })
    readonly property string state0: {
        const a = pop.showCi ? Ops.ci.state : "ok";
        const b = pop.showSvc ? Ops.svc.state : "ok";
        return pop.rank[a] <= pop.rank[b] ? a : b;
    }
    readonly property var firstFailing: Ops.ci.failing.length > 0 ? Ops.ci.failing[0] : null

    implicitWidth: 380
    implicitHeight: card.implicitHeight
    // A fresh "updated" line: the cache is re-read (no network) each time the panel opens.
    onVisibleChanged: if (pop.visible && pop.showCi)
        Ci.refresh()

    function summary() {
        const parts = [];
        if (pop.showCi) {
            const c = Ops.ci;
            parts.push(c.state === "fail" ? c.count + (c.count === 1 ? " failing pipeline" : " failing pipelines") : c.state === "stale" ? "CI: last known " + c.count + " failing" : c.state === "unknown" ? "CI not read" : c.state === "run" ? c.count + " running" : "CI passing");
        }
        if (pop.showSvc) {
            const s = Ops.svc;
            parts.push(s.state === "ok" ? "all " + s.total + " services up" : s.state === "unknown" ? "services not read" : s.state === "stale" ? "services: last known " + s.count + " not up" : s.count + (s.count === 1 ? " service" : " services") + " not up");
        }
        const t = parts.join(" · ");
        return t.charAt(0).toUpperCase() + t.slice(1);
    }
    function freshness() {
        const lines = [];
        if (pop.showCi)
            lines.push(Ops.ci.state === "unknown" ? "CI unavailable" : Ops.ci.state === "stale" ? "CI is the last known state" : "CI updated " + (Ci.checkedAt > 0 ? (Ci.agoSec(Ci.checkedAt) === "now" ? "now" : Ci.agoSec(Ci.checkedAt) + " ago") : "at an unknown time"));
        if (pop.showSvc)
            lines.push(Services.fetched <= 0 ? "Services unavailable" : Ops.svc.state === "stale" ? "Services stale since " + Ci.agoSec(Services.fetched) + " ago" : "Services updated " + (Ci.agoSec(Services.fetched) === "now" ? "now" : Ci.agoSec(Services.fetched) + " ago"));
        return lines.join(" · ");
    }

    PopCard {
        shown: pop.visible
        id: card
        pad: Theme.sp4
        gap: Theme.sp3
        onHoveredChanged: pop.bar.panelPopHovered = card.hovered

        // ── Header: the verdict, what it means, how fresh it is ──
        PopHeader {
            title: pop.key === "ops-svc" ? "Services" : (pop.key === "ops-ci" ? "CI" : "Operations")
            icon: Ops.icon(pop.state0)
            verdict: Ops.word(pop.state0)
            verdictColor: Ops.tone(pop.state0)
        }
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 2
            Text {
                Layout.fillWidth: true
                text: pop.summary()
                color: Theme.colText
                font.family: Theme.uiFont
                font.pixelSize: Theme.fontBody
                font.bold: true
                elide: Text.ElideRight
            }
            Text {
                Layout.fillWidth: true
                text: pop.freshness()
                color: Theme.colDim
                font.family: Theme.uiFont
                font.pixelSize: Theme.fontSmall
                wrapMode: Text.WordWrap
            }
        }

        // ── Body: CI, one block per forge ──
        Repeater {
            model: pop.showCi ? Ops.forges : []
            delegate: ColumnLayout {
                id: forgeBlock
                required property var modelData
                Layout.fillWidth: true
                spacing: Theme.sp1
                RowLayout {
                    Layout.fillWidth: true
                    spacing: Theme.sp2
                    Text {
                        text: Ops.icon(forgeBlock.modelData.state)
                        color: Ops.tone(forgeBlock.modelData.state)
                        font.family: Theme.uiFont
                        font.pixelSize: Theme.iconBar
                    }
                    Text {
                        Layout.fillWidth: true
                        text: forgeBlock.modelData.name
                        color: Theme.colText
                        font.family: Theme.uiFont
                        font.pixelSize: Theme.fontBody
                        font.bold: true
                    }
                    Text {
                        text: forgeBlock.modelData.state === "fail" ? forgeBlock.modelData.fail + " failing" : forgeBlock.modelData.state === "run" ? forgeBlock.modelData.run + " running" : forgeBlock.modelData.state === "ok" ? "Healthy" : forgeBlock.modelData.state === "stale" ? "Stale" : "Unknown"
                        color: Ops.tone(forgeBlock.modelData.state)
                        font.family: Theme.uiFont
                        font.pixelSize: Theme.fontSmall
                    }
                }
                Text {
                    visible: forgeBlock.modelData.why !== ""
                    Layout.fillWidth: true
                    Layout.leftMargin: Theme.iconBar + Theme.sp2
                    text: forgeBlock.modelData.why
                    color: Theme.colDim
                    font.family: Theme.uiFont
                    font.pixelSize: Theme.fontSmall
                    elide: Text.ElideRight
                }
                Repeater {
                    model: forgeBlock.modelData.failing.slice(0, 4)
                    delegate: RowLayout {
                        id: runRow
                        required property var modelData
                        Layout.fillWidth: true
                        Layout.leftMargin: Theme.iconBar + Theme.sp2
                        spacing: Theme.sp2
                        Text {
                            Layout.fillWidth: true
                            text: runRow.modelData.repo.split("/").pop() + "  " + runRow.modelData.name
                            color: Theme.colSubtext
                            font.family: Theme.uiFont
                            font.pixelSize: Theme.fontSmall
                            elide: Text.ElideRight
                        }
                        Text {
                            text: runRow.modelData.finished ? Ci.ago(runRow.modelData.finished) : ""
                            color: Theme.colDim
                            font.family: Theme.uiFont
                            font.pixelSize: Theme.fontSmall
                        }
                    }
                }
                Text {
                    visible: forgeBlock.modelData.failing.length > 4
                    Layout.leftMargin: Theme.iconBar + Theme.sp2
                    text: "+" + (forgeBlock.modelData.failing.length - 4) + " more on the dashboard"
                    color: Theme.colDim
                    font.family: Theme.uiFont
                    font.pixelSize: Theme.fontSmall
                }
            }
        }

        // ── Body: the services that are not up ──
        ColumnLayout {
            visible: pop.showSvc
            Layout.fillWidth: true
            spacing: Theme.sp1
            RowLayout {
                Layout.fillWidth: true
                spacing: Theme.sp2
                Text {
                    text: Ops.icon(Ops.svc.state)
                    color: Ops.tone(Ops.svc.state)
                    font.family: Theme.uiFont
                    font.pixelSize: Theme.iconBar
                }
                Text {
                    Layout.fillWidth: true
                    text: "Services"
                    color: Theme.colText
                    font.family: Theme.uiFont
                    font.pixelSize: Theme.fontBody
                    font.bold: true
                }
                Text {
                    text: Ops.svc.total > 0 ? (Ops.svc.total - Ops.svc.count) + " of " + Ops.svc.total + " up" : "No data"
                    color: Ops.tone(Ops.svc.state)
                    font.family: Theme.uiFont
                    font.pixelSize: Theme.fontSmall
                }
            }
            Repeater {
                model: Ops.svc.bad.slice(0, 6)
                delegate: RowLayout {
                    id: svcRow
                    required property var modelData
                    Layout.fillWidth: true
                    Layout.leftMargin: Theme.iconBar + Theme.sp2
                    spacing: Theme.sp2
                    Text {
                        Layout.fillWidth: true
                        text: svcRow.modelData.label || svcRow.modelData.key
                        color: Theme.colSubtext
                        font.family: Theme.uiFont
                        font.pixelSize: Theme.fontSmall
                        elide: Text.ElideRight
                    }
                    Text {
                        text: (svcRow.modelData.running !== undefined ? svcRow.modelData.running + "/" + svcRow.modelData.expected + " · " : "") + svcRow.modelData.state
                        color: svcRow.modelData.state === "down" ? Theme.colCrit : Theme.colAlert
                        font.family: Theme.uiFont
                        font.pixelSize: Theme.fontSmall
                    }
                }
            }
        }

        // ── Footer: the band first; the failing run itself when there is one ──
        Hairline {}
        RowLayout {
            Layout.fillWidth: true
            spacing: Theme.sp2
            Repeater {
                model: [
                    {
                        label: "Show on dashboard",
                        primary: true,
                        shown: true
                    },
                    {
                        label: "Open details",
                        primary: false,
                        shown: pop.showCi && pop.firstFailing !== null && !!pop.firstFailing.url
                    }
                ]
                delegate: Rectangle {
                    id: act
                    required property var modelData
                    visible: act.modelData.shown
                    Layout.fillWidth: true
                    implicitHeight: Theme.barControl
                    radius: Theme.radiusControl
                    color: actArea.containsMouse ? (act.modelData.primary ? Theme.colMenuHoverBg : Theme.colHoverFill) : (act.modelData.primary ? Theme.colSelectFill : "transparent")
                    Behavior on color {
                        ColorAnimation {
                            duration: Theme.motionHover
                        }
                    }
                    Accessible.role: Accessible.Button
                    Accessible.name: act.modelData.label
                    Text {
                        anchors.centerIn: parent
                        text: act.modelData.label
                        color: act.modelData.primary ? Theme.colText : Theme.colSubtext
                        font.family: Theme.uiFont
                        font.pixelSize: Theme.fontSmall
                        font.bold: act.modelData.primary
                    }
                    MouseArea {
                        id: actArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (act.modelData.primary)
                                pop.bar.dashRequested(pop.key === "ops-svc" || (pop.key === "ops" && Ops.ci.state === "ok") ? "svc" : "ci");
                            else
                                pop.bar.launch(["xdg-open", pop.firstFailing.url]);
                            pop.bar.closePanels();
                        }
                    }
                }
            }
        }
    }
}
