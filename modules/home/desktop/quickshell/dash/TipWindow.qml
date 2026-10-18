// The tooltip CARD of one band (one per Dashboard, so per screen). A layer surface and not a
// PopupWindow: Hyprland #6682 leaves a resized popup with a wrong input region
// (docs/notes/desktop/quickshell.md). It reserves nothing and has an empty input region, so it never
// takes the pointer from the item it describes. Placed by hand under its target.
import Quickshell
import Quickshell.Wayland
import QtQuick
import QtQuick.Layouts
import "root:/"
import "root:/widgets"

PanelWindow {
    id: tw

    required property var band // the Dashboard window it belongs to
    readonly property var t: Tips.target
    // Only the band the target lives in shows it: walk up to the stage, which names its band. Not
    // `root === band.contentItem`: Quickshell hands out a new wrapper there, so `===` is always false.
    function inBand(item) {
        for (let p = item; p; p = p.parent)
            if (p.tipBand !== undefined)
                return p.tipBand === tw.band;
        return false;
    }
    readonly property bool mine: Tips.shown && tw.t !== null && tw.inBand(tw.t)

    // The target's rect in the band window (native px, the stage's scale already applied), moved into
    // screen coordinates: the band starts at Theme.bandTop, screenInset in from the left.
    readonly property point at: {
        if (!tw.mine)
            return Qt.point(0, 0);
        const p = tw.t.mapToItem(null, 0, tw.t.height);
        const x = Theme.screenInset + p.x;
        const y = Theme.bandTop + p.y + 6;
        const maxX = (tw.screen ? tw.screen.width : 1080) - tw.implicitWidth - 4;
        return Qt.point(Math.max(4, Math.min(x, maxX)), y);
    }

    screen: tw.band.screen
    visible: tw.mine
    anchors {
        top: true
        left: true
    }
    margins {
        top: tw.at.y
        left: tw.at.x
    }
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "qs-panel" // a PopCard like the bar's hints, so the same glass
    exclusionMode: ExclusionMode.Ignore
    mask: Region {}
    color: "transparent"
    implicitWidth: card.implicitWidth
    implicitHeight: card.implicitHeight

    PopCard {
        shown: tw.visible
        id: card
        pad: 10
        gap: 4

        Text {
            visible: text !== ""
            Layout.maximumWidth: 360
            wrapMode: Text.WordWrap
            text: tw.t ? tw.t.title : ""
            color: Theme.colText
            font.family: Theme.uiFont
            font.pixelSize: 13
            font.bold: true
        }
        Repeater {
            model: tw.t ? tw.t.lines : []
            delegate: Text {
                required property var modelData
                Layout.maximumWidth: 360
                wrapMode: Text.WordWrap
                text: modelData
                color: Theme.colSubtext
                font.family: Theme.uiFont
                font.pixelSize: 12
            }
        }
    }
}
