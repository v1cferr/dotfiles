//@ pragma UseQApplication
// The shell's root: it only COMPOSES the components, there is no logic here. A ~190-line VPN panel
// was REMOVED from here on 30/07 as dead code on 3 levels: docs/notes/desktop/quickshell.md
import Quickshell
import QtQuick
import "root:/bar"
import "root:/notifications"
import "root:/osd"
import "root:/media"

ShellRoot {
    id: root

    // The volume/mic OSD (a toast), bottom-center on the main monitor. The component is in Osd.qml.
    Osd {}

    // The media control panel (Spotify). The component is in Mpris.qml.
    Mpris {}

    // The main bar, replacing Waybar. The component is in Bar.qml.
    Bar {}

    // Quickshell owns org.freedesktop.Notifications: the daemon is Notifs.qml and the UI is
    // Notifications.qml. The bar's bell reads Notifs.count/dnd.
    Notifications {}
}
