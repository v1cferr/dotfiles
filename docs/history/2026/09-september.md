# History: september 2026

11 entries. Index in [README.md](../README.md).

- [~] A KVM host for a DISPOSABLE Windows 11, and three wiki steps that do not survive 26.05
      (19/09/2026). The host is declared, switched and verified; no guest exists yet, which is why
      this is not closed. [notes/services/libvirt.md](../../notes/services/libvirt.md) holds the
      detail.
      • THE REASON IS A SANDBOX AND NOT VIRTUALISATION AS A HOBBY. A static review of a game
        loader the same morning came back clean on the loader and BLACK BOX on the trainer payload
        it deploys, which only decrypts against the vendor's server. The report's own advice was
        to run it on something I can afford to reset, so half the decisions below are about
        keeping the guest AWAY from the host rather than about making it comfortable.
      • THREE THINGS BOTH WIKI PAGES TELL YOU TO DO ARE WRONG HERE, and I only know because I
        checked each against the PINNED tree instead of copying it. `qemu.ovmf.packages` is
        REMOVED in 26.05 and carries an assertion that FAILS the build on it; the tmpfiles line
        for `/var/lib/qemu/firmware` is already emitted by the module itself; and `dnsmasq` is
        already on libvirt's wrapped `binPath`. Nothing about UEFI is declared as a result, and
        that is not an omission: the pinned `qemu-10.2.4` ships `50-edk2-x86_64-secure.json`,
        which is the Secure Boot firmware Windows 11 asks for. `swtpm` is the only requirement on
        that list Nix still has to declare.
      • THE `libvirtd` GROUP GOES IN AND `kvm` STILL DOES NOT, which look like one decision and
        are two. 11/08 disproved the `kvm` one by measuring that `/dev/kvm` is born 0666, and it
        still is. `libvirtd` is the opposite: the module's own polkit rule keys
        `org.libvirt.unix.manage` on that group, so without it every action is a password prompt.
        MEASURED after the switch, `virsh -c qemu:///system list --all` answers with none.
      • `virbr0` IS DELIBERATELY NOT A TRUSTED INTERFACE, against what both pages say. This host
        is listening on 2222, 8096, 8080 and 11434, and handing an unreviewed Windows payload a
        free pass to all of it defeats the purpose of the VM. It is not needed either: libvirt
        installs its own rules, and `LIBVIRT_INP` was measured accepting EXACTLY dport 53 and 67
        on `virbr0` and nothing else, so the guest gets DHCP, DNS and NAT while everything else it
        aims at the host falls through to the NixOS firewall.
      • QEMU RUNS UNPRIVILEGED, `runAsRoot = false`, which is what Debian and Fedora do and what
        NixOS does not. THE PRICE IS THE MEDIA PATH and it bites at once, so it is written down
        rather than discovered: `qemu-libvirtd` cannot traverse a 0700 home, so an ISO in
        `~/Downloads` is unreadable to it no matter what libvirt chowns, because the failure is
        traversal and not ownership. Media lives in `/var/lib/libvirt/images`, and
        `sudo -u qemu-libvirtd test -r` on the moved ISO answers YES. It went in NOW because the
        option's own documentation says flipping it later breaks an existing guest's permissions.
      • TWO HAND-TYPED STEPS WERE DECLARED AWAY. `virsh net-autostart default` is one symlink,
        so it is a tmpfiles `L+` line, and the network came up `active` with `autostart yes` on
        the first boot with nobody typing anything. And the images pool is NOCOW through a
        tmpfiles `h` line, since a qcow2 over btrfs CoW plus zstd fragments as the guest writes
        it: `lsattr -d` reads `---------------C------`, the same lesson `@swap` already carries.
      • THE CLOSURE PAID FOR AN EMULATOR THE MACHINE ALREADY HAD. `libvirtd` defaults
        `qemu.package` to the full `pkgs.qemu`, which emulates alien architectures, and this host
        runs x86_64 on x86_64. The find was not the size but WHOSE path it is: claude-desktop's
        FHS already pulls that exact `qemu-host-cpu-only`, recorded in
        [notes/repo/packages.md](../../notes/repo/packages.md) since 30/07. MEASURED on the whole
        system closure, 26.89 GiB to 25.95, 940 MiB. VERIFIED BEFORE SWITCHING, because this is
        the half that could have quietly broken the installer: `qemu_kvm` ships the SAME eight
        firmware descriptors, the Secure Boot one included.
      • THE SWAP DID NOT REACH THE RUNNING DAEMON, caught before creating any VM. nixpkgs
        patches libvirt so a domain records `/run/libvirt/nix-emulators/qemu-kvm` instead of a
        store path, to keep VMs off a particular derivation. But `libvirtd.service` carries
        `restartIfChanged = false` upstream and `libvirtd-config` only comes in through its
        `requires`, so the switch rebuilt both units and started NEITHER: the active unit
        declared `qemu-host-cpu-only` while the symlink still resolved to the full `qemu-10.2.4`
        from the switch before it. A VM created in that window would have recorded the stable
        path, had it resolve to a store path no generation references, and stopped booting at the
        next `nix-collect-garbage` with an error saying nothing about garbage collection.
        `systemctl restart libvirtd-config libvirtd` fixes it, a reboot does too, and that is why
        it normally stays invisible here.
      • WHAT IS LEFT, and it is the guest: install Windows with UEFI secure plus a TPM 2.0 on
        Q35, then the payload. USB passthrough and a virtiofs shared folder are both one line and
        both deliberately absent, unused today (rule 16) and both holes in the isolation this VM
        exists to provide. One claim also stays unproven until the guest boots: that libvirt's
        jump sits ahead of `nixos-fw` in `INPUT`. The first DHCP lease settles it.

