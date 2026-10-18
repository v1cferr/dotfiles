// The TIP for a control inside a panel (the NixOS Center's icons): the bar hint's card, drawn in the
// panel's own window, so it needs no layer of its own and never takes the keyboard. One per panel;
// a control points it at itself. The bar's pills use HintPopover instead: docs/notes/desktop/bar.md
import QtQuick
import QtQuick.Layouts
import "root:/"

Item {
    id: tip
    anchors.fill: parent
    z: 100

    // What it describes, set by the hovered control; null hides it.
    property Item target: null
    property string title: ""
    property string stateText: ""
    property string action: ""
    readonly property bool wanted: tip.target !== null && tip.title !== ""

    function show(item, title, stateText, action) {
        tip.target = item;
        tip.title = title;
        tip.stateText = stateText || "";
        tip.action = action || "";
        delay.restart();
    }
    function hide(item) {
        if (tip.target === item) {
            delay.stop();
            tip.target = null;
            card.visible = false;
        }
    }
    Timer {
        id: delay
        interval: Theme.tipDelay
        onTriggered: card.visible = tip.wanted
    }

    Rectangle {
        id: card
        visible: false
        // Under the control, kept inside the panel by sp1: mapToItem into a real Item is reliable.
        readonly property point at: tip.target ? tip.target.mapToItem(tip, 0, tip.target.height) : Qt.point(0, 0)
        x: Math.max(Theme.sp1, Math.min(card.at.x + (tip.target ? tip.target.width / 2 : 0) - card.width / 2, tip.width - card.width - Theme.sp1))
        y: card.at.y + Theme.sp1
        width: col.implicitWidth + 2 * Theme.sp3
        height: col.implicitHeight + 2 * Theme.sp2
        radius: Theme.radiusControl
        color: Theme.colSurfaceTip
        border.color: Theme.colEdge
        border.width: Theme.hairline

        ColumnLayout {
            id: col
            x: Theme.sp3
            y: Theme.sp2
            spacing: 2
            Text {
                text: tip.title
                color: Theme.colText
                font.family: Theme.uiFont
                font.pixelSize: Theme.fontBody
                font.bold: true
                Layout.maximumWidth: 260
                elide: Text.ElideRight
            }
            Text {
                visible: tip.stateText !== ""
                text: tip.stateText
                color: Theme.colSubtext
                font.family: Theme.uiFont
                font.pixelSize: Theme.fontSmall
                Layout.maximumWidth: 260
                wrapMode: Text.WordWrap
            }
            Text {
                visible: tip.action !== ""
                text: tip.action
                color: Theme.colDim
                font.family: Theme.uiFont
                font.pixelSize: Theme.fontSmall
                Layout.maximumWidth: 260
                wrapMode: Text.WordWrap
            }
        }
    }
}
