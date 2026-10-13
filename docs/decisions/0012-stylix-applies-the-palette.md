# 0012. Stylix applies the palette; the palette keeps the hexes

Stylix themes every app it knows, fed FROM `my.theme.palette`, instead of from a stock base16 scheme.

- **Status**: accepted, refines [0001](0001-own-nix-palette.md)
- **Date**: 13/10/2026

## Context

Decision 0001 made the palette the single source, but every app had to be wired to it by hand, and
a survey of the installed apps on 13/10/2026 found the gap that left: about nine GTK apps
(pavucontrol, Bottles, Czkawka, Seahorse, virt-manager, Blueman...) still in stock Adwaita gray,
mpv, yazi and LibreWolf with no theme, and Spotify and VS Code pinned to "TokyoNight" by name, so a
theme switch would skip them. Stylix (nix-community) has a target for each of those and more.

The obvious use of Stylix is a stock scheme from `pkgs.base16-schemes`. Measured, that is the
argument 0001 already made: the shipped `tokyo-night-dark.yaml` is not folke's Tokyo Night.

| Slot | `tokyo-night-dark.yaml` | `palette.nix` (folke) |
| --- | --- | --- |
| base05, the text | `#a9b1d6` | `#c0caf5` |
| base08, "red" | `#c0caf5`, the text color | `#f7768e` |
| base0A, "yellow" | `#0db9d7`, a cyan | `#e0af68` |
| base0D, "blue", the accent | `#2ac3de`, a cyan | `#7aa2f7` |

## Decision

Stylix is the APPLIER and `palette.nix` stays the OWNER. `modules/home/desktop/stylix.nix` builds
`stylix.base16Scheme` from `my.theme.palette`, so every Stylix target paints folke's exact hexes
and follows `my.theme.name` like every other consumer. The keys base16 has no slot for (sky, teal,
purple, border, shadow) stay with the consumers that read the palette directly: Quickshell,
Hyprland, the lock screen, rofi, Kvantum and Zen.

Stylix lives in home-manager only, since `my.theme` is a home-manager option and its ten consumers
read it there. It does not own the fonts (they come from `my.fonts.ui`, decision 0002), the cursor,
the icons or the wallpaper.

## Consequences

- One more flake input, pinned to the base's release (`release-26.05`).
- The apps the repo themes by itself stay OFF in Stylix, each with its reason in `stylix.nix`.
- No color on the TTY console, which is a NixOS-side target. Accepted: autologin skips it.
