# splash: the boot menu's look and the Plymouth splash, from one palette

Modules: [`modules/nixos/core/boot-appearance.nix`](../../../modules/nixos/core/boot-appearance.nix)
and the package [`pkgs/boot-theme`](../../../pkgs/boot-theme/package.nix). Both are OFF on the host
until [the migration](../../guides/limine-migration.md) turns them on.

## One palette, by name

`my.boot.theme` is a preset NAME from `modules/home/desktop/palette-presets.nix`, the desktop's own
file (rule 11), defaulting to its `default` (Tokyo Night). Not the home-manager `my.theme.palette`:
the boot screens are the SYSTEM's, and reaching into one user's home-manager config from a NixOS
module has no precedent here. The price is that a `base16:` theme on the desktop does not reach
the boot; a curated preset does.

`boot-theme` renders everything at build time, nothing at boot:

| Output | What it is |
| --- | --- |
| `limine/wallpaper.png` | 1920x1080 in `bg`, the official NixOS logo (from `nixos-icons`) at 144 px, centered in the top third |
| `share/plymouth/themes/nixos-minimal/` | a `script` theme: the logo, three dots, the per-mode title and the log pane |

288 KiB in all (22/10/2026). The logo comes from the pinned nixpkgs, so nothing is fetched.

## The Limine menu

Limine draws its own text menu; the theme only gives it a canvas and colors. It centers the entry
tree on its own (`common/menu.c`), so the logo sits in the band between the top line and the tree,
and the terminal background is fully transparent (`term_background ff<bg>`) so its cells never
paint over the logo. The built-in font at `2x2`, since 1x is unreadable at 1080p. If the firmware
refuses 1920x1080, `wallpaper_style: centered` with the same `bg` as backdrop keeps the color
around it. No custom font: the built-in one always loads, which is what "usable if the wallpaper
or font fails" asks.

## Plymouth

A `script` theme (`pkgs/boot-theme/nixos-minimal.script`, 22/10/2026), after a first version on the
`two-step` plugin. Both draw the logo, three dots that brighten in turn (a loop, indeterminate on
purpose, since boot has no honest percentage) and `Shutting down` or `Restarting` in those modes.
The script adds what two-step cannot: a **pane with the last 8 lines systemd logged**, asked for so
a boot or a shutdown can be read without leaving the splash.

- **Where the lines come from.** systemd tells Plymouth only which units FINISHED starting
  (`manager_send_unit_plymouth`, systemd 260): no failures, no stops, nothing at shutdown. A pane
  fed by that alone would show only good news, so `plymouth-log` (boot) and
  `plymouth-log-shutdown` (reboot, poweroff) run `journalctl --follow _PID=1` and pass each line
  through `plymouth display-message`. Bookkeeping is dropped: skipped conditions, CPU accounting,
  clean exits, signals.
- **Colors by the verb**: Started, Finished, Reached, Mounted in green with a check; Stopping,
  Stopped in yellow; Starting, Mounting dimmed; anything with `failed`/`Failed`/`error` in red; a
  unit name (`foo.service`) in the accent. Older lines fade, long ones end in an ellipsis. The
  font is the UI family's fixed-width cut (`JetBrainsMonoNerdFontMono`), so the columns line up.
- **Centering**: the script plugin centers the smaller head inside the larger one
  (`script-lib-sprite.c`), so everything is placed from the center and fits the 1080 p LG too.
- **How each feeder ends.** At boot, when the splash goes `display-message` stops answering and
  the loop exits 0. At shutdown, the final SIGTERM ends it. Neither orders anything after itself.
- **Three traps vm-limine caught**, kept so they stay caught: `Conflicts=plymouth-quit` made
  systemd drop the quit job and the boot wait forever; with `pipefail`, the closed pipe at the
  normal end marked the unit failed; and `ConditionPathExists=/run/plymouth/pid` skipped the
  shutdown feeder, since the shutdown splash keeps no pid file there (the script pings instead).
- **Not proven**: the red line on screen. In the drill the failing unit's line comes in the last
  half second before poweroff, after the last frame; the color rule is the same code as the green
  and yellow lines that were seen.

- **Handoff**: LightDM quits Plymouth itself when it takes the screen, and nixpkgs' `lightdm.nix`
  starts `plymouth-quit` as the display manager's `onFailure`, so a LightDM that dies never leaves
  the splash up. No extra unit here. Drilled in `vm-limine` (no LightDM there):
  `plymouth-quit.service` succeeded.
- **The GPU**: `xe` is already in the initrd for early KMS ([intel-arc-b580](../../../modules/nixos/hardware/intel-arc-b580.nix)),
  so the splash draws on the real driver, not on `simpledrm`. Seen on the B580 on 22/10/2026,
  at boot and at poweroff, with no black screen (stage C1 of the migration).
- **Two monitors**: the splash shows on both, but the LG's rotation is Hyprland's and does not
  exist yet at boot, so on the LG it is sideways. Expected, and only for those seconds.
- **Diagnostics stay**: no `quiet` was added, `loglevel=4` stays, Escape switches to the text
  console. To boot once without it: `plymouth.enable=0` on the command line (GRUB's `e`; Limine's
  editor is off under Secure Boot, so there it is an older generation or a rebuild).
- **No added delay**: nothing waits for the animation; it is shown for exactly as long as boot or
  shutdown takes.
