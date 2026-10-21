// The LOCK SCREEN: a Quickshell instance of its own (`qs -p .../lock.qml`), never part of the shell,
// so a bar or band bug cannot reach it. ext-session-lock: if this process dies while locked, Hyprland
// keeps the screen locked and lock-launch hands over to hyprlock. docs/notes/desktop/lockscreen.md
import Quickshell
import Quickshell.Wayland
import QtQuick
import "root:/lock"

ShellRoot {
    id: root

    Auth {
        id: authCtx
        onUnlocked: {
            lock.locked = false;
            quitLater.start();
        }
    }

    WlSessionLock {
        id: lock
        locked: true
        // The launcher's watchdog waits for this file: no file in time means no lock, and hyprlock.
        onSecureChanged: if (lock.secure)
            authCtx.markSecure()

        WlSessionLockSurface {
            id: surface
            color: "black"
            Face {
                anchors.fill: parent
                auth: authCtx
                screenName: surface.screen ? surface.screen.name : ""
            }
        }
    }

    Timer {
        id: quitLater
        interval: 300
        onTriggered: Qt.quit()
    }
}
