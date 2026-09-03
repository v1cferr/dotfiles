# The games disk: one install, two systems

`hosts/nixos-kingston/default.nix` mounts it, `home/apps/games-disk.nix` links into it.

## The problem it solves

The games were installed TWICE. MEASURED on 31/08/2026, 135 GiB of the Kingston was a byte-for-byte
duplicate of what was already sitting in the SanDisk's `C:\Games`, left over from a migration that
copied and then never deleted, because "validate on the Windows side first" never happened.

Paying for a game on both disks is the worst of both: the NVMe loses the space AND the two copies
drift apart, which is exactly what Overwatch did (68.9 GiB of it differs between the two).

So the rule is ONE install, on the disk both systems can reach.

## Why the SanDisk and not the Seagate

The Seagate looks like the obvious "other disk" because it is the one already mounted, and it is
wrong on three counts at once: it is an **HDD** (`/sys/block/sdb/queue/rotational` is 1), it has
194 GiB free against ~370 GiB of games, and it is where the restic backup lands.

The SanDisk is the only SATA **SSD** in the machine, and it is Windows' `C:`. That last part is not
a drawback here, it is the entire point: a game on `C:\Games` is reachable from Windows without any
translation.

## The two reasons this disk used to be unmounted, and what answers them

The host config said, correctly at the time, that mounting `C:` "invites NTFS writes with
fast-startup pending plus restic sweeping 900 GB".

**restic never applied.** Its `paths` is `/home/v1cferr` and nothing else
([restic.md](restic.md)), so a mount under `/mnt` was out of scope from the start. That half of the
worry was already structurally false.

**Fast startup is real, and the answer is an option that is ABSENT.** ntfs3 refuses a read-write
mount of a volume with the dirty flag set unless `force` is passed. So the mount simply carries no
`force`, and a Windows hybrid shutdown makes `/mnt/windows` FAIL to mount; `nofail` turns that into
a boot that carries on and a game that will not launch. Loud and harmless, instead of quiet and
half-written.

> Never add `force` to make that error go away. It mounts read-write with NO consistency check over
> a volume Windows believes it still owns. The fix is on the Windows side: `powercfg /h off`, or
> `chkdsk` if it is already dirty.

MEASURED on 03/09 before the first read-write mount: `hiberfil.sys` existed at 6.8 GiB with an
all-zero signature, so there was no pending image and the volume was clean. The 6.8 GiB is ~42% of
this machine's 16 GiB of RAM, which is the REDUCED hiberfile Windows allocates for fast startup
without full hibernation, so the feature is most likely still enabled and the mount can start
failing after any Windows session.

## The other mount options

- `uid=1000,gid=100`: NTFS has no unix owner, so ownership is assigned at mount time or everything
  belongs to root and the launcher cannot write a patch.
- `windows_names`: refuses to CREATE a name Windows could not open. On a disk whose whole purpose
  is being read by both systems, a file only Linux can see is a bug waiting to be reported as
  "the game is corrupted on Windows".
- `noatime`: an atime write per file read, on a disk that holds nothing but games. Same reasoning
  as everywhere else in this repo, and here it is not even a trade-off.

## Why symlinks, and why AT THE OLD PATH

`home/apps/games-disk.nix` maps a path under `$HOME` to a path under `/mnt/windows/Games` and
declares it with `mkOutOfStoreSymlink`. Out-of-store because the target is MUTABLE data the
launcher patches in place: copying 89 GiB into the nix store would be absurd and read-only.

The symlink deliberately sits where the launcher ALREADY looks, instead of relocating the game:

- **Battle.net** keeps believing Diablo IV is in `C:\Program Files (x86)\Diablo IV`. The two systems
  do NOT share a Battle.net config, only the files, so making the paths match across systems buys
  nothing and would cost a "locate the installation" round through the UI.
- **RPCS3** keeps its `~/.config/rpcs3/games.yml` untouched for the same reason.
- Bottles needs no change at all: the registered program is `Battle.net.exe`, which stays in the
  prefix. Only the game data leaves.

## What was verified before deleting anything

A copy is not a duplicate until it is proven to be one, and `du -sh` matching is not proof.

