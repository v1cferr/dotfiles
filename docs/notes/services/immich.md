# Immich, the photo library

`system/services/immich.nix`, served at `photos.v1cferr.dev`. A self-hosted Google Photos: a
timeline, face recognition, text search over the photos ("beach", "dog") and a phone app that
backs up in the background. All of it runs on this machine, the machine learning included.

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

## `settings` stays null

A non-null `services.immich.settings` writes a config file, and Immich then makes the WHOLE admin
panel read-only. So the settings live in the UI, like Jellyfin's libraries. The external domain
(`https://photos.v1cferr.dev`, used for share links) is set there, in Server Settings.

## Reach

`public`, the same criterion as Jellyfin: Immich has its own login, and the phone app has to reach
the server from outside the house for backup to work. Under `lan`, backup would depend on the
WireGuard tunnel being up.

## It is NOT a backup

`/srv` is not in btrbk and the daily restic stopped on 24/09/2026, so a photo that exists only here
has ONE copy, on one NVMe. Do not delete a photo from the phone on the strength of Immich alone.
