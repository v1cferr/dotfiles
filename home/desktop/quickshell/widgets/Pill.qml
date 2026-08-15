// The bar's reusable pill/chip. It used to be an inline component inside Bar.qml; now it is its
// own file (reuse, plus the root's id resolves in the handlers, which an inline component does
// not guarantee on this Qt). The colors come from Theme.
import QtQuick
import QtQuick.Layouts
import "root:/"

Rectangle {
    id: pill
    property string icon: ""
    property string label: ""
    // Secondary text in the SAME pill: after the label and in a discreet color, for two pieces
    // of data that travel together without becoming two pills (the date next to the time, say).
    // It comes AFTER on purpose: the label is the main information and sits on the left edge,
    // which is where the eye enters the pill, and `sub` is the complement and does not compete
    // for that spot.
    property string sub: ""
    property color accent: Theme.colText
    property int maxWidth: 0
    signal clicked
    signal rightClicked
    signal scrolledUp
    signal scrolledDown
    property alias hovered: area.containsMouse
    property bool italic: false

    implicitWidth: (pill.maxWidth > 0) ? Math.min(prow.implicitWidth + 22, pill.maxWidth) : prow.implicitWidth + 22
    implicitHeight: 22
    radius: 8
    color: area.containsMouse ? Theme.colPillHoverBg : Theme.colPillBg
    border.color: area.containsMouse ? Theme.colHoverBorder : Theme.colPillBorder
    border.width: 1
    Behavior on color {
        ColorAnimation {
            duration: 200
            easing.type: Easing.InOutQuad
        }
    }
    Behavior on border.color {
        ColorAnimation {
            duration: 200
        }
    }

    RowLayout {
        id: prow
        anchors.fill: parent
        anchors.leftMargin: 11
        anchors.rightMargin: 11
        spacing: 5
        Text {
            visible: pill.icon !== ""
            text: pill.icon
            color: pill.accent
            font.family: Theme.uiFont
            font.pixelSize: 13
        }
        Text {
            visible: pill.label !== ""
            Layout.fillWidth: pill.maxWidth > 0
            text: pill.label
            color: pill.accent
            font.family: Theme.uiFont
            font.pixelSize: 11
            font.italic: pill.italic
            elide: Text.ElideRight
        }
        Text {
            visible: pill.sub !== ""
            text: pill.sub
            color: Theme.colDim
            font.family: Theme.uiFont
            font.pixelSize: 11
        }
    }
    MouseArea {
        id: area
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        onClicked: m => {
            if (m.button === Qt.RightButton)
                pill.rightClicked();
            else
                pill.clicked();
        }
        onWheel: w => {
            if (w.angleDelta.y > 0)
                pill.scrolledUp();
            else
                pill.scrolledDown();
        }
    }
}
