// UI das notificações: toasts (canto superior direito do DP-1) + central de
// notificações (toggle pelo sino da barra). Lê o serviço Notifs.qml. Estilo
// Tokyo Night, alinhado com a barra / OSD / painéis.
// O card (NotifCard.qml) e o botão do cabeçalho (HeaderBtn.qml) são arquivos
// próprios — inline component quebra o escopo da raiz nos handlers neste Qt.
import Quickshell
import Quickshell.Services.Notifications
import QtQuick
import QtQuick.Layouts

Scope {
    id: root

    // ===== Toasts — topo-direita do DP-1 =====
    PanelWindow {
        id: popupWin
        visible: Notifs.popups.length > 0
        screen: Theme.screenDP1
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

    // ===== Central — painel no TOPO-CENTRO, ajustado ao conteúdo (cresce com as
    // notificações até um teto, depois rola). Toggle pelo sino. =====
    PanelWindow {
        id: centerWin
        visible: Notifs.centerVisible
        screen: Theme.screenDP1
        // só `top` => o layer-shell centraliza horizontalmente
        anchors {
            top: true
        }
        margins {
            top: 8
        }
        exclusiveZone: 0
        color: "transparent"
        implicitWidth: 420
        implicitHeight: centerCard.implicitHeight

        // Some sozinha após 5s; o contador pausa enquanto o mouse está no painel
        // (e reinicia do zero quando o mouse sai).
        Timer {
            running: Notifs.centerVisible && !centerHover.hovered
            interval: 5000
            onTriggered: Notifs.centerVisible = false
        }

        Rectangle {
            id: centerCard
            anchors.fill: parent
            implicitHeight: centerCol.implicitHeight + 28
            radius: 14
            color: Theme.colBg
            border.color: Theme.colBorder
            border.width: 1

            HoverHandler {
                id: centerHover
            }

            ColumnLayout {
                id: centerCol
                anchors.fill: parent
                anchors.margins: 14
                spacing: 12

                // Cabeçalho: título + badge de contagem + ações
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8
                    Text {
                        text: "󰂚"
                        color: Theme.colAccent
                        font.family: Theme.uiFont
                        font.pixelSize: 16
                    }
                    Text {
                        text: "Notificações"
                        color: Theme.colText
                        font.family: Theme.uiFont
                        font.pixelSize: 14
                        font.bold: true
                    }
                    Rectangle {
                        visible: Notifs.count > 0
                        implicitWidth: badge.implicitWidth + 12
                        implicitHeight: 18
                        radius: 9
                        color: Theme.colAccent
                        Text {
                            id: badge
                            anchors.centerIn: parent
                            text: "" + Notifs.count
                            color: "#1a1b26"
                            font.family: Theme.uiFont
                            font.pixelSize: 10
                            font.bold: true
                        }
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
                    implicitHeight: 1
                    color: Theme.colBorder
                    opacity: 0.5
                }

                // Estado vazio — compacto e centralizado
                ColumnLayout {
                    visible: Notifs.count === 0
                    Layout.alignment: Qt.AlignHCenter
                    Layout.topMargin: 8
                    Layout.bottomMargin: 8
                    spacing: 6
                    Text {
                        Layout.alignment: Qt.AlignHCenter
                        text: "󰂜"
                        color: Theme.colDim
                        font.family: Theme.uiFont
                        font.pixelSize: 32
                    }
                    Text {
                        Layout.alignment: Qt.AlignHCenter
                        text: "Sem notificações"
                        color: Theme.colDim
                        font.family: Theme.uiFont
                        font.pixelSize: 12
                    }
                }

                // Lista — cresce com o conteúdo até 560px, depois rola
                ListView {
                    visible: Notifs.count > 0
                    Layout.fillWidth: true
                    Layout.preferredHeight: Math.min(contentHeight, 560)
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
}
