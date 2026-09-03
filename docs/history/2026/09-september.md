# History: september 2026

1 entry. Index in [README.md](../README.md).

- [x] The games moved to the Windows disk, 351 GiB, and the two traps on the way (03/09/2026).
      Wanting them on the SATA SSD started as a preference ("I play on Windows sometimes") and
      turned out to be the answer to a much older mess: 135 GiB of the Kingston was a DUPLICATE of
      what was already in `C:\Games`, left by a migration that copied and then never deleted,
      because "validate on the Windows side first" never happened. Full reasoning and the mount in
      [notes/boot-and-storage/games-disk.md](../../notes/boot-and-storage/games-disk.md).
      • THE HARDWARE PREMISE WAS WRONG, and getting it right decided everything. "The SATA SSD" was
        assumed to be the Seagate, the one already mounted. It is an **HDD**
        (`/sys/block/sdb/queue/rotational` = 1), it has 194 GiB free against ~370 GiB of games, and
        it is where restic lands: wrong on three counts at once. The only SATA SSD in the machine
        is the SanDisk, which IS Windows' `C:`, and that is not a drawback, it is the whole
        mechanism: a game in `C:\Games` needs no translation to be played from either side.
      • `du -sh` IS NOT PROOF, and Overwatch is the evidence. Its two copies read 74 GiB against
        76 and would have passed any eyeball, but comparing every file by relative path and size
        showed **76 files differing, 68.9 GiB**: two different builds, with the newer one on Linux.
        Deleting the local copy on the strength of the total would have thrown away the newer game.
        Diablo IV, checked the same way, really was identical (1183 files, zero mismatches, the
        only difference being CASC indices the agent rebuilds), and the 46 GiB PS3 ISO got a full
        sha256 on both disks (`9c600ebb…04b2`) because it is a single file with no launcher to
        repair it and the SanDisk is a budget SSD where corruption looks exactly like a size match.
      • DELETING 135 GiB FREED NOTHING, and this is the trap worth remembering. `df` did not move
        by one GiB, because all **59** btrbk snapshots still contained the games: they had existed
        continuously up to the moment of the delete, and a snapshot holding an extent keeps that
        extent alive. Nothing to fix in btrbk, 59 is exactly `48h 7d 4w` working as designed. It
        was ORDER that mattered: purging the snapshots first would have been useless, since btrbk
        snapshots hourly and would have pinned the next 216 GiB all over again. Move everything
        first, purge once at the end.
      • THE `force` OPTION THAT IS NOT THERE is what makes mounting `C:` safe. The disk had been
        deliberately unmounted over "NTFS writes with fast-startup pending", and the answer is that
        ntfs3 REFUSES a read-write mount of a dirty volume unless `force` is passed. So the mount
        carries `nofail` and no `force`: a Windows hybrid shutdown makes it fail loudly instead of
        writing half of anything. The other half of the old worry, "restic sweeping 900 GB", was
        never real: restic's `paths` is `/home/v1cferr` and nothing else.
        Checked before the first write: `hiberfil.sys` was 6.8 GiB with an ALL-ZERO signature, so
        no pending image. 6.8 is ~42% of 16 GiB of RAM, the reduced hiberfile of fast startup
        without full hibernation, so the feature is probably still on and the mount can start
        failing after any Windows session. `powercfg /h off` is the fix, on that side.
      • ONLY THE GAME FOLDER MOVES, NEVER THE BOTTLE. A Wine prefix does not survive on NTFS (no
        unix permissions, no symlinks, no case sensitivity) and does not need to: after the move
        the three prefixes together weigh **8.4 GiB, down from 225**. The CS2 saves are
        irreplaceable (a repack, no Steam cloud) and live in `drive_c/users/`, a different tree
        from `drive_c/Games`, so they were never in the path of the move: 40 files and 1.3 GiB
        before and after, matching the mirror `cs2-saves-backup.nix` keeps inside restic's reach.
      • THE SYMLINK GOES WHERE THE LAUNCHER ALREADY LOOKS, declared with `mkOutOfStoreSymlink` in
        `home/apps/games-disk.nix` (out of store because the target is mutable data the launcher
        patches in place, and 89 GiB in the store would be absurd and read-only). Relocating the
        game inside Battle.net would have bought nothing: the two systems do NOT share a Battle.net
        config, only the files, so the paths never had to agree. RPCS3's `games.yml` kept working
        untouched for the same reason, and Bottles needed no change at all, since the registered
        program is `Battle.net.exe`, which stays in the prefix.
      • THE MONITORING HAD TO FOLLOW, in a way that is easy to get silently wrong. The sampler from
        the 30/08 entry resolves with `readlink -f`, so a game launched through the symlink reports
        the NTFS path: leaving the `$HOME` path in `usagePaths` would have matched nothing forever
        while reading as "a game nobody plays". `/mnt/windows/Games` is deliberately NOT in
        `watchPaths` though: that ranking exists to explain why the ROOT filesystem is full, and
        another disk in it answers a question nobody asked. That the games disk has no ALARM is a
        gap, written down as a gap.
      • THE OUTCOME WAS BIGGER THAN THE GAMES, measured after the cleaner settled: **659 GiB used
        went to 196**, so **463 GiB came back** against the 351 the games weigh. The extra ~112 GiB
        was snapshot-EXCLUSIVE data with nothing to do with this migration: a month of `@home`
        churn (Downloads, game patches, caches) that only those 59 snapshots were still holding.
        Worth knowing on its own: the retention was costing about 112 GiB in the steady state, and
        it had never been visible because `du` on the live tree cannot see it.
        The space arrives GRADUALLY, over minutes: `btrfs subvolume delete` prints `(no-commit)`
        and hands the extents to the cleaner thread, so the first `df` right after the purge still
        read 659 and looked like a failure.
      • STEAM STAYED, on purpose. Of its 7.9 GiB only 4.3 are the game; the rest is the Steam Linux
        Runtime, which cannot leave Linux. Valve does not support an NTFS library either, so moving
        4 GiB would have bought trouble at no gain.
