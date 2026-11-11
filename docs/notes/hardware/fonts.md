# Fonts and typography

`modules/nixos/desktop/fonts.nix` is the SSOT of the UI family, `my.fonts.ui`, of the shell's text
(`my.fonts.shell`) and of the bar's icons (`my.fonts.icons`).

## Why the SSOT lives on the system side

It is not in `my.theme` (`modules/home/desktop/palette.nix`, which handles the COLORS) for two reasons:
the font's PACKAGE is system level (rule 4), so the name and the package stay together; and the
fontconfig below also needs the name, and a system module cannot read a home-manager option.

The USER consumers read it through `osConfig`, the same pattern as `my.services`: GTK and Qt
(`modules/home/desktop/theme.nix`), kitty, hyprlock and Vicinae. Quickshell's JSON carries the
shell's own two families instead (below).

Switching fonts is 1 line (`my.fonts.ui`) plus the corresponding package in the list.

The SIZE stays with each consumer: 11pt in GTK, 12pt in kitty, Vicinae's own default (10.5pt), and the lockscreen varies per
widget. That is context, not theme.

Note that keeping a MONO font in the system's UI (GTK, kitty, Vicinae) is a deliberate choice, not
an accident; the shell alone left it on 11/11/2026. fontconfig does not control the font of an Electron app, which was measured.

## The coverage packages, and why they are declared even when they come for free

JetBrainsMono NF covers Latin, Greek, Cyrillic plus the patched symbols, and THAT IS ALL. Emoji,
CJK, math, arrows and dingbats come out through FALLBACK, and with nobody declared fontconfig
resolves in an order of its own, ending at `unifont`: a 16px bitmap that comes from
`enableDefaultPackages` and is the only one covering ranges like U+0870/U+2FFC. That is the
pixelated little square that showed up in a stream title and in a spreadsheet.

So the three coverage fonts go in to make the fallback a CHOICE and not an accident, and they stay
DECLARED even the ones that already came for free, otherwise the rendering depends on a NixOS
default nobody here asked for.

| Package                  | Covers                                                                       |
| ------------------------ | ---------------------------------------------------------------------------- |
| `noto-fonts`             | proportional Sans/Serif plus Symbols/Symbols2, the broadest general coverage |
| `noto-fonts-color-emoji` | COLOR emoji (CBDT); monochrome-emoji is the opposite of what we want         |
| `noto-fonts-cjk-sans`    | Japanese/Chinese/Korean (a stream name, Twitch chat)                         |

## The Microsoft metrics

`corefonts` (Arial, Times New Roman, Courier New, Verdana, so Office 2003 and earlier) and
`vista-fonts` (Calibri, Cambria, Consolas, and the modern `.docx` uses Calibri by default) exist so
OnlyOffice (`modules/home/apps/office.nix`) opens `.docx`/`.xlsx` with the right layout. Without them
fontconfig substitutes and the pagination shifts.

## The defaultFonts ordering

A "laboratory" aesthetic: the UI font in menus and in the browser too. It is also what answers
when a document asks for a font that is not installed.

The SSOT stays FIRST in every list, and what comes after it is only consulted for a glyph it does
not have, so the appearance does not change, things merely stop being missing.

Emoji goes at the END of each generic on purpose: at the end it never beats a text font, but it is
reached directly instead of by luck in the queue. The `emoji` generic is set explicitly even
though it is NixOS' default, because a silent default is not something to inherit.

## The shell's own families (11/11/2026)

The Quickshell shell (the bar, its panels, the band and the lock) is set in Geist, a proportional
sans, and the bar draws its icons from Material Symbols Rounded. Both were the lock screen's alone
until 11/11/2026, when the owner asked for the bar's face and icons to change and chose the two the
lock already used, over the whole shell, so a panel never opens in another face than the item that
opened it. Neither enters `defaultFonts`: no app, no terminal and no GTK surface changes face. Why
each one was picked for the lock: [lockscreen.md](../desktop/lockscreen.md).

| Option           | Value                      | Reaches the shell as                                    |
| ---------------- | -------------------------- | ------------------------------------------------------- |
| `my.fonts.shell` | `Geist`                    | `uiFont` in `quickshell-colors.json`, `Theme.uiFont`    |
| `my.fonts.icons` | `Material Symbols Rounded` | `iconFont` in the same file, `Theme.iconFont`           |

**Icons inside a text still work.** About 270 texts in the shell hold a Nerd Font glyph beside
their words (a panel's row, the band's rain percentage, an app's brand icon in the window title),
and Geist has none. A fontconfig alias (`localConf`) sends a glyph Geist lacks to the UI family's
PROPORTIONAL cut, `JetBrainsMono Nerd Font Propo`. The plain cut would also be found, but its icons
are drawn two cells wide on a one-cell advance, which a mono text hides and a proportional one does
not: rendered on 11/11/2026 without the alias, the title's icon sat on its first letter and the
band's rain icon on its percentage.

**Numbers hold their column without a mono face.** The bar's labels and the templates that size
them ask for tabular digits (`Theme.fontTabular`, OpenType `tnum`), and a number padded to a fixed
width is padded with U+2007, the space as wide as a digit.

**The icons are outlined.** Material Symbols has a `FILL` axis, and at `FILL` 1 this Qt drew broken
shapes (an inner outline showing through the fill, rendered on 11/11/2026), so `Theme.iconAxes`
sets the weight and the optical size only, as the lock does.

Until the next rebuild the generated JSON still names the UI family, so the shell keeps its mono
face with the new icons; the rebuild is what switches the text.
