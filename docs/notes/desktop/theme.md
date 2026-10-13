# The theme: dark mode, Stylix, Kvantum and the Windows 11 icons

`modules/home/desktop/theme.nix` and `modules/home/desktop/stylix.nix`. The palette that feeds both
is `modules/home/desktop/palette.nix` ([decision 0001](../../decisions/0001-own-nix-palette.md)), and
Stylix only APPLIES it ([decision 0012](../../decisions/0012-stylix-applies-the-palette.md)).

## Dark mode on Hyprland has two fronts

1. `color-scheme = "prefer-dark"` is the signal read by GTK4/libadwaita apps AND forwarded by
   `xdg-desktop-portal-gtk` to the Electron/Chromium apps (VS Code, Chrome, Spotify, LibreWolf).
   It is what darkens most of them.
2. `gtk-theme` names Stylix's `adw-gtk3`, recolored by a generated `gtk.css` (`window_bg_color`,
   `accent_color` and the rest of libadwaita's named colors) in the palette. Until 13/10/2026 this
   was stock `Adwaita-dark`, so pavucontrol, Seahorse, Bottles, Czkawka, virt-manager and Blueman
   were gray. Measured on a headless sway: `#2d2d2d` before, `#1a1b26` after.

**The trap**: GTK on Wayland reads the theme name from dconf, through the settings portal, and NOT
from `settings.ini`. A key dropped from Nix also stays in dconf. So `gtk-theme` is still set, to
`config.gtk.theme.name`, instead of being removed; removing it kept Adwaita-dark on screen.

## Stylix: what it themes, and what it does not

`autoEnable = true`: any app Stylix has a target for follows the palette when it is installed. Today
that is GTK, mpv (OSD), yazi, fzf, starship, MangoHud (colors only) and gdu. Each exception is in
`stylix.nix` with its reason, in three groups:

- **Themed here from the same palette**, with keys base16 has no slot for: Hyprland (Lua written
  by hand), hyprlock, hyprpaper, Qt (Kvantum plus a KDE color scheme), rofi, Zen, VS Code (its settings.json is in the repo).
- **An official per-app theme beats a generic base16 one**: kitty, bat (and delta through it),
  Spotify, btop. Measured for kitty: base16 has no bright ANSI slots, so Stylix painted color8
  `#292e42` (zsh autosuggestions near invisible) and every bright color the same as its normal one.
- **Not installed**: blender, forge, vencord, whose targets write files whether the app exists or
  not.

To exclude one more app: `stylix.targets.<name>.enable = false;` with the reason on the same line.
To keep only its colors: `stylix.targets.<name>.{fonts,opacity}.enable = false;`, as MangoHud does.

## Switching the theme

