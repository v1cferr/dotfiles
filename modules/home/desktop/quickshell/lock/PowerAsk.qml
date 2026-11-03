// The question that takes the field's place while a restart or a shut down asks, then what is
// happening. The state is Power.qml's, the same machine as the Center's; the words are pt-BR.
import QtQuick
import "root:/"

Column {
    id: ask

    required property color ink
    readonly property color vermilion: "#c4342c"
    readonly property var s: Power.state
    readonly property bool asking: ask.s.phase === "confirm"
    readonly property bool failed: ask.s.phase === "error"
    readonly property var words: ({
            reboot: {
                verb: "reiniciar",
                title: "Reiniciar o computador?",
                going: "reiniciando…"
            },
            poweroff: {
                verb: "desligar",
                title: "Desligar o computador?",
                going: "desligando…"
            }
        })
    readonly property var w: ask.words[ask.s.key] || ask.words.poweroff

    visible: ask.s.phase !== "idle"
    spacing: 26

    Text {
        anchors.horizontalCenter: parent.horizontalCenter
        text: ask.failed ? "não foi possível: " + ask.s.error : ask.asking ? ask.w.title : ask.w.going
        color: ask.failed ? ask.vermilion : ask.ink
        font.family: "Geist"
        font.weight: Font.Light
        font.pixelSize: 34
    }
    Row {
        anchors.horizontalCenter: parent.horizontalCenter
        spacing: 64
        visible: ask.asking || ask.failed
        Choice {
            text: ask.failed ? "fechar" : "cancelar"
            line: ask.ink
            onClicked: Power.cancel()
        }
        Choice {
            visible: ask.asking
            text: ask.w.verb
            line: ask.vermilion // the verb in the ink, so it reads on any print; the accent is the line
            onClicked: Power.confirm()
        }
    }

    component Choice: Text {
        id: choice
        property color line
        signal clicked
        color: ask.ink
        font.family: "Geist"
        font.pixelSize: 24
        font.letterSpacing: 1
        Rectangle {
            anchors.top: parent.bottom
            anchors.topMargin: 6
            width: parent.width
            height: 2
            color: choice.line
            opacity: area.containsMouse ? 1 : 0.6
        }
        MouseArea {
            id: area
            anchors.fill: parent
            anchors.margins: -12
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: choice.clicked()
        }
    }
}
