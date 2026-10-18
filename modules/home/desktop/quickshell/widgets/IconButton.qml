// A square glyph button with its own NAME: the accessible name and the tooltip are the same words,
// so a control shown only as an icon still says what it does.
import QtQuick
import QtQuick.Controls
import "root:/"

Rectangle {
    id: btn
    property string glyph: ""
    property color tint: Theme.colText
    property bool active: false // a toggle that is on
    property string name: ""
    signal clicked

    implicitWidth: Theme.barControl
    implicitHeight: Theme.barControl
    radius: Theme.radiusControl
    opacity: btn.enabled ? 1 : Theme.opacityDisabled
    color: area.pressed ? Theme.colPressFill : (area.containsMouse ? Theme.colHoverFill : (btn.active ? Theme.colSelectFill : "transparent"))
    Behavior on color {
        ColorAnimation {
            duration: Theme.motionHover
        }
    }
    Accessible.role: Accessible.Button
    Accessible.name: btn.name
    Accessible.checkable: btn.active
    ToolTip.visible: area.containsMouse && btn.name !== ""
    ToolTip.delay: Theme.hoverIntent
    ToolTip.text: btn.name

    Text {
        anchors.centerIn: parent
        text: btn.glyph
        color: btn.tint
        font.family: Theme.uiFont
        font.pixelSize: 16
    }
    MouseArea {
        id: area
        anchors.fill: parent
        hoverEnabled: true
        enabled: btn.enabled
        cursorShape: Qt.PointingHandCursor
        onClicked: btn.clicked()
    }
}
