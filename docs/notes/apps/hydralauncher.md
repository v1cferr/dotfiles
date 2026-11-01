# hydralauncher

Modules: [`pkgs/hydralauncher/package.nix`](../../../pkgs/hydralauncher/package.nix),
[`modules/nixos/gaming/hydralauncher.nix`](../../../modules/nixos/gaming/hydralauncher.nix),
[`modules/home/apps/hydralauncher.nix`](../../../modules/home/apps/hydralauncher.nix),
[`modules/home/apps/hydralauncher/sync.py`](../../../modules/home/apps/hydralauncher/sync.py)

[Hydra](https://github.com/hydralauncher/hydra) is a game launcher with its own BitTorrent client,
an Electron app (MIT). The repo repackages the official AppImage, the same pattern as
[`stack-wallet`](crypto.md) and [`curseforge`](curseforge.md).

## Why not nixpkgs' `hydralauncher`

On 01/11/2026 the stable channel had 3.9.5 and unstable 4.1.6, while upstream was on 4.3.0. The
user wants it on the latest release, so it lives on the third layer of the version strategy:
[`hydralauncher-bump`](../../../pkgs/hydralauncher/bump.nix) runs on every `update`, see
[version bumps](../repo/version-bumps.md).

The bump costs two small requests and no download: the redirect of `/releases/latest` gives the
tag, and electron-builder's `latest-linux.yml` in that release carries the AppImage's sha512 in
base64, which is already the body of the SRI hash. The URL is versioned, so the package stays in
the `packages` check, unlike curseforge.

## Python inside the sandbox

The AppImage bundles `umu-run`, which Hydra uses to start Windows games through Proton. It is a
`#!/usr/bin/env python3` zipapp, and the AppImage FHS ships no Python, so the package adds
`python3` through `extraPkgs`.

## The torrent port is open end to end

A peer that cannot dial in only downloads from the peers it dials itself, which on a thin swarm is
most of the speed lost. Hydra's libtorrent (2.1, in `hydra-native`) listens on **5881**, TCP and
UDP, hard-coded (`DEFAULT_TORRENT_PORT` in `torrent-client.ts`) with no setting to move it. Two
places have to agree on that number:

- **The host**: [`modules/nixos/gaming/hydralauncher.nix`](../../../modules/nixos/gaming/hydralauncher.nix)
  opens it in the NixOS firewall, to everyone, since peers come from anywhere.
- **The router**: the `hydra_torrent` redirect DNATs 5881 to the desktop. The router runs no UPnP,
  so nothing opens it on the app's behalf. Measured on 01/11/2026 with a download running: 883 TCP
  and 8105 UDP packets through that DNAT, a swarm that could not reach this host before.

**IPv4 only, measured.** The desktop has a public IPv6 and a `hydra_torrent6` rule accepted 5881
into the LAN for a few hours on 01/11/2026, and its counters stayed at zero: Hydra's libtorrent
binds 5881 on each IPv4 address only (`ss -lntu`: 192.168.1.10, lo, the Docker bridges, no IPv6
socket). The rule opened a port nobody answers, so it was removed. If a release starts listening on
IPv6, the rule comes back with NO destination address: the kernel announces the swarm from its
temporary (privacy) address, which rotates, so a rule pinned to one address goes stale within a day.

[`router-ssot`](../repo/router-ssot.md) fails when the router's mirror loses the redirect or
carries another number. Rollback on the device: `uci delete firewall.hydra_torrent`, then commit
and reload.

Everything else about speed is already parallel: a torrent pulls from every peer at once, and a
direct download (gofile and friends) is split into 8 ranges by the app. Those limits are
constants in the source, not settings. Past an open port, what adds speed for free is choosing the
option with more seeders, or a direct download over a torrent on a thin swarm.

## Where the games live

Hydra installs each game through `umu-run` (UMU-Proton plus the Steam Runtime, downloaded on the
first install) into a Wine prefix of its own, `~/.config/hydralauncher/wine-prefixes/<steam id>`,
and the installed game sits inside that prefix. The repacks it downloads go to the folder set in
its settings, `~/Games/Hydra` here. That folder is pinned by the same launch sync, as the
`downloadsPath` of the `userPreferences` key: one changed in the app goes back on the next cold
start, since a download outside the subvolume would land in the snapshots and the backup.

Both are tens of GiB per game and re-obtainable, so both are out of the hourly @home snapshots
(nested subvolumes, through `my.disk.subvolumes` in the home module) and out of the backup (the
prefixes through `my.backup.exclude` in the NixOS module, the downloads with the rest of
`~/Games`). A prefix created before that is a plain directory, and the activation only warns about
it: `convert-to-subvolume` is the deliberate way, as for any other path in that list.

Why not hand the install to Bottles, considered on 01/11/2026: Hydra has no setting for another
runner, it always spawns `umu-run`. Redirecting that means a fake interpreter behind
`HYDRA_UMU_PYTHON` translating into `bottles-cli`, which trades Proton and its per-game fixes for
Bottles' runners and takes the process away from Hydra, the thing its playtime and cloud saves
watch. Bottles keeps what it already holds (Battle.net, CS2).

## The internal self-updater does not work

electron-updater swaps the AppImage file in place, and the store is read-only. Updating is
`update`/`upgrade`, like everything else.

## The download sources are declared

What Hydra lists for each game comes from download sources, JSON lists the community publishes.
The module declares them as a query on the [library.hydra.wiki](https://library.hydra.wiki/sources/)
catalog (`api.hydralibrary.com/sources?status=Trusted`, NSFW always dropped) plus an `extra` list
of loose URLs. The catalog decides what Trusted means, so a source it demotes leaves on the next
launch, the same way one removed from the module would.

Hydra keeps them in its LevelDB (`hydra-db`), under the `downloadSources` sublevel
(`!downloadSources!<id>`), and the id comes from its own API: adding a source is
`POST /download-sources {url}` and storing the answer, removing one is deleting the key. Read
from the app's source maps on 01/11/2026 (`add-download-source.ts`, `remove-download-source.ts`).
`sync.py` does exactly that, so the app sees sources it could have added itself, and on
its next start its own `/download-sources/sync` refreshes their status and game counts.

It runs from the wrapper the module puts around `hydralauncher`, before the app starts:

- **The app open** holds LevelDB's LOCK. The sync skips, and a second launch only focuses the
  running window anyway, so the next cold start catches up.
- **The catalog not answering** skips the sources, asked before the DB is opened: an empty
  answer must not read as "declare nothing" and wipe the list.
- **One source failing** to register does not keep the others out; the run exits 1 and the
  wrapper sends a notification. The app opens either way.
- **By hand**: `hydralauncher-sync`, with the app closed, prints what it added or removed.

A status of `DEAD` on a source (DODI on 01/11/2026) is the server's verdict on that JSON, not a
sync failure. The format is internal to Hydra, so a release that changes it breaks the sync
loudly (an exception, a notification), not silently.

The account's own source sync (`/profile/download-sources`) is for subscribers only, and stays
out of this: the declared list is the source of truth.

## The login scheme is declared, not registered

The `.desktop` claims `x-scheme-handler/hydralauncher`, but `~/.config/mimeapps.list` is managed
by home-manager, so the default is declared in the module instead of being left to the app.
State lives in `~/.config/hydralauncher`, listed in [`persistence.nix`](../../../modules/home/persistence.nix).
