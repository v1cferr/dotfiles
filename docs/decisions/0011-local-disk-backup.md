# 0011. The backup goes to a local disk first

The daily restic comes back aimed at a local disk, which covers a dead NVMe and leaves theft, fire and
surge to an offsite copy that is still open.

- **Status**: accepted; supersedes the "no destination" half of [0008](0008-no-offsite-backup-yet.md)
- **Date**: 03/10/2026

## Context

[0008](0008-no-offsite-backup-yet.md) compared three destinations on 30/09/2026 and picked none.
Meanwhile the repo already rebuilt the config and the secrets on new hardware, and the one thing a
reinstall could not bring back was the state rule 6 keeps out of git: `~`, the photos, the
databases, and the identity keys (Secure Boot, SSH host keys, Wi-Fi profiles, Bluetooth pairings).

## Decision

A local disk, formatted btrfs with the label `BACKUP`, holding a restic repo. FOR NOW that disk is
the internal Seagate, reformatted for the job after its SMART read on 03/10/2026 showed clean media
and worn mechanics ([disk health](../notes/hardware/smart.md)); a new disk replaces it by
2026-12-31, the same review as the offsite half.

- **Why local first**: the most likely loss on this desk is the NVMe itself, and a local restore of
  ~100 GiB does not wait on a 100 Mb/s link. It costs the disk once and nothing a month.
- **Why restic and not btrbk `send`**: restic encrypts (the disks are not encrypted,
  [0006](0006-no-disk-encryption.md), so a stolen backup disk would otherwise be a stolen `~`), it
  dedups across `~`, `/srv` and `/var`, and the same repo format moves to an offsite target later
  with `restic copy`.
- **Same password as the old repo** (`restic_password`): already in Bitwarden, so no new secret.
- **Databases as logical dumps**, taken before each snapshot, never as a copy of a hot volume.
  Immich keeps its own dumps (upstream's restore path).

## Consequences

- A dead NVMe now restores in a handful of commands, the identity keys included, so Secure Boot
  re-enrolls the SAME keys instead of new ones.
- **Theft, fire or surge still take everything**: the disk sits inside the same case. The offsite
  half of [0008](0008-no-offsite-backup-yet.md) stays an accepted risk until its review on
  2026-12-31, and the cheapest close is a second restic repo (`restic copy`) on a Hetzner Storage
  Box or B2.
- `/srv/media` (168 GiB MEASURED on 03/10/2026) is out: it is re-downloadable, and it would more
  than double the repo.
- Until the disk is bought the module is built but off (`my.services.restic = false`).
