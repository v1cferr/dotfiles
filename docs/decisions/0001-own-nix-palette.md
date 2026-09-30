# 0001. The theme is a Nix palette of my own

Every themed program reads one palette of my own, picked by one option, instead of nix-colors.

- **Status**: accepted
- **Date**: 29/07/2026, first recorded; it was rule 9 until 30/09/2026

## Context

Every themed program (kitty, Hyprland, Quickshell, the lockscreen, GTK/Qt, VS Code) needs the
same colors, and switching themes should not mean editing each of them. The community answer was
`nix-colors`, a base16 scheme shared through a flake input.

## Decision

A palette of my own in `home/desktop/palette.nix`, picked by one option, `my.theme.name`, with
presets for tokyo-night (the default), catppuccin-mocha and gruvbox-dark. Every consumer reads
`my.theme.palette`, never a hex (rule 11).

## Consequences

- Changing the theme is one line, and a sentinel theme proves every consumer follows it.
- **`nix-colors` was rejected**: it was archived in April 2026, and a base16 scheme of 16 colors
  does not reproduce the exact hexes each preset publishes.
- The palette is mine to maintain: a new preset means typing its hexes once.
