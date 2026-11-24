# Power loss: what survives a cut, and the report after one

`modules/nixos/hardware/power-loss.nix`. The desk has no UPS yet, so a knocked cable or a power
outage cuts it with no shutdown at all. This page is what each layer does about it, the alarm
that says what recovered, and the checklist after one.

## The 2026-11-24 cut, layer by layer

A knocked power strip at 13:43:52. The journal stops mid Chromium activity and `last -x` says
`crash`. The 13:45 boot recovered with no help:

| Layer                | What the boot log showed                                  | Verdict                            |
| -------------------- | --------------------------------------------------------- | ---------------------------------- |
| btrfs root           | `start tree-log replay`, then a normal mount              | OK: CoW plus the log tree held     |
| ESP (vfat, `/boot`)  | fsck cleared the dirty bit; boot sector differs at 65     | Harmless (offset 65 is that flag)  |
| journald             | `system.journal corrupted or uncleanly shut down`         | Rotated; up to 5 min never synced  |
| PostgreSQL           | `automatic recovery in progress`, WAL redo, checkpoint    | OK: that is what the WAL is for    |
| ntfs3 (Windows disk) | `Correct links count -> 2` on one inode                   | Run chkdsk from Windows            |
| systemd units        | none failed                                               | OK                                 |

Nothing was lost that a backup had to bring back. What a cut CAN take: unsaved editor buffers,
the last seconds of writes still in the page cache, and the open Chromium session state.

## What already protects each layer

- **btrfs** never overwrites live data (CoW) and replays its log tree on the next mount, so the
  FS is consistent after a cut. Write barriers stay on (the default; turning them off is how a
  cut corrupts btrfs). The monthly scrub and the daily `device stats` alarm
  ([btrfs](../boot-and-storage/btrfs.md)) catch damage a cut could leave behind.
- **Snapshots and backup**: btrbk every hour on `/home` ([btrbk](../boot-and-storage/btrbk.md))
  and restic to the Seagate every night ([restic](../boot-and-storage/restic.md)).
- **Postgres** replays its WAL. Never turn off `fsync` or `full_page_writes` for speed.
- **ntfs3** refuses a dirty volume, and `windows-disk-clear-dirty` only clears a flag
  `ntfs-3g.probe` calls safe ([games-disk](../boot-and-storage/games-disk.md)). ntfs3 fixes
  little things itself, but only Windows' chkdsk really checks NTFS.
- **journald** syncs every minute (`SyncIntervalSec=1m` in `modules/nixos/core/core.nix`, the
  default is 5 min), so a cut loses at most the last minute of log.
- **VS Code** saves a second after each edit (`files.autoSave`). `hotExit` alone only covers a
  window closed on purpose.

## The report

A marker file tells a clean shutdown from a cut:

1. `power-loss-marker.service` runs early in every boot. If `/var/lib/power-loss/running` is
   still there, the last boot never reached its clean stop, so it copies the marker to
   `pending`. Then it writes a new marker.
2. Its `ExecStop` deletes the marker. systemd only runs it on a real shutdown or reboot, so a
   cut leaves the marker behind. That is more reliable than parsing `last`.
3. `power-loss-report.timer` fires 5 minutes into the boot. By then every recovery has run (a
   container Postgres took 2 minutes on 24/11) and the autologin session can get the bubble.
   When `pending` exists it collects the evidence, writes `/var/lib/power-loss/last-report` and
   sends one `my.alert`.

What it collects: when the previous boot last logged, a btrfs log replay and any btrfs error,
ntfs3 corrections, the ESP fsck, Postgres crash recoveries (native and in containers, they all
log to the journal), failed units, and the NVMe `Unsafe Shutdowns` counter. The report keeps that
counter on every boot, so the alarm shows how much THIS incident added. If the counter grows on
CLEAN boots too, the drive is being cut at shutdown, and that is worth investigating on its own.

The first boot after the module lands has no marker, so it reports nothing.

To read the last report: `sudo cat /var/lib/power-loss/last-report`.

## After a cut: the checklist

1. Read the alarm. If everything says clean or OK, stop here.
2. Any btrfs error: `sudo btrfs device stats /` and `sudo btrfs scrub start -B /`.
3. Any ntfs3 correction: boot Windows and run `chkdsk D: /f` (the games disk) before trusting
   the disk again.
4. Any failed unit: `systemctl status <unit>`. A container whose volume is NOCOW
   (`/var/lib/docker/volumes`) has no btrfs checksums, so its own recovery is the only check.
5. Confirm the backup is fresh: `systemctl status backup-staleness`.
