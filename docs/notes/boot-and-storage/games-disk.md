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
is no alarm on it. With 270 GiB still free after Bodycam landed (measured 07/09) that is not urgent, and the honest
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

### The save stays in $HOME, and what that reasoning got wrong

Pointing the prefix at the Windows save with a symlink would have given the two systems ONE
progress, which is what this disk already does for the game data. It was rejected on 05/09 for two
reasons, and REVISITED on 12/09 when Victoria 3 asked the same question. Both are weaker than they
read, and the rejection is left standing here on a third reason neither of them named.

The first was that the save would leave restic's reach. That was already false when it was written.
`paths` is `/home/v1cferr`, but `.local/share/bottles` sits in the EXCLUDES ([restic.md](restic.md))
and has since 15/08, so a save inside a prefix is not backed up either. That exclusion is the whole
reason `home/services/cs2-saves-backup.nix` exists as a job of its own. The choice was never backed
up against not backed up, it was between two unbacked places.

The second was that a `/mnt/windows` failing to mount (by design, after a Windows hybrid shutdown)
would leave the game with nowhere to write instead of failing loudly. But the GAME sits on that same
mount, so a failed mount means it does not launch at all, and the options carry no `force`, so ntfs3
refuses a dirty volume outright instead of degrading to read-only. The loud failure is what happens
either way.

WHAT ACTUALLY SEPARATES THE TWO GAMES is where the save already was. Black Flag's was inside the
prefix, on the Kingston, so the symlink would have meant MOVING it onto NTFS to buy the sharing, and
a move is the one operation that can lose it. Victoria 3's had never been anywhere else, and that is
why the same question gets the opposite answer below.

So for this game the copy is one-way and dated: 12 files from 29/08, verified by sha256 on both
sides. From here the two progresses diverge, and repeating the copy is the only way back.

## The game that arrives as an archive, and where it gets extracted

Bodycam came in as a STEAMRIP release: one RAR5 file in `~/Downloads`, 55.9 GiB across 367 entries,
no installer, and a readme whose whole instruction is "extract into `C:\Games` and run the exe". The
layout inside is stock UE5, `Bodycam.exe` at the root next to `Bodycam/` and `Engine/`, which is
already the shape of this folder: one directory per game with the exe at its top.

**The extraction target was the destination, never `$HOME`.** That is not a shortcut, it is the
snapshot section above applied BEFORE the fact instead of after. Unpacking into `~/Downloads` or
into the bottle would have written 56 GiB inside `@home`, btrbk snapshots hourly, and from that
moment the space stays pinned for the four weeks of `48h 7d 4w` however fast the files are moved out
afterwards. Writing straight into `/mnt/windows/Games` puts those bytes outside every subvolume on
the first pass, and leaves nothing to reclaim.

The archive itself is the one copy that does pay that cost, since it was downloaded into
`~/Downloads` and is already inside the snapshots. Deleting it frees nothing today, for exactly the
reason the section above measured.

**THE MASK DOES NOT RESTRICT ANYTHING**, and that is the one thing worth remembering from the
unpacking itself. `unrar x <archive> "Bodycam/" /mnt/windows/Games/` reads as "only that folder" and
extracts the WHOLE archive: a mask with a trailing slash and no wildcard matches nothing and unrar
falls back to everything, so the `.url` ad, the readme and `_CommonRedist/` all landed at the root
of `Games/`, next to every other game. MEASURED TWICE, because the second invocation was written the
same way and started duplicating the game into `Bodycam/Bodycam/Bodycam/`, 25 GiB of it before it
was killed. The mask that works carries a wildcard (`"Bodycam/*"`), and the cheaper habit is to
unpack everything and then move, which on one filesystem is a rename.

What the folder keeps afterwards is the game root plus `_CommonRedist` INSIDE it, the way Cities
Skylines II keeps its `_Redist`: 32 MiB of Windows installers Wine should not need (a GE-Proton
prefix already carries `vcruntime140` and `msvcp140`, measured on Black Flag) but the Windows side
might, and keeping them there is what stops that fallback from depending on holding on to a 55.9 GiB
archive. The `.url` went out, and so did everything the first pass had spilled at the root of
`Games/`.

VERIFIED after extracting, because on this disk that is the house rule and `unrar` printing `All OK`
only says the CRCs matched what the archive claims about itself: every file compared to the listing
by relative path and size, **258 files, zero missing, zero size mismatches**. The folder holds 265
of them, the other seven being `_CommonRedist` and the readme, and 56 GiB against 270 GiB still free
on the disk.

`Bodycam` is its OWN prefix, for the same reason `Black-Flag` is: UE5 renders through DX12, so it
needs vkd3d-proton, which the Battle.net bottle has no use for. What each bottle LISTS is declared
in `home/apps/bottles.nix` ([bottles.md](../apps/bottles.md)); the prefix itself stays state.

## The game whose save was already on the Windows disk

Victoria 3 is the third that was never duplicated: a RUNE repack installed straight into
`/mnt/windows/Games` on 29/08, 16 GiB, which only got a bottle on 12/09. The game side holds no
surprise. `Victoria-3` is its own prefix with the components the other repacks use, and the program
declared in `home/apps/bottles.nix` is `binaries/victoria3.exe` and NOT `launcher/dowser.exe`: the
Paradox launcher opens on a Steam login a repack cannot pass, and what answers for Steam here is the
`steam_api64.dll` sitting next to the exe.

The save is what is new, and it is the case the section above did not have. Paradox writes into the
Windows user profile and not into the game folder, and on that install Documents is REDIRECTED into
OneDrive:

`/mnt/windows/Users/vfla1/OneDrive/Documentos/Paradox Interactive/Victoria 3/save games`

It has lived there since 29/08 and has never been on the Kingston, so linking it moves nothing and
costs no backup that existed. It gains one: OneDrive syncs that folder whenever Windows is the
system running, which is more than a save inside a prefix gets here.

That path is also why `my.games.linked` could not carry it. Its values are relative to
`my.games.root` and this one is nowhere near `Games/`, so `home/apps/games-disk.nix` grew a second
attrset, `my.games.saves`, whose values are absolute.

### `save games` alone, and what stays out of the link on purpose

The rest of the profile sits right beside it and none of it crosses:

| What | Why it stays per system |
| --- | --- |
| `shadercache` | compiled against the API in use, DX11 native on Windows against DXVK here |
| `pdx_settings.json` | carries the other system's resolution and video adapter |
| `logs`, `crashes`, `dumps` | churn, on a disk that takes none |
| `continue_game.json` | points at a last-played path, the one thing that genuinely differs |

The price is the Continue button, which reads that last file. The save itself comes back from the
Load menu, so the cost is one extra click and never a lost campaign.

**VERIFIED THAT THE FILE WAS REAL before anything pointed at it.** OneDrive can leave a dehydrated
placeholder that reports the full size and holds no data, and a symlink to one resolves fine and
fails at load, which reads as a corrupt save rather than a missing download. `japan_ironman.v3`
allocates 37464 blocks against 19178897 bytes, so it is fully materialized, and its header reads
`SAV01` straight from Linux.

It is IRREPLACEABLE in the ironman sense and it is not in restic, the same as every other save in a
bottle. OneDrive is the off-machine copy and it only runs when Windows does. If that stops being
enough, the shape to copy is `home/services/cs2-saves-backup.nix`.
