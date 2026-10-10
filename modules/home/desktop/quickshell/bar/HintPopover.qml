// The HINT popover (hover) for the pills with no panel of their own: the state, then what each
// button does. Content is a binding on the Bar, so it follows a scroll on the volume live.
import Quickshell
import QtQuick
import QtQuick.Layouts
import "root:/"
import "root:/widgets"

PanelWindow {
    id: hintPop
    required property var bar
    readonly property var h: bar.hintFor(bar.hintKey)

    visible: bar.hintVisible && hintPop.h !== null
    screen: bar.popScreen || bar.screenPrimary
    anchors {
        top: true
        left: true
    }
    margins {
        top: 4 // = Hyprland's gaps_out (the barExclusiveZone 30 is already discounted)
        left: bar.popLeft(hintPop.implicitWidth)
    }
    exclusiveZone: 0
    implicitWidth: card.implicitWidth
    implicitHeight: card.implicitHeight
    color: "transparent"

    PopCard {
        id: card
        pad: 12
        gap: 6

        Text {
            Layout.maximumWidth: 320
            wrapMode: Text.WordWrap
            text: hintPop.h ? hintPop.h.title : ""
            color: Theme.colAccent
            font.family: Theme.uiFont
            font.pixelSize: 12
            font.bold: true
        }
        Repeater {
            model: hintPop.h ? hintPop.h.lines : []
            delegate: Text {
                required property var modelData
                Layout.maximumWidth: 320
                wrapMode: Text.WordWrap
                text: modelData
                color: Theme.colDim
                font.family: Theme.uiFont
                font.pixelSize: 11
            }
        }
    }
}
