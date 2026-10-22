// The NixOS Center's confirmation: the card shows THIS instead of its sections while a session
// action asks (Log out, Reboot, Shut down) or any action failed. State: Power.qml.
// Keys and why it lives in the card: docs/notes/desktop/nixos-center.md
import QtQuick
import QtQuick.Layouts
import "root:/"

ColumnLayout {
    id: view
    readonly property var s: Power.state
    readonly property var a: Power.current
    readonly property bool asking: view.s.phase === "confirm"
    readonly property bool failed: view.s.phase === "error"
    readonly property bool going: view.s.phase === "handoff" || (view.s.phase === "busy" && !!view.a && !!view.a.ends)
    spacing: Theme.sp3

    function focusDefault() {
        cancelBtn.forceActiveFocus(); // the safe answer is the default one
    }
    // Confirming hides the focused button: the failure that follows hands the focus to Close.
    onFailedChanged: if (view.failed)
        Qt.callLater(view.focusDefault)

    // The keys reach the focused button first; Escape bubbles up to here and answers "no".
    Keys.onPressed: event => {
        if (event.key === Qt.Key_Escape && !view.going) {
            Power.cancel();
            event.accepted = true;
        }
    }

    RowLayout {
        Layout.fillWidth: true
        Layout.topMargin: Theme.sp2
        spacing: Theme.sp3
        Text {
            text: view.a ? view.a.icon : ""
            color: view.failed ? Theme.colCrit : Theme.colRed
            font.family: Theme.uiFont
            font.pixelSize: 28
        }
        Text {
            Layout.fillWidth: true
            text: view.failed ? (view.a ? view.a.label + " did not happen" : "") : view.going ? (view.a.going || view.a.label) : (view.a ? view.a.title || "" : "")
            color: Theme.colText
            font.family: Theme.uiFont
            font.pixelSize: Theme.fontTitle + 2
            font.bold: true
            wrapMode: Text.WordWrap
        }
    }

    Text {
        Layout.fillWidth: true
        text: view.failed ? view.s.error || "" : view.going ? "The system is closing the session." : (view.a ? view.a.body || "" : "")
        color: view.failed ? Theme.colCrit : Theme.colSubtext
        font.family: Theme.uiFont
        font.pixelSize: Theme.fontBody
        wrapMode: Text.WordWrap
    }

    // Two buttons while asking, one while showing a failure, none once the OS has it.
    RowLayout {
        Layout.fillWidth: true
        Layout.topMargin: Theme.sp2
        Layout.bottomMargin: Theme.sp2
        spacing: Theme.sp2
        visible: !view.going
        Item {
            Layout.fillWidth: true
        }
        ConfirmButton {
            id: cancelBtn
            label: view.failed ? "Close" : "Cancel"
            KeyNavigation.right: confirmBtn
            KeyNavigation.tab: confirmBtn.visible ? confirmBtn : cancelBtn
            onActivated: Power.cancel()
        }
        ConfirmButton {
            id: confirmBtn
            visible: view.asking
            danger: true
            label: view.a && view.a.verb ? view.a.verb : "Confirm"
            KeyNavigation.left: cancelBtn
            KeyNavigation.tab: cancelBtn
            onActivated: Power.confirm()
        }
    }

    component ConfirmButton: Rectangle {
        id: btn
        property string label: ""
        property bool danger: false
        signal activated
        implicitWidth: Math.max(96, txt.implicitWidth + 2 * Theme.sp4)
        implicitHeight: 34
        radius: Theme.radiusControl
        color: btn.danger ? (area.pressed ? Qt.darker(Theme.colRed, 1.15) : Theme.colRed) : (area.pressed ? Theme.colPressFill : (area.containsMouse ? Theme.colHoverFill : "transparent"))
        // `focus`, not `activeFocus`: the ring must stay while the keyboard is re-entered.
        border.width: btn.focus ? 2 : Theme.hairline
        border.color: btn.focus ? Theme.colAccent : Theme.colEdge
        activeFocusOnTab: true
        Accessible.role: Accessible.Button
        Accessible.name: btn.label
        Accessible.onPressAction: btn.activated()
        Behavior on color {
            ColorAnimation {
                duration: Theme.ms(Theme.motionHover)
            }
        }
        Keys.onPressed: event => {
            if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_Space) {
                btn.activated();
                event.accepted = true;
            }
        }
        Text {
            id: txt
            anchors.centerIn: parent
            text: btn.label
            color: btn.danger ? Theme.colBgSolid : Theme.colText
            font.family: Theme.uiFont
            font.pixelSize: Theme.fontLabel
            font.bold: btn.danger
        }
        MouseArea {
            id: area
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: btn.activated()
        }
    }
}
