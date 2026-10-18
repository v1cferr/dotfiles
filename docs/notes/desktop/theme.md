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
  by hand), hyprlock, hyprpaper, Qt (Kvantum plus a KDE color scheme), Vicinae, Zen, VS Code (its settings.json is in the repo).
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

- **Nix consumers** (Vicinae, lockscreen, flameshot, the Kvantum theme) read
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
- **`motion`** (`subtle` or `off`): the desktop's motion profile, read by Hyprland and Quickshell
  through the same two files. [`motion.md`](motion.md).
- **`glass`** (`perceptible`, `clear-gradient` or `solid`): the glass PROFILE, read by Quickshell,
  Hyprland (HyprGlass) and kitty. The next section is the whole system.

The UI FONT deliberately does NOT live here: it is `my.fonts.ui`, in `modules/nixos/desktop/fonts.nix`,
next to its package (rule 4).

## Tokyo Night Adaptive Glass: the shell's design system

Chosen on 17/10/2026 for the bar, the glance band and every panel, and refined the same day into
v2: one continuous Powerline over the astronomy wallpapers, a bento grid on the standing monitor,
one geometry and one material. The COLORS
stay the palette above; what this adds is presentation, and it lives in `Theme.qml` as tokens, so a
component never holds a size, an opacity or a duration of its own (rule 11).

### The tokens

| Group | Tokens | Values |
| --- | --- | --- |
| Spacing, a 4 px grid | `sp1` `sp2` `sp3` `sp4` `sp6` | 4, 8, 12, 16, 24 |
| Radii, concentric | `radiusControl`, `radiusSurface` | 8, and 8 + `sp1` = 12 |
| The bar | `barHeight`, `barControl`, `barTop`, `barSlant`, `barCenterWidth`, `barLogo` | 40, 40 - 12 = 28, 0, 8, 64, 22 |
| Insets | `bandTop`, `screenInset` | the bar plus 8 = 48; `my.theme.gaps.outer` = 12 |
| Type (px, all mono) | `fontMicro` `fontSmall` `fontBody` `fontLabel` `fontTitle` | 10, 11, 12, 13, 14 |
| Glass | `colSurfaceBar`, `colSurfaceCard`, `colSurfacePop` | the palette's bg at 90%, 92%, 96% |
| Edges | `colEdge`, `colSheen`, `hairline` | border at 55%, text at 6%, 1 px |
| States | `colHoverFill`, `colPressFill`, `colSelectFill`, `opacityDisabled` | text at 8% and 14%, accent at 18%, 0.4 |
| Motion | `motionHover` `motionNormal` `motionSlow`, `hoverIntent` | [motion.md](motion.md); the intent is 200 ms |

**Concentric radii** are why the numbers pair up: a control's 8 px corner plus 4 px of padding is a
surface's 12 px corner, so the two curves run parallel, and a panel, a band card and (since the same
day) every window use the same 12 (`my.theme.rounding`).

