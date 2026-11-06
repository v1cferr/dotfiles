# wow-addons

Module: [`modules/home/apps/wow-addons/default.nix`](../../../modules/home/apps/wow-addons/default.nix)

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
"CurseForge API Key" and synced like any other secret ([secrets](../repo/secrets.md)).

`wow-addons-key` does all of it in one go: it opens the console, reads the pasted key, writes the
Bitwarden item, adds the index line, runs `sync-secrets`, commits the index, switches and installs.
The index line waits for that run because dead-config rejects an entry with no value. Until then,
only the GitHub entries install; the CurseForge ones are skipped, not failed.

## Adding an add-on

A CurseForge add-on goes in by its NUMERIC project id (the "Project ID" on its page), never by
slug: see the pitfall below. Add it to `githubAddons` or `curseAddons`,
rebuild, and run `wow-addons` (or wait for the timer). Removing a line does NOT uninstall it:
`instawow -p forever remove <id>`.

## Pitfalls

- **Some authors forbid the API.** Leatrix Plus (94855), Baganator (914482) and Auctionator (6124)
  all have Forever files, but their projects carry `allowModDistribution: false`, so instawow
  answers "package distribution is forbidden" with a valid key. No third-party manager can fetch
  them, and none of the three publishes GitHub releases. They come from the CurseForge app, and
  instawow leaves those folders alone.

- **A personal key cannot search.** On 06/11/2026 the key answered 200 on `/games`, `/mods/{id}`
  and `POST /mods`, and 403 ("API Key missing or invalid") on `/mods/search`. instawow resolves a
  slug through that search and a numeric id through `/mods/{id}`, so slugs fail with a 403 that
  reads like a wrong key, and `instawow search` does not work either.

- **No TTY, no progress bar.** instawow's prompt_toolkit bar throws `EOFError` without a terminal.
  The install still completes, but the timer runs it under `script` to keep the journal clean.
- **A copy unpacked by hand** is "unreconciled" and instawow refuses to touch it, so the install
  passes `--replace` to adopt it.
- **The add-ons live on NTFS** (`my.games.linked`, [games-disk](../boot-and-storage/games-disk.md)).
  That is fine for Lua files, and Windows sees the same add-ons.
