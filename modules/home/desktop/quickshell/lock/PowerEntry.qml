// "reiniciar · desligar" under the signature, in the clock column's measured ink. A click only ASKS:
// PowerAsk.qml takes the field's place with the question. Chosen from a bake-off on 03/11/2026.
import QtQuick
import "root:/"

Row {
    id: entry

    required property color ink

    Repeater {
        model: [
            {
                key: "reboot",
                label: "reiniciar"
            },
            {
                key: "poweroff",
                label: "desligar"
            }
        ]
        Row {
            id: one
            required property var modelData
            required property int index
            Text {
                visible: one.index > 0
                text: "  ·  "
                color: entry.ink
                opacity: 0.72
                font.family: "Geist"
                font.pixelSize: 18
            }
            // The area is the word's child, sized by it: sized by the Row, it would loop the layout.
            Text {
                text: one.modelData.label
                color: entry.ink
                opacity: hover.containsMouse ? 1 : 0.72
                font.family: "Geist"
                font.pixelSize: 18
                font.letterSpacing: 1
                MouseArea {
                    id: hover
                    anchors.fill: parent
                    anchors.margins: -8
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: Power.request(one.modelData.key)
                }
            }
        }
    }
}