- [x] The docs contract became rule 20, and the day found its own counterexample (19/09/2026).
      Two days of decisions about the site were living in a note, which is where reasoning goes,
      not where a contract goes. The rule states it and
      [notes/repo/site.md](../../notes/repo/site.md) keeps the reasoning, which is the usual
      split here.
      • WHAT THE RULE ACTUALLY FIXES is not that the docs are published, it is that the TREE and
        the NAV are separate and the tree never moves to match a renderer. Regrouping `docs/` by
        topic to mirror a sidebar reads as tidying and is the tree mirror
        [notes/README.md](../../notes/README.md) already measured and rejected, it would rewrite
        197 pointers across 136 code files, and rule 17 wants a `git mv` history that survives.
      • THE RULE CAUGHT SOMETHING WHILE I WAS WRITING IT, which is the best argument it could
        have made for itself: `notes/services/libvirt.md` had been written the day before,
        indexed in the notes README, and left out of the nav. The build refuses that, so the
        page would have shipped unreachable and the CI would have gone red on the next push.
      • AND IT EXPOSED THAT THE ENFORCEMENT WAS A STEP LATE. Only the gate builds the site, so
        the omission survived two commits. The build moved to `pre-push` as well, which is a
        MEASUREMENT and not a taste: 7.12s per run, and a page is added rarely, so every docs
        edit paying it buys nothing while one run per push keeps the CI from being where I find
        out. git-hooks.nix installs the hook type from the stage on its own.

