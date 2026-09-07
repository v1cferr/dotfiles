# History: september 2026

4 entries. Index in [README.md](../README.md).

- [~] Bodycam is on the shared disk and declared, and nothing has launched it yet (07/09/2026). It
      arrived as a STEAMRIP release: one RAR5 of **55.9 GiB across 367 entries**, no installer, and
      a readme whose entire instruction is "extract and run the exe". So the work was deciding WHERE
      to unpack it, not how, and the reasoning is in
      [notes/boot-and-storage/games-disk.md](../../notes/boot-and-storage/games-disk.md).
      • THE EXTRACTION TARGET IS THE WHOLE DECISION, and it is the snapshot trap of the entry below
        applied BEFORE the fact instead of measured after it. Unpacking into `~/Downloads` or into
        the prefix would have written 56 GiB inside `@home`, which btrbk snapshots hourly, and from
        there the space stays pinned for the four weeks of `48h 7d 4w` however fast the files are
        moved out afterwards. Written straight into `/mnt/windows/Games`, those bytes never enter a
        subvolume at all and there is nothing left to reclaim. The ARCHIVE is the one copy that does
        pay that cost, since it was downloaded into `~/Downloads` and is already in the snapshots:
        deleting it today frees nothing.
      • THE MASK I WROTE RESTRICTS NOTHING, and it took two passes to see it.
        `unrar x <archive> "Bodycam/" /mnt/windows/Games/` reads as "only that folder" and unpacks
        the WHOLE archive, because a mask with a trailing slash and no wildcard matches nothing and
        unrar falls back to everything: the `.url` ad, the readme and `_CommonRedist/` landed at the
        root of `Games/`, next to every other game. The second invocation, written the same way to
        pull `_CommonRedist` alone, started duplicating the game into `Bodycam/Bodycam/Bodycam/` and
        had 25 GiB in there before it was killed. `"Bodycam/*"` is the form that restricts.
      • WHAT THE FOLDER KEEPS is the game root plus `_CommonRedist` INSIDE it, the way Cities
        Skylines II keeps its `_Redist`: 32 MiB Wine should not need (a GE-Proton prefix already
        carries `vcruntime140` and `msvcp140`, measured on Black Flag) but the Windows side might,
        kept so that fallback does not depend on holding on to a 55.9 GiB archive. The ad went out,
        and so did everything the first pass had spilled at the root of `Games/`.
      • VERIFIED against the archive's own listing, path by path and size by size, because `du -sh`
        is not proof and that is the house rule on this disk: **258 files, zero missing, zero size
        mismatches**. THE COUNT IS THE HALF THAT EARNED ITS KEEP, since every named file matched
        while the folder held 365 of them and 81 GiB, and that gap is the only reason the duplicate
        above was noticed instead of sitting there.
      • THE BOTTLE IS ITS OWN, `Bodycam`, created with the SAME components as `Black-Flag` and for
        the same reason: UE5 renders through DX12, so it needs vkd3d-proton, which the Battle.net
        bottle has no use for. `bottles-cli new` takes every one of them as a flag, so the prefix
        was created from the terminal and its `Parameters` block came out identical to Black-Flag's.
      • WHAT IS NOT DONE is why this entry is not `[x]`: the bottle has never run the game. The trap
        already visible in `Binaries/Win64` is `winmm.dll` sitting next to the exe with a
        `dlllist.txt` naming `OnlineFix64.dll`. That is a proxy DLL, and it loads on Windows because
        the application directory comes first in the DLL search order, while Wine resolves a system
        name to its BUILTIN first. Expected, NOT measured, and it is the first thing to check if the
        game opens and the online half does not.
      • THE UPSCALER SITUATION REPEATS BLACK FLAG'S, with the same conclusion on the same GPU: the
        release ships DLSS 8.8.0 and the whole Streamline set, dead weight on an Arc B580, next to
        FSR 4.1.1 and XeSS 3.0.5. XeSS is the one that runs here.

