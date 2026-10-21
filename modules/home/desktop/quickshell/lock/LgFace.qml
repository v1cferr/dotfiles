// The secondary (standing LG): the print under four rows of real glass. Every card is the same
// system: a quiet label, ONE hero number, one chart, one line of context; the accent only in the
// charts. Música takes the last row while something plays, Clima otherwise.
import Quickshell
import Quickshell.Services.Mpris
import QtQuick
import "root:/"
import "root:/dash"
import "root:/data"

Item {
    id: face

    required property var auth
    readonly property color vermilion: "#c4342c"
    readonly property int margin: 72
    readonly property int gap: 24
    readonly property int full: face.width - 2 * face.margin
    readonly property int half: (face.full - face.gap) / 2
    // A CLEAR glass (the user's pick from a bake-off of four, 21/10/2026): the print shows through a
    // thin tint, 0.6 of the measured shade over a 0.06 floor, and a light blur; a dark halo on the
    // type keeps it readable where the tint alone no longer would.
    readonly property real tintAlpha: Math.max(0.06, Math.min(0.85, ink.result.shade * 0.6))
    readonly property real glassBlur: 0.6
    readonly property var player: {
        const ps = Mpris.players.values;
        for (let i = 0; i < ps.length; i++)
            if (ps[i].isPlaying)
                return ps[i];
        return null;
    }
    property var cpuHistory: []
    // With the main monitor gone the field goes with it: this face says how to unlock and echoes the dots.
    readonly property bool primaryGone: {
        const want = Quickshell.env("LOCK_PRIMARY") || Theme.primaryMonitor;
        const s = Quickshell.screens;
        for (let i = 0; i < s.length; i++)
            if (s[i].name === want)
                return false;
        return true;
    }

    // When each of n evenly spaced samples was taken, the last one now, for a chart's readout.
    function timeLabels(n, stepS, fmt) {
        const now = Date.now(), out = [];
        for (let i = 0; i < n; i++)
            out.push(Qt.locale("pt_BR").toString(new Date(now - (n - 1 - i) * stepS * 1000), fmt));
        return out;
    }

    function fmtBytes(b) {
        return b >= 1e9 ? (b / 1073741824).toFixed(1).replace(".", ",") + " GB" : Math.round(b / 1048576) + " MB";
    }

    Wallpaper {
        id: wall
        anchors.fill: parent
        pools: (Quickshell.env("LOCK_POOL_SECONDARY") || (Quickshell.env("HOME") + "/Pictures/lockscreen")).split(":")
        historyFile: Quickshell.env("LOCK_STATE") ? Quickshell.env("LOCK_STATE") + "/seen-secondary.json" : ""
        onShown: measureLater.start()
    }
    Timer {
        id: measureLater
        interval: 120
        onTriggered: ink.measure()
    }
    // The glass's tint is measured, not guessed: enough to keep light text AA over THIS print.
    Ink {
        id: ink
        target: wall
        zones: [
            {
                x: 0.07,
                y: 0.15,
                w: 0.86,
                h: 0.7
            }
        ]
    }

    // CPU over the last two minutes, for the Sistema card's chart.
    Connections {
        target: System
        function onCpuPctChanged() {
            if (!isNaN(System.cpuPct))
                face.cpuHistory = face.cpuHistory.concat([System.cpuPct]).slice(-60);
        }
    }

    component Hero: Row {
        id: hero
        property string value: "–"
        property string unit: ""
        spacing: 8
        Text {
            text: hero.value
            color: Theme.colText
            font.family: "Geist"
            font.weight: Font.Light
            font.pixelSize: 76
            font.features: {
                "tnum": 1
            }
        }
        Text {
            text: hero.unit
            visible: hero.unit !== ""
            color: Theme.colSubtext
            font.family: "Geist"
            font.weight: Font.Light
            font.pixelSize: 30
            anchors.baseline: parent.children[0].baseline
        }
    }
    component Context: Text {
        color: Theme.colSubtext
        font.family: "Geist"
        font.pixelSize: 19
        elide: Text.ElideRight
    }

    Column {
        x: face.margin
        anchors.verticalCenter: parent.verticalCenter
        spacing: face.gap
        opacity: ink.measured || wall.failed ? 1 : 0
        Behavior on opacity {
            NumberAnimation {
                duration: Theme.motionSlow
            }
        }

        Card {
            id: energy
            loading: Energy.loading
            backdrop: wall
            width: face.full
            height: 300
            tintAlpha: face.tintAlpha
            blur: face.glassBlur
            contentHalo: true
            label: "Energia"
            icon: "bolt"
            Hero {
                id: eHero
                x: energy.pad
                y: energy.contentTop
                value: Energy.ok ? Math.round(Energy.measured) : "–"
                unit: "W"
            }
            Trace {
                x: energy.width - energy.pad - width
                y: energy.contentTop + 8
                width: 470
                height: 84
                series: Energy.history
                color: face.vermilion
                labels: face.timeLabels(Energy.history.length, 60, "HH:mm")
                unit: " W"
            }
            Context {
                x: energy.pad
                y: energy.height - energy.pad - height
                width: energy.contentWidth
                text: Energy.ok ? "CPU " + Math.round(Energy.cpu) + " W  ·  GPU " + Math.round(Energy.gpu) + " W  ·  pico " + Math.round(Energy.peak) + " W em 30 min" : "sem dados do power-log"
            }
        }

        Card {
            id: claude
            loading: ClaudeUsage.error === "loading"
            backdrop: wall
            width: face.full
            height: 300
            tintAlpha: face.tintAlpha
            blur: face.glassBlur
            contentHalo: true
            label: "Claude Code"
            icon: "terminal"
            Row {
                x: claude.pad
                y: claude.contentTop
                spacing: 40
                Column {
                    Hero {
                        value: isNaN(ClaudeUsage.session.pct) ? "–" : Math.round(ClaudeUsage.session.pct)
                        unit: "%"
                    }
                    Context {
                        text: "sessão"
                    }
                }
                Column {
                    Hero {
                        value: isNaN(ClaudeUsage.weekly.pct) ? "–" : Math.round(ClaudeUsage.weekly.pct)
                        unit: "%"
                    }
                    Context {
                        text: "semana"
                    }
                }
            }
            Trace {
                x: claude.width - claude.pad - width
                y: claude.contentTop + 8
                width: 400
                height: 84
                bars: true
                scaleTop: 100
                series: ClaudeUsage.series("w", 7 * 86400, 4 * 3600)
                color: face.vermilion
                labels: face.timeLabels(series.length, 4 * 3600, "ddd HH'h'")
                unit: "%"
            }
            Context {
                x: claude.pad
                y: claude.height - claude.pad - height
                width: claude.contentWidth
                text: ClaudeUsage.ok ? "sessão reinicia em " + (ClaudeUsage.left(ClaudeUsage.session.resets) || "–") + "  ·  semana em " + (ClaudeUsage.left(ClaudeUsage.weekly.resets) || "–") : "sem dados do Claude"
            }
        }

        Row {
            spacing: face.gap
            Card {
                id: sys
                loading: isNaN(System.cpuPct)
                shape: "hero"
                backdrop: wall
                width: face.half
                height: 300
                tintAlpha: face.tintAlpha
                blur: face.glassBlur
                contentHalo: true
                label: "Sistema"
                icon: "memory"
                Hero {
                    x: sys.pad
                    y: sys.contentTop
                    value: isNaN(System.cpuPct) ? "–" : Math.round(System.cpuPct)
                    unit: "%"
                }
                Trace {
                    x: sys.pad
                    y: sys.contentTop + 100
                    width: sys.contentWidth
                    height: 40
                    scaleTop: 100
                    series: face.cpuHistory
                    color: face.vermilion
                    labels: face.timeLabels(face.cpuHistory.length, 2, "HH:mm:ss")
                    unit: "%"
                }
                Context {
                    x: sys.pad
                    y: sys.height - sys.pad - height
                    width: sys.contentWidth
                    text: "CPU  ·  " + (System.mem ? "RAM " + face.fmtBytes(System.mem.used) : "RAM –") + "  ·  GPU " + (isNaN(System.gpuTempC) ? "–" : System.gpuTempC + " °C")
                }
            }
            Card {
                id: procs
                loading: System.topCpu.length === 0
                shape: "list"
                backdrop: wall
                width: face.half
                height: 300
                tintAlpha: face.tintAlpha
                blur: face.glassBlur
                contentHalo: true
                label: "Processos"
                icon: "leaderboard"
                Column {
                    x: procs.pad
                    y: procs.contentTop + 6
                    width: procs.contentWidth
                    spacing: 12
                    Repeater {
                        model: System.topCpu.slice(0, 3)
                        Item {
                            required property var modelData
                            width: parent.width
                            height: 30
                            Text {
                                width: parent.width - 90
                                text: modelData.name
                                color: Theme.colText
                                font.family: "Geist"
                                font.pixelSize: 22
                                elide: Text.ElideRight
                            }
                            Text {
                                anchors.right: parent.right
                                text: Math.round(modelData.value) + " %"
                                color: Theme.colText
                                font.family: "Geist"
                                font.pixelSize: 22
                                font.features: {
                                    "tnum": 1
                                }
                            }
                        }
                    }
                }
                Context {
                    x: procs.pad
                    y: procs.height - procs.pad - height
                    width: procs.contentWidth
                    text: "CPU agora, % de um núcleo"
                }
            }
        }

        // Always on screen: the sky now, then the next 12 hours (the temperature as a line, the
        // chance of rain as bars under it), each hour readable under the pointer.
        Card {
            id: weather
            loading: Weather.loading
            shape: "hero-chart"
            backdrop: wall
            width: face.full
            height: 330
            tintAlpha: face.tintAlpha
            blur: face.glassBlur
            contentHalo: true
            label: "Clima"
            icon: "partly_cloudy_day"
            Row {
                x: weather.pad
                y: weather.contentTop
                spacing: 16
                Text {
                    text: Weather.icon
                    color: Theme.colText
                    font.family: "Material Symbols Rounded"
                    font.pixelSize: 60
                    font.variableAxes: {
                        "wght": 300
                    }
                    anchors.verticalCenter: parent.verticalCenter
                }
                Column {
                    anchors.verticalCenter: parent.verticalCenter
                    Hero {
                        value: Weather.ok ? Weather.temp + "°" : "–"
                    }
                    Context {
                        text: Weather.condition
                        color: Theme.colText
                    }
                }
            }
            Column {
                x: weather.width - weather.pad - width
                y: weather.contentTop + 6
                width: 430
                spacing: 4
                Trace {
                    width: parent.width
                    height: 62
                    series: Weather.next.map(h => h.temp)
                    scaleBottom: Weather.ok ? Math.min.apply(null, Weather.next.map(h => h.temp)) - 3 : 0
                    labels: Weather.next.map(h => h.label)
                    unit: "°"
                    color: face.vermilion
                }
                Trace {
                    width: parent.width
                    height: 22
                    bars: true
                    scaleTop: 100
                    series: Weather.next.map(h => h.rain)
                    labels: Weather.next.map(h => h.label + " chuva")
                    unit: "%"
                    color: Theme.colSubtext
                }
                Item {
                    width: parent.width
                    height: 18
                    Repeater {
                        model: Weather.next.length ? [0, 6, 12].filter(k => k < Weather.next.length) : []
                        Text {
                            required property int modelData
                            x: Math.max(0, Math.min(parent.width - width, modelData / Math.max(1, Weather.next.length - 1) * parent.width - width / 2))
                            text: Weather.next[modelData].label
                            color: Theme.colSubtext
                            font.family: "Geist"
                            font.pixelSize: 14
                        }
                    }
                }
            }
            Context {
                x: weather.pad
                y: weather.height - weather.pad - height
                width: weather.contentWidth
                text: Weather.ok ? "máx " + Weather.high + "°  ·  mín " + Weather.low + "°  ·  chuva " + Weather.rain + "%  ·  sensação " + Weather.feels + "°" : "sem previsão no cache"
            }
        }

        // Only while something plays: one compact row, never in the weather's place.
        Card {
            id: media
            visible: !!face.player
            backdrop: wall
            width: face.full
            height: 150
            tintAlpha: face.tintAlpha
            blur: face.glassBlur
            contentHalo: true
            label: "Tocando"
            icon: "music_note"
            Row {
                x: media.pad
                y: media.contentTop - 6
                width: media.contentWidth
                spacing: 14
                Text {
                    id: track
                    width: Math.min(implicitWidth, media.contentWidth * 0.7)
                    text: face.player ? face.player.trackTitle : ""
                    color: Theme.colText
                    font.family: "Geist"
                    font.pixelSize: 24
                    elide: Text.ElideRight
                }
                Context {
                    width: media.contentWidth - track.width - 14
                    anchors.baseline: track.baseline
                    text: face.player ? face.player.trackArtist : ""
                }
            }
            Rectangle {
                x: media.pad
                y: media.height - media.pad - 4
                width: media.contentWidth
                height: 4
                radius: 2
                color: Qt.rgba(1, 1, 1, 0.14)
                Rectangle {
                    height: parent.height
                    radius: 2
                    color: face.vermilion
                    width: face.player && face.player.lengthSupported && face.player.length > 0 ? parent.width * Math.min(1, face.player.position / face.player.length) : 0
                }
            }
        }
    }

    Text {
        visible: face.primaryGone
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 96
        horizontalAlignment: Text.AlignHCenter
        text: face.auth.buffer.length ? "•".repeat(Math.min(24, face.auth.buffer.length)) : (face.auth.fails > 0 ? "senha incorreta" : "Tela principal desconectada · digite a senha e pressione Enter")
        color: face.auth.fails > 0 && !face.auth.buffer.length ? face.vermilion : Theme.colText
        font.family: "Geist"
        font.pixelSize: 22
        style: Text.Outline
        styleColor: Qt.rgba(0, 0, 0, 0.5)
    }
}
