# Quickshell: the bar, and the XEmbed bridge

`home/desktop/quickshell.nix`. The shell in QML (bar, OSD, media, notifications), replacing waybar.
The binary comes from the official FLAKE (`inputs.quickshell`, so always the latest; bump with
`nix flake update quickshell`).

## Hot-reload, the reason it is shaped like this

The QML config lives in the REPO (`home/desktop/quickshell/`) and is linked through
`mkOutOfStoreSymlink`, a symlink to the MUTABLE file and not to the read-only store. Quickshell
reloads the QML LIVE on save, with no rebuild, and the files stay versioned in git (portable:
another machine clones the repo at the same path and it works).

It is a conscious deviation from rule 3, since it is not a pure store symlink, and it is the
community pattern for QML ricing.

## `qs-restart` (SUPER+ESCAPE)

The hot-reload does NOT reapply a Repeater delegate (the ws-pills, the notifications), so editing
their QML is not enough: the process has to restart.

Why a SCRIPT and not `qs kill; sleep 0.3; qs &` directly in the bind: rule 7 (the logic in the
build, the bind being one command) and rule 15 (an explicit owner). Starting it through
`hyprctl dispatch` makes the COMPOSITOR the parent, the same owner as `autostart.lua`'s
`exec-once`, instead of the process being reparented to init. As a bonus the script works from a
shell outside the session, because of the `-i 0`, which finds the instance without
`HYPRLAND_INSTANCE_SIGNATURE`.