`my.theme.name` takes a curated preset (`tokyo-night`, `catppuccin-mocha`, `gruvbox-dark`, with each
theme's official hexes) or ANY base16 scheme as `base16:<file>`, from
`${pkgs.base16-schemes}/share/themes/`. For a base16 scheme the 20 palette keys are derived from the
16 slots (sky and teal repeat the cyan, purple the magenta), and kitty and bat fall back to Stylix,
btop to `TTY`. Proved with `base16:dracula`: Quickshell, Hyprland, GTK, kitty, bat, Kvantum, Zen and
fzf all followed. A stock scheme may not match the official colors of the theme it is named after;
`tokyo-night-dark` does not (the table in decision 0012).

Qt/KDE apps (Dolphin) do NOT follow GTK on their own under Hyprland. Three layers put them on the
palette, and each one was MEASURED missing on 13/10/2026 before it went in:

| Layer | What it does | Without it |
| --- | --- | --- |
| `QT_STYLE_OVERRIDE=kvantum` | the recolored Win11OS theme draws the widgets | Qt's own Fusion look |
| `QT_QPA_PLATFORMTHEME=qt5ct` (qt6ct answers to it) | hands Kvantum's palette to the app (`custom_palette=false`) | Qt keeps its LIGHT default palette: dark text on `#F0F0F0` rows |
| the KDE color scheme `<slug>.colors`, selected in `dolphinrc` | KDE apps paint their views from KColorScheme, not from the style | Breeze's colors (Breeze Dark under gtk3, `#141618`) |

The old declared value, `platformTheme.name = "kvantum"`, was never real: there is no `kvantum`
platform theme plugin, so Qt silently used none. It never showed, because `hypr/lua/environment.lua`
pinned `gtk3` and `adwaita-dark` over it; that pin is gone, and the Lua now reads the pair from the
generated `hypr-colors.lua`, so `qt.*` in `theme.nix` is the only owner (rule 11).

**The color scheme is chosen PER APP.** Outside Plasma, `kdeglobals [General] ColorScheme` is
ignored (measured); only the app's own `[UiSettings] ColorScheme` loads it, so `dolphin.nix` sets
Dolphin's. Another KDE app that shows Breeze colors needs the same one key in its own module.

**Dolphin's free-space text needs a tool button with no vertical padding.** Dolphin sizes that
button to the font height, and Win11OS' frame (5+6 px) plus its 4 px text margin cut the text in
half; the build zeroes the three in `[PanelButtonTool]`, measured as the smallest change that shows
it whole.

**The Kvantum theme is OPAQUE.** Win11OS ships `translucent_windows` and `blurring` on, which put the
wallpaper behind Dolphin's file names on screen; the build turns both off, so Qt windows are as solid
as the GTK ones.

How it was measured, for the next time: a headless output (`hyprctl output create headless`) plus
`grim -o`, out of sight. **It costs Quickshell**: after about twenty create/remove cycles the bar died
with no line in its log (13/10/2026), so keep the cycles few and start it again with `qs` from a
Hyprland exec. Close `dolphin --daemon` first: a new `dolphin` is handed to the running
instance over D-Bus, and that instance keeps the environment it started with, so every variant
measures the same process. The engine's plugin (`qtstyleplugin-kvantum`) and qt6ct come through the
qt module itself, the same exception as `adwaita-qt`.

## Fonts and cursor

The font in the dconf block is what GTK/GNOME apps use in the interface. fontconfig already covers
mono/sans/serif, but GTK apps read the UI font FROM HERE, not from fontconfig. The numeric suffix
is the size in pt. The SSOT is `modules/nixos/desktop/fonts.nix`; see [`fonts.md`](../hardware/fonts.md).

The Bibata cursor is referenced by NAME (the dconf `cursor-theme` plus the XCURSOR envs in
`hypr/lua/environment.lua`), so the package has to be in the user's profile.

## The two vendored derivations

Both are an exception to the "`modules/home/` does not install a package" rule: they are theme assets
consumed only by home-manager's qt/gtk modules, the same case as `adwaita-qt`.

### `win11os-kvantum`

Only the Kvantum folder of yeyushengfan258/Win11OS-kde, pinned by commit, RECOLORED BY THE PALETTE
at build time (19/08/2026). The `/share/Kvantum/<Theme>` layout is what `qt.kvantum.themes` expects,
since it does `stripPrefix "/share/Kvantum"`.

The theme is called `Win11OS-<preset>` (`Win11OS-tokyo-night` today) because that is what it is: the
Win11OS GEOMETRY carrying this repo's colors. Switching `my.theme.name` renames the directory too,
and home-manager drops the old symlinks on the switch, since `qt.kvantum` writes them with
`xdg.configFile` and `recursive = true`.

WHY RECOLOR INSTEAD OF ADOPTING A READY-MADE TOKYO NIGHT THEME: what was picked in july was the
WIDGET SHAPE (the Windows 11 corners, the underline on focus, the flat toolbar) and the colors came
along as a side effect, which left rule 11 broken (the palette, decision 0001) in the app that is on screen the most. Recoloring
keeps the shape and puts the palette back in charge, and it also means the preset switch finally
reaches Dolphin, which it never did before.

#### One attrset, applied to both files

`kvantumRecolor` maps the Win11OS hex to a palette KEY, never to another hex, and a single `sed`
runs it over the `.kvconfig` and the `.svg` together, so `[GeneralColors]` and the SVG surfaces
cannot drift apart. The `I` flag is not decoration: `link.color` is the uppercase `#0057AE`.

The colors live in BOTH files, which is why one map has to cover both:

- the `.kvconfig` holds the Qt PALETTE (`[GeneralColors]`) plus a `text.*.color` per widget, and
  that is what paints the file view, the sidebar and every label;
- the `.svg` holds the widget ART, and the window itself is in there (`window-normal`, `#1e1e1e` at
  0.8 opacity), along with the toolbar and the tab strip (`menubar-normal`, `#191919`).

WHAT IS DELIBERATELY LEFT OUT OF THE MAP:

- **the white and black overlays** (`#ffffff` 207 times, `#000000` 117): the theme draws selection,
  hover, the active tab and the menu items as WHITE AT 0.1 to 0.2 OPACITY, so they already follow
  whatever sits underneath. Recoloring them would replace a mechanism that already works.
- **`#b74aff` and `#9f5aff`**: they are the `*-shadow-hint` elements, Kvantum's markers for the
  shadow geometry, and they are never painted.
- **the neutral grays** (`#646464`, `#6c6e70`, `#969696` and so on): grooves and tick marks, which
  read as gray under any palette.

#### Two decisions the palette does not make on its own

**`surface` is LIGHTER than `bg` here, and the Night variant does the opposite.** In
folke/tokyonight.nvim, `night` is `storm` with `bg`, `bg_dark` and `bg_dark1` overridden, so night's
own `bg_dark` is `#16161e` (DARKER than `bg`), while this repo's `surface = #1f2335` is STORM's
`bg_dark` (lighter). Both are official hexes; what `surface` means here is ELEVATED. So the popups
(menu, tooltip, the column header) take `surface` and the WINDOW CHROME takes `bg`: the toolbar and
the tab strip go flat with the window, which is what Explorer does and what "cleaner" was asking
for.

**`highlight.text.color` stays `#ffffff`.** The reflex is to set it to `bg`, for dark text over the
light blue `#7aa2f7`, and it would be WRONG: `[Hacks] no_selection_tint=true`, so the selected row
is not painted with the highlight color at all, it is `itemview-toggled`, white at 0.2 over `bg`.
Dark text there would be dark on dark. The highlight color shows up as the focus frame and as the
selection inside a line edit, where white over `#7aa2f7` is the usual Tokyo Night trade.

#### The two keys upstream never sets

`tooltip.base.color` and `shadow.color`, appended after the recolor because there is nothing to
substitute for them. Kvantum's `Theme-Config` is explicit that an absent key is taken "from the
currently used color palette", which is Qt's LIGHT default, so absent does not mean unused.

### `win11-icons`

yeyushengfan258/Win11-icon-theme, pinned by commit. Vendored because it is NOT in nixpkgs.

Chosen on 07/08/2026 over `pkgs.fluent-icon-theme`, which was the theme here and is ALSO Windows
11. Two reasons, in this order:

1. it is a redraw of Microsoft's icons, not an author's own take on Fluent Design, compared icon by
   icon before switching;
2. it is by the SAME author as the Kvantum theme, so widget and icon match out of the box.

**The price, accepted**: it leaves the nixpkgs channel, so bumping it here became manual (the
version strategy's rule: upstream directly only when the gain justifies it).

Three build details that each cost something:

- **`-t` stays OUT on purpose.** With an empty variant the script skips the `cp colors/color<X>`,
  and it is precisely `src/places/scalable` (Microsoft's light blue folder) that was approved.
  Passing `-t blue` and so on would RECOLOR the folders on top and deliver something else.
- **`gtk3` is in `nativeBuildInputs` only for the binary.** `install.sh` ends every variant with
  `gtk-update-icon-cache` (line 202) and the `set -eo pipefail` turns "command not found" into a
  fatal error. The damage was worse than just failing: it died AFTER installing the first variant,
  so `Win11-dark`, which is exactly what we use, never even came to exist. It is not for the cache
  itself; checked that no `icon-theme.cache` is left in the output.
- **It runs `install.sh` instead of copying `src/` by hand.** Besides copying, the script renames
  the `index.theme`, applies the dark variant swap, and recreates the SYMLINK FARM in `links/`,
  which is what makes hundreds of mime names land on the same SVG. Copying by hand would deliver a
  theme full of generic icons.

**Pruning dead symlinks** is required, otherwise nixpkgs' `noBrokenSymlinks` fails the build (147
per variant). It is not a workaround: they are COLOR VARIANT links (`folder-green.svg`,
`green-folder-video.svg`, `folder_color_yellow_wine.svg`) whose target does not exist in any
installation, not even on Arch, because `colors/color-<X>/` uses `folder-*.svg` names to OVERWRITE
and never creates the prefixed names. A cosmetic upstream bug; nixpkgs is just stricter. Checked
that none of them is a freedesktop name Dolphin looks up: `folder`, `folder-documents`,
`user-home` and the mimes stay intact.

## The KDE icon activation

Kvantum does NOT set icons. KDE apps read the theme from `kdeglobals [Icons] Theme`, and KDE
rewrites that file at runtime, so only that key is forced, idempotently, the same pattern as
[`dolphin.md`](../apps/dolphin.md).

## The palette is the SSOT, and how it reaches a hot-reloaded file

`modules/home/desktop/palette.nix`. Switching themes means changing `my.theme.name` (1 line) and
rebuilding. Each preset carries the exact OFFICIAL hexes of its palette, stored WITHOUT the `#`
and 6 digits long, so each consumer formats them as it needs.

The presets themselves are plain DATA in `modules/home/desktop/palette-presets.nix`, with the default
name beside them, since 13/10/2026. A data file and not a `let` inside the module because the docs
site is built OUTSIDE home-manager and reads the same hexes: two copies would be rule 11 broken.

The presets today are Tokyo Night (the Night variant), Catppuccin Mocha and Gruvbox Dark. The
second and third exist to demonstrate that the switch really works; Gruvbox in particular is warm
enough that a broken consumer is obvious at a glance.

There are two kinds of consumer:

- **Nix consumers** (rofi, lockscreen, flameshot, the Kvantum theme) read
  `config.my.theme.palette.<color>` directly.
- **Hot-reload consumers** (Quickshell in QML, Hyprland in Lua) read DATA FILES generated into
  `~/.config/theme/`, because Nix cannot write inside the symlinked `quickshell/` and `hypr/` trees.

That is why `uiFont` rides along in `quickshell-colors.json` and the cursor rides along in
`hypr-colors.lua`: those JSON and Lua files are the ONLY path into a hot-reloaded tree, even though
neither value is a color. Both file names are historical.

`modules/home/desktop/monitors.nix` exists for exactly the same reason and generates
`~/.config/theme/monitors.lua` and `monitors.json`. Note that the monitors OPTION does not live
there: it moved to `modules/nixos/desktop/monitors.nix` on 04/08/2026 because Sunshine needs it too (see
[`monitors.md`](../hardware/monitors.md)). The home module only READS it through `osConfig`.

### What is in `my.theme` but does not derive from the color preset

- **`iconTheme`** (`Win11-dark`). It is theming, but Win11-dark is the Windows 11 look and holds
  under any palette. The PACKAGE lives in `theme.nix`, so switching means this line plus the
  package. The NAME has to match the directory `install.sh` generates (`-n Win11` plus the `-dark`
  variant), otherwise the theme silently falls back.
- **`cursor.name` and `cursor.size`**, same reasoning; the package (`bibata-cursors`) lives in
  `theme.nix`. The size is global here, not per context.

The UI FONT deliberately does NOT live here: it is `my.fonts.ui`, in `modules/nixos/desktop/fonts.nix`,
next to its package (rule 4).
