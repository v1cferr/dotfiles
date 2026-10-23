# darling-lol: League through Darling

`modules/home/apps/darling-lol.nix`, input `darling-lol` in `flake.nix`. Upstream:
<https://github.com/lucannez64/darling-lol>. The window rules are in
[hypr](../desktop/hypr.md#window-rules), the bar pill in [bar](../desktop/bar.md).

## Why it is here

League on Windows needs Vanguard, a kernel anti-cheat that no Linux layer runs. The macOS client
does not ship it, and darling-lol runs that client through Darling, a Darwin compatibility layer,
with patches to Metal, AppKit, CoreAudio and the server. The game binary is native x86-64 code
that Darling loads, so it is not emulated.

Measured on this desk (23/10/2026, Arc B580, 2560x1440, Metal): about 175 fps in the first ARAM,
with dips to 125 to 145. Upstream's own numbers are 118 to 135 on an RX 6600.

## The ban risk, and why it was accepted

Running the client in a modified environment breaks Riot's terms. Upstream's README reported
3-day "UNSUPPORTED_THIRD_PARTY_TOOLS" suspensions in October 2026 and expects permanent bans.
It is only ever used with a TEST account, never the main one, never ranked.

## The namespace, and why it is a unit

Rootless Darling lives in a user namespace, and the `darling-lol` launcher is the only process
that can shut it down safely ([`nix-lifecycle.py`](https://github.com/lucannez64/darling-lol/blob/main/scripts/nix-lifecycle.py) upstream). A terminal hangup sends it
SIGHUP and it stops Darling, game included. So the session starts it as `darling-lol.service`:

- `KillMode=mixed`: SIGTERM reaches the launcher only, which shuts Darling down from inside the
  namespace. The default would kill every guest process at once.
- No `WantedBy`: it starts on demand, from the menu entry (which replaces upstream's, same id and
  no terminal) or from the bar pill.
- It stays up while a client does, and stops by itself once none is left. Upstream has no way to
  reopen a window into a live namespace, so "reopen" is a restart of the unit (the bar pill).
- `RCLOL_REGION`/`RCLOL_LOCALE`: the installer region is not remembered, and the launcher
  defaults to EUW.

First setup and updates still need a terminal (`darling-lol --installer`), with the unit stopped.

## Why the input does not follow nixpkgs

Upstream keys the runtime's readiness on the package's store path (`DARLING_PACKAGE_ID`). With
`follows`, the path changes and the launcher asks for the 40 to 50 GB Darling rebuild again.
Without it, the derivation is the one `nix run` built from a checkout of the same revision
(`gaik185j...-darling-lol-0.1.0`, verified 23/10/2026). A bump of the lock IS a rebuild: do it
from a terminal, never as part of a routine update.

## State

The prefix (`~/.darling`, the game in `Applications/League of Legends.app`) and the workspace
(`~/.local/share/darling-lol`) are state (rule 6): nothing here declares them. The Windows key
bindings live in `/mnt/windows/Riot Games/League of Legends/Config` (`PersistedSettings.json`);
copying them into the bundle's `Contents/LoL/Config` is a one-off, and the account's cloud copy can
overwrite it on login.