- [x] The site draws diagrams, and stopped calling out to anybody (19/09/2026). Follow-up to the
      day before: the first diagram went in, and putting it there exposed two third parties the
      site was quietly talking to. Both are gone. [notes/repo/site.md](../../notes/repo/site.md)
      holds the detail.
      • THE FIRST DIAGRAM IS THE ONE THE PROSE COULD NOT DRAW: `commonModules` is hoisted, so
        the machine, the disko drill and the boot test all evaluate the SAME list plus their own
        override, and none of the three can drift from what gets installed. It lives in
        [notes/repo/flake.md](../../notes/repo/flake.md), as a ```mermaid fence that GitHub
        renders natively and the site renders through superfences: one source, two renderers.
      • MERMAID CAME WITH A CDN ATTACHED. Material fetches `unpkg.com/mermaid@11` at page load,
        a moving pointer running in the reader's browser, which is rule 13's trap on somebody
        else's machine. Its loader guards on `typeof mermaid == "undefined"`, so a vendored copy
        defined first keeps it home: pinned at 11.12.0 by hash from the npm registry, and the
        one template override serves it ONLY on pages whose markdown has the fence, because 2.7
        MB on all 90 pages to draw one diagram is a worse deal than the CDN was. `mermaid-cli`
        was the obvious source and measures 2.1 GiB of closure, since it drags chromium.
      • THE BIGGER ONE WAS THE FONTS, and it had been there since the first commit: Material
        links Roboto from `fonts.gstatic.com` on EVERY page, so reading this site sent every
        visitor to Google ninety times over. It survived the first audit because that one
        grepped for `src=` and a font arrives through `href=`. `theme.font: false` plus a stack
        naming `system-ui` and JetBrains Mono, neither required, both prepended to Material's
        own fallback chain. What is left pointing outward is what the pages cite on purpose.
      • EXISTING STOPPED BEING THE WHOLE TEST for a link. Once a link leaving `docs/` is
        published as a blob URL, a target that is present but UNTRACKED resolves in the working
        tree and 404s on the site. `docs-links` now checks those against `git ls-files`, which
        it was already reading, and it catches nothing today on purpose: 921 references, zero
        untracked, the gap being the one that opens later.
      • AND THE REPO AND BRANCH GOT ONE OWNER. The hook had both hardcoded next to a
        `mkdocs.yml` that already declares them, which is two owners of a value whose staleness
        breaks 134 links at once. It derives them from `repo_url` and `edit_uri` now, proven by
        pointing `edit_uri` elsewhere and watching every published link follow. The network half
        is a weekly `lychee` over the BUILT site in the canary, 91 URLs, since none of those
        links appears in any `.md` for the markdown run to find.

- [x] docs/ became a site, and the tree did not move to get there (18/09/2026). 88 pages and
      ~188k words were a manual with no reader outside a file tree. MkDocs plus Material for
      MkDocs turns them into static HTML at <https://dotfiles.v1cferr.dev/>, built by the flake
      and published by `.github/workflows/docs.yml`. The whole reasoning is in
      [notes/repo/site.md](../../notes/repo/site.md).
      • THE ONE DECISION WORTH THE DAY WAS NOT REORGANISING `docs/`. The obvious move is to
        regroup the tree by topic to match a sidebar, and it is wrong three times over: sections
        named after the repo's own directories are the tree mirror that
        [notes/README.md](../../notes/README.md) already measured and rejected, the move would
        rewrite 193 pointers across 132 code files, and rule 17 wants a `git mv` history that
        survives. MkDocs writes the nav in its own config, so the sidebar is topic-first and the
        files never moved. Nine of the twelve sections are subjects.
      • THE NAV IS CHECKED BY THE BUILD, not by a new checker. `validation.nav.omitted_files`
        plus `--strict` makes MkDocs refuse to build a site that left a page out of the nav,
        which is the same trade rule 7 makes for shell scripts. It paid for itself immediately:
        `notes/apps/spotify.md` had been written and never indexed, 15 of 16 apps in the table.
      • 134 LINKS POINT AT SOURCE FILES OUTSIDE `docs/`, which MkDocs does not serve, so under
        --strict every one of them is a build error. `scripts/mkdocs-hooks.py` resolves each
        target against the page's own directory, the same rule `docs-links` applies, and rewrites
        the ones that escape into blob URLs. The markdown on disk is untouched, so the link still
        works when the page is read on GitHub, which is where most of them get read.
      • A FOLDER LINK NEEDS AN INDEX PAGE. GitHub renders a listing for `guides/` and a static
        site has nothing to render, so `docs/guides/README.md` was born, the counterpart of the
        one `notes/` and `history/` already had.
      • THE UPSTREAM IS FROZEN AND I FOUND OUT FROM THE BUILD, which is the kind of thing worth
        checking before trusting a warning: MkDocs 1.x has no release in 24 months and no commit
        in 11, and 2.0 is a pre-release that drops plugins, moves to TOML and carries no license.
        Material's answer is Zensical, MIT, which reads this config as it stands but sits at
        0.0.62 with a release every two days. The numbers and the trigger to migrate went to
        [ideas.md](../../ideas.md). The tree not having moved is what makes that a config change
        later instead of a migration.
      • TWO HALVES STAY OUTSIDE THE REPO, and both are worth knowing before debugging a 404: the
        Pages source has to be "GitHub Actions" and not a branch, and `dotfiles.v1cferr.dev`
        needs a DNS record of its own, since the wildcard for this zone points home and Caddy
        would answer for a site that is not there.

- [x] An image in the clipboard reaches the TUI on the workstation (14/09/2026). Claude Code over
      ssh reads the WORKSTATION's filesystem and has no idea this machine has a clipboard, so an
      image copied here had exactly one way in: a path it can open on that side. `clipboard-push`
      is that path, in `home/desktop/clipboard.nix` next to `clipboard-menu`, bound to SUPER+ALT+V,
      and by the end of the day it was ctrl+shift+v deciding on its own. The full reasoning is in
      [notes/desktop/desktop-plumbing.md](../../notes/desktop/desktop-plumbing.md).
      • THE CLIPBOARD COMES BACK CARRYING THE REMOTE PATH, which is the whole trick: push,
        paste, done, with no second terminal and no thinking about where the file went. The image
        is not destroyed by being replaced, since cliphist still holds it one SUPER+SHIFT+V away.
      • NO TRAILING NEWLINE ON THE PATH. `wl-copy "$path"` and not an echo into it, because a
        newline pasted into a TUI SUBMITS the prompt instead of typing into it, which would have
        made the feature actively annoying while looking like it worked.
      • THE REMOTE HALF GOES IN THROUGH SSH'S STDIN, the same shape `wake-workstation` already
        uses for its python: the workstation is somebody else's Ubuntu 26.04 and nothing may be
        installed there. It answers `$HOME` RESOLVED, which is what scp and the TUI both need (a
        `~` pasted into a prompt is not expanded by whatever reads it), and it prunes the drop of
        what is over a week old in the same pass, so a folder on a machine that is not mine cannot
        grow forever.
      • TWO CONNECTIONS, ONE HANDSHAKE. The `workstation` block already sets `ControlMaster
        auto` with a 10 min persist for VS Code's sake, so the scp rides the master the ssh above
        opened instead of paying a second SonicWall round trip.
      • A COPIED FILE IS THE FALLBACK, and it is not decoration: half the time what is in the
        clipboard is a Dolphin selection, which is a `file://` URI and not image bytes. It is
        percent-decoded before the transfer, because a name with a space arrives as `a%20b.png` and
        would land on the other side as a file nobody can find.
      • MEASURED END TO END the same day, with the VPN up: an 8x8 PNG through `image/png`, then
        the same file as a `text/uri-list` with a space in the name. Both arrived intact (`file`
        confirms the PNG on the far side) and both came back in the clipboard as an absolute path.
      • TWO KEYS FOR ONE INTENTION WAS THE WRONG SHAPE, and that is the second half of the day:
        push, then paste, and remember which window was an ssh. The terminal already knows, so
        `home/shell/kitty/smart-paste.py` asks it: the window's FOREGROUND PROCESS is an `ssh`, so
        the destination is that ssh's host, and anything else is `local`, a drop in `~/.cache` with
        the path pasted from there. ctrl+shift+v, one key, no decision left to me.
      • WHAT DOES NOT DIVERGE IS THE POINT. Only an IMAGE takes the new path; every other paste
        falls through to kitty's own, keeping the bracketed paste, the `paste_actions` filters and
        the large-paste confirmation. The most used key on this machine is the wrong place to
        reimplement pasting, and ctrl+alt+v stays bound to the plain paste so a broken kitten
        cannot take it down with it (rule 15).
      • THE FREEZE I DID NOT SHIP: `handle_result` runs INSIDE the kitty process, so a blocking scp
        would hold the whole terminal for the length of the transfer, and for 14 s with the VPN
        down. The child is spawned and `boss.monitor_pid` pastes when it dies. The paste also aims
        at the window the key was pressed in and not at the active one, which after a two second
        transfer is not necessarily the same window.
      • THE TEST LIED BEFORE THE FEATURE DID. Driving a throwaway kitty over its own remote control
        pasted NOTHING, and the cause was Wayland and not the kitten: an unfocused window never
        receives a selection offer, so `get_clipboard_string()` is empty there and even kitty's own
        `paste_from_clipboard` does nothing. With a focused window all three cases passed: text
        unchanged, an image in an `ssh workstation` window arriving as a remote path, and the same
        image in a local shell arriving as a `~/.cache` path.

