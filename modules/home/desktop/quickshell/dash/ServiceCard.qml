// One service on the strip: what it is and whether it is whole (line 1), what it costs now and over
// the last 2 minutes (line 2); the rest is in its tooltip. A click opens its site, or its live log
// when it has none (Services.open).
import QtQuick
import QtQuick.Layouts
import "root:/"
import "root:/widgets"

Rectangle {
    id: card

    property var s: ({})
    readonly property bool up: card.s.state === "up"
    readonly property color stateColor: card.s.state === "down" ? Theme.colRed : (card.s.state === "degraded" ? Theme.colPeach : Theme.colGreen)
    // The sparkline's ceiling follows the service's own peak: an idle daemon at 0.03% still has a shape.
    readonly property real cpuTop: Math.max(0.2, Math.max.apply(null, (card.s.hist || []).concat([0])) * 1.25)

    function fmtBytes(b) {
        if (b >= 1073741824)
            return (b / 1073741824).toFixed(1) + " GB";
        if (b >= 1048576)
            return Math.round(b / 1048576) + " MB";
        if (b >= 1024)
            return Math.round(b / 1024) + " KB";
        return Math.round(b) + " B";
    }
    function fmtUp(since) {
        if (!since)
            return "";
        const m = Math.max(0, Math.floor((Services.now / 1000 - since) / 60));
        if (m < 60)
            return m + "m";
        if (m < 1440)
            return Math.floor(m / 60) + "h " + (m % 60) + "m";
        return Math.floor(m / 1440) + "d " + Math.floor((m % 1440) / 60) + "h";
    }

    radius: 10
    color: area.containsMouse ? Theme.colHoverBgAccent : Theme.colGroupBg
    border.width: 1
    border.color: card.up ? Theme.colGroupBorder : Qt.rgba(card.stateColor.r, card.stateColor.g, card.stateColor.b, 0.6)

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 12
        anchors.topMargin: 9
        anchors.bottomMargin: 9
        spacing: 5

        // ── 1. Identity and wholeness ──
        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            Rectangle {
                implicitWidth: 9
                implicitHeight: 9
                radius: 4.5
                color: card.stateColor
                // Only trouble breathes: a steady dot is a healthy one.
                SequentialAnimation on opacity {
                    running: !card.up
                    loops: Animation.Infinite
                    alwaysRunToEnd: true
                    NumberAnimation {
                        to: 0.3
                        duration: 600
                    }
                    NumberAnimation {
                        to: 1
                        duration: 600
                    }
                }
            }
            Text {
                text: card.s.label || ""
                color: Theme.colText
                font.family: Theme.uiFont
                font.pixelSize: 16
                font.bold: true
            }
            Text {
                visible: (card.s.expected || 0) > 1 && card.s.running < card.s.expected // a whole service says nothing
                text: card.s.running + "/" + card.s.expected + (card.s.kind === "compose" ? " containers" : " units")
                color: card.s.running < card.s.expected ? Theme.colPeach : Theme.colDim
                font.family: Theme.uiFont
                font.pixelSize: 12
            }
            Item {
                Layout.fillWidth: true
            }
            Text {
                text: card.s.state === "down" ? "down" : "up " + card.fmtUp(card.s.since)
                color: card.up ? Theme.colSubtext : card.stateColor
                font.family: Theme.uiFont
                font.pixelSize: 12
            }
            Text {
                visible: (card.s.restarts || 0) > 0
                text: "↻" + card.s.restarts
                color: Theme.colPeach
                font.family: Theme.uiFont
                font.pixelSize: 12
                font.bold: true
            }
        }

        // ── 2. What it costs now: CPU with its own 2 minutes, then RAM ──
        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            Text {
                Layout.minimumWidth: 52
                // Two decimals under 1%: "idle" and "almost idle" are different readings.
                text: (card.s.cpu || 0).toFixed((card.s.cpu || 0) < 1 ? 2 : ((card.s.cpu || 0) < 10 ? 1 : 0)) + "%"
                color: Theme.colBlue
                font.family: Theme.uiFont
                font.pixelSize: 16
                font.bold: true
            }
            Sparkline {
                Layout.fillWidth: true
                Layout.preferredHeight: 20
                series: card.s.hist || []
                scaleTop: card.cpuTop
                fill: Theme.colBlue
                placeholder: ""
            }
            Text {
                Layout.leftMargin: 8
                text: card.fmtBytes(card.s.mem || 0)
                color: Theme.colMauve
                font.family: Theme.uiFont
                font.pixelSize: 16
                font.bold: true
            }
        }
    }

    // Tasks, disk traffic, the parts and where a click goes: on hover. Several parts are named; one
    // part says what KIND it is, instead of echoing the label.
    Tip {
        external: true
        hovered: area.containsMouse
        title: card.s.label || ""
        lines: [(card.s.parts || []).length > 1 ? card.s.parts.map(p => p.name.replace((card.s.key || "") + "-", "").replace(/-1$/, "")).join(" · ") : (card.s.kind === "compose" ? "1 container" : card.s.kind + " unit"), (card.s.tasks || 0) + " tasks", "disk ↓ " + card.fmtBytes(card.s.rd || 0) + "/s  ↑ " + card.fmtBytes(card.s.wr || 0) + "/s", (card.s.restarts || 0) > 0 ? "restarted " + card.s.restarts + "× since boot" : "", "click: " + (card.s.url ? "open " + card.s.url : "follow its log")].filter(x => x)
    }

    MouseArea {
        id: area
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: Services.open(card.s)
    }
}
