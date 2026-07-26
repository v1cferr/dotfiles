// Botão do cabeçalho da central de notificações (DND, Limpar).
// Arquivo próprio (não inline) pra o handler do MouseArea enxergar o id da raiz
// neste Qt — em inline component o id não resolve dentro de handler.
import QtQuick
import "root:/"

Rectangle {
    id: hb
    property string text: ""
    property bool active: false
    signal clicked

    implicitWidth: hbLabel.implicitWidth + 18
    implicitHeight: 26
    radius: 8
    opacity: hb.enabled ? 1 : 0.4
    color: hbArea.containsMouse ? "#33414868" : "transparent"
    border.color: hb.active ? Theme.colPeach : Theme.colBorder
    border.width: 1

    Text {
        id: hbLabel
        anchors.centerIn: parent
        text: hb.text
        color: hb.active ? Theme.colPeach : Theme.colText
        font.family: Theme.uiFont
        font.pixelSize: 11
    }
    MouseArea {
        id: hbArea
        anchors.fill: parent
        hoverEnabled: true
        onClicked: hb.clicked()
    }
}
