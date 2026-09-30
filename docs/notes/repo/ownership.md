# Ownership: one source per value, one writer per file, one starter per process

The long form of the three rules about OWNERS, moved here from [rules.md](../../rules.md) when
they became cards on 30/09/2026: [rule 11](../../rules.md) (a value has one source),
[rule 14](../../rules.md) (a file has one writer) and [rule 15](../../rules.md) (an automation
has one starter). They are the same idea at three levels, and every silent failure this repo has
recorded traces back to one of them having two owners, or none.

## The long form of rule 11

Moved here VERBATIM from [rules.md](../../rules.md) on 30/09/2026, when rule 11 became a
card. Nothing was cut; the card links back here.

SSOT ALWAYS: a value repeated in 2+ places becomes a `my.<domain>.<thing>` option and a consumer NEVER holds a literal. Today those are `my.theme.name`/`.palette` (colors, rule 9), `my.fonts.ui` (font, rule 10) and `my.services.<n>` (optional services). The option lives at the LOWEST level that needs it: if any module in `system/` consumes it, it is a system option and `home/` reads it through `osConfig`. The opposite does NOT exist (a system module cannot read a home-manager option). A HOT-RELOAD consumer (Quickshell/Hyprland) does not accept Nix interpolation, because the tree is a symlink: the module GENERATES a data file (JSON/Lua) that it reads, and then the only legitimate literal is the "file was missing" fallback. VALIDATE by swapping the option for a SENTINEL: rebuild, check that ALL consumers changed, revert and check that the store path came back identical.

## The former rule 9

Moved here VERBATIM from rules.md on 30/09/2026, when it was folded into rule 11.

Everything in the TokyoNight theme, centralized in a Nix PALETTE of my own (`home/desktop/palette.nix`, option `my.theme.name`), so changing themes = 1 line (presets: tokyo-night/catppuccin-mocha/gruvbox-dark). nix-colors was DISCARDED: archived (apr/2026) and a base16 of only 16 colors does not reproduce the exact hexes.

## The former rule 10

Moved here VERBATIM from rules.md on 30/09/2026, when it was folded into rule 11.

The UI FONT has its OWN SSOT, separate from the colors: `my.fonts.ui` in `system/hardware/fonts.nix` (next to the package, because a font is system level, rule 4; and fontconfig also needs the name, and a system module cannot read a home-manager option). Changing the font = 1 line + the package. A user-side consumer reads it through `osConfig.my.fonts.ui`, never as a literal.
