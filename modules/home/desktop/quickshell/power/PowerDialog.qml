// The session's confirmation: ONE window, on the main monitor only, over a dimmed desktop. It asks
// before Log out, Reboot and Shut down, and shows any action's failure. State: Power.qml.
// Keys, focus and motion: docs/notes/desktop/nixos-center.md
import Quickshell
import Quickshell.Wayland
import QtQuick
import QtQuick.Layouts
import "root:/"
import "root:/widgets"

PanelWindow {
    id: dialog
    readonly property var s: Power.state
    readonly property var a: Power.current
    readonly property bool asking: dialog.s.phase === "confirm"
    readonly property bool failed: dialog.s.phase === "error"
    readonly property bool going: dialog.s.phase === "handoff" || (dialog.s.phase === "busy" && !!dialog.a && !!dialog.a.ends)

    // A safe action that fails also lands here: the failure is the one thing it must not hide.
    visible: !!dialog.a && (dialog.asking || dialog.failed || dialog.going)
    screen: Theme.screenPrimary
    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }
    exclusionMode: ExclusionMode.Ignore // over the bar too
    color: Theme.colScrim // the dim; the fade is Hyprland's layer animation
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "qs-dialog" // outside the blur rule on purpose: a dim, not a frosted screen
    // Exclusive while it asks: Escape and Enter must reach it whatever window had the focus.
    WlrLayershell.keyboardFocus: dialog.asking || dialog.failed ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    // The monitor it lives on went away, or another one became the main: never ask on a dark screen.
    Connections {
        target: Theme
        function onScreenPrimaryChanged() {
            Power.cancel();
        }
    }
    onVisibleChanged: if (dialog.visible)
        cancelBtn.forceActiveFocus() // the safe answer is the default one

    // A click on the dim answers "no", like Escape. A click on the card is the card's.
    MouseArea {
        anchors.fill: parent
        onClicked: Power.cancel()
    }

    Item {
        anchors.fill: parent
        Keys.onPressed: event => {
            if (event.key === Qt.Key_Escape) {
                Power.cancel();
                event.accepted = true;
            }
        }

        // The card's own area, under it: a click on the card never falls through to the dim.
        MouseArea {
            anchors.fill: card
        }

        PopCard {
            id: card
            shown: dialog.visible
            anchors.fill: undefined
            anchors.centerIn: parent
            width: 400
            pad: Theme.sp6
            gap: Theme.sp4

            RowLayout {
                Layout.fillWidth: true
                spacing: Theme.sp3
                Text {
                    text: dialog.a ? dialog.a.icon : ""
                    color: dialog.failed ? Theme.colCrit : Theme.colRed
                    font.family: Theme.uiFont
                    font.pixelSize: 28
                }
                Text {
                    Layout.fillWidth: true
                    text: dialog.failed ? (dialog.a ? dialog.a.label + " did not happen" : "") : dialog.going ? (dialog.a.going || dialog.a.label) : (dialog.a ? dialog.a.title || "" : "")
                    color: Theme.colText
                    font.family: Theme.uiFont
                    font.pixelSize: Theme.fontTitle + 2
                    font.bold: true
                    wrapMode: Text.WordWrap
                }
            }

            Text {
                Layout.fillWidth: true
                text: dialog.failed ? dialog.s.error || "" : dialog.going ? "The system is closing the session." : (dialog.a ? dialog.a.body || "" : "")
                color: dialog.failed ? Theme.colCrit : Theme.colSubtext
                font.family: Theme.uiFont
                font.pixelSize: Theme.fontBody
                wrapMode: Text.WordWrap
            }

            // Two buttons while asking, one while showing a failure, none once the OS has it.
            RowLayout {
                Layout.fillWidth: true
                Layout.topMargin: Theme.sp2
                spacing: Theme.sp2
                visible: !dialog.going
                Item {
                    Layout.fillWidth: true
                }
                DialogButton {
                    id: cancelBtn
                    label: dialog.failed ? "Close" : "Cancel"
                    KeyNavigation.right: confirmBtn
                    KeyNavigation.tab: confirmBtn.visible ? confirmBtn : cancelBtn
                    onActivated: Power.cancel()
                }
                DialogButton {
                    id: confirmBtn
                    visible: dialog.asking
                    danger: true
                    label: dialog.a && dialog.a.verb ? dialog.a.verb : "Confirm"
                    KeyNavigation.left: cancelBtn
                    KeyNavigation.tab: cancelBtn
                    onActivated: Power.confirm()
                }
            }
        }
    }

    component DialogButton: Rectangle {
        id: btn
        property string label: ""
        property bool danger: false
        signal activated
        implicitWidth: Math.max(96, txt.implicitWidth + 2 * Theme.sp4)
        implicitHeight: 34
        radius: Theme.radiusControl
        color: btn.danger ? (area.pressed ? Qt.darker(Theme.colRed, 1.15) : Theme.colRed) : (area.pressed ? Theme.colPressFill : (area.containsMouse ? Theme.colHoverFill : "transparent"))
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
