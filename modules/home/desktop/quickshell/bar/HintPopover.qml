// The HINT popover (hover) for the pills with no panel of their own: the state, then what each
// button does. Content is a binding on the Bar, so it follows a scroll on the volume live.
import Quickshell
import Quickshell.Wayland
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
    WlrLayershell.namespace: "qs-panel"
    anchors {
        top: true
        left: true
    }
    // Placed from the screen's edge, sp1 under the bar (the same rule as BarPanel).
    exclusionMode: ExclusionMode.Ignore
    margins {
        top: Theme.bandTop
        left: bar.popLeft(hintPop.implicitWidth)
    }
    implicitWidth: card.implicitWidth
    implicitHeight: card.implicitHeight
    color: "transparent"

    PopCard {
        shown: hintPop.visible
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
