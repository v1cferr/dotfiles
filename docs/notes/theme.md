# The theme: dark mode, Kvantum and the Windows 11 icons

`home/desktop/theme.nix`. Here we only CONFIGURE; the theme package (`gnome-themes-extra`, which
brings Adwaita-dark) and the GTK portal live in `system/`.

## Dark mode on Hyprland has two fronts

1. `color-scheme = "prefer-dark"` is the signal read by GTK4/libadwaita apps AND forwarded by
   `xdg-desktop-portal-gtk` to the Electron/Chromium apps (VS Code, Chrome, Spotify, LibreWolf).
   It is what darkens most of them.
2. `gtk-theme = "Adwaita-dark"` is for the old GTK3 apps, which do not follow the color-scheme on
   their own. The theme is found through `XDG_DATA_DIRS`.

Qt/KDE apps (Dolphin) do NOT follow GTK on their own under Hyprland. This used to follow GTK
(`platformTheme gtk3` plus `adwaita-dark`); now Qt is 100% Kvantum for the Windows 11 theme in
Dolphin. Kvantum takes over EVERYTHING in Qt (palette plus widgets), so the gtk3-follow was
dropped. The GTK and Electron apps are unchanged.

`QT_QPA_PLATFORMTHEME=kvantum` makes Kvantum set the palette, `QT_STYLE_OVERRIDE=kvantum` makes it
draw the widgets. The engine's plugin (`qtstyleplugin-kvantum`) comes through the qt module itself,
the same exception as `adwaita-qt`.

## Fonts and cursor

The font in the dconf block is what GTK/GNOME apps use in the interface. fontconfig already covers
mono/sans/serif, but GTK apps read the UI font FROM HERE, not from fontconfig. The numeric suffix
is the size in pt. The SSOT is `system/hardware/fonts.nix`; see [`fonts.md`](fonts.md).

The Bibata cursor is referenced by NAME (the dconf `cursor-theme` plus the XCURSOR envs in
`hypr/lua/environment.lua`), so the package has to be in the user's profile.

## The two vendored derivations

Both are an exception to the "`home/` does not install a package" rule: they are theme assets
consumed only by home-manager's qt/gtk modules, the same case as `adwaita-qt`.

### `win11os-kvantum`

Only the Kvantum folder of yeyushengfan258/Win11OS-kde, pinned by commit. The
`/share/Kvantum/<Theme>` layout is what `qt.kvantum.themes` expects, since it does
`stripPrefix "/share/Kvantum"`. It only copies SVG and kvconfig files, so there is nothing to
configure or compile.

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
[`dolphin.md`](dolphin.md).

## The palette is the SSOT, and how it reaches a hot-reloaded file

`home/desktop/palette.nix`. Switching themes means changing `my.theme.name` (1 line) and
rebuilding. Each preset carries the exact OFFICIAL hexes of its palette, stored WITHOUT the `#`
and 6 digits long, so each consumer formats them as it needs.

The presets today are Tokyo Night (the Night variant), Catppuccin Mocha and Gruvbox Dark. The
second and third exist to demonstrate that the switch really works; Gruvbox in particular is warm
enough that a broken consumer is obvious at a glance.

There are two kinds of consumer:

- **Nix consumers** (rofi, lockscreen, flameshot) read `config.my.theme.palette.<color>` directly.
- **Hot-reload consumers** (Quickshell in QML, Hyprland in Lua) read DATA FILES generated into
  `~/.config/theme/`, because Nix cannot write inside the symlinked `quickshell/` and `hypr/` trees.

That is why `uiFont` rides along in `quickshell-colors.json` and the cursor rides along in
`hypr-colors.lua`: those JSON and Lua files are the ONLY path into a hot-reloaded tree, even though
neither value is a color. Both file names are historical.

`home/desktop/monitors.nix` exists for exactly the same reason and generates
`~/.config/theme/monitors.lua` and `monitors.json`. Note that the monitors OPTION does not live
there: it moved to `system/desktop/monitors.nix` on 04/08/2026 because Sunshine needs it too (see
[`monitors.md`](monitors.md)). The home module only READS it through `osConfig`.

### What is in `my.theme` but does not derive from the color preset

- **`iconTheme`** (`Win11-dark`). It is theming, but Win11-dark is the Windows 11 look and holds
  under any palette. The PACKAGE lives in `theme.nix`, so switching means this line plus the
  package. The NAME has to match the directory `install.sh` generates (`-n Win11` plus the `-dark`
  variant), otherwise the theme silently falls back.
- **`cursor.name` and `cursor.size`**, same reasoning; the package (`bibata-cursors`) lives in
  `theme.nix`. The size is global here, not per context.

The UI FONT deliberately does NOT live here: it is `my.fonts.ui`, in `system/hardware/fonts.nix`,
next to its package (rule 4).
