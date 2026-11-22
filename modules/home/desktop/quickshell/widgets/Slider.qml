// A SLIDER for a level the user sets (a volume, a brightness): the icon outside, a thin track with
// a round knob, and the value as a number on the right. The owner holds the value; this only
// reports where the user put it. Its keys and the tap on the icon:
// docs/notes/desktop/nixos-center.md#the-levels
import QtQuick
import "root:/"

Item {
    id: slider
    property real value: 0 // 0..1, the owner's truth
    property string icon: "" // a Material Symbols name
    property string name: ""
    property real step: 0.05
    property bool dimmed: false // the level is there but not in effect (muted)
    // A way on from the value (the Sound page): a small chevron after the number, and the number
    // and the chevron are its button.
    property bool more: false
    property string moreName: ""
    // The value's column, the same on two sliders stacked so their tracks start and end together.
    property int tailWidth: slider.more ? 52 : 36
    signal moved(real value)
    signal iconClicked
    signal moreClicked

    implicitHeight: 24
    activeFocusOnTab: true
    Accessible.role: Accessible.Slider
    Accessible.name: slider.name + ", " + Math.round(slider.value * 100) + "%"

    readonly property real shown: Math.max(0, Math.min(1, slider.value))
    readonly property bool hot: trackArea.containsMouse || trackArea.pressed || slider.activeFocus

    // ── The icon: a tap is the mute ──
    Rectangle {
        id: iconCell
        width: slider.height
        height: slider.height
        radius: height / 2
        color: iconArea.containsMouse ? Theme.colHoverFill : "transparent"
        Text {
            anchors.centerIn: parent
            text: slider.icon
            color: slider.dimmed ? Theme.colDim : Theme.colSubtext
            font.family: Theme.iconFont
            font.pixelSize: Theme.iconBar
            font.variableAxes: Theme.iconAxes
        }
        MouseArea {
            id: iconArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: slider.iconClicked()
        }
    }

    // ── The track: 4 px, the filled part in the text's tone, a knob that grows under the hand ──
    Item {
        id: lane
        x: iconCell.width + Theme.sp2
        width: slider.width - x - Theme.sp2 - slider.tailWidth
        height: slider.height
        readonly property real knobR: slider.hot ? 8 : 6
        Rectangle {
            id: track
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width
            height: 4
            radius: 2
            color: Theme.colCellHoverFill
        }
        Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            width: Math.round(slider.shown * track.width)
            height: track.height
            radius: track.radius
            color: Qt.alpha(Theme.colText, slider.dimmed ? 0.3 : 0.75)
        }
        Rectangle {
            x: Math.round(slider.shown * track.width - lane.knobR)
            anchors.verticalCenter: parent.verticalCenter
            width: 2 * lane.knobR
            height: width
            radius: lane.knobR
            color: slider.dimmed ? Theme.colDim : Theme.colText
            border.width: slider.activeFocus ? 2 : 0
            border.color: Theme.colAccent
            Behavior on width {
                NumberAnimation {
                    duration: Theme.motionFast
                }
            }
        }
        MouseArea {
            id: trackArea
            anchors.fill: parent
            anchors.leftMargin: -lane.knobR
            anchors.rightMargin: -lane.knobR
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            function at(x) {
                slider.moved(Math.max(0, Math.min(1, (x - lane.knobR) / track.width)));
            }
            onPressed: m => at(m.x)
            onPositionChanged: m => {
                if (pressed)
                    at(m.x);
            }
        }
    }

    // ── The number, and the way on ──
    Rectangle {
        id: tail
        anchors.right: parent.right
        width: slider.tailWidth
        height: slider.height
        radius: Theme.radiusControl
        color: slider.more && tailArea.containsMouse ? Theme.colHoverFill : "transparent"
        // The number starts at the column's left, so two sliders stacked have their numbers aligned
        // whether one carries the chevron or not.
        Row {
            x: Theme.sp1
            anchors.verticalCenter: parent.verticalCenter
            spacing: 0
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: Math.round(slider.shown * 100) + "%"
                color: slider.dimmed ? Theme.colDim : Theme.colSubtext
                font.family: Theme.uiFont
                font.pixelSize: Theme.fontSmall
                font.features: Theme.fontTabular
            }
            Text {
                visible: slider.more
                anchors.verticalCenter: parent.verticalCenter
                text: "chevron_right"
                color: Theme.colDim
                font.family: Theme.iconFont
                font.pixelSize: Theme.iconBar
                font.variableAxes: Theme.iconAxes
            }
        }
        MouseArea {
            id: tailArea
            anchors.fill: parent
            enabled: slider.more
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            Accessible.role: Accessible.Button
            Accessible.name: slider.moreName
            onClicked: slider.moreClicked()
        }
    }

    // The wheel anywhere on it moves the level, a step per notch. A layer of its own over the rest
    // that takes no button, so the clicks still reach the icon, the track and the number: a
    // WheelHandler on the slider sat UNDER those areas and the wheel never reached it (22/11/2026).
    // A smooth wheel sends fractions of a notch; they add up to a step.
    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.NoButton
        property real pending: 0
        onWheel: w => {
            const d = w.angleDelta.y !== 0 ? w.angleDelta.y : -w.angleDelta.x;
            pending += d / 120;
            const notches = pending > 0 ? Math.floor(pending) : Math.ceil(pending);
            if (notches !== 0) {
                pending -= notches;
                slider.moved(Math.max(0, Math.min(1, slider.shown + notches * slider.step)));
            }
            w.accepted = true;
        }
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
