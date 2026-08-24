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

## The Lua modules

`hyprland.lua` only loads the modules, in order, from `~/.config/hypr/lua/`. `hl` is global and
stays visible inside every module loaded through `dofile`. The order is load-bearing: `autostart`
comes late, so anything that aborts an earlier module leaves the session with no services.

| Module | Subject |
| --- | --- |
| `environment` | `hl.env`: the cursor, the Qt theme, the Wayland platform |
| `monitors` | `hl.monitor` plus `hl.workspace_rule` |
| `appearance` | general, decoration, animations |
| `input` | the ABNT2 keyboard plus the mouse |
| `autostart` | `hl.on("hyprland.start")` |
| `rules` | `hl.window_rule` |
| `keybinds` | every `hl.bind`, see [`keybinds.md`](keybinds.md) |

### The `pcall` fallback, repeated in four modules

Four modules read a Nix-generated data file, and each wraps the `dofile` in a `pcall` with a
literal fallback. That repetition is deliberate: if the file is missing (the first boot before a
rebuild, or new data not generated yet) a bare `dofile` BLOWS UP and aborts the config, and since
"autostart" comes later in the load order, the session comes up with NO services.

Do NOT factor it into a global helper: Hyprland does not share globals between `dofile` calls.

### Appearance

Ported from the Arch `look-and-feel.conf` (Tokyo Night), adapted to the Lua 0.55 API. The palette
comes from Nix as hexes WITHOUT `#`, and the borders and shadow assemble `rgba(<hex><alpha>)`.

In the Lua API a gradient border is the table `{ colors = {...}, angle = N }`; the hyprlang string
does not stick.

`layout = "scrolling"` is global, on ALL the workspaces, native in 0.55. `column_width = 1.0` is
the ONLY value away from the default (0.5); the other six `scrolling` settings already are what we
want, so they are not written. The `dwindle` block left along with the layout.

Three `misc` settings worth keeping:

- **`vrr = 2`** (G-Sync only in fullscreen games). The LG UltraGear is G-Sync Compatible, and on
  the Arc (`xe`) the freeze NVIDIA used to give on the lockscreen does NOT reproduce, which is why
  the always-on `vrr = 1` was vetoed back on Arch. 2 is safe.
- **`allow_session_lock_restore = true`**, a safety net against a lockout: if hyprlock dies during
  teardown, relaunching `hyprlock` from a TTY REATTACHES the locked session instead of refusing,
  which avoids a `sudo reboot` to escape an orphaned lock screen. It is the one path that produces
  a hyprlock NOT born from `hyprlock.service`, which is what the unit's `ExecCondition` covers.
- **`render_unfocused_fps = 30`**, the GLOBAL ceiling for the windows that carry the
  `render_unfocused` rule (a game on a workspace that is off screen). It is 30 and not the default
  15 because 15 measured JITTERY; the table is in "Window rules" below.

