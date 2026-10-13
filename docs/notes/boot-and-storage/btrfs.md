# btrfs policy

`modules/nixos/hardware/btrfs.nix` is the SSOT of btrfs POLICY. The division of labor, so nobody looks in
the wrong place:

| Concern | Where |
| --- | --- |
| LAYOUT (subvolumes, mount options) | `hosts/<host>/disko.nix` |
| POLICY (scrub, alarm, reclaim) | `modules/nixos/hardware/btrfs.nix` |
| SNAPSHOTS (retention, schedule) | `modules/nixos/services/btrbk.nix` |

It is machine-agnostic on purpose (it lives in `modules/nixos/`, not in `hosts/`): everything is behind
the `is the root btrfs?` guard, so a future ext4 host simply receives none of it, instead of
breaking with a scrub unit pointing at a filesystem that has no checksums.

## Scrub

Without a scrub the checksum only reports an error when you happen to read the rotten sector,
which is to say on the day the file matters. On ext4 that did not even exist.

ONE target is enough for the NVMe: a scrub is per FILESYSTEM, not per subvolume, so `/` already
covers `@home`, `@nix`, `@persist` and `@log`, which are all the same `/dev/nvme0n1p2`.

The SECOND target is the backup disk (`my.backup.mountPoint`, `/mnt/backup`), since 13/10/2026. It
is btrfs too and holds the only other copy of the data, and the `check` after each restic run reads just 2%
of the packs, so rot there would only show up on restore day. It is included only when restic is on
AND that mount is btrfs, and the automount means the scrub's own access wakes the disk. Its alarm
says something different from the NVMe's: the live data is fine, the BACKUP copy is what is
damaged, and `restic check --read-data` tells which snapshots it touched.

The unit names are DERIVED (`utils.escapeSystemdPath`), not written by hand: the autoScrub module
names each unit with the escaped path (`/` becomes `-`, hence `btrfs-scrub--`, and `/mnt/backup`
becomes `btrfs-scrub-mnt-backup`), and its alarm is `btrfs-alert-scrub-<same>`. Deriving them
means the `onFailure` follows if a target ever changes instead of pointing at a nonexistent unit.

`btrfs scrub start -B` exits non-zero when it finds an error, correctable or not, and it is that
exit that becomes the alarm. BEFORE this, the scrub ran and failed silently, and a scrub nobody
reads is the same as a scrub turned off.

## The alarm

A checksum error is the most expensive information this filesystem produces, and the one that
least forgives delay, so it goes out through TWO channels in this order:

1. the journal (`@log`, its own subvolume), which survives nobody being logged in;
2. a critical notification (it stays on screen and does not disappear on its own) in EVERY live
   session.

Channel 2 is what you see; channel 1 is what guarantees the message existed.

The script is `my.alert` (`modules/nixos/core/alert.nix`), shared with the backup since 03/10/2026.
`runuser` plus `DBUS_SESSION_BUS_ADDRESS` because what delivers notifications here is Quickshell,
which runs in the user's session, and a system unit does not talk to it without entering the right
bus. The ABSOLUTE path of `notify-send` is used because `runuser` can rebuild the PATH when
switching users and the libnotify binary would fall out of reach. The user list comes from
`users.users`, not from a literal (rule 11), and it is expanded into a bash ARRAY rather than a
`for u in <list>` because Nix may generate a SINGLE name, and then shellcheck complains about a
loop that runs once.

## Error counters: the watchman between one scrub and the next

The scrub is monthly; an NVMe that starts failing on day 2 would go 28 days with no warning. The
counters are persistent and go up on EVERY bad I/O (read, write, flush, corruption, generation),
so checking them daily is cheap and catches the problem early. `-c` makes it exit non-zero if any
counter is different from zero.

A counter does not reset itself. After investigating, acknowledge it with
`sudo btrfs device stats -z /`, otherwise the alarm correctly repeats every day.

`LogLevelMax = "warning"` so the daily unit does not log "Starting/Finished" forever (the bb8690c
lesson).

## Automatic block group reclaim, which replaces the periodic balance

The classic btrfs footgun: it allocates block groups for data and metadata and does not give them
back when they empty, so the disk becomes "full" (ENOSPC) with free space showing in `df`. The old
recipe was a `btrfs balance -dusage=N` cron (btrfsmaintenance). Since kernel 6.11 that is a KERNEL
FEATURE, and the kernel knows something the cron does not: when relocating is NOT worth it.

- `dynamic_reclaim=1` makes the threshold stop being fixed and become computed (a target of 10
  unallocated block groups, with aggressiveness proportional to the pressure). It relocates
  ~nothing with the disk roomy, which is the case today at 49%.
- `periodic_reclaim=1` makes the cleaner thread sweep from time to time and mark the candidates.

Writing to `bg_reclaim_threshold` would be EINVAL with `dynamic_reclaim` on (they are mutually
exclusive in the kernel), which is why it is not touched.

Data and metadata only: the `system` block group is tiny and relocating it is risk with no return.
The manual escape hatch still exists: `btrfs balance start -dusage=10 /`.

