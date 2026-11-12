// A Control Center TILE: a round icon that is the switch, a name, what it is now, and a chevron
// when it has a page of its own. docs/notes/desktop/control-center.md#the-building-blocks
import QtQuick
import QtQuick.Layouts
import "root:/"

Rectangle {
    id: tile
    property string icon: "" // a Material Symbols name
    property string title: ""
    property string status: ""
    property bool on: false // the switch's state: the icon takes the accent
    property bool toggles: true // the icon is a switch; otherwise it opens the page like the rest
    property bool hasPage: false
    property bool available: true // false: the hardware or the service is not there, said in `status`
    signal toggled
    signal opened

    function act() {
        tile.hasPage ? tile.opened() : tile.toggled();
    }

    Layout.fillWidth: true
    Layout.preferredWidth: 0 // equal columns, whatever the texts hold
    implicitHeight: Theme.sp6 * 2 + Theme.sp1
    radius: Theme.radiusSurface
    opacity: tile.available ? 1 : Theme.opacityDisabled
    color: body.pressed ? Theme.colPressFill : (body.containsMouse ? Theme.colHoverFill : Qt.alpha(Theme.colText, 0.04))
    Behavior on color {
        ColorAnimation {
            duration: Theme.motionHover
        }
    }
    Accessible.role: Accessible.Button
    Accessible.name: tile.title + ", " + tile.status

    MouseArea {
        id: body
        anchors.fill: parent
        hoverEnabled: true
        enabled: tile.available
        cursorShape: Qt.PointingHandCursor
        onClicked: tile.act()
    }
    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: Theme.sp2
        anchors.rightMargin: Theme.sp2
        spacing: Theme.sp2
        Rectangle {
            id: knob
            implicitWidth: Theme.barHeight
            implicitHeight: Theme.barHeight
            radius: width / 2
            color: tile.on ? Theme.colAccent : (knobArea.containsMouse ? Theme.colCellPressFill : Theme.colCellHoverFill)
            Behavior on color {
                ColorAnimation {
                    duration: Theme.motionHover
                }
            }
            Text {
                anchors.centerIn: parent
                text: tile.icon
                color: tile.on ? Theme.colBgSolid : Theme.colText
                font.family: Theme.iconFont
                font.pixelSize: Theme.iconSymbol
                font.variableAxes: Theme.iconAxes
            }
            MouseArea {
                id: knobArea
                anchors.fill: parent
                hoverEnabled: true
                enabled: tile.available
                cursorShape: Qt.PointingHandCursor
                onClicked: tile.toggles ? tile.toggled() : tile.act()
            }
        }
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 0
            Text {
                Layout.fillWidth: true
                text: tile.title
                color: Theme.colText
                font.family: Theme.uiFont
                font.pixelSize: Theme.fontBody
                font.weight: Theme.weightStrong
                elide: Text.ElideRight
            }
            Text {
                Layout.fillWidth: true
                text: tile.status
                color: Theme.colSubtext
                font.family: Theme.uiFont
                font.pixelSize: Theme.fontSmall
                elide: Text.ElideRight
            }
        }
        Text {
            visible: tile.hasPage
            text: "chevron_right"
            color: Theme.colDim
            font.family: Theme.iconFont
            font.pixelSize: Theme.iconSymbol
            font.variableAxes: Theme.iconAxes
        }
    }
    KeyTarget {
        activeFocusOnTab: tile.available
        onActivated: tile.toggles && !tile.hasPage ? tile.toggled() : tile.act()
    }
}
