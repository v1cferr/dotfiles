// Botão do cabeçalho da central de notificações (DND, Limpar).
// Arquivo próprio (não inline) pra o handler do MouseArea enxergar o id da raiz
// neste Qt — em inline component o id não resolve dentro de handler.
import QtQuick

Rectangle {
    id: hb
    property string text: ""
    property bool active: false
    signal clicked

    readonly property color colBorder: "#414868"
    readonly property color colText: "#c0caf5"
    readonly property color colPeach: "#ff9e64"
    readonly property string uiFont: "JetBrainsMono Nerd Font"

    implicitWidth: hbLabel.implicitWidth + 18
    implicitHeight: 26
    radius: 8
    opacity: hb.enabled ? 1 : 0.4
    color: hbArea.containsMouse ? "#33414868" : "transparent"
    border.color: hb.active ? hb.colPeach : hb.colBorder
    border.width: 1

    Text {
        id: hbLabel
        anchors.centerIn: parent
        text: hb.text
        color: hb.active ? hb.colPeach : hb.colText
        font.family: hb.uiFont
        font.pixelSize: 11
    }
    MouseArea {
        id: hbArea
        anchors.fill: parent
        hoverEnabled: true
        onClicked: hb.clicked()
    }
}
