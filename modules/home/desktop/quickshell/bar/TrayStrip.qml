// The SYSTEM TRAY: one control per StatusNotifierItem, pinned to the bar's right edge and growing left,
// so nothing else on the bar can move it. Its own file so the band screen can host it when it is
// the only screen left: docs/notes/desktop/bar.md
import Quickshell
import Quickshell.Io
import Quickshell.Services.SystemTray
import QtQuick
import QtQuick.Layouts
import "root:/"

RowLayout {
    id: strip
    required property var host // the Bar's Scope: hints and launches go through it
    required property var barContent
    required property var barWindow
    // The width from the item count alone, never from the delegates: the bar budgets around it.
    readonly property int count: SystemTray.items ? SystemTray.items.values.length : 0
    readonly property int stableWidth: strip.count > 0 ? strip.count * Theme.barControl + (strip.count - 1) * Theme.sp1 : 0
    height: Theme.barHeight
    spacing: Theme.sp1

    Repeater {
        model: SystemTray.items
        Rectangle {
            id: trayDel
            required property var modelData
            implicitWidth: Theme.barControl
            implicitHeight: Theme.barControl
            radius: Theme.radiusControl
            color: trayArea.containsMouse ? Theme.colHoverFill : "transparent"
            Behavior on color {
                ColorAnimation {
                    duration: Theme.motionHover
                }
            }
            // Some SNIs (Dropbox) publish image://icon/<name>?path=<dir> in a theme the provider does not
            // resolve, so we find the real file in <dir> and point at file://.
            readonly property string rawIcon: "" + trayDel.modelData.icon
            readonly property bool isPathIcon: /^image:\/\/icon\/[^?]+\?path=/.test(trayDel.rawIcon)
            property string resolvedIcon: ""
            function resolveTrayIcon() {
                trayDel.resolvedIcon = "";
                const m = trayDel.rawIcon.match(/^image:\/\/icon\/([^?]+)\?path=(.+)$/);
                if (m) {
                    iconFinder.command = ["find", m[2], "-name", m[1] + ".png", "-print", "-quit"];
                    iconFinder.running = true;
                }
            }
            onRawIconChanged: trayDel.resolveTrayIcon()
            Component.onCompleted: trayDel.resolveTrayIcon()
            Process {
                id: iconFinder
                stdout: StdioCollector {
                    onStreamFinished: {
                        const p = text.trim();
                        if (p)
                            trayDel.resolvedIcon = "file://" + p;
                    }
                }
            }
            Image {
                anchors.centerIn: parent
                // path icons: it only shows after resolving to file:// (which avoids the broken load)
                source: trayDel.isPathIcon ? trayDel.resolvedIcon : trayDel.rawIcon
                sourceSize.width: 16
                sourceSize.height: 16
                width: 16
                height: 16
                opacity: trayDel.modelData.status === 0 ? 0.55 : 1
            }
            MouseArea {
                id: trayArea
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                hoverEnabled: true
                acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton
                onContainsMouseChanged: {
                    if (containsMouse)
                        strip.host.hintTray = trayDel.modelData;
                    strip.host.hoverHint("tray", trayDel, strip.barContent, strip.barWindow, containsMouse);
                }
                onClicked: m => {
                    strip.host.hideHint();
                    if (m.button === Qt.LeftButton)
                        trayDel.modelData.activate();
                    else if (m.button === Qt.MiddleButton)
                        trayDel.modelData.secondaryActivate();
                    else if (trayDel.modelData.hasMenu) {
                        // A native SNI gets our themed menu. It is a LAYER SURFACE (Hyprland#6682 breaks a PopupWindow's
                        // input region), docs/notes/desktop/quickshell.md
                        const pt = trayDel.mapToItem(strip.barContent, 0, trayDel.height);
                        trayCtxMenu.openAt(trayDel.modelData.menu, strip.barWindow, pt.x + strip.barWindow.margins.left);
                    } else {
                        // xembedsniproxy icons have NO DBusMenu, and display() refuses them, so we fire the SNI's own
                        // ContextMenu() through a helper and the app draws its menu at the cursor.
                        strip.host.launch(["tray-native-menu", "" + trayDel.modelData.id]);
                    }
                }
                onWheel: w => trayDel.modelData.scroll(w.angleDelta.y, false)
            }
        }
    }
    // A single shared instance of the context menu: opening it on one icon
    // switches or closes another's (which avoids stacking several menus).
    TrayMenu {
        id: trayCtxMenu
    }
}
