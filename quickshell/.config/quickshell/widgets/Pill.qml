// Pílula/chip reutilizável da barra. Antes era inline component dentro do
// Bar.qml; agora arquivo próprio (reuso + o id da raiz resolve nos handlers, o
// que inline component não garante neste Qt). Cores via Theme.
import QtQuick
import QtQuick.Layouts
import "root:/"

Rectangle {
    id: pill
    property string icon: ""
    property string label: ""
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
