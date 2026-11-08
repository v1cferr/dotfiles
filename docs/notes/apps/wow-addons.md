# wow-addons

Modules: [`pkgs/wow-addons/`](../../../pkgs/wow-addons/package.nix),
[`modules/home/apps/wow-addons/default.nix`](../../../modules/home/apps/wow-addons/default.nix)

Every WoW Forever add-on is a pinned zip in
[`sources.json`](../../../pkgs/wow-addons/sources.json), the single list of what is installed.
The package unpacks them into one tree, and every switch copies that tree into
`_forever_/Interface/AddOns`. `update` (and so `upgrade`) moves each one to its latest STABLE
Forever release through the vendored-bump runner ([version-bumps](../repo/version-bumps.md)).

## Why Nix and not an add-on manager

Tried on 06/11/2026, in this order:

- **instawow** works for GitHub and CurseForge, but its state lives in its own database and it
  cannot fetch an add-on whose author disabled API distribution. Leatrix Plus, Baganator,
  Auctionator and DBM all did.
- **The CurseForge app** can fetch everything, but its list is GUI state, not the repo.
- **[nix-warcraft](https://github.com/raccube/nix-warcraft)** has the right idea (pinned zips, a
  Home Manager module) but targets Retail through its own Proton wrapper, and packages none of
  Questie, Layer-Swap, Leatrix Plus or Auctionator. This package borrows its CDN approach.

## What "latest stable Forever" means

For CurseForge, the bump asks `/v1/mods/{id}/files?gameVersionTypeId=88568` (88568 is "WoW
Forever") and takes the newest file with `releaseType == 1`, so alphas and betas never land. The
pinned version is the FILE id. For GitHub it takes `/releases/latest` and its zip asset. Questie,
DBM and DBM-Vanilla come from GitHub because their official releases are there.

The one exception is an entry with `"channel": "beta"`: it takes the newest file with
`releaseType <= 2`, stable or beta. Offhand needs it because it has never shipped a stable file.
Every other entry stays on stable only.

## The CurseForge CDN decision

Authors can set `allowModDistribution: false`, and then the API answers `downloadUrl: null`. The
file is still public on the CDN at `edge.forgecdn.net/files/<id/1000>/<id%1000>/<fileName>`, and the
bump builds that URL. It goes against those authors' opt-out (they lose the download credit), and
the user chose it knowingly on 06/11/2026 to keep one source for every add-on.

## Folders with no Forever TOC are dropped

Upstream ships ONE zip for every flavour, so DBM brings its Midnight raid modules, which the game lists as incompatible. The build keeps a folder only if its TOC
declares Forever: interface `160xx`, a `_Forever`/`_Camelot` TOC, or `AllowLoadGameType`. Pawn's TOC
starts with a UTF-8 BOM, which is why the match allows `EF BB BF` before `##`. Two zips that ship
the same folder fail the build instead of overwriting each other.

## How it reaches the game

`home.activation.wowAddons` rsyncs each folder into the AddOns directory. Copies, not store
symlinks: the folder is on NTFS (`my.games.linked`, [games-disk](../boot-and-storage/games-disk.md))
and Windows plays from it too. `~/.local/state/wow-addons/managed` remembers what the last switch
put there, so an add-on that leaves the list is deleted, and folders Nix never managed stay.

## The CurseForge key

The bump needs a personal key from <https://console.curseforge.com>, read from
`/run/secrets/curseforge_api_key` ([secrets](../repo/secrets.md)). `wow-addons-key` sets it in one
go: Bitwarden item, index line, `sync-secrets`, switch, bump, switch. Without the key the bump keeps
the CurseForge pins and warns; the GitHub ones still move.

## Adding an add-on

Add `"<name>": { "source": "curseforge", "projectId": N, "version": "0", "url": "", "hash": "" }`
(or `"source": "github", "repo": "owner/repo"`) to `sources.json`, run `update`, then `rebuild`.
The project id is on the add-on's CurseForge page, under Details.

A repo that ships several things takes `"tagPrefix"`: the bump lists that line's TAGS
(`/git/matching-refs/tags/<prefix>`), highest version first, and pins the first stable release
among them. Tags and not the releases list, because spoken-wow publishes one release per build and
its October voice packs had already fallen past the first 100 releases.

## Spoken in pt-BR

The client runs in pt-BR, and Spoken's pt-BR quest, zone and book voices exist only as GitHub
releases of `rusty-key/spoken-wow` (CurseForge carries the English ones). No English pack is
installed on purpose: a line with no pt-BR voice stays a subtitle instead of switching language.
DialogueUI is the NPC dialogue of choice because Spoken has a narrator style made for it.

## Pitfalls

- **The first key was wrong** and every call answered 403. A valid personal key answers `/mods/search`
  too, so a 403 there means the key, not a missing permission.
- **`nix store prefetch-file` rejects `!`** in the name it derives from the URL
  (`!BugGrabber-v12.1.1.zip`), so the bump passes `--name`.
- **GitHub allows 60 anonymous API calls an hour**, and a tag line costs one call per tag: adding
  the three Spoken pt-BR lines ran it dry (403) on 06/11/2026. The bump now sends the `gh` login's
  token when there is one (`GITHUB_TOKEN` wins), which lifts the limit to 5000.
- **Mastercraft overlaps three add-ons.** It sells grey junk, fishes and records gathering nodes.
  Angleur and GatherMate2 were dropped for it on 08/11/2026. Dejunk stays, because Mastercraft
  never destroys an item and has no price threshold or lists, so its own `autoJunk` is off.
- **`/reload` is enough.** Tested on 06/11/2026 with the game open: a switch, then `/reload`,
  picked up NEW add-on folders too, not just changed files. No client restart needed.
- **Required dependencies are checked at build**, from the TOC the Forever client loads. Run-time
  ones are not: Baganator declared Syndicator OPTIONAL and still raised a Lua error without it.
  After adding an add-on, `/reload` and read `WTF/Account/<id>/SavedVariables/!BugGrabber.lua`.
- **Bagnon tainted Blizzard's own code** on 06/11/2026: with it loaded, opening Options threw
  dozens of `attempt to compare a secret number value (execution tainted by 'Bagnon')` in
  Blizzard_NamePlates, Blizzard_CombatText and Blizzard_TextStatusBar (Midnight's secret values,
  which Forever inherits). Back to Baganator, this time WITH Syndicator, its run-time dependency.
- **The "Fatality" shout is BugSack's error sound**, not a game event.
- **Social Diary 2.3.0** errors in `UI/Style/Widgets.lua:152` when a tooltip line list comes back
  EMPTY (`unpack(list[1])` on nil): its own guard only covers nil. Upstream bug, harmless (one
  tooltip does not show).
- **Offhand** (dual-monitor UI) is beta only and has two parts. Only the add-on is installed. The
  Companion is a Windows exe that the upstream Linux guide calls experimental under Wine. Its guide
  also lists mixed orientation and negative coordinates (the portrait LG at `-1080x-240`) as a
  future goal. The window spanning both screens is tested by hand first: Windowed mode, a floating
  WoW window in Hyprland, then `/offhand guide`. A Hyprland window rule comes only if that works.
