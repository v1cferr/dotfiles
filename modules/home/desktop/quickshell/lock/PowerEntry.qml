// Restart and shut down as two icons under the signature, in the clock column's measured ink. A
// click only ASKS: PowerAsk.qml takes the field's place and names the action in words.
import QtQuick
import "root:/"

Row {
    id: entry

    required property color ink
    spacing: 36

    Repeater {
        // The Center's glyphs, so the two places read as one set.
        model: [
            {
                key: "reboot",
                icon: "󰜉"
            },
            {
                key: "poweroff",
                icon: "󰐥"
            }
        ]
        // The area is the glyph's child, sized by it: sized by the Row, it would loop the layout.
        Text {
            id: one
            required property var modelData
            text: one.modelData.icon
            color: entry.ink
            opacity: hover.containsMouse ? 1 : 0.72
            font.family: Theme.uiFont
            font.pixelSize: 26
            MouseArea {
                id: hover
                anchors.fill: parent
                anchors.margins: -10
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: Power.request(one.modelData.key)
            }
        }
    }
}
