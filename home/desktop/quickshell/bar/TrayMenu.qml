// Menu de contexto do system tray, tematizado TokyoNight (harmônico com o
// resto da barra). Renderiza o DBusMenu (com.canonical.dbusmenu) que os SNI
// nativos expõem, via QsMenuOpener. Só serve itens COM DBusMenu (hasMenu);
// os ícones do xembedsniproxy (wine/Battle.net, pamac) não têm DBusMenu e
// caem no display() nativo lá no Bar.qml — esses o app desenha sozinho e não
// dá pra tematizar aqui.
//
// Suporta: separadores, checkbox/radio (buttonType + checkState), itens
// desabilitados e UM nível de submenu (coluna à direita — cobre o "VPN
// Connections" do nm-applet). Fecha ao clicar fora via HyprlandFocusGrab.
import Quickshell
import Quickshell.Hyprland
import QtQuick
import QtQuick.Layouts
import "root:/"

PopupWindow {
    id: root

    // QsMenuHandle do menu raiz e do submenu aberto (null = fechado).
    property var menuHandle: null
    property var submenuHandle: null
    // Janela da barra que abriu o menu (pra incluir no focus-grab: clicar noutro
    // ícone do tray TROCA o menu em vez de contar como "clique fora").
    property var barWindow: null

    color: "transparent"
    visible: false
    implicitWidth: card.implicitWidth
    implicitHeight: card.implicitHeight

    // Abre o menu ancorado abaixo de `rect` na janela `win`. Reseta visible
    // antes pra forçar reposicionar caso já esteja aberto em outro ícone.
    function openAt(handle, win, rect) {
        root.visible = false;
        root.barWindow = win;
        root.anchor.window = win;
        root.anchor.rect = rect;
        root.anchor.edges = Edges.Bottom;
        root.anchor.gravity = Edges.Bottom;
        root.anchor.adjustment = PopupAdjustment.Flip | PopupAdjustment.Slide;
        root.submenuHandle = null;
        root.menuHandle = handle;
        root.visible = true;
    }
    function closeMenu() {
        root.visible = false;
        root.menuHandle = null;
        root.submenuHandle = null;
    }

    // Some sozinho após um tempo se o mouse não estiver sobre o menu (pausa
    // enquanto o cursor está em cima; reinicia a contagem ao sair).
    Timer {
        running: root.visible && !menuHover.hovered
        interval: 4000
        onTriggered: root.closeMenu()
    }

    QsMenuOpener {
        id: opener
        menu: root.menuHandle
    }
    QsMenuOpener {
        id: subOpener
        menu: root.submenuHandle
    }

    // Clique fora → fecha. Inclui a barra no grab pra que clicar noutro ícone do
    // tray TROQUE o menu (o clique chega no ícone) em vez de contar como "fora".
    HyprlandFocusGrab {
        active: root.visible
        windows: root.barWindow ? [root, root.barWindow] : [root]
        onCleared: root.closeMenu()
    }

    // Delegate reutilizado pela coluna principal e pela do submenu.
    // `menu` recebe o controller (o próprio root) por propriedade — evita
    // depender de acesso a id externo dentro do component inline.
    component MenuEntry: Item {
        id: entry
        required property var modelData
        property var menu: null
        property bool isSub: false
        width: parent ? parent.width : 180
        implicitWidth: entry.modelData.isSeparator ? 40 : (rowInner.implicitWidth + 16)
        implicitHeight: entry.modelData.isSeparator ? 7 : 26

        // separador
        Rectangle {
            visible: entry.modelData.isSeparator
            anchors.verticalCenter: parent.verticalCenter
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.leftMargin: 6
            anchors.rightMargin: 6
            height: 1
            color: Theme.colBorder
            opacity: 0.6
        }

        // item normal
        Rectangle {
            visible: !entry.modelData.isSeparator
            anchors.fill: parent
            radius: 6
            color: (hov.containsMouse && entry.modelData.enabled) ? "#33414868" : "transparent"

            RowLayout {
                id: rowInner
                anchors.fill: parent
                anchors.leftMargin: 8
                anchors.rightMargin: 8
                spacing: 8

                // marca de checkbox/radio (buttonType: 1=check, 2=radio)
                Text {
                    visible: entry.modelData.buttonType !== 0
                    Layout.preferredWidth: entry.modelData.buttonType !== 0 ? 12 : 0
                    text: entry.modelData.buttonType === 2 ? (entry.modelData.checkState === 2 ? "◉" : "○") : (entry.modelData.checkState === 2 ? "✓" : "")
                    color: Theme.colAccent
                    font.family: Theme.uiFont
                    font.pixelSize: 12
                }

                Text {
                    Layout.fillWidth: true
                    elide: Text.ElideRight
                    // tira os mnemônicos "_" do label do DBusMenu
                    text: ("" + entry.modelData.text).replace(/_(.)/g, "$1")
                    color: entry.modelData.enabled ? Theme.colText : Theme.colDim
                    font.family: Theme.uiFont
                    font.pixelSize: 12
                }

                // seta de submenu
                Text {
                    visible: entry.modelData.hasChildren
                    Layout.preferredWidth: entry.modelData.hasChildren ? 12 : 0
                    text: "›"
                    color: Theme.colDim
                    font.family: Theme.uiFont
                    font.pixelSize: 14
                }
            }

            MouseArea {
                id: hov
                anchors.fill: parent
                hoverEnabled: true
                enabled: entry.modelData.enabled && !entry.modelData.isSeparator
                onClicked: {
                    if (entry.modelData.hasChildren) {
                        // toggla o submenu (mesmo item fecha; outro troca)
                        entry.menu.submenuHandle = (entry.menu.submenuHandle === entry.modelData) ? null : entry.modelData;
                    } else {
                        entry.modelData.triggered();
                        entry.menu.closeMenu();
                    }
                }
            }
        }
    }

    Row {
        id: card
        spacing: 6

        // hover no menu pausa o auto-hide
        HoverHandler {
            id: menuHover
        }

        // coluna principal
        Rectangle {
            id: mainCol
            implicitWidth: Math.min(360, Math.max(160, mainList.implicitWidth + 16))
            implicitHeight: mainList.implicitHeight + 12
            radius: 10
            color: Theme.colBg
            border.color: Theme.colBorder
            border.width: 1

            Column {
                id: mainList
                x: 8
                y: 6
                width: mainCol.width - 16
                spacing: 1
                Repeater {
                    model: opener.children ? opener.children.values : []
                    delegate: MenuEntry {
                        menu: root
                    }
                }
            }
        }

        // coluna do submenu (aparece à direita quando há um aberto)
        Rectangle {
            visible: root.submenuHandle !== null
            implicitWidth: visible ? Math.min(360, Math.max(160, subList.implicitWidth + 16)) : 0
            implicitHeight: subList.implicitHeight + 12
            radius: 10
            color: Theme.colBg
            border.color: Theme.colBorder
            border.width: 1

            Column {
                id: subList
                x: 8
                y: 6
                width: parent.width - 16
                spacing: 1
                Repeater {
                    model: subOpener.children ? subOpener.children.values : []
                    delegate: MenuEntry {
                        menu: root
                        isSub: true
                    }
                }
            }
        }
    }
}
