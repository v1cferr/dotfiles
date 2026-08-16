# Fonts and typography

`system/hardware/fonts.nix` is the SSOT of the UI family, `my.fonts.ui`.

## Why the SSOT lives on the system side

It is not in `my.theme` (`home/desktop/palette.nix`, which handles the COLORS) for two reasons:
the font's PACKAGE is system level (rule 4), so the name and the package stay together; and the
fontconfig below also needs the name, and a system module cannot read a home-manager option.

The USER consumers read it through `osConfig`, the same pattern as `my.services`: GTK and Qt
(`home/desktop/theme.nix`), kitty, hyprlock, rofi and Quickshell's JSON.

Switching fonts is 1 line (`my.fonts.ui`) plus the corresponding package in the list.

The SIZE stays with each consumer: 11pt in GTK, 12pt in kitty/rofi, and the lockscreen varies per
widget. That is context, not theme.

Note that keeping a MONO font in the UI is a deliberate choice, not an accident; see the memory
about it. fontconfig does not control the font of an Electron app, which was measured.

## The coverage packages, and why they are declared even when they come for free

JetBrainsMono NF covers Latin, Greek, Cyrillic plus the patched symbols, and THAT IS ALL. Emoji,
CJK, math, arrows and dingbats come out through FALLBACK, and with nobody declared fontconfig
resolves in an order of its own, ending at `unifont`: a 16px bitmap that comes from
`enableDefaultPackages` and is the only one covering ranges like U+0870/U+2FFC. That is the
pixelated little square that showed up in a stream title and in a spreadsheet.

So the three coverage fonts go in to make the fallback a CHOICE and not an accident, and they stay
DECLARED even the ones that already came for free, otherwise the rendering depends on a NixOS
default nobody here asked for.

| Package | Covers |
| --- | --- |
| `noto-fonts` | proportional Sans/Serif plus Symbols/Symbols2, the broadest general coverage |
| `noto-fonts-color-emoji` | COLOR emoji (CBDT); monochrome-emoji is the opposite of what we want |
| `noto-fonts-cjk-sans` | Japanese/Chinese/Korean (a stream name, Twitch chat) |

## The Microsoft metrics

`corefonts` (Arial, Times New Roman, Courier New, Verdana, so Office 2003 and earlier) and
`vista-fonts` (Calibri, Cambria, Consolas, and the modern `.docx` uses Calibri by default) exist so
OnlyOffice (`home/apps/office.nix`) opens `.docx`/`.xlsx` with the right layout. Without them
fontconfig substitutes and the pagination shifts.

## The defaultFonts ordering

A "laboratory" aesthetic: the UI font in menus and in the browser too. It is also what answers
when a document asks for a font that is not installed.

The SSOT stays FIRST in every list, and what comes after it is only consulted for a glyph it does
not have, so the appearance does not change, things merely stop being missing.

Emoji goes at the END of each generic on purpose: at the end it never beats a text font, but it is
reached directly instead of by luck in the queue. The `emoji` generic is set explicitly even
though it is NixOS' default, because a silent default is not something to inherit.
