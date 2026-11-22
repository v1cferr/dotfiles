// A QUICK TILE of the NixOS Center: an icon over one word. Its color is its state (the accent
// while on, the warning while something wants a look); a click is its one act, a switch or a page
// of its own, and where it has both the right button opens the page. Its words are in the tip.
// docs/notes/desktop/nixos-center.md#the-tiles
import QtQuick
import QtQuick.Layouts
import "root:/"

Rectangle {
    id: tile
    property string icon: "" // a Material Symbols name
    property string label: ""
    property string name: "" // the tip's title and the accessible name
    property string stateText: ""
    property string action: ""
    property bool on: false
    property bool warn: false
    property bool available: true // false: the hardware or the service is not there
    property bool hasPage: false
    property bool toggles: true // false: the click opens the page
    property Item tips: null
    signal toggled
    signal opened

    readonly property color ink: tile.warn ? Theme.colWarn : (tile.on ? Theme.colAccent : Theme.colText)
    function act() {
        tile.toggles ? tile.toggled() : tile.opened();
    }

    Layout.fillWidth: true
    Layout.preferredWidth: 0 // equal columns, whatever the words hold
    implicitHeight: Theme.sp6 * 2 + Theme.sp2
    radius: Theme.radiusSurface
    opacity: tile.available ? 1 : Theme.opacityDisabled
    color: area.pressed ? Theme.colPressFill : (area.containsMouse ? Theme.colHoverFill : Qt.alpha(tile.ink, tile.on || tile.warn ? 0.14 : 0.04))
    Behavior on color {
        ColorAnimation {
            duration: Theme.motionHover
        }
    }
    Accessible.role: Accessible.Button
    Accessible.name: tile.name + ", " + tile.stateText
    Accessible.checkable: tile.toggles
    Accessible.checked: tile.on

    ColumnLayout {
        anchors.centerIn: parent
        width: parent.width - 2 * Theme.sp1
        spacing: 2
        Text {
            Layout.alignment: Qt.AlignHCenter
            text: tile.icon
            color: tile.ink
            font.family: Theme.iconFont
            font.pixelSize: Theme.iconSymbol
            font.variableAxes: Theme.iconAxes
        }
        Text {
            Layout.fillWidth: true
            horizontalAlignment: Text.AlignHCenter
            text: tile.label
            color: tile.on || tile.warn ? Theme.colText : Theme.colSubtext
            font.family: Theme.uiFont
            font.pixelSize: Theme.fontSmall
            elide: Text.ElideRight
        }
    }
    // A tile that is a switch AND has a page says so with a mark in its corner.
    Text {
        visible: tile.hasPage && tile.toggles
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: Theme.sp1
        text: "more_horiz"
        color: Theme.colDim
        font.family: Theme.iconFont
        font.pixelSize: Theme.fontBody
        font.variableAxes: Theme.iconAxes
    }
    MouseArea {
        id: area
        anchors.fill: parent
        hoverEnabled: true
        enabled: tile.available
        cursorShape: Qt.PointingHandCursor
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        onContainsMouseChanged: if (tile.tips)
            area.containsMouse ? tile.tips.show(tile, tile.name, tile.stateText, tile.action) : tile.tips.hide(tile)
        onClicked: mouse => mouse.button === Qt.RightButton && tile.hasPage ? tile.opened() : tile.act()
    }
    KeyTarget {
        activeFocusOnTab: tile.available
        onActivated: tile.act()
    }
}