- [x] The Bottles library stopped being a thing I had only clicked (07/09/2026). Eight programs
      across five bottles existed nowhere but in the GUI, so nothing in the repo said what a
      restored prefix SHOULD list, and the answer after a restore would be "whatever the backup
      happened to catch". `home/apps/bottles.nix` declares it now, and the reasoning is in
      [notes/apps/bottles.md](../../notes/apps/bottles.md).
      • THE PREFIX STAYS STATE AND THE LIST BECOMES CONFIG, which is the whole design. A bottle is
        tens of thousands of files Wine rewrites at will, so it comes back from restic (rule 6);
        the programs it shows are a handful of names, paths and command lines, which is precisely
        what a restore cannot reconstruct on its own.
      • ADDED BY ACTIVATION, NEVER WRITTEN, because Bottles rewrites `bottle.yml` on every change
        and a managed file there would be a second owner (rule 14). Same shape as `dolphinPlaces`:
        insert only what is missing. Checked before trusting it, `bottles-cli add` produces an
        entry identical to the GUI's, down to `folder` and the dxvk flags.
      • I DECLARED THE WRONG "LIBRARY" FIRST, and this is the part worth remembering. Bottles has
        TWO of them: `External_Programs` inside each `bottle.yml`, which is the list on a bottle's
        own page, and `library.yml` next to the `bottles/` folder, which is the Library TAB. All
        eight programs were registered and visible on their bottles, and the tab still showed
        three tiles. A tile REFERENCES a program by the uuid `bottles-cli add` generated, so it
        cannot be declared outright, only built by reading that uuid back out of the prefix, and
        no CLI subcommand covers that file at all. `bottles-library-add` does it, as a package so
        shellcheck sees the awk (rule 7). Validated by parsing the result back: eight entries,
        each id resolving to a program with a matching name in the right bottle.
      • THE TILES CAME UP BLANK, and the covers turned out to be declarable too. Bottles resolves
        art through a proxy of its own (`steamgrid.usebottles.com/api/search/<name>`) and saves it
        under `bottles/<dir>/grids/`, so the script does the same when it creates a tile: 8 second
        cap, failure leaves a text tile, and an entry that already exists is skipped before any
        request, so the steady state touches the network zero times. It answered for all eight
        names, `Battle.net` and `Ascension Launcher` included, 219 to 899 KiB each.
      • THE FIRST SWITCH FAILED, and the reason is worth more than the fix: `-l` takes a value
        that starts with `--` and argparse reads it as another option, so
        `-l '--productcode=pro'` dies with `expected one argument` and takes the whole
        home-manager activation with it. `--launch-options=<value>` is the form that survives.
        What made this hide until the switch is that the same command typed BY HAND had worked,
        because the entries I tested by hand were the ones with no arguments; three of the eight
        carry Battle.net command lines and all three would have failed.
      • THE NAME IS NOT THE DIRECTORY, and this is what makes the CLI look broken:
        `bottles-cli add -b Battlenet` answers `Bottle Battlenet not found` with the bottle sitting
        right there, because the directory is `Battlenet` and the `Name:` inside its `bottle.yml`
        is `Battle.net`. So the activation reads the name back out of the file instead of the
        module carrying a second copy of it (rule 11).
      • NOTHING IN THE LIST WAS INVENTED. The five entries that already existed were transcribed
        from `bottle.yml`, and the two that were missing came from the `.lnk` files Battle.net
        itself wrote in the prefix: `Diablo IV Launcher.exe` with no arguments, and
        `Overwatch Launcher.exe --productcode=pro`. Guessing a product code would have produced a
        library entry that looks right and launches nothing.
      • THE PATHS ARE LOOKED UP AND NOT REPEATED: an entry names the game and its exe, and `inGame`
        finds the bottle and the prefix path in `my.games.linked`. A game that is not linked fails
        at EVAL with a message saying so, which is the opposite of the silent wrong path.
      • WHAT IT DOES NOT DO, said here so it is not discovered later: a program deleted in the GUI
        comes back on the next rebuild (that is the declaration working), and renaming one in the
        GUI makes the declared name absent, so the bottle ends up with both.
      • A LEFTOVER FOUND ON THE WAY: `bottles/` holds six directories and the app lists five.
        `Battle.net` with the dot has no `bottle.yml`, which is exactly what makes a directory
        invisible to Bottles, and it is 688 MiB of `@home` from 05/07 that nothing references.
        Left alone rather than deleted on a hunch, and written down so it stops being a mystery.