The unit loops over every mounted btrfs because the `*/allocation` glob does not match
`/sys/fs/btrfs/features`, and a hardcoded UUID would be a literal duplicated from disko (rule 11).
The `|| true` is there because a kernel without the feature cannot be allowed to take the boot
down.

## TRIM: one, not two

Since kernel 6.2 btrfs turns `discard=async` on by itself on an SSD that supports it, and disko
now declares it EXPLICITLY, which is what makes turning the timer off safe (not depending on a
kernel default). Async discard IS the same operation as fstrim, only queued by btrfs as extents
are freed, with a rate limit. Keeping `fstrim.timer` alongside it means re-TRIMming in a weekly
burst ranges that were already trimmed: duplicated work, no gain.

If `discard=async` ever leaves disko, turn `services.fstrim` back on in the SAME commit.

## NOCOW on the databases

CoW plus random 8 KiB writes, which is what a database does, equals fragmentation that only gets
worse. A `+C` on the DIRECTORY makes every NEW file be born nodatacow. Applied to
`/var/lib/docker/volumes` (duo's Postgres) and `/var/lib/jellyfin/data` (the library's SQLite).

Two honest warnings:

- A file that ALREADY exists is not converted (`chattr +C` fails on a file with extents).
  Converting for real requires copying into a new directory that already has `+C` and swapping,
  which is too invasive to automate here, and the gain at these databases' current size does not
  pay for the risk.
- nodatacow also turns the CHECKSUM off for those files. A conscious trade: Postgres has its own
  checksums, and Jellyfin's SQLite is rebuildable by scanning the library again.

## `~/.cache` is its own subvolume

A snapshot stops at a subvolume boundary, so a NESTED subvolume at `~/.cache` keeps btrbk's hourly
`@home` snapshots from pinning the cache's churn for up to 4 weeks (14 GiB of nix, uv, recoll,
Spotify, Chrome and pnpm caches, MEASURED on 13/10/2026). restic already excluded it; this is the
same decision applied to the snapshots. It is the article's "subvolumes for caches" (Akita,
12/10/2026).

The tmpfiles `v` rule makes `~/.cache` be BORN a subvolume for every normal user on a fresh
install. It does nothing to a path that already exists, so an existing one is converted ONCE, by
hand, as the user (no sudo: a user can create a subvolume inside a directory it owns):

```bash
btrfs subvolume create ~/.cache.new && chmod 700 ~/.cache.new
cp -a --reflink=always ~/.cache/. ~/.cache.new/   # shares extents: instant, no extra space
mv -T ~/.cache ~/.cache.old && mv -T ~/.cache.new ~/.cache
rm -rf ~/.cache.old
stat -c %i ~/.cache                                # 256 = a subvolume root
```

Then log out and back in, so apps reopen their caches in the new subvolume. Steam stays in `@home`
on purpose: its library changes little between updates, and the games live on the Windows disk.

## Checked against Akita's article

[Akita, "always pick BTRFS, not EXT4"](https://akitaonrails.com/2026/10/12/usuarios-linux-sempre-escolham-btrfs-nao-ext4/)
(12/10/2026), item by item, audited on 13/10/2026:

| The article recommends | Here |
| --- | --- |
| `compress=zstd:1` | every subvolume but `@swap`, from disko's `btrfsOptions`; MEASURED below |
| a monthly scrub, watch `device stats` | the NVMe AND the backup disk, plus a daily `device stats -c`, both with the alarm |
| metadata DUP on a single disk | yes: `Metadata, DUP` and `System, DUP` (the mkfs default) |
| balance only when unallocated runs low | better: the kernel's dynamic plus periodic reclaim does exactly that |
| `chattr +C` before VM images and databases | Docker volumes, Jellyfin's SQLite, libvirt images |
| snapshots with automatic retention | btrbk on `@home`, hourly `onchange`, `48h 7d 4w` ([btrbk](btrbk.md)) |
| subvolumes to keep caches out of snapshots | `~/.cache`, above |
| restic, with databases dumped first | yes, to the backup disk ([restic](restic.md)) |
| reflinks and offline dedup | `cp` reflinks by default (coreutils 9+); `nix.optimise` dedups the store |

`sudo compsize -x /home /nix`, MEASURED on 13/10/2026: 253 GiB of data take 182 GiB on disk, so
**28% (71 GiB) saved**, above the article's 15%. The zstd part alone goes from 101 GiB to 30 GiB
(30%); the other 151 GiB are stored raw because btrfs gave up on them as incompressible (media,
already-compressed archives), which is the heuristic doing its job, not a missed saving.

Left out on purpose:

- **Snapshots of `/`** (snapper, Timeshift): the NixOS generation list already is the system
  rollback, and a snapshot of `@` would not even include `@nix` ([btrbk](btrbk.md#home-only)).
- **bees or duperemove**: CPU and RAM around the clock for what `nix.optimise` already does on the
  only place with real duplication.
- **qgroups**: their accounting slows snapshot deletion and balance; `btrfs filesystem du` answers
  the same question on demand ([disk-insight](disk-insight.md)).