- [x] Black Flag Resynced plays on Linux, and the Windows save came with it (05/09/2026). The game
      had been on the shared disk since 25/08, so what was missing was a bottle, and the bottle was
      the easy half: `Black-Flag` with GE-Proton and vkd3d-proton, opening at 1920x1080 on the
      first try, with 10287 pipelines compiled that first time and 11 on the second. The part worth
      keeping is the save, and it is written down in
      [notes/boot-and-storage/games-disk.md](../../notes/boot-and-storage/games-disk.md).
      • THE SAVE NEEDED NO PATCHING, for a structural reason and not a lucky one. The repack
        authenticates through a Ubisoft Connect emulator whose `upc_r2.ini` sits NEXT TO THE EXE,
        on the disk both systems read, so the `UserId` is the same on both BY CONSTRUCTION. The
        only thing that differs between the systems is where `%APPDATA%` points. 12 blobs, the
        manifest of the game's own save-storage layer and the `.ini`, all verified by sha256 on
        both sides.
      • THE PATH THAT LOOKS RIGHT AND IS NOT is `drive_c/users/v1cferr`. A GE-Proton prefix has
        no user named after the account, only `steamuser`, so a copy into the obvious one lands in
        a directory the game never opens, and the result is indistinguishable from a save that did
        not survive the transfer.
      • THE SETTINGS TRANSFERRED 1:1 for a reason that will not repeat on another machine: the
        `.ini` carries `AdapterVendorID=32902` and `AdapterDeviceID=57867`, which are `0x8086` and
        `0xE20B`. Windows had been played on this SAME Arc B580, so the quality profile was already
        tuned for the GPU it would run on here. Its `NVStreamline` DLLs, on the other hand, are
        dead weight on an Intel card: XeSS is the upscaler that works.
      • THE SYMLINK I DID NOT DECLARE was the tempting one: point the prefix at the Windows save
        so both systems share ONE progress, exactly like the game data already does. It costs
        restic, whose `paths` is `/home/v1cferr` and would not cover a save on NTFS, and it turns
        this disk's DELIBERATE refusal to mount after a Windows hybrid shutdown into a game with
        nowhere to write instead of a mount that fails loudly. Copied on purpose, diverging on
        purpose, and the copy is dated: 29/08.
      • THE SAMPLER HAD TO LEARN THE GAME, which is the kind of omission that hides for a month.
        `usagePaths` lists every game individually, at game granularity and not bucket, so without
        a line for this one the BIGGEST game on the disk, 67 GiB of it, would have been the one the
        report never names.

- [~] The webcam is recognized, declared, and still does not stream (04/09/2026). What I asked for
      was a viewer, and the viewer was the easy half: `guvcview` plus `v4l-utils` and nothing else,
      because the camera (Sonix `0c45:636b`, sold as a REDRAGON Live Camera) needs no driver, no
      udev rule and no quirk. Every measurement is in
      [notes/hardware/webcam.md](../../notes/hardware/webcam.md); what is worth keeping here is the
      shape of the diagnosis, because I nearly declared a workaround.
      • THE FAILURE IS THE TRANSPORT, NOT THE DRIVER, and WHERE it happens is what says so.
        `Failed to set UVC probe control : -71` is EPROTO on a CONTROL transfer, endpoint 0, which
        runs BEFORE any isochronous bandwidth is reserved. A camera asking for more bandwidth than
        the bus has fails later and differently, at STREAMON with ENOSPC. So dropping the
        resolution, which is the first thing every forum suggests, changes nothing: MJPG at
        1280x720 and 640x480 and YUYV at 640x480 and 320x240 all die identically. And the device
        REBOOTS ITSELF on each attempt, going from USB device number 6 to 10 in one session.
      • THE MICROPHONE IS THE EVIDENCE, which is why I recorded from it before blaming anything.
        The same physical device exposes `snd-usb-audio` interfaces, and 3 seconds of real
        non-silent audio came through the same cable and the same hub. Enumeration works, endpoint
        0 works for the audio function, and the link carries isochronous traffic. That is what
        narrows a vague "USB problem" down to the video function alone, and it is the reason the
        remaining suspicion is CURRENT: the sensor and the JPEG encoder are what draw the 500 mA
        the descriptor asks for, and they only switch on at the moment of stream negotiation, which
        is exactly where it dies. The hub it hangs off advertises 100 mA and is shared with a USB
        Audio and HID device.
      • THE WORKAROUND I DID NOT DECLARE is the part I want to remember. The camera sits at
        `power/control = auto` with a 2000 ms delay, it WAS suspended when the first attempt ran,
        and EPROTO on the first control transfer after a resume is a documented UVC quirk with a
        one-line udev fix. It fit so well that I almost wrote it. Four more attempts with the
        device already `active` logged the same failure on both the probe and the commit control,
        so autosuspend is not the cause and the rule would have been dead config that LOOKS like a
        fix (rule 16). The honest output of an afternoon can be two packages and a page saying what
        the problem is not.
      • WHAT IS LEFT IS NOT DECLARABLE, so it went to open-items: plugging the camera into a rear
        motherboard port with no hub. Bus 2, the USB 3 root, has no devices on it at all. If it
        streams there the hub is the answer; if it fails on a USB 2 and a USB 3 port too, the video
        half of the camera is dead while its microphone keeps working, which is the confusing state
        this whole entry exists to make recognizable.

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