**A correction worth keeping (30/07).** The previous version of this comment claimed the old form
did NOT restart anything. That was FALSE. The evidence ("Quickshell with 5h of uptime after
pressing SUPER+ESCAPE") had a banal cause: I pressed SUPER+SPACE. Tested afterwards, the old form
does restart it; the process just ends up with `ppid=1`, which is normal daemonization and
survives. So this is an architectural IMPROVEMENT, not a bug fix. It is recorded because inferring
a mechanism from an observation that has a simpler explanation is exactly the mistake rule 14 warns
about.

## `tray-native-menu`

It triggers the NATIVE context menu of an SNI that does NOT expose DBusMenu (icons coming from
xembedsniproxy: Wine/Battle.net, pamac). Quickshell's `display()` refuses an item with no menu
("No menu present"), so this calls the SNI's `ContextMenu()` method at the cursor position, and the
proxy forwards it to X11 where the app draws its own menu.

**Ported from the Arch waybar (30/07)**: `Bar.qml` called
`$HOME/.config/waybar/scripts/tray-native-menu.sh`, a WAYBAR path, and waybar was REMOVED in the
migration. The directory does not exist on this machine and the script was not in the repo, so
right-clicking those icons failed SILENTLY. Now it lives in the build (rule 7) and the QML calls it
by NAME through the PATH.

**A second correction (30/07)**: this comment used to cite xembedsniproxy as if it existed here,
and it was NOT installed, so the helper was dead code justified by a comment describing an absent
component. The proxy is now actually declared and the path is real.

## The XEmbed to StatusNotifierItem bridge

A legacy X11 app (Wine/Bottles, and therefore Battle.net) publishes its tray icon through the OLD
protocol, XEmbed (`_NET_SYSTEM_TRAY_S0`), not through the SNI the bar understands. With no XEmbed
host, Wine gives up and draws the tray in a LITTLE WINDOW of its own: MEASURED as
`class=explorer.exe`, 160x20, floating over the desktop. That was the annoyance, since the
Battle.net icon never reached the bar.

`xembedsniproxy` hosts the XEmbed selection and republishes each icon as an SNI. VERIFIED live with
Battle.net open: it went from 3 to 4 items in the StatusNotifierWatcher and the `explorer.exe`
little window DISAPPEARED, because the icon was embedded into the proxy.

### The cost, measured and accepted

The binary only exists inside `kdePackages.plasma-workspace`, which brings **758 new MiB** to this
closure, 429 MiB of them qtwebengine, plus kwin, breeze and oxygen-icons. Ugly on a Hyprland
system. The alternatives were discarded with a reason:

| Alternative | Why not |
| --- | --- |
| `snixembed` | it goes the OPPOSITE way (publishes SNI as XEmbed, for old bars) and so tries to BE the StatusNotifierWatcher, dying with "could not acquire watcher name" because Quickshell already is |
| a standalone package | there is none in nixpkgs (checked: `xembed-sni-proxy` and `xembedsniproxy` do not exist as attributes) |
| extracting the binary by hand | does not escape the weight, since plasma-workspace references kwin, breeze and oxygen-icons DIRECTLY |
| `stalonetray` | another floating window, which is the original problem coming back |

### A known limitation of icons that come through here

Measured: they have NO name and NO menu. `Id` is the X11 window ID in decimal (`"14680080"`),
`Title` and `ToolTip` are empty, and `Menu` does not exist. That is why right click falls into
`tray-native-menu`, and why a future tooltip cannot settle for the `Id`: it would have to resolve
the X11 window's `WM_CLASS`.

### Ordering

The proxy needs the watcher (Quickshell) to register the items, and Quickshell is NOT a systemd
unit (it comes up through `autostart.lua`'s `exec-once`), so there is no way to order against it.
The SNI standard tells the item to re-register when the watcher appears. If the icon ever fails to
show up at boot, THIS is where to look first.

It needs X11 (XWayland). `DISPLAY` comes from the `systemd --user` environment (measured:
`DISPLAY=:0` present) and is NOT hardcoded, otherwise it breaks if XWayland changes number. If
XWayland is not up yet it fails, and the 3 attempts give it room. The `StartLimit` is the same
brake as `autostart.nix`: a loop dies and STAYS VISIBLE instead of running silently.

## The QML tree

`shell.qml` is the root and only COMPOSES the components (bar, OSD, media, notifications). Each one
lives in its own file; there is no logic there. The bar and its popovers have their own note:
[`bar.md`](bar.md).

### The recurring QML lesson: inline components break scope

Several files exist SEPARATELY for one reason: in an inline component (`component X: ...`) the
root's `id` and properties do NOT resolve inside nested handlers on this Qt, giving a
ReferenceError. That is why `NotifCard.qml`, `HeaderBtn.qml` and `widgets/Pill.qml` are files and
not inline blocks. It also broke dismiss and the notification actions, and it is the same failure
that made `VpnStatsPopover` receive `info` from outside instead of fetching it.

`TrayMenu`'s delegate works around the same thing differently: the controller is passed in through
a `menu` property, which avoids depending on access to an external id inside an inline component.

### `Theme.qml`

The PALETTE comes from Nix through the JSON generated by `home/desktop/palette.nix`, so switching
themes there recolors the whole bar (the `FileView` watches the file, so qs reloads live). The UI
FONT comes through the same JSON. Only the glass opacities are STYLE and stay in the QML.

**The hover tokens (rule 11).** Every hover highlight in the shell (the tray menu, the power menu,
the notification buttons, the media controls) is "the color at 20% over transparent". That was
written BY HAND in 7 files, and in 4 of them with the OLD CATPPUCCIN palette (`#f38ba8`/`#a6e3a1`),
which does not exist in `my.theme` anymore: the "danger" hover was painted with a red from ANOTHER
theme.

**A MENU ROW is a case apart**: it has no border to indicate the hover, so the background is the
only signal, and at 20% it is invisible. MEASURED: the border at 20% over the menu's background
gives 1.11:1 of contrast, which the eye does not catch. The accent at 30% gives 1.77:1 AND changes
HUE, gray to blue, which is what sight perceives from a distance. It is not raised further so the
item does not become a flat block of blue.

**The hover transition is 120 ms in menus**, not the Pill's 200 ms: in a MENU the cursor crosses
several items in a row, and 200 ms leaves a trail of 2-3 items lit at the same time. 120 ms still
reads as a fade but keeps up with the cursor.

**The main monitor** falls back to the first available one. It USED to be `"DP-1"`, which does NOT
exist on this machine: it never matched and always fell into `s[0]`, so the toast and the OSD could
open on the TV depending on the enumeration order.

### What was REMOVED from `shell.qml` (30/07)

An entire VPN control panel, ~190 lines, that was DEAD CODE on three levels and never showed up:

1. it called `$HOME/.local/bin/vpn`, a path from the ARCH setup, whereas here the CLI is `vpn` on
   the PATH, so every action and every status failed silently against a binary that does not exist;
2. it was unreachable, since the only trigger was `qs ipc call vpn toggle`, inherited from WAYBAR's
   `custom/vpn` module, which was removed in the migration, and no bind calls it;
3. it modeled the old world ("FAI through netExtender", "NetworkManager profiles") when today it is
   nxBender plus openconnect, and it read a `neservice` field `vpn status-json` does not even emit.

That is rule 16 in one commit. The VPN control now lives anchored to the bar.

### Notifications

Quickshell IS the `org.freedesktop.Notifications` daemon, replacing swaync (the orphaned mako
died). `Notifs.qml` is the singleton service holding the state (DND, live toasts, history) and
exposing IPC (`qs ipc call notif toggle|dnd|clear`); `Notifications.qml` is the UI, toasts in the
main monitor's top right corner plus the center toggled by the bar's bell.

**The card's app icon** arrives as `image://icon/<name>`. If it exists in the CURRENT theme
(Win11-dark plus hicolor) it is used directly; otherwise the same name is tried in breeze (a
complete theme), ONLY in this card, WITHOUT changing the system's theme. With none of that, it
falls back to the bell. `hasThemeIcon` avoids the checkered placeholder the provider returns when
the icon is not in the theme.

### The OSD

Volume, microphone mute and brightness, pinned bottom-center on the main monitor, gone after
~1.5 s. Volume and mic react to Pipewire; brightness is PUSHED through IPC by the
XF86MonBrightness keys, since brightness here is hyprsunset's gamma (100 = normal, up to
max-gamma 150) and there is no real backlight.

**The anti-flash lock**: every settling event on Pipewire's reactive path pushes the arming back,
and the real show is coalesced into a `Timer(0)` that only fires if "armed" is still true on the
event loop's next cycle. It covers boot and device switching. Brightness through IPC does NOT go
through that lock, since it is an explicit action.

A note for whoever reads the log: `Translate ID error: -1 (default-nodes-api)` is libpipewire's own
noise, not this QML's.

### `Mpris.qml`

The media control panel (Spotify), modeled on the VPN panel, opened through
`qs ipc call mpris toggle`. It uses the native `Quickshell.Services.Mpris` service and sits
bottom/top-left on the main monitor, near the Spotify pill.

### `Pill.qml`

The bar's reusable pill/chip. Its `sub` is secondary text in the SAME pill, after the label and in
a discreet color, for two pieces of data that travel together without becoming two pills (the date
next to the time). It comes AFTER on purpose: the label is the main information and sits on the
left edge, which is where the eye enters the pill, so `sub` does not compete for that spot.

## TrayMenu: why a layer surface and not a PopupWindow

`bar/TrayMenu.qml` renders the DBusMenu (`com.canonical.dbusmenu`) that native SNIs expose, through
`QsMenuOpener`, themed to match the rest of the bar. It only serves items WITH a DBusMenu; the
xembedsniproxy ones fall into `tray-native-menu`, since those the app draws itself and there is no
theming them here.

It supports separators, checkbox/radio (`buttonType` plus `checkState`), disabled items and ONE
level of submenu (a column on the right, which covers nm-applet's "VPN Connections"). It closes on
a click outside through `HyprlandFocusGrab`.

**The Hyprland bug.** As a `PopupWindow`, this menu APPEARED but did not receive a SINGLE pointer
event: no hover, and it closed on its own after 4 s with the mouse sitting on it. The cause is
hyprwm/Hyprland#6682: a Qt popup RESIZED after being shown ends up with the wrong input region, it
stays "centered", misaligned from what you see.

That is exactly what happens here, because `openAt()` makes the window visible BEFORE
`QsMenuOpener` finishes populating the items, so the card is born small and grows, and the input
region does not follow. The issue was reproduced with Quickshell ITSELF and is CLOSED as "not
planned": no fix is coming from upstream, it has to be avoided here.

A layer surface does not go through that path (no `xdg_surface::set_window_geometry`) and it is
what the other four panels of this bar already use with working hover. As a bonus it also covers
OPENING A SUBMENU, which likewise makes the card grow after being shown.

**The price is positioning by hand**: a layer surface has no `anchor.rect` and no
`PopupAdjustment.Slide`, so the X comes from the clicked icon and the edge clamp is explicit. Since
the tray sits at the RIGHT END, in practice it is the clamp that rules and the menu touches the
edge, which is what `PopupAdjustment.Slide` did on its own. The Y comes for free: the bar reserves
`exclusiveZone 30`, and a layer surface with no zone of its own is already positioned BELOW what is
reserved.

**The hover has two signals**, and that is deliberate. The background is an AREA signal; the accent
bar that slides in from the left is a POSITION signal, pointing at the row. Cheap redundancy: it
works even if the background difference goes unnoticed. The same accent bar appears in the power
menu, so the shell speaks ONE hover language.

The row's TEXT does not light up in the accent: over the lit background the accent drops to 3.83:1
of contrast, against `colText`'s 5.97:1. Legibility beats effect.
