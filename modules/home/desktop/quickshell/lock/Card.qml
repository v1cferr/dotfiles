// One LG card: glass, a quiet label with its icon, then whatever the card holds. Every card shares
// the padding and the label, so the column reads as one system. While its data has not arrived the
// content stays hidden under a pulsing skeleton of the same shape: never a "–" that looks like data.
import QtQuick
import "root:/"
import "root:/widgets"

LiquidGlass {
    id: card

    property string label: ""
    property string icon: ""
    property color ink: Theme.colText
    property color soft: Theme.colSubtext
    property bool loading: false
    property string shape: "hero-chart" // the skeleton: "hero-chart" | "hero" | "list"
    readonly property int pad: 32
    // Where a card's own content starts and how wide it may be: under the label, inside the padding.
    readonly property int contentTop: pad + 48
    readonly property int contentWidth: width - 2 * pad

    property real reveal: card.loading ? 0 : 1
    Behavior on reveal {
        NumberAnimation {
            duration: Theme.motionSlow
        }
    }
    contentOpacity: card.reveal

    // The label sits on the card itself (`parent`), outside the content that fades.
    Row {
        parent: card
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

    component Bone: Rectangle {
        radius: 6
        color: Qt.rgba(1, 1, 1, 0.10)
    }

    // The skeleton: blocks where the hero, the chart and the context line will be.
    Item {
        id: skeleton
        parent: card
        anchors.fill: parent
        visible: opacity > 0
        opacity: 1 - card.reveal

        Item {
            anchors.fill: parent
            SequentialAnimation on opacity {
                running: skeleton.visible
                loops: Animation.Infinite
                NumberAnimation {
                    from: 1
                    to: 0.45
                    duration: Theme.ms(700)
                    easing.type: Easing.InOutSine
                }
                NumberAnimation {
                    from: 0.45
                    to: 1
                    duration: Theme.ms(700)
                    easing.type: Easing.InOutSine
                }
            }

            Bone {
                visible: card.shape !== "list"
                x: card.pad
                y: card.contentTop + 10
                width: Math.min(170, card.contentWidth * 0.4)
                height: 58
            }
            Bone {
                visible: card.shape === "hero-chart"
                x: card.width - card.pad - width
                y: card.contentTop + 18
                width: Math.min(420, card.contentWidth * 0.48)
                height: 66
            }
            Column {
                visible: card.shape === "list"
                x: card.pad
                y: card.contentTop + 10
                spacing: 16
                Repeater {
                    model: 3
                    Bone {
                        required property int index
                        width: card.contentWidth * (0.85 - index * 0.12)
                        height: 22
                    }
                }
            }
            Bone {
                x: card.pad
                y: card.height - card.pad - height - 2
                width: card.contentWidth * 0.55
                height: 16
            }
        }
    }
}
