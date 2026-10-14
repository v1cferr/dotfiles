# Vicinae: the launcher, the clipboard history and the command palette

`modules/home/desktop/vicinae/`. One Raycast-style window on SUPER+Q for apps, files, the
calculator, the clipboard history and my own commands.

## How it is installed

Home Manager's own `programs.vicinae` module (release-26.05) with `pkgs.unstable.vicinae`, because
26.05 ships 0.23 and the features below need 0.29. The binary comes from cache.nixos.org, so there
is no extra flake input and no extra substituter.

The unit is Home Manager's (`vicinae server`, `Restart=always`, wanted by
`graphical-session.target`), extended with the repo's session conventions: `ConditionEnvironment =
WAYLAND_DISPLAY` and `Slice = session.slice`, the same as `polkit-agent.nix`.

## Settings stay writable

`programs.vicinae.settings` is left empty on purpose: it would turn
`~/.config/vicinae/settings.json` into a read-only store link, and Vicinae writes that file from its
own settings window. The declared values go in a store JSON passed through `VICINAE_OVERRIDES` on
the unit instead. The server merges those files AFTER `settings.json` (verified in 0.29.0's
`src/server/src/config/config.cpp`), so the repo wins on every key it declares and the GUI keeps
working for the rest.

## The theme

`themes.palette` is generated from `my.theme.palette`, so a `my.theme.name` switch plus a rebuild
recolors it like every other consumer. Stylix's own Vicinae target is off: its base16 mapping has no
slot for `border`. The font is `my.fonts.ui` and the icons are `my.theme.iconTheme`.
