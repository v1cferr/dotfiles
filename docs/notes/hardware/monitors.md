# The monitors' SSOT

`system/desktop/monitors.nix` is the SINGLE SOURCE of the connector NAMES (rule 11).

It was the repo's worst case of duplication: `DP-2` in 8 files and `HDMI-A-3` in 7, across Nix, Lua
and QML, so changing a monitor (or a cable) meant hunting a string through everything.

Only the NAMES live there, which is what was repeated. The mode, position and refresh stay in
`home/desktop/hypr/lua/monitors.lua`: each appears once, and they are not the SSOT of anything.

## Why in `system/` and not in `home/` (changed 04/08/2026)

A connector is a HARDWARE fact, and whoever needs it is not only the user: Sunshine, a system
service, picks WHICH monitor to capture by this name.

A system module cannot read a home option without naming the user and reaching inside
`home-manager.users.<x>`. The other direction is clean and idiomatic, because home-manager runs as
a NixOS module and hands `osConfig` ready to every home module. So the option lives on the system
side and EVERYBODY reads downward.

| Consumer | Reads |
| --- | --- |
| `system/` modules | `config.my.monitors.<n>` |
| `home/` modules | `osConfig.my.monitors.<n>` |
| hot-reload (Hyprland, Quickshell) | the data files generated in `home/desktop/monitors.nix` |

The hot-reload case exists because Nix does not write inside the symlinked trees. Same mechanics as
the palette in `home/desktop/palette.nix`.

## No `default`, on purpose (04/08/2026)

`DP-2`/`HDMI-A-3` are THIS board's connectors, and `system/` is the machine-agnostic tree. A
hardware default there is the lie that only shows up on host nº 2: the laptop would inherit
connectors it does not have, and nobody would see the error.

With no default, the module REQUIRES the host to declare it. The value lives in
`hosts/<host>/default.nix`, and a new host that forgets BREAKS at eval, loudly and early.

The roles: `primary` is at origin 0x0 with workspaces 1 to 4; `secondary` is on the left with
workspaces 5 to 8.
