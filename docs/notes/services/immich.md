# Immich, the photo library

`modules/nixos/services/immich.nix`, served at `photos.v1cferr.dev`. A self-hosted photo library: a
timeline, face recognition and text search over the photos ("beach", "dog"), with the machine
learning running on this machine.

## The role: an archive, NOT a Google Photos replacement

Google Photos stays the primary: it keeps backing up the phone. Immich is where photos go to LEAVE
it, so they stop costing phone storage and the free 15 GB of the Google account. The flow, when the
quota gets close:

1. Export the oldest photos with Google Takeout.
2. Import them with [`immich-go`](https://github.com/simulot/immich-go), which reads Takeout's
   `.json` sidecars, so dates, places and albums survive.
3. Check the counts in Immich, and only then delete them from Google Photos.

So the phone app's background backup is NOT used here. It stays optional, for browsing.

## Why Immich

Compared on 28/09/2026 against Ente and PhotoPrism. Immich is the only one that has all of these at
once: a native Android app with background backup, server-side ML, and an official NixOS module. Ente
wins only if end-to-end encryption is mandatory. PhotoPrism has no phone backup at all, only a PWA.

## The package comes from unstable

Stable (26.05) carries Immich 2.7.5, which nixpkgs marks INSECURE and refuses to evaluate: the 2.x
line is end of life, with CVE-2026-59258 and CVE-2026-82272 open. 3.x ships only from 26.11, so the
package is `pkgs.unstable.immich` (3.2.2 on 28/09/2026). The stable MODULE runs it unchanged: the
diff against unstable's module is a postgres client option and a comment. On the 26.11 upgrade the
`package` line goes.

## Layout

| Path | Owner | What |
| --- | --- | --- |
| `/srv/photos/immich` | `immich`, `0700` | uploads, thumbnails, encoded video; Immich's own state |
| `/srv/photos/archive` | `v1cferr:immich`, `2750` | an EXTERNAL library: files I copy in, Immich only reads |

**Not under `/home`**: the unit runs with `ProtectHome`, so `~/Pictures` does not exist for it.

**The archive's group is `immich` itself, not a shared `photos` group.** The unit also runs with
`PrivateUsers`, which maps every group except the service's own to `nobody` inside the sandbox. A
shared group would show up there as no access at all, with no error to point at it.

The external library is Immich state, not config (rule 6): it is added once in the web UI,
Administration, External Libraries, with the import path `/srv/photos/archive`.

## Postgres listens on sockets only

The module turns on the NATIVE `services.postgresql` (with VectorChord), and `duo-db` (Docker)
already holds `127.0.0.1:5432`. Postgres would die on the port conflict at boot. Immich talks over
`/run/postgresql` anyway, so `listen_addresses = ""` removes the conflict at no cost.

## It listens on 127.0.0.1, not "localhost"

The module's default `host` is `"localhost"`, which here resolved to `[::1]` ONLY. `my.ingress`
proxies to `127.0.0.1`, so the first boot answered 502 through Caddy with every unit active and
nothing in the logs. `host = "127.0.0.1"` matches the ingress contract.

## `settings` stays null

A non-null `services.immich.settings` writes a config file, and Immich then makes the WHOLE admin
panel read-only. So the settings live in the UI, like Jellyfin's libraries. The external domain
(`https://photos.v1cferr.dev`, used for share links) is set there, in Server Settings.

## Reach

`public`, the same criterion as Jellyfin: Immich has its own login, and the archive stays viewable
from the phone outside the house without bringing the WireGuard tunnel up.

## It is NOT a backup

`/srv` is not in btrbk and the daily restic stopped on 24/09/2026, so a photo that exists only here
has ONE copy, on one NVMe. That is the WHOLE point of the archive role, so it cuts the other way
too: a photo deleted from Google after step 3 exists only here. It needs a second copy on another
disk before the Google copy goes.
