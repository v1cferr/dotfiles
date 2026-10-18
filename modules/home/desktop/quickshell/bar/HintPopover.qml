// The HINT popover (hover) for the pills with no panel of their own: what it is, how it is now, what
// a click does, in that order. The same card as the panels'. Content is a binding on the Bar, so
// it follows a scroll on the volume live; it shows after Theme.tipDelay (Bar.qml's coordinator).
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
        pad: Theme.sp3
        gap: Theme.sp1

        Text {
            Layout.maximumWidth: 320
            wrapMode: Text.WordWrap
            text: hintPop.h ? hintPop.h.title : ""
            color: Theme.colText
            font.family: Theme.uiFont
            font.pixelSize: Theme.fontBody
            font.bold: true
        }
        Repeater {
            model: hintPop.h ? hintPop.h.lines : []
            delegate: Text {
                required property var modelData
                Layout.maximumWidth: 320
                wrapMode: Text.WordWrap
                text: modelData
                color: Theme.colSubtext
                font.family: Theme.uiFont
                font.pixelSize: Theme.fontSmall
            }
        }
        Text {
            visible: text !== ""
            Layout.maximumWidth: 320
            Layout.topMargin: 2
            wrapMode: Text.WordWrap
            text: hintPop.h && hintPop.h.action ? hintPop.h.action : ""
            color: Theme.colDim
            font.family: Theme.uiFont
            font.pixelSize: Theme.fontSmall
        }
    }
}
