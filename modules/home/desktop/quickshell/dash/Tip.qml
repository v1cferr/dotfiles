// A tooltip TARGET: drop it inside any item of the band, `Tip { title: "..."; lines: [...] }`, and
// hovering that item shows the card (TipWindow.qml). Where the item already has a hover MouseArea,
// set `external: true` and feed its `containsMouse` into `hovered`, so hover is never contested.
import QtQuick

Item {
    id: tip

    property string title: ""
    property var lines: []
    property bool external: false
    property bool hovered: false

    readonly property bool on: (tip.external ? tip.hovered : hh.hovered) && (tip.title !== "" || tip.lines.length > 0)

    anchors.fill: parent
    onOnChanged: tip.on ? Tips.show(tip) : Tips.hide(tip)
    Component.onDestruction: Tips.hide(tip)

    HoverHandler {
        id: hh
        enabled: !tip.external
    }
}
