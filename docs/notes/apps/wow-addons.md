# wow-addons

Module: [`modules/home/apps/wow-addons.nix`](../../../modules/home/apps/wow-addons.nix)

The WoW Forever add-ons are a list in the module. `wow-addons` installs whatever is missing and
updates the rest, and a daily `--user` timer runs it. Nothing is clicked in a GUI.

## Why instawow

It is a CLI, it is in nixpkgs, and it reads GitHub releases and CurseForge. The CurseForge app
and WowUp are GUIs whose add-on list lives in their own state, not in the repo.

The Forever flavour (`forever_classic`) exists since 7.2.x. Version 7.3.0 (23/10/2026) only taught
it to RECOGNISE the `_forever_` folder, so the profile forces the flavour instead of waiting for
nixpkgs. Stable 26.05 ships 7.0.0, which predates the flavour, hence `pkgs.unstable`.

Flavour matching is the compatibility check: instawow only picks a file whose TOC declares the
Forever interface (16001, or a `_Camelot`/`_Forever` TOC suffix).

## The CurseForge key

CurseForge's API needs a key, and instawow ships none on purpose (its README explains why). It is a
personal key from <https://console.curseforge.com>, stored as the Bitwarden item
"CurseForge API Key". Then `"curseforge_api_key": "CurseForge API Key"` goes into
`secrets/bitwarden-secrets.json`, followed by `sync-secrets` and a rebuild
([secrets](../repo/secrets.md)). The index line waits for the item because dead-config rejects an
entry with no value. Until then, only the GitHub entries install; the CurseForge ones are skipped,
not failed.

## Adding an add-on

Find its id with `instawow -p forever search <name>`, add it to `githubAddons` or `curseAddons`,
rebuild, and run `wow-addons` (or wait for the timer). Removing a line does NOT uninstall it:
`instawow -p forever remove <id>`.

## Pitfalls

- **No TTY, no progress bar.** instawow's prompt_toolkit bar throws `EOFError` without a terminal.
  The install still completes, but the timer runs it under `script` to keep the journal clean.
- **A copy unpacked by hand** is "unreconciled" and instawow refuses to touch it, so the install
  passes `--replace` to adopt it.
- **The add-ons live on NTFS** (`my.games.linked`, [games-disk](../boot-and-storage/games-disk.md)).
  That is fine for Lua files, and Windows sees the same add-ons.
