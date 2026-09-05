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

## The game that was never duplicated, and the save that came back with it

Black Flag Resynced is absent from the table above because it was never a duplicate: the repack
installed it straight into `/mnt/windows/Games` on 25/08 and the Kingston has never held a copy of
its 67 GiB. All it needed on this side was a bottle, and the work turned out not to be the game.

`Black-Flag` is its OWN prefix and not the Battle.net one because it is a DX12 game, so it needs
vkd3d-proton where the others need only DXVK. Nothing had to be installed into it: a GE-Proton
prefix already carries `vcruntime140` and `msvcp140`, so the `VC_redist.x64.exe` the repack bundles
never ran. MEASURED on the first launch, 10287 pipelines compiled; the second created 11. The
`NVStreamline` DLLs in the folder are dead weight here, since the GPU is an Arc: XeSS is the
upscaler that works and DLSS is not.

### The save transfers with no patching, because the identity is in the SHARED folder

The repack authenticates through a Ubisoft Connect emulator whose config, `upc_r2.ini`, sits next
to the exe, which is on the disk both systems read. The `UserId` is therefore the same on Windows
and here BY CONSTRUCTION, and nothing in the save has to be rewritten. The only thing that differs
between the two systems is where `%APPDATA%` points.

| What | Where it goes in the prefix |
| --- | --- |
| the 12 save blobs | `drive_c/users/steamuser/AppData/Roaming/Goldberg UplayEmu Saves/66088/` |
| manifest and journal | `drive_c/users/steamuser/AppData/Local/Ubisoft/<game>/save/` |
| language and graphics | `drive_c/users/steamuser/Documents/<game>/ACBlackFlag.ini` |

**`steamuser`, never `v1cferr`.** A GE-Proton prefix has no user named after the account, so a copy
into `drive_c/users/v1cferr` lands in a directory the game will never open, and it looks exactly
like a save that did not survive.

The manifest is not optional either. The game keeps its own save-storage layer
(`SaveStorageManifest-05AC24EB-UPC.json` plus a journal), and blobs without it leave that layer
disagreeing with what is on disk.

The `.ini` came over for a reason that will not generalize to another machine:
`AdapterVendorID=32902` and `AdapterDeviceID=57867` are `0x8086` and `0xE20B`, this same Arc B580.
The Windows session was tuned on the SAME GPU, so the quality profile transfers 1:1.

### The save stays in $HOME, and that is what costs the shared progress

Restic's `paths` is `/home/v1cferr` ([restic.md](restic.md)), so a save inside the prefix is backed
up and a save on `/mnt/windows` is not. Pointing the prefix at the Windows save with a symlink would
have given the two systems ONE progress, which is what this disk already does for the game data. It
was rejected on 05/09 for two reasons: the save would leave restic's reach, and a `/mnt/windows`
that fails to mount (by design, after a Windows hybrid shutdown) would leave the game with nowhere
to write instead of failing loudly.

So the copy is one-way and dated: 12 files from 29/08, verified by sha256 on both sides. From here
the two progresses diverge, and repeating the copy is the only way back.
