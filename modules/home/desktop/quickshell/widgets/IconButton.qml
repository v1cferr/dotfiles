// A square glyph button with its own NAME: the accessible name and the tip's title are the same
// words, so a control shown only as an icon still says what it does. The tip is the panel's
// GlassTip (`tips`), never Qt's native ToolTip, which drew a light box off the theme.
import QtQuick
import "root:/"

Rectangle {
    id: btn
    property string glyph: ""
    property color tint: Theme.colText
    property bool active: false // a toggle that is on
    property string name: ""
    property string stateText: "" // the tip's second line: what it is now
    property string action: ""    // the tip's third line: what a click does
    property Item tips: null      // the panel's GlassTip
    readonly property bool symbol: /^[a-z0-9_]+$/.test(btn.glyph)
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

    Text {
        anchors.centerIn: parent
        text: btn.glyph
        color: btn.tint
        // A Material Symbols name draws in the icon font, a glyph in the text's (the same rule as Pill).
        font.family: btn.symbol ? Theme.iconFont : Theme.uiFont
        font.pixelSize: btn.symbol ? Theme.iconSymbol : Theme.iconBar
        font.variableAxes: btn.symbol ? Theme.iconAxes : ({})
    }
    MouseArea {
        id: area
        anchors.fill: parent
        hoverEnabled: true
        enabled: btn.enabled
        cursorShape: Qt.PointingHandCursor
        onContainsMouseChanged: if (btn.tips)
            area.containsMouse ? btn.tips.show(btn, btn.name, btn.stateText, btn.action) : btn.tips.hide(btn)
        onClicked: btn.clicked()
    }
    KeyTarget {
        activeFocusOnTab: btn.enabled
        onActivated: btn.clicked()
    }
}
