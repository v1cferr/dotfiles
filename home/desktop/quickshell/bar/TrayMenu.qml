// The tray's context menu, themed: it renders the DBusMenu native SNIs expose. It is a LAYER
// SURFACE and not a PopupWindow (Hyprland#6682, closed as not: docs/notes/desktop/quickshell.md
import Quickshell
import Quickshell.Hyprland
import QtQuick
import QtQuick.Layouts
import "root:/"

PanelWindow {
    id: root

    // The QsMenuHandle of the root menu and of the open submenu (null = closed).
    property var menuHandle: null
    property var submenuHandle: null
    // The bar window that opened the menu (to include in the focus grab: clicking another tray
    // icon SWITCHES the menu instead of counting as a "click outside").
    property var barWindow: null
    // The desired SCREEN X for the menu's left edge (= the clicked icon's left edge).
    property int desiredX: 0

    visible: false
    color: "transparent"
    exclusiveZone: 0 // it is a menu, not a panel: it reserves no screen space
    implicitWidth: card.implicitWidth
    implicitHeight: card.implicitHeight

    anchors {
        top: true
        left: true
    }
    margins {
        top: 4 // 4px below the bar; its exclusiveZone 30 is already discounted
        // It aligns with the icon and clamps at the edge, which is what PopupAdjustment.Slide used to do.
        left: {
            const sw = root.screen ? root.screen.width : 1920;
            return Math.max(4, Math.min(root.desiredX, sw - root.implicitWidth - 4));
        }
    }

    // It opens the menu with its left edge at `x` (SCREEN coordinates), on `win`'s screen.
    // It resets visible first so it repositions if it is already open on another icon.
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

    // It disappears on its own after a while if the mouse is not over the menu (it pauses while
    // the cursor is on it and restarts the count when it leaves).
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

    // A click outside closes it. It includes the bar in the grab so that clicking another tray
    // icon SWITCHES the menu (the click reaches the icon) instead of counting as "outside".
    HyprlandFocusGrab {
        active: root.visible
        windows: root.barWindow ? [root, root.barWindow] : [root]
        onCleared: root.closeMenu()
    }

    // Reused by both columns. The controller arrives through a property, which avoids depending on an
    // external id inside an inline component.
    component MenuEntry: Item {
        id: entry
        required property var modelData
        property var menu: null
        property bool isSub: false
        // a single place decides "it is under the cursor": the background, the bar and the arrow read from here
        readonly property bool hovered: hov.containsMouse && entry.modelData.enabled
        width: parent ? parent.width : 180
        implicitWidth: entry.modelData.isSeparator ? 40 : (rowInner.implicitWidth + 16)
        implicitHeight: entry.modelData.isSeparator ? 7 : 26

        // the separator
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

        // a normal item
        Rectangle {
            visible: !entry.modelData.isSeparator
            anchors.fill: parent
            radius: 6
            // an animated fade; colMenuHoverBg (the accent at 30%) and not colHoverBg, since
            // the latter gives 1.11:1 of contrast here, which is to say a hover you cannot see.
            color: entry.hovered ? Theme.colMenuHoverBg : "transparent"
            Behavior on color {
                ColorAnimation {
                    duration: Theme.hoverAnim
                    easing.type: Easing.OutQuad
                }
            }

            // An accent bar sliding in from the left: a POSITION signal next to the background's AREA signal.
            // Cheap redundancy, and it works even if the background difference goes unnoticed.
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

                // the checkbox/radio mark (buttonType: 1=check, 2=radio)
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
                    // it strips the "_" mnemonics from the DBusMenu label
                    text: ("" + entry.modelData.text).replace(/_(.)/g, "$1")
                    // The text does NOT light up: over the lit background the accent drops to 3.83:1, against
                    // colText's 5.97:1. Legibility beats effect.
                    color: entry.modelData.enabled ? Theme.colText : Theme.colDim
                    font.family: Theme.uiFont
                    font.pixelSize: 12
                }

                // the submenu's arrow
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
                        // it toggles the submenu (the same item closes it; another switches it)
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

        // hovering the menu pauses the auto-hide
        HoverHandler {
            id: menuHover
        }

        // the main column
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

        // the submenu's column (it appears on the right when one is open)
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