| Game | Method | Result |
| --- | --- | --- |
| Diablo IV | every file compared by relative path and size | 1183 files, **zero** size mismatches |
| Uncharted 3 | full sha256 of the 46 GiB ISO on both disks | `9c600ebb…04b2`, **identical** |
| Overwatch | same file-by-file comparison | **76 files differ, 68.9 GiB.** NOT a duplicate |

Diablo IV's only differences were CASC indices (`.index` here, `.idx` there), which are local
metadata the Battle.net agent rebuilds. The ISO got a full hash rather than a size check because it
is a single file with no launcher to repair it, and the SanDisk is a budget SSD where silent
corruption would look exactly like a size match.

**Overwatch is the reason this table exists.** It would have passed a `du -sh` eyeball, 74 GiB
against 76, and deleting the local copy would have thrown away the NEWER build.

### The four that were copied, not deduplicated

Overwatch, Hearthstone, Cities Skylines II and the Ascension launcher had no counterpart on the
Windows disk, or a stale one. They went over with `rsync -rt --no-perms --no-owner --no-group`
(NTFS has no unix ownership, and asking rsync to set it only produces errors) and `--delete`, so
Overwatch's outdated copy became a faithful replica instead of a merge of two builds.

Each was then re-checked by path and size, not by total, for exactly the reason the table above
gives. All four came back with zero differences across 24425 files.

Only the GAME folder moved, never the bottle. A Wine prefix does not survive on NTFS (no unix
permissions, no symlinks, no case sensitivity) and does not need to: afterwards the three prefixes
together weigh **8.4 GiB, down from 225**.

## The trap: deleting does not free the space, the snapshots still hold it

MEASURED on 03/09, right after removing 135 GiB from `@home`: `df` did not move by a single GiB.
All **59** btrbk snapshots still contained both games, because they had existed continuously up to
the moment of the deletion, and a snapshot holding an extent keeps that extent alive.

This is not a btrbk bug and there is nothing to fix in it. 59 is the exact steady state of
`snapshot_preserve = "48h 7d 4w"` (48 hourly + 7 daily + 4 weekly), working as designed.

What it changes is the TIMELINE, and this is worth planning around before moving the rest:

- The space comes back GRADUALLY, as each snapshot ages out of the retention window. The oldest
  here was from 02/08, so full reclaim lands about four weeks after the deletion.
- Expiring the snapshots by hand returns it immediately and costs the undo window for everything
  else in `$HOME`, which is the whole reason btrbk exists ([btrbk.md](btrbk.md)).
- It is a ONE-TIME cost per game. Once a game lives on the NTFS disk it is outside `@home`
  entirely, so it never enters another snapshot, and patching it stops churning them.

MEASURED after purging all 59 and letting the cleaner settle: **659 GiB used became 196**, so
463 GiB came back against the 351 the games weigh. The extra ~112 GiB was snapshot-exclusive data
unrelated to the games, a month of `@home` churn that only those snapshots still held. That is what
the `48h 7d 4w` retention costs in the steady state, and it is invisible to any `du` of the live
tree.

The space also arrives GRADUALLY. `btrfs subvolume delete` prints `(no-commit)` and hands the
extents to the cleaner thread, so the `df` immediately after the purge still read 659 GiB and
looked like the purge had failed.

The structural alternative, had the games been staying on the Kingston, would have been making the
games directory its OWN subvolume: btrbk snapshots subvolumes, and a snapshot does not descend into
a nested one. It is moot here precisely because the destination is another disk.

## Known gap: nothing watches the games disk filling up

`disk-hygiene.nix` alarms on `/` only, and `watchPaths` is deliberately NOT extended with
`/mnt/windows/Games`: that list explains why the ROOT filesystem is full, and 250 GiB of NTFS in it
would be an answer to a question nobody asked.

The games disk is covered by the trend log and by `disk-report` (through `usagePaths`), but there
is no alarm on it. With ~249 GiB free after the full migration that is not urgent, and the honest
statement is that it is a gap and not a decision.

## The monitoring has to point at the REAL path

`disk-insight.nix` lists the moved games at `/mnt/windows/Games/...` and not at the `$HOME` symlink.
The sampler resolves with `readlink -f`, so a process launched through the symlink reports the NTFS
path; leaving the old path in `usagePaths` would match nothing, forever, and look like a game
nobody plays.
