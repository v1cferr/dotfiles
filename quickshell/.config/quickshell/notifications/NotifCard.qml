// Card de notificação (usado pelos toasts e pela central).
// É um ARQUIVO próprio de propósito: em inline component (component X: ...) o id
// e as propriedades da raiz NÃO resolvem dentro de handlers aninhados neste Qt
// (ReferenceError), o que quebrava dismiss/ações. Em arquivo separado, card.notif
// resolve em qualquer profundidade. Estilo Tokyo Night.
import Quickshell
import Quickshell.Services.Notifications
import QtQuick
import QtQuick.Layouts
import "root:/"

Rectangle {
    id: card
    property var notif
    property bool isPopup: false

    function urgColor(u) {
        if (u === NotificationUrgency.Critical)
            return Theme.colRed;
        if (u === NotificationUrgency.Low)
            return Theme.colDim;
        return Theme.colAccent;
    }

    // Ícone do card: dado de imagem (capa/print) ou ícone do app que notificou >
    // sino genérico. O Quickshell entrega o ícone do app como "image://icon/<nome>";
    // se o ícone NÃO existe no tema atual, o provider devolve um placeholder
    // quadriculado que "carrega ok" — por isso validamos com hasThemeIcon.
    readonly property string iconSource: {
        if (!card.notif)
            return "";
        const img = card.notif.image || "";
        const m = img.match(/^image:\/\/icon\/(.+)$/);
        if (m)
            return Quickshell.hasThemeIcon(m[1]) ? img : "";
        if (img !== "")
            return img;
        const ai = card.notif.appIcon || "";
        if (ai === "")
            return "";
        if (ai.startsWith("/"))
            return "file://" + ai;
        return Quickshell.hasThemeIcon(ai) ? Quickshell.iconPath(ai) : "";
    }

    implicitHeight: cardRow.implicitHeight + 20
    radius: 12
    color: Theme.colCard
    border.color: card.notif ? card.urgColor(card.notif.urgency) : Theme.colBorder
    border.width: 1

    // Auto-dismiss do toast; Critical permanece até interação.
    Timer {
        running: card.isPopup && card.notif && card.notif.urgency !== NotificationUrgency.Critical
        interval: (card.notif && card.notif.urgency === NotificationUrgency.Low) ? 4000 : 6000
        onTriggered: Notifs.removePopup(card.notif)
    }
    // Fechada por fora (app/central/expira) -> remove o toast também.
    Connections {
        target: card.notif
        function onClosed(reason) {
            Notifs.removePopup(card.notif);
        }
    }

    // Botão DIREITO em qualquer ponto do card = dispensar (dismiss). Fica no fundo
    // (z-order): os botões de ação tratam o esquerdo por cima; o direito propaga.
    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.RightButton
        onClicked: Notifs.dismiss(card.notif)
    }

    RowLayout {
        id: cardRow
        anchors.fill: parent
        anchors.margins: 10
        spacing: 10

        Item {
            Layout.alignment: Qt.AlignTop
            implicitWidth: 36
            implicitHeight: 36
            Image {
                id: nimg
                anchors.fill: parent
                // some (cai no sino) se a fonte for vazia OU falhar ao carregar —
                // evita o quadriculado magenta/preto de "imagem quebrada" do Qt.
                visible: card.iconSource !== "" && nimg.status !== Image.Error
                source: card.iconSource
                asynchronous: true
                fillMode: Image.PreserveAspectFit
                sourceSize.width: 36
                sourceSize.height: 36
            }
            Text {
                anchors.centerIn: parent
                visible: !nimg.visible
                text: "󰂚"
                color: card.notif ? card.urgColor(card.notif.urgency) : Theme.colAccent
                font.family: Theme.uiFont
                font.pixelSize: 22
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 2

            RowLayout {
                Layout.fillWidth: true
                Text {
                    Layout.fillWidth: true
                    text: card.notif ? card.notif.appName : ""
                    color: Theme.colDim
                    font.family: Theme.uiFont
                    font.pixelSize: 10
                    elide: Text.ElideRight
                }
                Text {
                    text: "✕"
                    color: closeArea.containsMouse ? Theme.colRed : Theme.colDim
                    font.family: Theme.uiFont
                    font.pixelSize: 12
                    MouseArea {
                        id: closeArea
                        anchors.fill: parent
                        anchors.margins: -4
                        hoverEnabled: true
                        onClicked: Notifs.dismiss(card.notif)
                    }
                }
            }
            Text {
                visible: text !== ""
                Layout.fillWidth: true
                text: card.notif ? card.notif.summary : ""
                color: Theme.colText
                font.family: Theme.uiFont
                font.pixelSize: 13
                font.bold: true
                wrapMode: Text.WordWrap
            }
            Text {
                visible: text !== ""
                Layout.fillWidth: true
                text: card.notif ? card.notif.body : ""
                color: Theme.colText
                font.family: Theme.uiFont
                font.pixelSize: 11
                textFormat: Text.StyledText
                wrapMode: Text.WordWrap
                opacity: 0.85
            }

            RowLayout {
                Layout.fillWidth: true
                Layout.topMargin: 4
                visible: card.notif && card.notif.actions.length > 0
                spacing: 6
                Repeater {
                    model: card.notif ? card.notif.actions : []
                    Rectangle {
                        required property var modelData
                        implicitWidth: actLabel.implicitWidth + 18
                        implicitHeight: 24
                        radius: 7
                        color: actArea.containsMouse ? "#33414868" : "transparent"
                        border.color: Theme.colBorder
                        border.width: 1
                        Text {
                            id: actLabel
                            anchors.centerIn: parent
                            text: modelData.text
                            color: Theme.colText
                            font.family: Theme.uiFont
                            font.pixelSize: 10
                        }
                        MouseArea {
                            id: actArea
                            anchors.fill: parent
                            hoverEnabled: true
                            onClicked: {
                                modelData.invoke();
                                Notifs.dismiss(card.notif);
                            }
                        }
                    }
                }
            }
        }
    }
}
