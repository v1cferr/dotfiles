// One LG card: glass, a quiet label with its icon, then whatever the card holds. Every card shares
// the padding and the label, so the column reads as one system.
import QtQuick
import "root:/"
import "root:/widgets"

LiquidGlass {
    id: card

    property string label: ""
    property string icon: ""
    property color ink: Theme.colText
    property color soft: Theme.colSubtext
    readonly property int pad: 32
    // Where a card's own content starts and how wide it may be: under the label, inside the padding.
    readonly property int contentTop: pad + 48
    readonly property int contentWidth: width - 2 * pad

    Row {
        x: card.pad
        y: card.pad - 4
        spacing: 10
        Text {
            text: card.icon
            visible: card.icon !== ""
            color: card.soft
            font.family: "Material Symbols Rounded"
            font.pixelSize: 22
            font.variableAxes: {
                "wght": 300
            }
            anchors.verticalCenter: parent.verticalCenter
        }
        Text {
            text: card.label
            color: card.soft
            font.family: "Geist"
            font.weight: Font.Medium
            font.pixelSize: 19
            anchors.verticalCenter: parent.verticalCenter
        }
    }
}
