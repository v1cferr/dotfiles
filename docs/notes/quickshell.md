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
