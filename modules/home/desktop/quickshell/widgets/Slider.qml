// A SLIDER for a level the user sets (a volume, a brightness): a tall rounded track with its icon
// inside the left end. The owner holds the value; this only reports where the user put it.
// Its keys and the tap on the icon: docs/notes/desktop/control-center.md#the-building-blocks
import QtQuick
import "root:/"

Item {
    id: slider
    property real value: 0 // 0..1, the owner's truth
    property string icon: "" // a Material Symbols name
    property string name: ""
    property real step: 0.05
    property bool dimmed: false // the level is there but not in effect (muted)
    signal moved(real value)
    signal iconClicked

    implicitHeight: Theme.barControl
    activeFocusOnTab: true
    Accessible.role: Accessible.Slider
    Accessible.name: slider.name + ", " + Math.round(slider.value * 100) + "%"

    readonly property real shown: Math.max(0, Math.min(1, slider.value))

    Rectangle {
        id: track
        anchors.fill: parent
        radius: height / 2
        color: Theme.colCellHoverFill
    }
    Rectangle {
        // Never narrower than the icon's circle, so the icon always sits on the fill.
        width: Math.round(Math.max(track.height, slider.shown * track.width))
        height: track.height
        radius: track.radius
        color: Qt.alpha(Theme.colText, slider.dimmed ? 0.35 : 0.88)
    }
    Text {
        x: (track.height - width) / 2
        anchors.verticalCenter: parent.verticalCenter
        text: slider.icon
        color: Theme.colBgSolid
        font.family: Theme.iconFont
        font.pixelSize: Theme.iconSymbol
        font.variableAxes: Theme.iconAxes
    }
    Rectangle {
        anchors.fill: parent
        radius: track.radius
        color: "transparent"
        border.width: 2
        border.color: Theme.colAccent
        visible: slider.activeFocus
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        // A press on the icon is a tap until the pointer travels: only then does it set the level.
        property real downX: 0
        property bool onIcon: false
        property bool dragged: false
        function at(x) {
            slider.moved(Math.max(0, Math.min(1, x / width)));
        }
        onPressed: m => {
            downX = m.x;
            onIcon = m.x <= height;
            dragged = false;
            if (!onIcon)
                at(m.x);
        }
        onPositionChanged: m => {
            if (!pressed)
                return;
            if (onIcon && !dragged && Math.abs(m.x - downX) < Theme.sp1)
                return;
            dragged = true;
            at(m.x);
        }
        onReleased: if (onIcon && !dragged)
            slider.iconClicked()
        onWheel: w => slider.moved(Math.max(0, Math.min(1, slider.shown + (w.angleDelta.y > 0 ? slider.step : -slider.step))))
    }

    // Left and Right set the level; Up and Down walk the panel, as on every other control.
    Keys.onPressed: event => {
        switch (event.key) {
        case Qt.Key_Right:
            slider.moved(Math.min(1, slider.shown + slider.step));
            break;
        case Qt.Key_Left:
            slider.moved(Math.max(0, slider.shown - slider.step));
            break;
        case Qt.Key_Space:
        case Qt.Key_Return:
        case Qt.Key_Enter:
            slider.iconClicked();
            break;
        case Qt.Key_Down:
            slider.nextItemInFocusChain(true).forceActiveFocus(Qt.TabFocusReason);
            break;
        case Qt.Key_Up:
            slider.nextItemInFocusChain(false).forceActiveFocus(Qt.BacktabFocusReason);
            break;
        default:
            return;
        }
        event.accepted = true;
    }
}
