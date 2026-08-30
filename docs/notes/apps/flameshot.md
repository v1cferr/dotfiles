# Flameshot v14: the keyboard flow, and the duplicated bar

`home/apps/flameshot.nix`. v14 from the UNSTABLE channel (through flake.nix's overlay) plus the
config and the keyboard-flow scripts. The binds (Print, SUPER+SHIFT+S, and the "screenshot" submap)
live in `home/desktop/hypr/lua/keybinds.lua`.

## Capture goes through the portal

`org.freedesktop.portal.Screenshot`, served by `xdg-desktop-portal-wlr`. The `-hyprland` one only
DECLARES the interface, it does not implement it; see [`desktop.md`](../desktop/desktop.md). With no direct
grim and no `useGrimAdapter`, there is no "grim … GNOME" warning.

**NB**: the `.ini` comes from `/nix/store` (read-only), so changes through the GUI do NOT persist.
Edit the module and rebuild. Qt QSettings does NOT accept an inline comment in the `.ini`.

## The keyboard flow, at parity with the Arch v14

v14 ALWAYS shows a monitor picker on a multi-monitor setup. There is no skipping it, not even with
`--region`. The picker only accepts a mouse CLICK.

So SUPER+SHIFT+S opens the picker and enters a submap, and `1`/`2` SYNTHESIZE the click on the
right monitor's preview (move the cursor, then `send_shortcut mouse:272`).

**With ONE monitor there is no picker**, and that was the other half of the single-monitor bug,
fixed on 30/08/2026. v14 opens the selection overlay straight away, so `flameshot-screenshot` counts
the ACTIVE monitors and only enters the submap when there are 2 or more. Entering it with a single
monitor HIJACKED flameshot's own keys: `1`/`2` moved the cursor to the middle of the overlay and
synthesized a left click, which drags a bogus selection instead of capturing a screen, and Esc left
through `flameshot-cancel` instead of flameshot's own cancel.

The flameshot window has an EMPTY class plus the title `flameshot`, so the selectors and the window
rule (`rules.lua`) match on the TITLE.

`flameshot-pick` resolves the target's slice DYNAMICALLY: the previews sit side by side in PHYSICAL
order (monitors sorted by X, left to right), so it finds the target's 0-based index among the
ACTIVE monitors and clicks the center of slice `i` of `n`. Nothing is hardcoded, so it survives a
turned-off TV or a rearrangement. If the target is not active, it just resets the submap and exits.

The watcher resets the submap when flameshot closes (a mouse click on the picker, an internal Esc,
or the 60 s timeout), otherwise `1`/`2` would stay hijacked afterwards. `flameshot-cancel` is the
explicit Esc path.

## The duplicated bar

By the time the overlay is up, its FROZEN frame has already been captured, WITH the bar in it.
Hiding the LIVE bar at that point kills the duplicate WITHOUT taking it out of the shot.

On Hyprland a normal window NEVER covers a `top` layer, and the bar lives in one. There is no
window rule to invert that (an open feature request, hyprwm/Hyprland#4847), so hiding is the only
path.

It only hides if flameshot actually opened, otherwise the bar would disappear for nothing, and it
ALWAYS comes back, the 60 s timeout included.

## The aliases

They stay next to the tool and not in `home/shell/zsh.nix`, the same convention as eza and bat,
which live in `cli.nix`. `zsh.nix` keeps only the shell and system ones.

VERIFIED on this machine's v14/Wayland: only `gui` opens the monitor picker; `full` and
`screen --number` capture DIRECTLY, with no picker. So the Arch aliases still hold; what does not
hold is `--region`, which v14 ignores.

| Alias | Command |
| --- | --- |
| `screenshot` | `flameshot gui`, an interactive selection |
| `scfull` | both screens, to the clipboard |
| `sc1` | the TV (`my.monitors.secondary`), to the clipboard |
| `sc2` | the main one (`my.monitors.primary`), to the clipboard |

**`--number` is a Qt screen index and NOT a monitor name**, and it was a measured literal here until
30/08/2026, guarded by nothing but a "if the layout changes, MEASURE AGAIN". It also broke with the
TV disconnected: index 1 stops existing, so `sc1` answered `Requested screen exceeds screen count`
and exited 2.

`flameshot-screen` takes the NAME, which does come from `my.monitors` (rule 11), and DERIVES the
index: Qt numbers the screens in the order the compositor advertises the `wl_output`s, which is
Hyprland's monitor `id` order, so the index is the target's position among the ACTIVE monitors
sorted by `id`. A monitor that is not connected gets a notification instead of a capture, and the
numbers still match the screenshot submap (1 = TV, 2 = main).

MEASURED on 30/08/2026 with a HEADLESS output standing in for the TV (`hyprctl output create
headless HDMI-A-3`, which `monitors.lua` then places at `-1920x0` exactly like the real one):
`--number 0` captured the LG and `--number 1` the stand-in, which is the `id` order (DP-2 = 0,
HDMI-A-3 = 1) and the same mapping that had been measured by hand against the wallpapers.

## Two small things

`runtimeInputs` is mandatory on these scripts, since `writeShellApplication` uses a restricted
PATH, not the user's. And `Pictures/Screenshots/.keep` exists because flameshot does not create the
output folder reliably on its own.
