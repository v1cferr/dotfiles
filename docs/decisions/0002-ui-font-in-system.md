# 0002. The UI font is a system option, apart from the colors

- **Status**: accepted
- **Date**: 29/07/2026; it was rule 10 until 30/09/2026

## Context

Seven consumers named the UI font as a literal. The font is also read by fontconfig, which is
system level, while most of the consumers are home-manager modules.

## Decision

`my.fonts.ui` is declared in `system/hardware/fonts.nix`, next to the font package, and not next
to the palette. A home-side consumer reads it through `osConfig.my.fonts.ui`.

## Consequences

- Changing the font is one line plus the package.
- It had to be a SYSTEM option: a system module cannot read a home-manager option, and
  fontconfig needs the name too (rule 11's "the lowest level that needs it").
- Colors and font are two separate choices, so a theme change never moves the font.
