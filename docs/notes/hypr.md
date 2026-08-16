# Hyprland: the Lua config and its session services

`home/desktop/hypr.nix`. The compositor and the session come from `system/`
(`programs.hyprland.enable`); here it is ONLY the config file plus the helper services, following
the folder rule (`home/` configures, it does not install).

Docs: <https://wiki.hypr.land>

## The Lua format, and hot-reload

The Lua format (Hyprland 0.55+) replaces the old `hyprland.conf` (hyprlang), which is deprecated.
`hl` is a global object injected by Hyprland, and if `hyprland.lua` exists it is loaded instead of
the `.conf`.

`hyprland.lua` does NOT live in the store: it comes through `mkOutOfStoreSymlink` from the real
files in the repo. The entrypoint only does a `dofile` of the modules in `~/.config/hypr/lua/*.lua`,
one subject per file: monitors, appearance, input, keybinds, rules, autostart, environment.

Editing any `.lua` plus `hyprctl reload` applies immediately, with NO rebuild. Same scheme as
quickshell. The scripts the binds call (`minimize-others`, `brightness-osd`, `monitor-toggle`) go
to the PATH through `home.packages`, so the modules invoke them by NAME, which is what lets the
`.lua` files stay static.

The keybinds and window rules are at PARITY with the Arch/Kingston setup (the `arch` branch), with
the tools adapted to the NixOS stack (rofi, dolphin, quickshell).

Idleness and the lock screen live in [`lockscreen.md`](lockscreen.md).

## The user systemd session

LightDM launches Hyprland "raw", with no systemd integration, so `graphical-session.target`, which
the desktop's `--user` services use as `WantedBy`, was never activated and none of them came up at
login.

`hyprland-session.target` activates it through `BindsTo` (`graphical-session.target` refuses a
manual start, only a dependency works), and autostart starts it. It mirrors what the
`wayland.windowManager.hyprland` module would do, since here the config is raw.

## The remote access safety net

`autostart.lua` brings the target up through `exec-once`. That has a hole that cost dearly on
29/07: if the Lua config BLOWS UP, the following modules do not run, and "autostart" comes after
"monitors", so the target never comes up and the machine is left WITHOUT Sunshine and WITHOUT
Quickshell. Remotely that is unrecoverable: Hyprland is alive, but nothing that depends on
`graphical-session.target` is.

`hypr-session-ensure` takes remote access out of the config's hands. It checks the compositor's
SOCKET, which exists even with a broken config, and brings the target up on its own. Redundant with
the `exec-once` on purpose, since `systemctl start` on an already active target is a no-op.

It has to DERIVE the environment from the socket, not read it from the config, because it runs
outside the compositor: `HYPRLAND_INSTANCE_SIGNATURE` is the directory name in
`$XDG_RUNTIME_DIR/hypr/` (take the newest mtime, since the dir survives a crash) and
`WAYLAND_DISPLAY` is the first `wayland-N` socket, ignoring the `.lock` ones. Without those two in
the `systemd --user` environment, the session's services come up unable to talk to the compositor.

**A TIMER, not a path unit.** With `PathExistsGlob` systemd re-triggers while the condition stays
true, so the oneshot exits, the socket is still there, it triggers again, and it loops until
`unit-start-limit-hit`. Tested; it failed exactly like that. A path unit only works when the
service CONSUMES the path. A timer is idempotent by construction and costs nothing.

**The journal discipline**: it runs every 30 s, so `LogLevelMax = "warning"` is required. Without
it SYSTEMD logs "Starting…/Finished…" on its own and drowns the journal (measured: 1708 lines in
one day). Making the script exit silently is NOT enough, since those lines are systemd's, not the
script's. `warning` cuts the info out and lets through what the script emits with the `<4>` prefix,
which is precisely the time it acted.

## The four helper scripts

### `minimize-others` (SUPER+M)

Sends the OTHER windows of the current workspace to `special:minimized`; pressing again brings them
back. Rewritten for the 0.55 Lua dispatch, since the old `hyprctl dispatch movetoworkspacesilent`
broke; now it is `hl.dsp.window.move` with `follow=false` (silent).

It keeps a state file per workspace so the toggle knows what to restore, and has a fallback: if the
state was lost but there ARE windows in `special:minimized`, restore everything.

### `brightness-osd` (SHIFT+Vol/0)

"Brightness" through hyprsunset's gamma, because this desktop has no real backlight (brightnessctl
and ddcutil are absent). It shows Quickshell's NATIVE OSD, a bottom-center bar, through IPC, and it
is not a toast. It only has an effect with hyprsunset running.

It reads the current gamma, computes the new one and CLAMPS it to `[20, 150]` by setting an
ABSOLUTE value, because hyprsunset only clamps the CEILING (`max-gamma`); below that it went to 0
or negative and glitched the screen.

One trap: the gamma comes back as a FLOAT (for instance `90.000015`), so take only the integer part
by cutting at the dot. Otherwise `tr -dc '0-9'` would join the digits into `90000015` and the value
would explode.

### `monitor-toggle` (SUPER+SHIFT+T)

Turns the TV on and off IN HYPRLAND, by hand. It is necessary because the TV (or the
receiver/switch in between) keeps the HDMI link alive even when off, so DRM stays "connected" and
Hyprland NEVER emits `monitorremoved`. `monitor-watch` has no event to react to, and the "ghost
monitor" remains: the cursor going to a screen that disappeared.

In the Lua parser (0.55) `hyprctl keyword` is blocked ("Use eval"), so runtime monitor config goes
through `hyprctl eval` calling the SAME `hl.monitor` as `hyprland.lua`. Turning it back on repeats
mode, position and scale from there; turning it off is just `disabled=true`.

On disable, Hyprland gathers workspaces 5 to 8 back onto the LG by itself.

### `hypr-monitor-watch`

Listens to Hyprland's events (socket2) and runs `hyprctl reload` when a monitor CONNECTS or
DISCONNECTS. The reload recalculates the layout (killing the ghost monitor) and MOVES the lost
monitor's workspaces to the remaining one.

It is a `systemd --user` service and NOT an `exec-once` in the Lua, so it does not duplicate on
reload. The `sleep 0.4` lets Hyprland settle the hotplug before the reload.

## What is in `home.packages` here

The Hyprland SESSION tools the Lua invokes, with app and config in home (rule 4): the three scripts
above, plus `wl-clipboard` and `wl-clip-persist` as the clipboard's base (the cliphist history and
the rofi picker live in `clipboard.nix`), `pamixer` and `playerctl` for the media keys, and
`pavucontrol` as the mixer on SUPER+S. The launcher is rofi, in `launcher.nix`, the same tool as
the clipboard picker.