The custom beziers go through `hl.curve` (hyprlang's old `bezier=`); "default" and "linear" are
Hyprland's built-ins and the four others are ours. In `hl.animation`, `leaf` is the animation's
name, `speed` is the duration (lower is faster), `bezier` is the curve and `style` is the
variation.

### Monitors

The connector names were confirmed through `hyprctl monitors`. The primary is the LG ULTRAGEAR
(1080p 144Hz) at the origin `0x0`; the secondary is the LG TV on the LEFT, at a negative x, Full HD
60Hz. Keeping the main one at `0x0` is what makes a disconnected TV clean: the LG stands alone with
no ghost offset and workspaces 5 to 8 fall back onto it automatically.

Four workspaces per monitor. `default = true` marks the workspace that opens on each monitor when
the session boots. There is no `layout` per workspace, since scrolling is global ever since the
trial on ws 2 and 6 was approved in use. If a dwindle workspace ever comes back, the tape's binds
need their guard back, or dwindle spits an error toast PER EVENT; see [`keybinds.md`](keybinds.md).

### Environment

`XCURSOR_*` covers XWayland and legacy apps plus Hyprland's fallback; `HYPRCURSOR_*` is the native
format, which falls back to XCursor when the theme has no hyprcursor variant. GTK apps pick the
cursor up from gsettings, not from here.

The Qt vars are pinned here even though the qt module already sets them as session vars, because on
Wayland the session does not always load them, and pinning guarantees the dark look in apps opened
by Hyprland. `QT_QPA_PLATFORM = "wayland;xcb"` makes Qt run natively with an xcb fallback:
flameshot needs it to position the overlay and picker correctly.

### Autostart

`hyprland.start` fires ONCE when the session boots, not on a reload. hypridle does NOT go here; it
is a `systemd --user` service.

It does four things:

1. Imports the Wayland env and starts `hyprland-session.target`. Without this the `--user` services
   do NOT come up at login, since LightDM launches a bare Hyprland with no systemd integration.
2. **Locks at boot**, through the UNIT and not a loose `hyprlock`. The machine logs itself in so
   Sunshine can come up, but the session is born LOCKED, so Moonlight lands straight on hyprlock.
   Going through `hyprlock.service` keeps ONE owner: a loose process would break systemd's
   idempotence, the idle lock would raise a SECOND session-lock surface on top, and two of them
   break the keyboard grab so the password field stops typing. The old `pidof ||` became the unit's
   `ExecCondition`.
3. Starts Quickshell.
4. Starts `wl-clip-persist`, which keeps a copy alive after the source app closes. On Wayland the
   clipboard's owner is the app, so without it a Flameshot image disappears when flameshot exits
   and Ctrl+V pastes nothing. It pairs with cliphist, which is now a declarative service and is no
   longer launched here.

### Window rules

Ported from the Arch `window-rules.conf`. A subtle global transparency (0.98 active / 0.96
inactive), maximize requests suppressed since that behaves better under tiling, and an XWayland
drag fix for classless floating windows that steal focus. Picture-in-Picture stays fully opaque,
and Ascension (a private WoW through Wine) is floating, centered on the LG, opaque and
idle-inhibiting.

**Hearthstone and the workspace that is off screen.** Leaving the game's workspace made its render
AND its audio fall behind, and both only caught up on coming back. It is not a Hyprland bug and
there is no switch that turns it off: a Wayland surface that is not on screen receives no
`wl_surface.frame` callback, so the client's next buffer swap BLOCKS and the whole game loop stops
with it, audio included. XWayland surfaces, which is what Wine and Bottles produce, are hit the
same way.

Measured with `glxgears` parked on a workspace that was off screen (0.55.4, Arc B580):

| State | FPS |
| --- | --- |
| Visible | 141.78 (vsync at 144 Hz) |
| Off screen, no rule | 1.000 |
| Off screen, `render_unfocused` + `render_unfocused_fps = 15` | 8 to 18, jittery |
| Off screen, `render_unfocused` + `render_unfocused_fps = 30` | 30.28, steady |

`render_unfocused = true` per class is the intended fix; the wiki's own example is Dark Souls, which
disconnects when the fps flutters. The ceiling is not per rule, it is the global
`misc.render_unfocused_fps` in appearance.lua.

The class to match is the LOWERCASED file name of the .exe, which is what Wine puts on the XWayland
window: `Hearthstone.exe` becomes `hearthstone.exe`, `Ascension Launcher.exe` becomes
`ascension launcher.exe`. Another game that crawls is one more line with its class.

Ascension does NOT carry the rule. Off screen it keeps burning 56% of a core, so its loop is not
blocked (D3D9 through wined3d is a different present path), and the rule would pay 30 fps of GPU
for nothing.

An upstream hole worth knowing (hyprwm/Hyprland#12463): a window rendering unfocused still leans on
its MONITOR having a reason to draw, so on a completely static screen it can fall under the ceiling.
There is nothing to configure, and it did not show up in the measurement above.

Two knobs that would be relevant do NOT exist in 0.55.4: `misc:vfr` was removed in 0.55, and
`render:not_shown_fifo_lock`, which controls exactly this locking for invisible surfaces, is only on
main. Worth a look on the next bump.

**The Flameshot rule is the subtle one.** The `-1920/3840` stretch of the OLD flow (v13 with grim)
BREAKS v14, since v14 opens a monitor PICKER (a normal window) and then a fullscreen overlay on the
chosen monitor, and forcing a giant move/size scrambles the picker.

So the rule only leaves it floating and centered, with no animation.
`suppress_event = "fullscreen"` keeps the overlay a floating window, so it does not enter
Hyprland's fullscreen and there is no wallpaper flash on close. `opacity`/`no_blur`/`no_shadow`
because the overlay is a FROZEN FRAME and must not inherit the global transparency and blur.

It matches by TITLE, because on this box the flameshot window (both the picker and the overlay) has
an EMPTY class and the title `flameshot`. With no `float` it falls into dwindle's tiling, born
squeezed into half a screen, which is where the "bug" came from.
