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
| `share/plymouth/themes/nixos-minimal/` | a `two-step` theme: the logo, three dots, the per-mode title |

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

The `two-step` plugin, the C one behind `spinner` and `bgrt`, chosen over a `script` theme because
it centers on every head by itself and costs no interpreter. Three dots that brighten in turn, a
1.2 s loop at Plymouth's 30 fps, and nothing moves: indeterminate on purpose, since boot has no
honest percentage. `Shutting down` and `Restarting` as the title in those modes, nothing at boot.

- **Handoff**: LightDM quits Plymouth itself when it takes the screen, and nixpkgs' `lightdm.nix`
  starts `plymouth-quit` as the display manager's `onFailure`, so a LightDM that dies never leaves
  the splash up. No extra unit here. Drilled in `vm-limine` (no LightDM there):
  `plymouth-quit.service` succeeded.
- **The GPU**: `xe` is already in the initrd for early KMS ([intel-arc-b580](../../../modules/nixos/hardware/intel-arc-b580.nix)),
  so the splash draws on the real driver, not on `simpledrm`. Seen in `vm-limine` on QEMU's VGA
  (22/10/2026), not yet on the B580.
- **Two monitors**: the splash shows on both, but the LG's rotation is Hyprland's and does not
  exist yet at boot, so on the LG it is sideways. Expected, and only for those seconds.
- **Diagnostics stay**: no `quiet` was added, `loglevel=4` stays, Escape switches to the text
  console. To boot once without it: `plymouth.enable=0` on the command line (GRUB's `e`; Limine's
  editor is off under Secure Boot, so there it is an older generation or a rebuild).
- **No added delay**: nothing waits for the animation; it is shown for exactly as long as boot or
  shutdown takes.