**Mono everywhere** is also the tabular-figures answer: JetBrains Mono gives every digit the same
advance, so a number padded to a fixed count of columns never changes width
([bar.md](bar.md#numbers-that-hold-still)).

### The three glass levels

One component paints all of them, `widgets/GlassSurface.qml`: the palette's bg at the level's
opacity, a hairline edge, and a 1 px sheen along the top edge inset past the corners, which is what
makes a surface read as a pane over the photo instead of a hole cut in it. There is no drop shadow:
Hyprland draws none for layers, and a shadow painted in QML would need a margin of transparent
window around every card for no gain in legibility.

| Level | Opacity | Used by | Why that much |
| --- | --- | --- | --- |
| `bar` | 90% | the Powerline | short labels, glanced at, the most photo can show through |
| `card` | 92% | the band's bento cards | read from the chair for a while, with fine print on the pages |
| `pop` | 96% | every panel, menu, the OSD, the notification center | dense text, read the longest |

Those are the `perceptible` profile's numbers; the next section has the other profile's.

### The two profiles (18/10/2026)

`my.theme.glass` picks a PROFILE, one value with three readers generated by Nix, the same way
`motion` travels: the QML surfaces (`quickshell-colors.json`), HyprGlass's presets (`glass.lua`,
through `hypr-colors.lua`) and kitty's `background_opacity` (`kitty.nix`).

| | `perceptible` (the default) | `clear-gradient` |
| --- | --- | --- |
| Bar | 90% flat | the palette's bg at 70% at the top easing into its surface at 70% at the foot (it was 86% into 80%) |
| Band cards | 92% flat | 70% bg into 70% surface, kitty's own opacity (18/10/2026; it was 88% into 84%) |
| Panels, Center, toasts | 96% flat | 70% flat: dense text gets no gradient (it was 90%) |
| kitty | background 0.95, then the global 0.98 window opacity on top | background 0.70, exempt from the global rule |
| HyprGlass tint, panel tint | bg at 33%, at 50% | bg at 20%, at 30% |
| HyprGlass brightness | 0.85 | 0.95 |
| HyprGlass blur, window / bar / panel | 1.2 / 1.6 / 2.0 | 0.9 / 1.2 / 1.6 |
| HyprGlass refraction | 0.3, at the rim | 0.25, at the rim |
| xray, self sampling | off | off |

`solid` stays the opaque fallback for both: every surface at 100% and HyprGlass leaving the layers
alone.

**The gradient is a shift in tint as much as in alpha:** top in the palette's bg, foot in its
`surface` (Tokyo Night's #1f2335, a step lighter and bluer), both from the palette, so another
theme gets its own gradient. It is a plain two-stop `Gradient` on the surface's Rectangle, drawn
once: no shader, nothing that repaints on its own.

**kitty's composite, on purpose.** In `perceptible` the background is 0.95 x 0.98 = 0.931 of the
window opacity and the TEXT is dimmed to 0.98 with it. In `clear-gradient` kitty is exempt from the
0.98 rule (`rules.lua`), so its `background_opacity` of 0.70 is the only reduction: the background is
exactly 0.70 and the text stays at 100%, which is what keeps it sharp over a busier backdrop.

**Contrast, computed** on 18/10/2026 (the same method as above, over a galaxy core that the blur
turns into `#cccccc`, without counting HyprGlass's own dimming, which only helps):

| Surface, clear-gradient | `text` | `subtext` | `accent` | `red` |
| --- | --- | --- | --- | --- |
| bar top, 86% bg | 7.3 | 5.6 | 4.7 | 4.4 |
| card top, 88% bg (before 18/10/2026) | 8.3 | 6.3 | 5.3 | 5.1 |
| panel, 90% bg | 8.5 | 6.5 | 5.4 | 5.2 |
| kitty background, 85% (the first value) | 7.5 | 5.7 | 4.8 | 4.6 |
| kitty background, 70%, HyprGlass's dimming counted | 6.3 | 4.8 | 4.0 | 3.9 |

The foot of the gradients is where it gets close: the bar's 80% surface foot leaves the accent near
3.9 over the brightest part of a photo, which is why the gradient stops there and not at the 76%
first considered (3.4). On this desk's usual dark wallpapers the backdrop is close to the palette's
own bg, and every number is far higher.

**kitty went from 0.85 to 0.70 on 18/10/2026**, to make the glass read. Measured live, kitty over
bright colored stripes, transmission being the spread of the patch behind the glass over the bare
backdrop's, and contrast read off the real text pixels:

| kitty background | Transmission | Text contrast, mean / worst 5% |
| --- | --- | --- |
| 0.85 | 0.067 | 9.2 / 9.0 |
| 0.70 (chosen) | 0.108 | 8.1 / 7.9 |
| 0.55 | 0.16 | 7.1 / 6.8 |
| 0.40 | 0.20 | 6.1 / 5.8 |

The cost is the worst case: computed, a white page right behind the terminal would leave the accent
at about 4.0. Measured, it does better, since HyprGlass darkens more than that estimate assumed. Back
to 0.85 is one line in `kitty.nix`.

**Every shell surface went to the windows' recipe on 18/10/2026**, at the owner's request that the
whole desktop read as one material: the band first, then the bar, the logo's compartment and the
panels, all at kitty's 0.70 and on HyprGlass's `window` preset instead of `ui` and `panel`. Only
under `clear-gradient`; `perceptible` keeps its denser numbers. The panels were the doubtful part:
they open over anything, a white page included, and hold the most running text, and the measurement
below is what says they still pass. Same opacity, same tint, same glass, so the kitty measurement below holds for the cards as it
stands: text 7.3, the accent 4.7 over the brightest 5% of white stripes. The dim footnotes
(`colDim`) were never meant to pass AA and pay the most for it.

**HyprGlass's own numbers were measured too, and left alone** (18/10/2026). In a nested Hyprland, a
kitty at 0.70 floating over the same stripes, white included, one grim capture per variant of the
`window` preset; contrast as mean / the brightest 5% of what shows through:

| Variant | Transmission | `text` | `subtext` | `accent` |
| --- | --- | --- | --- | --- |
| no HyprGlass, Hyprland's blur only | 0.272 | 6.3 / 3.9 | 4.8 / 3.0 | 4.0 / 2.5 |
| current: tint 20%, brightness 0.95, blur 0.9 | 0.109 | 8.7 / 7.3 | 6.6 / 5.6 | 5.6 / 4.7 |
| tint 13%, brightness 1.0 | 0.125 | 8.4 / 6.9 | 6.4 / 5.3 | 5.4 / 4.4 |
| blur 0.6 | 0.114 | 8.7 / 7.2 | 6.6 / 5.5 | 5.6 / 4.6 |
| tint 13%, brightness 1.0, blur 0.6 | 0.130 | 8.4 / 6.8 | 6.4 / 5.2 | 5.4 / 4.4 |

The best variant buys 19% more transmission and takes the accent's worst case under AA (4.5), and
less blur barely moves it: the glass's tint is what keeps text readable over a bright backdrop, so the
current values stay. Without the plugin the stripes show the most, and the accent drops to 2.5.

**What was measured live, and what was not.** The profile was applied with a `rebuild` and checked
in the running shell: the bar at `#db1a1b26` easing to `#cc1f2335`, the cards `#e01a1b26` to
`#d61f2335`, the panels `#e61a1b26`, kitty at 0.85 with HyprGlass drawing behind it (a floating
kitty tagged `hyprglass_enabled`, 1.16 window draws per frame). An empty patch of a band card read
the SAME color in both profiles: Tokyo Night's bg (26,27,38) is almost exactly the mean of a dark
space photo (28,28,38), so any alpha over it gives the same pixel. The difference shows over bright
things, a nebula core or a window behind a panel, and judging it there is the owner's to do at the
desk.

**Switching, and going back.** One line in the host, `home-manager.users.v1cferr.my.theme.glass =
"clear-gradient";` (`hosts/ex-b560m-v5/default.nix`), then `! rebuild`; the shell and kitty pick it up
from the generated files and Hyprland on its next reload. Deleting the line and rebuilding is the way
back to `perceptible`. Every number above is one line: the hex bytes in `Theme.qml`, the `V` table in
`glass.lua`, the opacity in `kitty.nix`.

**Contrast, computed** on 17/10/2026 (WCAG 2 relative luminance, the surface composited over the two
extremes a space photo puts behind it: black sky, and a galaxy core that Hyprland's blur, at
`brightness = 0.8`, turns from white into `#cccccc`):

| Text color | bar over black | bar over a bright core | panel over a bright core | solid |
| --- | --- | --- | --- | --- |
| `text` | 10.9 | 8.5 | 9.8 | 10.6 |
| `subtext` | 8.3 | 6.5 | 7.5 | 8.1 |
| `accent` | 7.0 | 5.4 | 6.3 | 6.8 |
| `red` | 6.6 | 5.2 | 6.0 | 6.5 |
| `dim` | 2.8 | 2.2 | 2.5 | 2.8 |

Everything that carries information stays above WCAG AA's 4.5 even over the brightest part of a
photo. `dim` does not, and it does not on a SOLID Tokyo Night background either (2.8): it is the
palette's own low-contrast step, so it is kept for decoration and for what a hover repeats. The bar's
date, which used to be `dim`, is `subtext` now for that reason. The fix for contrast is on the
surface, never a darker wallpaper: the photo stays as it is.

### The blur, and `solid`

`appearance.lua` blurs exactly the shell's named layers, `qs-bar`, `qs-dash`, `qs-panel` and
`qs-center` (the NixOS Center's own, so a capture can wait for it), with
the global `decoration.blur` settings, and `ignore_alpha = 0.5` keeps the blur off their transparent
margins: the gaps between bento cards show the photo sharp, and only what sits
under glass is frosted. Every other Quickshell layer keeps the default `quickshell` namespace and is
not blurred. No plugin is involved (HyprGlass and similar were ruled out by the brief); this is the
native layer rule on the pinned Hyprland.

`my.theme.glass = "solid"` paints all three levels opaque and drops the rule, so no blur is paid
for. It is the fallback for a wallpaper where something still reads badly, or for a GPU that needs
the frames; the design does not depend on the blur, only looks better with it. Tested on 17/10/2026
by forcing the QML default: the cards turn opaque with the same geometry.

### Tuning

| To change | Where |
| --- | --- |
| How see-through a level is | `colSurfaceBar` / `colSurfaceCard` / `colSurfacePop` in `Theme.qml` (the hex byte) |
| Glass off entirely | `my.theme.glass = "solid";` and a rebuild |
| The blur's look | `decoration.blur` in `appearance.lua`, shared with the windows |
| The band's height | `my.dash.share` ([dash.md](dash.md#the-share-35-by-default-never-above-40)) |
| Window gaps and corners | `my.theme.gaps.inner` / `.outer`, `my.theme.rounding` ([hypr.md](hypr.md#balanced-geometry)) |
| Liquid Glass instead of the blur | `my.hypr.hyprglass.enable` ([hyprglass.md](hyprglass.md)) |
| A duration | the `motion*` tokens ([motion.md](motion.md)) |
