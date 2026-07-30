// Menu de contexto do system tray, tematizado TokyoNight (harmônico com o
// resto da barra). Renderiza o DBusMenu (com.canonical.dbusmenu) que os SNI
// nativos expõem, via QsMenuOpener. Só serve itens COM DBusMenu (hasMenu);
// os ícones que vêm pela ponte xembedsniproxy (wine/Battle.net, pamac) não têm
// DBusMenu e caem no tray-native-menu lá no Bar.qml — esses o app desenha sozinho
// e não dá pra tematizar aqui. MEDIDO num ícone desses (Battle.net no Bottles):
// Id é o window ID do X11 ("14680080"), Title/ToolTip vazios, Menu inexistente.
//
// Suporta: separadores, checkbox/radio (buttonType + checkState), itens
// desabilitados e UM nível de submenu (coluna à direita — cobre o "VPN
// Connections" do nm-applet). Fecha ao clicar fora via HyprlandFocusGrab.
//
// POR QUE PanelWindow (layer surface) E NÃO PopupWindow — bug DO HYPRLAND:
// como PopupWindow, este menu APARECIA mas não recebia UM evento de ponteiro:
// nenhum hover, e fechava sozinho aos 4s com o mouse parado em cima. Causa:
// hyprwm/Hyprland#6682 — popup Qt REDIMENSIONADO depois de exibido fica com a
// região de input errada (ela fica "centrada", desalinhada do que se vê). É
// exatamente o que acontece aqui: o openAt() torna a janela visível ANTES de o
// QsMenuOpener terminar de popular os itens, então o card nasce pequeno e
// cresce — e a região de input não acompanha. O issue foi reproduzido com o
// PRÓPRIO Quickshell e está FECHADO como "not planned": não vem correção de
// lá, tem de ser evitado aqui.
//
// Layer surface não passa por esse caminho (nada de xdg_surface::set_window_
// geometry) e é o que os outros 4 painéis desta barra já usam com hover
// funcionando (PowerMenu, Metrics, Calendar, Weather). De quebra cobre a
// ABERTURA DE SUBMENU, que também faz o card crescer depois de exibido.
//
// O preço é posicionar à mão: layer surface não tem anchor.rect nem
// PopupAdjustment.Slide, então o X vem do ícone clicado (via openAt) e o clamp
// de borda é explícito. O Y sai de graça: a barra reserva exclusiveZone 30, e
// um layer surface sem zona própria já é posicionado ABAIXO do reservado.
import Quickshell
import Quickshell.Hyprland
import QtQuick
import QtQuick.Layouts
import "root:/"

PanelWindow {
    id: root

    // QsMenuHandle do menu raiz e do submenu aberto (null = fechado).
    property var menuHandle: null
    property var submenuHandle: null
    // Janela da barra que abriu o menu (pra incluir no focus-grab: clicar noutro
    // ícone do tray TROCA o menu em vez de contar como "clique fora").
    property var barWindow: null
    // X de TELA desejado pra borda esquerda do menu (= borda esq. do ícone clicado).
    property int desiredX: 0

    visible: false
    color: "transparent"
    exclusiveZone: 0 // é menu, não painel: não reserva espaço de tela
    implicitWidth: card.implicitWidth
    implicitHeight: card.implicitHeight

    anchors {
        top: true
        left: true
    }
    margins {
        top: 4 // 4px abaixo da barra — o exclusiveZone 30 dela já está descontado
        // Alinha com o ícone sem vazar da tela. Como o tray fica na PONTA DIREITA,
        // na prática é o clamp que manda e o menu encosta na borda — que é o que o
        // PopupAdjustment.Slide fazia sozinho quando isto era PopupWindow.
        left: {
            const sw = root.screen ? root.screen.width : 1920;
            return Math.max(4, Math.min(root.desiredX, sw - root.implicitWidth - 4));
        }
    }

    // Abre o menu com a borda esquerda em `x` (coords de TELA), na tela de `win`.
    // Reseta visible antes pra reposicionar caso já esteja aberto em outro ícone.
    function openAt(handle, win, x) {
        root.visible = false;
        root.barWindow = win;
        root.screen = win.screen;
        root.desiredX = x;
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
        // um só lugar decide "está sob o cursor" — fundo, barra e seta leem daqui
        readonly property bool hovered: hov.containsMouse && entry.modelData.enabled
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
            // fade animado; colMenuHoverBg (accent 30%) e não colHoverBg — este último
            // dá 1.11:1 de contraste aqui, ou seja, hover que não se vê.
            color: entry.hovered ? Theme.colMenuHoverBg : "transparent"
            Behavior on color {
                ColorAnimation {
                    duration: Theme.hoverAnim
                    easing.type: Easing.OutQuad
                }
            }

            // Barra de acento que DESLIZA da esquerda. Vai junto do fundo de propósito:
            // é sinal de POSIÇÃO (aponta a linha), enquanto o fundo é sinal de área.
            // Redundância barata — resolve mesmo se a diferença de fundo passar batida.
            Rectangle {
                anchors.left: parent.left
                anchors.leftMargin: 2
                anchors.verticalCenter: parent.verticalCenter
                width: entry.hovered ? 3 : 0
                height: parent.height - 8
                radius: 1.5
                color: Theme.colAccent
                Behavior on width {
                    NumberAnimation {
                        duration: Theme.hoverAnim
                        easing.type: Easing.OutQuad
                    }
                }
            }

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
                    // NÃO acende no accent: sobre o fundo aceso o accent cai a 3.83:1 de
                    // contraste, contra 5.97:1 do colText. Legibilidade > efeito.
                    color: entry.modelData.enabled ? Theme.colText : Theme.colDim
                    font.family: Theme.uiFont
                    font.pixelSize: 12
                }

                // seta de submenu
                Text {
                    visible: entry.modelData.hasChildren
                    Layout.preferredWidth: entry.modelData.hasChildren ? 12 : 0
                    text: "›"
                    color: entry.hovered ? Theme.colText : Theme.colDim
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
