// A text that fades through to its next value, for a label whose MEANING changes in place (a new
// track, a VPN reaching its result). `epoch` marks a new subject: with a new epoch the text is
// simply the new one, since the subject's own entrance is already playing.
import QtQuick
import "root:/"

Item {
    id: swap
    property string text: ""
    property int epoch: 0
    property bool animate: true // false for a value that ticks (a level's percent)
    property color color: Theme.colText
    property var features: ({})

    property string shownText: ""
    property int shownEpoch: 0
    implicitWidth: probe.implicitWidth // the NEXT text's width, so the room is ready before it lands
    implicitHeight: probe.implicitHeight

    function settle() {
        if (swap.shownText === swap.text && swap.shownEpoch === swap.epoch)
            return;
        if (!swap.animate || swap.epoch !== swap.shownEpoch || Theme.motionReduced || swap.shownText === "") {
            fade.stop();
            swap.shownEpoch = swap.epoch;
            swap.shownText = swap.text;
            label.opacity = 1;
            return;
        }
        fade.restart();
    }
    // After the bindings settle: the text and the epoch change in the same update.
    onTextChanged: Qt.callLater(swap.settle)
    onEpochChanged: Qt.callLater(swap.settle)
    Component.onCompleted: swap.settle()

    SequentialAnimation {
        id: fade
        NumberAnimation {
            target: label
            property: "opacity"
            to: 0
            duration: Theme.motionFast
        }
        ScriptAction {
            script: swap.shownText = swap.text
        }
        NumberAnimation {
            target: label
            property: "opacity"
            to: 1
            duration: Theme.motionFast
        }
    }
    Text {
        id: probe
        visible: false
        text: swap.text
        font: label.font
    }
    Text {
        id: label
        anchors.fill: parent
        verticalAlignment: Text.AlignVCenter
        text: swap.shownText
        color: swap.color
        font.family: Theme.uiFont
        font.pixelSize: Theme.fontBody
        font.features: swap.features
        elide: Text.ElideRight
    }
}
