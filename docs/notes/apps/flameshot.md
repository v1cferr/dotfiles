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
| `sc1` | the TV (HDMI-A-3), to the clipboard |
| `sc2` | the main one (DP-2), to the clipboard |

**`--number` is a Qt screen index, NOT a monitor name**, so it does not come out of `my.monitors`
(rule 11 does not apply: there is no way to derive it). The mapping was measured by capturing both
screens and comparing against the wallpapers: 0 = the main one (DP-2), 1 = the TV (HDMI-A-3). If
the monitor layout changes, MEASURE AGAIN. The numbers inherited from Arch already match the
screenshot submap (1 = TV, 2 = main).

## Two small things

`runtimeInputs` is mandatory on these scripts, since `writeShellApplication` uses a restricted
PATH, not the user's. And `Pictures/Screenshots/.keep` exists because flameshot does not create the
output folder reliably on its own.
