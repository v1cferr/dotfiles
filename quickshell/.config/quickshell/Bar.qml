// Barra Quickshell (substituta da Waybar) — FASE 1: shell por-monitor + relógio
// + cpu/ram/disco. Tokyo Night, pílulas iguais às da Waybar. Mais módulos vêm
// nas próximas fases (áudio, spotify, rede, scripts, workspaces, janela, tray).
import Quickshell
import Quickshell.Io
import QtQuick
import QtQuick.Layouts

Scope {
    id: root

    // Permite testar sem reservar espaço (harness seta 0); produção usa 30.
    property int barExclusiveZone: 30

    // ===== Paleta (Tokyo Night + Catppuccin, fiel ao style.css) =====
    readonly property color colGroupBg: "#591a1b26"     // grupo 0.35
    readonly property color colGroupBorder: "#2e414868" // 0.18
    readonly property color colPillBg: "#db1a1b26"      // pílula 0.86
    readonly property color colPillHoverBg: "#eb1a1b26" // 0.92
    readonly property color colPillBorder: "#59414868"  // 0.35
    readonly property color colHoverBorder: "#807aa2f7" // accent 0.5
    readonly property color colText: "#c0caf5"
    readonly property color colDim: "#565f89"
    readonly property color colAccent: "#7aa2f7"
    readonly property color colGreen: "#a6e3a1"
    readonly property color colRed: "#f38ba8"
    readonly property color colYellow: "#f9e2af"
    readonly property color colPeach: "#fab387"
    readonly property color colMauve: "#cba6f7"
    readonly property color colLavender: "#b4befe"
    readonly property color colSky: "#89dceb"
    readonly property color colBlue: "#89b4fa"
    readonly property color colSapphire: "#74c7ec"
    readonly property color colTeal: "#94e2d5"
    readonly property color colPink: "#f5c2e7"
    readonly property string uiFont: "JetBrainsMono Nerd Font"

    function stateColor(pct, base) {
        return pct >= 90 ? root.colRed : (pct >= 70 ? root.colPeach : base);
    }

    // ===== Relógio (SystemClock nativo) =====
    property bool showDate: false
    property string timeStr: ""
    SystemClock {
        id: sysClock
        precision: SystemClock.Seconds
    }
    function updateClock() {
        const d = sysClock.date;
        root.timeStr = root.showDate ? "󰃭 " + Qt.formatDateTime(d, "dd/MM/yyyy") : "󰥔 " + Qt.formatDateTime(d, "HH:mm:ss");
    }
    Connections {
        target: sysClock
        function onDateChanged() {
            root.updateClock();
        }
    }
    Component.onCompleted: root.updateClock()

    // ===== CPU / RAM / Disco (lendo /proc e df) =====
    property int cpuPct: 0
    property int memPct: 0
    property int diskPct: 0
    property var cpuPrev: null

    function parseCpu(text) {
        const parts = text.trim().split(/\s+/);
        if (parts[0] !== "cpu")
            return;
        const n = parts.slice(1).map(Number);
        const total = n.reduce((a, b) => a + b, 0);
        const idle = (n[3] || 0) + (n[4] || 0);
        if (root.cpuPrev) {
            const dt = total - root.cpuPrev.total;
            const di = idle - root.cpuPrev.idle;
            if (dt > 0)
                root.cpuPct = Math.round((1 - di / dt) * 100);
        }
        root.cpuPrev = {
            total: total,
            idle: idle
        };
    }
    function parseMem(text) {
        let total = 0, avail = 0;
        const lines = text.split("\n");
        for (let i = 0; i < lines.length; i++) {
            const m = lines[i].match(/^(\w+):\s+(\d+)/);
            if (!m)
                continue;
            if (m[1] === "MemTotal")
                total = Number(m[2]);
            else if (m[1] === "MemAvailable")
                avail = Number(m[2]);
        }
        if (total > 0)
            root.memPct = Math.round((total - avail) / total * 100);
    }

    Process {
        id: cpuProc
        command: ["sh", "-c", "head -n1 /proc/stat"]
        stdout: StdioCollector {
            onStreamFinished: root.parseCpu(text)
        }
    }
    Process {
        id: memProc
        command: ["sh", "-c", "grep -E 'MemTotal|MemAvailable' /proc/meminfo"]
        stdout: StdioCollector {
            onStreamFinished: root.parseMem(text)
        }
    }
    Process {
        id: diskProc
        command: ["sh", "-c", "df -P / | awk 'NR==2{gsub(\"%\",\"\",$5); print $5}'"]
        stdout: StdioCollector {
            onStreamFinished: root.diskPct = parseInt(text.trim()) || 0
        }
    }

    Timer {
        interval: 2000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: cpuProc.running = true
    }
    Timer {
        interval: 5000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: memProc.running = true
    }
    Timer {
        interval: 30000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: diskProc.running = true
    }

    // ===== Pílula reutilizável =====
    component Pill: Rectangle {
        id: pill
        property string icon: ""
        property string label: ""
        property color accent: root.colText
        signal clicked
        signal rightClicked
        signal scrolledUp
        signal scrolledDown

        implicitWidth: prow.implicitWidth + 20
        implicitHeight: 22
        radius: 8
        color: area.containsMouse ? root.colPillHoverBg : root.colPillBg
        border.color: area.containsMouse ? root.colHoverBorder : root.colPillBorder
        border.width: 1
        Behavior on color {
            ColorAnimation {
                duration: 200
                easing.type: Easing.InOutQuad
            }
        }
        Behavior on border.color {
            ColorAnimation {
                duration: 200
            }
        }

        RowLayout {
            id: prow
            anchors.centerIn: parent
            spacing: 6
            Text {
                visible: pill.icon !== ""
                text: pill.icon
                color: pill.accent
                font.family: root.uiFont
                font.pixelSize: 13
            }
            Text {
                visible: pill.label !== ""
                text: pill.label
                color: pill.accent
                font.family: root.uiFont
                font.pixelSize: 11
            }
        }

        MouseArea {
            id: area
            anchors.fill: parent
            hoverEnabled: true
            acceptedButtons: Qt.LeftButton | Qt.RightButton
            onClicked: m => {
                if (m.button === Qt.RightButton)
                    pill.rightClicked();
                else
                    pill.clicked();
            }
            onWheel: w => {
                if (w.angleDelta.y > 0)
                    pill.scrolledUp();
                else
                    pill.scrolledDown();
            }
        }
    }

    // ===== Container de grupo (pílula 0.35) =====
    component Group: Rectangle {
        default property alias content: groupRow.data
        radius: 12
        color: root.colGroupBg
        border.color: root.colGroupBorder
        border.width: 1
        implicitWidth: groupRow.implicitWidth + 8
        implicitHeight: 26
        RowLayout {
            id: groupRow
            anchors.centerIn: parent
            spacing: 6
        }
    }

    // ===== Barra por monitor =====
    Variants {
        model: Quickshell.screens

        PanelWindow {
            id: bar
            required property var modelData
            screen: modelData

            anchors {
                top: true
                left: true
                right: true
            }
            margins {
                top: 4
                left: 4
                right: 4
                bottom: 1
            }
            implicitHeight: 30
            exclusiveZone: root.barExclusiveZone
            color: "transparent"

            // ESQUERDA (placeholder por enquanto; workspaces/janela/spotify vêm depois)
            Group {
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                Pill {
                    icon: "󰣇"
                    label: "QS"
                    accent: root.colAccent
                }
            }

            // CENTRO: relógio
            Group {
                anchors.centerIn: parent
                Pill {
                    label: root.timeStr
                    accent: root.colMauve
                    onClicked: root.showDate = !root.showDate
                }
            }

            // DIREITA: cpu / ram / disco
            Group {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                Pill {
                    icon: "󰻠"
                    label: root.cpuPct + "%"
                    accent: root.stateColor(root.cpuPct, root.colYellow)
                }
                Pill {
                    icon: "󰍛"
                    label: root.memPct + "%"
                    accent: root.stateColor(root.memPct, root.colPink)
                }
                Pill {
                    icon: "󰋊"
                    label: root.diskPct + "%"
                    accent: root.stateColor(root.diskPct, root.colTeal)
                }
            }
        }
    }
}
