//@ pragma UseQApplication
// The shell's root: it only COMPOSES the components (bar, OSD, media, notifications).
// Each one lives in its own file; there is no logic here.
//
// REMOVED (30/07): this file carried an entire VPN control panel (~190 lines) that was DEAD CODE
// on three levels, and none of it showed up:
//   1. it called `$HOME/.local/bin/vpn`, a path from the ARCH setup, whereas on this machine the
//      CLI is `vpn` on the PATH (system/net/vpn.nix), so every action and every status failed
//      silently against a binary that does not exist;
//   2. it was unreachable, since the only trigger was `qs ipc call vpn toggle`, inherited from
//      WAYBAR's custom/vpn module, which was removed in the migration; no bind in keybinds.lua
//      calls that;
//   3. it modeled the old world: "FAI through netExtender" and "NetworkManager profiles", when
//      today it is nxBender (FAI) plus openconnect (UFSCar), and it read a `neservice` field that
//      `vpn status-json` does not even emit anymore.
// The VPN control now lives ANCHORED to the bar, in bar/VpnPopover.qml.
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

    // Quickshell's native notifications (toasts plus the center). The daemon is in Notifs.qml
    // (a singleton) and the UI in Notifications.qml. It owns org.freedesktop.Notifications
    // (swaync was removed; the orphaned mako died). The bell in the Bar reads Notifs.count/dnd.
    Notifications {}
}
