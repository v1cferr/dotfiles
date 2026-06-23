// UI das notificações: toasts (canto superior direito do DP-1) + central de
// notificações (toggle pelo sino da barra). Lê o serviço Notifs.qml. Estilo
// Tokyo Night, alinhado com a barra / OSD / painéis.
import Quickshell
import Quickshell.Services.Notifications
import QtQuick
import QtQuick.Layouts

Scope {
    id: root

    // Paleta Tokyo Night (mesma da barra)
    readonly property color colBg: "#f21a1b26"
    readonly property color colCard: "#f21f2336"
    readonly property color colBorder: "#414868"
    readonly property color colText: "#c0caf5"
    readonly property color colDim: "#565f89"
    readonly property color colAccent: "#7aa2f7"
    readonly property color colRed: "#f38ba8"
    readonly property color colPeach: "#ff9e64"
    readonly property string uiFont: "JetBrainsMono Nerd Font"

    readonly property var screenDP1: {
        const s = Quickshell.screens;
        for (let i = 0; i < s.length; i++)
            if (s[i].name === "DP-1")
                return s[i];
        return s.length ? s[0] : null;
    }

    function urgColor(u) {
        if (u === NotificationUrgency.Critical)
            return root.colRed;
        if (u === NotificationUrgency.Low)
            return root.colDim;
        return root.colAccent;
    }

    // ===== Toasts — topo-direita do DP-1 =====
    PanelWindow {
        id: popupWin
        visible: Notifs.popups.length > 0
        screen: root.screenDP1
        anchors {
            top: true
            right: true
        }
        margins {
            top: 8
            right: 8
        }
        exclusiveZone: 0
        color: "transparent"
        implicitWidth: 390
        implicitHeight: Math.max(1, popupCol.implicitHeight)

        ColumnLayout {
            id: popupCol
            anchors.fill: parent
            spacing: 8
            Repeater {
                model: Notifs.popups
                NotifCard {
                    required property var modelData
                    Layout.fillWidth: true
                    notif: modelData
                    isPopup: true
                }
            }
        }
    }

    // ===== Central — coluna full-height à direita, toggle pelo sino =====
    PanelWindow {
        id: centerWin
        visible: Notifs.centerVisible
        screen: root.screenDP1
        anchors {
            top: true
            right: true
            bottom: true
        }
        margins {
            top: 8
            right: 8
            bottom: 8
        }
        exclusiveZone: 0
        color: "transparent"
        implicitWidth: 410

        Rectangle {
            anchors.fill: parent
            radius: 12
            color: root.colBg
            border.color: root.colBorder
            border.width: 1

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 14
                spacing: 10

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8
                    Text {
                        text: "󰂚  Notificações"
                        color: root.colAccent
                        font.family: root.uiFont
                        font.pixelSize: 15
                        font.bold: true
                    }
                    Item {
                        Layout.fillWidth: true
                    }
                    HeaderBtn {
                        text: Notifs.dnd ? "󰂛 DND" : "󰂚 DND"
                        active: Notifs.dnd
                        onClicked: Notifs.toggleDnd()
                    }
                    HeaderBtn {
                        text: "󰎟 Limpar"
                        enabled: Notifs.count > 0
                        onClicked: Notifs.clearAll()
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    height: 1
                    color: root.colBorder
                    opacity: 0.5
                }

                Text {
                    visible: Notifs.count === 0
                    Layout.fillWidth: true
                    Layout.topMargin: 24
                    horizontalAlignment: Text.AlignHCenter
                    text: "Sem notificações"
                    color: root.colDim
                    font.family: root.uiFont
                    font.pixelSize: 12
                }

                ListView {
                    visible: Notifs.count > 0
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    clip: true
                    spacing: 8
                    model: Notifs.history
                    delegate: NotifCard {
                        required property var modelData
                        width: ListView.view.width
                        notif: modelData
                        isPopup: false
                    }
                }
            }
        }
    }

    // ===== Botão do cabeçalho da central =====
    component HeaderBtn: Rectangle {
        id: hb
        property string text: ""
        property bool active: false
        signal clicked
        implicitWidth: hbLabel.implicitWidth + 18
        implicitHeight: 26
        radius: 8
        opacity: hb.enabled ? 1 : 0.4
        color: hbArea.containsMouse ? "#33414868" : "transparent"
        border.color: hb.active ? root.colPeach : root.colBorder
        border.width: 1
        Text {
            id: hbLabel
            anchors.centerIn: parent
            text: hb.text
            color: hb.active ? root.colPeach : root.colText
            font.family: root.uiFont
            font.pixelSize: 11
        }
        MouseArea {
            id: hbArea
            anchors.fill: parent
            hoverEnabled: true
            onClicked: hb.clicked()
        }
    }

    // ===== Card de notificação (serve toast e histórico) =====
    component NotifCard: Rectangle {
        id: card
        property var notif
        property bool isPopup: false

        implicitHeight: cardRow.implicitHeight + 20
        radius: 12
        color: root.colCard
        border.color: card.notif ? root.urgColor(card.notif.urgency) : root.colBorder
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

        // Botão DIREITO em qualquer ponto do card = dispensar (dismiss).
        // Fica no fundo (z-order): os botões de ação tratam o clique esquerdo por
        // cima; o direito não é aceito por eles e propaga até aqui.
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
                    visible: card.notif && card.notif.image !== ""
                    source: card.notif ? card.notif.image : ""
                    fillMode: Image.PreserveAspectCrop
                    sourceSize.width: 36
                    sourceSize.height: 36
                }
                Text {
                    anchors.centerIn: parent
                    visible: !nimg.visible
                    text: "󰂚"
                    color: card.notif ? root.urgColor(card.notif.urgency) : root.colAccent
                    font.family: root.uiFont
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
                        color: root.colDim
                        font.family: root.uiFont
                        font.pixelSize: 10
                        elide: Text.ElideRight
                    }
                    Text {
                        text: "✕"
                        color: closeArea.containsMouse ? root.colRed : root.colDim
                        font.family: root.uiFont
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
                    color: root.colText
                    font.family: root.uiFont
                    font.pixelSize: 13
                    font.bold: true
                    wrapMode: Text.WordWrap
                }
                Text {
                    visible: text !== ""
                    Layout.fillWidth: true
                    text: card.notif ? card.notif.body : ""
                    color: root.colText
                    font.family: root.uiFont
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
                            border.color: root.colBorder
                            border.width: 1
                            Text {
                                id: actLabel
                                anchors.centerIn: parent
                                text: modelData.text
                                color: root.colText
                                font.family: root.uiFont
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
}
