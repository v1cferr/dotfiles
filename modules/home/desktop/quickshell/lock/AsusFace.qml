// The primary: type straight on the print, no cards. The clock stacked on the calmer side, the
// field and the quote centered at the foot. One ink chosen per print, a soft shade only where the
// print would break AA, and the vermilion only for the caret, a failure and Caps Lock.
import Quickshell
import Quickshell.Io
import QtQuick
import QtQuick.Effects
import "root:/"

Item {
    id: face

    required property var auth
    readonly property color vermilion: "#c4342c"
    readonly property bool onRight: ink.result.side === "right"
    // Two inks, measured apart: the clock and the foot often sit on different parts of a print.
    readonly property color col: ink.result.ink === "dark" ? "#1a1b26" : Theme.colText
    readonly property color shadeCol: ink.result.ink === "dark" ? "#f4efe4" : "#101a33"
    readonly property color footCol: footInk.result.ink === "dark" ? "#1a1b26" : Theme.colText
    readonly property color footShade: footInk.result.ink === "dark" ? "#f4efe4" : "#101a33"
    readonly property real margin: 136

    Wallpaper {
        id: wall
        anchors.fill: parent
        pools: (Quickshell.env("LOCK_POOL_PRIMARY") || (Quickshell.env("HOME") + "/Pictures/lockscreen/wide")).split(":")
        historyFile: Quickshell.env("LOCK_STATE") ? Quickshell.env("LOCK_STATE") + "/seen-primary.json" : ""
        onShown: measureLater.start()
        onFailedChanged: if (wall.failed)
            quotes.armed = true
    }
    Timer {
        id: measureLater
        interval: 120 // one frame after the image lands, so the grab sees it
        onTriggered: {
            ink.measure();
            footInk.measure();
        }
    }
    Ink {
        id: ink
        target: wall
        // The clock column on the left, as fractions of the screen; the side is chosen from it.
        zones: [
            {
                x: 0.05,
                y: 0.12,
                w: 0.2,
                h: 0.56
            }
        ]
        onMeasuredChanged: if (ink.measured)
            quotes.armed = true
    }
    Ink {
        id: footInk
        target: wall
        // The foot: the field and the quote, centered (its mirror is itself).
        zones: [
            {
                x: 0.27,
                y: 0.7,
                w: 0.46,
                h: 0.24
            }
        ]
    }
    Quotes {
        id: quotes
        haikuOk: !!wall.meta.artist
    }

    SystemClock {
        id: clock
        precision: SystemClock.Minutes
    }

    // BOKASHI, the printmaker's graded wash: a band of the paper's (or the indigo's) tone that
    // the print itself might have had, as strong as the measured contrast needs and no stronger.
    // Zero when the print already reads; never a box, never a dark scrim.
    Rectangle {
        id: footWash
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        height: parent.height * 0.5
        opacity: footInk.measured ? Math.min(0.94, footInk.result.shade * 1.3) : 0 // the grab is reduced: its worst is not the worst pixel
        Behavior on opacity {
            NumberAnimation {
                duration: Theme.motionSlow
            }
        }
        gradient: Gradient {
            GradientStop {
                position: 0
                color: Qt.rgba(face.footShade.r, face.footShade.g, face.footShade.b, 0)
            }
            GradientStop {
                position: 0.36
                color: face.footShade
            }
            GradientStop {
                position: 1
                color: face.footShade
            }
        }
    }
    Rectangle {
        id: sideWash
        width: parent.width * 0.3
        height: parent.height
        x: face.onRight ? parent.width - width : 0
        opacity: ink.measured ? Math.min(0.94, ink.result.shade) : 0
        Behavior on opacity {
            NumberAnimation {
                duration: Theme.motionSlow
            }
        }
        gradient: Gradient {
            orientation: Gradient.Horizontal
            GradientStop {
                position: 0
                color: face.onRight ? Qt.rgba(face.shadeCol.r, face.shadeCol.g, face.shadeCol.b, 0) : face.shadeCol
            }
            GradientStop {
                position: face.onRight ? 0.6 : 0.4
                color: face.shadeCol
            }
            GradientStop {
                position: 1
                color: face.onRight ? face.shadeCol : Qt.rgba(face.shadeCol.r, face.shadeCol.g, face.shadeCol.b, 0)
            }
        }
    }

    // Everything on the print fades in together once the ink is known: never a flash of wrong ink.
    Item {
        id: type
        anchors.fill: parent
        opacity: ink.measured || wall.failed ? 1 : 0
        Behavior on opacity {
            NumberAnimation {
                duration: Theme.motionSlow
            }
        }
        layer.enabled: true
        layer.effect: MultiEffect {
            shadowEnabled: true
            shadowColor: face.shadeCol
            shadowBlur: 0.45
            shadowOpacity: 0.35
            shadowHorizontalOffset: 0
            shadowVerticalOffset: 0
            blurMax: 24
        }

        Column {
            id: stack
            x: face.onRight ? face.width - face.margin - width : face.margin
            anchors.verticalCenter: parent.verticalCenter
            anchors.verticalCenterOffset: -110
            spacing: 0
            Text {
                anchors.right: face.onRight ? parent.right : undefined
                horizontalAlignment: face.onRight ? Text.AlignRight : Text.AlignLeft
                text: Qt.formatTime(clock.date, "HH") + "\n" + Qt.formatTime(clock.date, "mm")
                color: face.col
                font.family: "Geist"
                font.weight: Font.Light
                font.pixelSize: 220
                font.features: {
                    "tnum": 1
                }
                lineHeight: 0.84
            }
            Text {
                anchors.right: face.onRight ? parent.right : undefined
                topPadding: 28
                text: Qt.locale("pt_BR").toString(clock.date, "dddd, d 'de' MMMM").replace("-feira", "")
                color: face.col
                font.family: "Geist"
                font.weight: Font.Light
                font.pixelSize: 30
            }
        }
    }

    // The foot on its own layer: its ink and shade were measured on its own part of the print.
    Item {
        id: foot
        anchors.fill: parent
        opacity: footInk.measured || wall.failed ? 1 : 0
        Behavior on opacity {
            NumberAnimation {
                duration: Theme.motionSlow
            }
        }
        layer.enabled: true
        layer.effect: MultiEffect {
            shadowEnabled: true
            shadowColor: face.footShade
            shadowBlur: 0.45
            shadowOpacity: 0.35
            shadowHorizontalOffset: 0
            shadowVerticalOffset: 0
            blurMax: 24
        }

        // The field: no box, a hairline that the caret and a failure color in vermilion.
        Item {
            id: field
            width: 420
            height: 64
            anchors.horizontalCenter: parent.horizontalCenter
            y: face.height * 0.72
            property real shake: 0
            transform: Translate {
                x: field.shake
            }

            Text {
                anchors.centerIn: parent
                anchors.verticalCenterOffset: -6
                text: face.auth.buffer.length ? "•".repeat(Math.min(24, face.auth.buffer.length)) : (face.auth.busy ? "verificando…" : face.auth.fails > 0 ? "senha incorreta" : "senha")
                color: face.auth.fails > 0 && !face.auth.buffer.length ? face.vermilion : face.footCol
                opacity: face.auth.buffer.length ? 1 : 0.8
                font.family: "Geist"
                font.weight: Font.Light
                font.pixelSize: face.auth.buffer.length ? 28 : 24
                font.letterSpacing: face.auth.buffer.length ? 6 : 1
            }
            Rectangle {
                anchors.bottom: parent.bottom
                anchors.horizontalCenter: parent.horizontalCenter
                width: parent.width
                height: 1
                color: face.footCol
                opacity: 0.45
            }
            Rectangle {
                anchors.bottom: parent.bottom
                anchors.horizontalCenter: parent.horizontalCenter
                width: face.auth.buffer.length ? Math.min(parent.width, 24 + face.auth.buffer.length * 18) : 32
                height: 2
                color: face.vermilion
                Behavior on width {
                    NumberAnimation {
                        duration: Theme.motionFast
                    }
                }
            }
            Text {
                anchors.top: parent.bottom
                anchors.topMargin: 10
                anchors.horizontalCenter: parent.horizontalCenter
                visible: caps.on
                text: "Caps Lock ativado"
                color: face.vermilion
                font.family: "Geist"
                font.pixelSize: 16
            }
            SequentialAnimation {
                id: shakeAnim
                NumberAnimation { target: field; property: "shake"; to: -14; duration: Theme.ms(50) }
                NumberAnimation { target: field; property: "shake"; to: 12; duration: Theme.ms(70) }
                NumberAnimation { target: field; property: "shake"; to: -6; duration: Theme.ms(60) }
                NumberAnimation { target: field; property: "shake"; to: 0; duration: Theme.ms(50) }
            }
            Connections {
                target: face.auth
                function onFailed() {
                    shakeAnim.restart();
                }
            }
        }

        // The quote: the text, the original smaller, the credit. Hierarchy by size, one ink.
        Column {
            anchors.horizontalCenter: parent.horizontalCenter
            y: face.height * 0.72 + 120
            width: 1100
            spacing: 6
            visible: !!quotes.quote
            Text {
                width: parent.width
                horizontalAlignment: Text.AlignHCenter
                text: quotes.quote ? quotes.quote.lines.join("\n") : ""
                color: face.footCol
                font.family: "Geist"
                font.weight: Font.Normal
                font.italic: true
                font.pixelSize: 27
                lineHeight: 1.15
            }
            Text {
                width: parent.width
                horizontalAlignment: Text.AlignHCenter
                visible: !!quotes.quote && quotes.quote.original.length > 0
                text: quotes.quote ? quotes.quote.original.join("\n") : ""
                color: face.footCol
                opacity: 0.78
                font.family: quotes.quote && quotes.quote.lang === "grc" ? "Noto Sans" : "Geist"
                font.pixelSize: 18
            }
            Text {
                width: parent.width
                horizontalAlignment: Text.AlignHCenter
                topPadding: 4
                text: quotes.quote ? quotes.quote.credit : ""
                color: face.footCol
                opacity: 0.78
                font.family: "Geist"
                font.pixelSize: 17
                font.letterSpacing: 0.5
            }
        }
    }

    // Caps Lock from the keyboard LEDs, polled only while locked (this face lives only then).
    QtObject {
        id: caps
        property bool on: false
    }
    Process {
        id: capsProc
        command: ["sh", "-c", "cat /sys/class/leds/*::capslock/brightness 2>/dev/null | sort -rn | head -n 1"]
        stdout: StdioCollector {
            onStreamFinished: caps.on = text.trim() !== "" && text.trim() !== "0"
        }
    }
    Timer {
        interval: 400
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: capsProc.running = true
    }
}