- [x] Bodycam runs, and the two errors on the way were both about a DLL nobody loaded (08/09/2026).
      The game data landed on 07/09 (the entry below); this is the bottle finally opening it, and
      both fixes are declared in `my.games.onlineFix`, so the next repack of this kind is one list
      entry. Full trace in [notes/apps/bottles.md](../../notes/apps/bottles.md).
      • THE FIRST ERROR WAS THE ONE I HAD PREDICTED, `Failed to get OnlineFix interface`, and the
        prediction was right for the right reason: the repack's `winmm.dll` sits next to the exe as
        a proxy that loads `OnlineFix64.dll`, Windows loads it because the application directory
        comes first in the DLL search order, and Wine prefers its builtin for a system name. So
        the fix was never loaded, and the message reads like the fix is broken instead.
        `WINEDLLOVERRIDES=winmm=native,builtin`, and `winecommand.py` MERGES that env var into the
        bottle's `DLL_Overrides` instead of replacing it, which is what made the env-var route safe
        to use when the CLI has no flag for overrides.
      • THE SECOND ERROR WAS BETTER HIDDEN: `Failed to load original steamclient. Error code: 126`,
        which is `ERROR_MOD_NOT_FOUND`. The fix reads a path out of
        `HKCU\Software\Valve\Steam\ActiveProcess` and LoadLibrary's it. Static inspection was
        USELESS here, 13 MB of packed DLL with not one readable string, so the answer came from
        `WINEDEBUG=+loaddll` instead of from guessing.
      • THE TRACE ANSWERED THE QUESTION I WAS ABOUT TO GET WRONG. I had written that the next step
        would probably be installing Steam inside the bottle. It is not: `lsteamclient.dll` loads
        as a BUILTIN from GE-Proton and forwards Steam API traffic to the client running on the
        HOST, so opening the ordinary Linux Steam is what made the game come up. Nothing goes in
        the prefix except two symlinks to the Windows DLLs the fix insists on finding, 47 MiB that
        follow Steam's updates instead of being copied and going stale.
      • RUNNING THE RUNNER DIRECTLY DOES NOT WORK, and knowing why saves the next debugging hour:
        `wine` from `runners/ge-proton11-1` dies with `/lib/ld-linux.so.2: could not open`, because
        it needs the FHS environment the Bottles wrapper builds. So `WINEDEBUG` has to go in the
        bottle's own `Environment_Variables`, since `Limit_System_Environment` drops anything not
        on the inherited list.
      • WHAT IS NOT DECLARED, because it is not config: this game wants the Linux Steam client
        RUNNING. 6m40s of play with it open.

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
