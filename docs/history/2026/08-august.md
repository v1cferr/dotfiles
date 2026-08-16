# History: august 2026

62 entries. Index in [README.md](../README.md).

- [x] Rule 2 stopped allowing a wall of prose, and the reasoning moved to `docs/notes/`
      (16/08/2026). The rule permitted a header block "as long as it needs to be", and the
      blocks grew: 6062 comment lines out of 16634 across the tree, 36%, with
      `home/shell/claude-code.nix` carrying a 123-line header. A header that long is not
      documentation, it is a wall you scroll past to reach the code. The tree now sits at 1601
      lines out of 13299, 12%, and NO comment anywhere runs longer than 2 lines.
      • NOTHING WAS DELETED, and that is the whole point. 51 pages in `docs/notes/` hold every
        measurement, every rejected alternative and every correction that used to live in a
        header, and the 2-line header points at its page. Deleting would have been faster and
        would have thrown away things that cost days to learn: the VPN probe's cadence, btrfs'
        reclaim decision, the Dolphin ViewMode enum, Spotify's 4145 restarts.
      • THE CAP IS PER COMMENT, not per module, and that correction came mid-task. I had capped
        only the headers, and `home/packages.nix` was still 101 comment lines because every
        package carried its own paragraph. The rule now says AT MOST 2 LINES, ANYWHERE: the
        header, a config, a package, a list item.
      • `keybinds.lua` was the one file that needed care instead of a sweep, because its
        comments are FUNCTIONAL: the SUPER+H cheatsheet is generated from them at runtime, the
        first line of a block becoming the group and the trailing comment the description.
        Verified by running the awk parser against the old and the new file: 78 binds both
        times, in the same order. Four labels that fall back to the group came out worse than
        before ("VPN (Arch parity)" says nothing) and were rewritten, because shorter is not
        the goal, it is the constraint.
      • THE GATE CAUGHT ONE REAL BREAK, which is the argument for running it per batch rather
        than at the end: a stray `>` leaked from a python heredoc into
        `curseforge-fix-perms`, and `nix flake check` failed on the derivation. From there the
        gate also became the toplevel BUILD and not only `nix eval`, because several of these
        files carry `writeShellApplication` bodies, so a comment run inside a shell string is
        script content and shellcheck is the only thing that sees a bad edit to it. That is
        also why the btrfs alert units changed derivation while doing nothing different: the
        comments I rewrote were inside the script, not in the Nix.
      • WHAT THIS BUYS beyond the reading: the reasoning was invisible from `docs/`. To find
        out why Caddy has a fail2ban jail you had to already know to open
        `system/services/caddy.nix`. `notes/` is indexed, cross-linked and covered by rule 16,
        so a page that stops being true is a bug, whereas a stale header block was just
        furniture.

- [x] The rules left the prompt and became `/etc/claude-code/CLAUDE.md` (15/08/2026). Three
      rules were being retyped BY HAND at the top of every prompt I wrote for Claude Code
      (incremental commits, everything in en-US, never a `Co-Authored-By:` trailer), which is
      rule 3's definition of manual: it works until the day I forget, and the day I forget is
      the one that produces a repo in two languages with a single blob commit signed by a
      coauthor I did not want. Now `system/services/claude-code.nix` generates them and EVERY
      project on this machine is born with them. It became rule 18.
      • WHY THE MANAGED LAYER and not `$CLAUDE_CONFIG_DIR/CLAUDE.md`, which is the path
        everybody knows: the user file is PER ACCOUNT, so with `claude-fai` and
        `claude-pessoal` it would be two copies of the same text drifting apart, and CC WRITES
        to it, because the `#` shortcut appends a memory to exactly that file. Nix owning it
        would break the shortcut and put two owners on one artifact (rule 14). The managed one
        CC only ever reads.
      • MEASURED IN THE BUNDLE (2.1.222) instead of trusted from the docs, because a memory
        file that is never read fails SILENTLY and looks exactly like an assistant ignoring the
        rules: the loader resolves "Managed" to `join(fU(), "CLAUDE.md")`, `fU()` returns
        "/etc/claude-code" on Linux ("/Library/Application Support/ClaudeCode" on macOS), and
        that layer is read UNCONDITIONALLY, unlike User and Project, which are gated by
        settings. Confirmed after the build: the file is in the built system's `/etc`.
      • THE NEAR MISS was managed-settings.json's `claudeMd` field ("instructions injected as
        organization-managed memory. Only honored from managed/policy settings"), which does the
        same job with no second file and LOSES ON THE DIFF: the markdown would turn into a JSON
        one-liner with escaped newlines, unreadable in a `git diff` and out of markdownlint's
        reach.
      • IT COSTS CONTEXT IN EVERY SESSION on this machine, this repo's included, so the file
        holds the rules and NOTHING else, and the reasoning stays in `docs/rules.md`. Rule 17's
        em dash and emoji bans did NOT go along: they are a style choice for what I publish,
        not a working agreement with the agent. Promoting them later is one line in the module.

- [x] The repo is ENTIRELY in en-US, and rule 17 stopped being a promise (15/08/2026). The
      rule was written this morning with the `.nix` tree named as known debt; by the end of the
      day the debt was gone. In order: the 12 densest modules, the other 86 `.nix` files, the CI
      workflow, `scripts/`, the Hyprland Lua, the Quickshell QML and the tooling files
      (`.envrc`, `statix.toml`, `.sops.yaml`, `.gitignore`, `.markdownlint.jsonc`, the two
      VS Code `settings.json`, `router/README.md`, `ci/stub-duo/.gitkeep`).
      • IT WAS NOT ONLY COMMENTS, and that is what made it worth doing in one stretch. Three
        files GENERATE what the session shows: `keybinds.lua` is parsed at runtime by the awk in
        `cheatsheet.nix`, so translating it translated the SUPER+H cheatsheet; the Quickshell QML
        is the bar itself; the shell scripts print to the terminal. Anything user-facing that
        this repo OWNS came along.
      • WHAT STAYS IN pt-BR IS A CLOSED LIST, and each item says why where it lives: the
        lockscreen (a product decision from july), the Brazilian holiday names plus the month and
        weekday names in the bar's calendar, and runtime identifiers whose rename would be a
        behavior change and not a translation (`my.archAntigo`, the `arch-antigo-mount` unit,
        `/mnt/arch-antigo`, the "Arch antigo" bookmark, `/srv/media/media/Filmes`).
      • `checks.pacotes` BECAME `checks.packages`, closing the one item the morning had left
        pending: it kept its name only because `.github/workflows/nix.yml` cited it BY NAME, so
        translating the workflow removed the reason.
      • THE REDACTION MARKER of `router-sync` changed with it, because the old one carried an em
        dash, and it is written INTO `router/uci/*.conf`. The four mirrored files that hold it
        were rewritten in the same commit: otherwise `router-sync diff` would report every config
        with a secret as diverging until the next `pull`, which is a gate lying about the
        router's state. A translation with a runtime side effect is not a translation, it is a
        change, and it went in as one.
      • MEASURED AS IT WENT, because "it is only a comment" is exactly how a live config breaks:
        `nix flake check` after each batch of `.nix`, `luac -p` plus a real `hyprctl reload`
        (which answered ok, 92 binds) for the Lua, `shellcheck -x` plus `py_compile` for the
        scripts, and for the QML the Quickshell log itself, which hot-reloads on save and said
        "Configuration Loaded" at the end, with `qs ipc call bar unhide` still answering.

- [x] Minecraft OPENED, and the "unexpected error" was the SAME lost `+x`, one tree wider
      (15/08/2026). This closes the item opened on 14/08 ("see Minecraft OPEN"). The app
      answered the Play button with the generic red banner, "An unexpected error occurred.
      Operation failed.", whose support article lists three causes (antivirus, a full disk,
      folder permissions on Windows) and none of them was it. The agent log named the victim:
          [Radiuminator] Failed to launch Minecraft instance: d967e030-...
            An error occurred trying to start process
            '.../Documents/curseforge/minecraft/Install/minecraft-launcher'
            with working directory '.../Install'. Permission denied.
      `chmod +x` on what the sweep found, and the game opened with the modpack running.
      • THE BANNER LIES BY OMISSION, and that is worth knowing before the next one: the app
        knows the real error and loses it on the way out. Right after the `Permission denied`
        the log shows `Invalid enum value: General` at `toApiErrorReason` (`background.js`),
        which is it failing to map its own internal error code and falling back to the generic
        message. Any `Operation failed.` here deserves the agent log before it deserves the
        support article.
      • THE LESSON OF THE PREVIOUS ENTRY REPEATED ITSELF ONE LEVEL UP: yesterday I learned
        that "missing Java" was really a lost `+x`, and fixed `Install/java`. The name
        `curseforge-fix-java` described the SYMPTOM I had seen, not the bug. A sweep of
        `Install/` by ELF magic byte found **115** files still at 644: `runtime/` 68 (the JRE of
        the VANILLA launcher, which is what actually runs the game), `natives/` 31, `launcher/`
        8, `bin/` 6, `webcache2/` 1 and `minecraft-launcher` itself. `java/` was the ONLY
        correct tree, 133 of 133, precisely because that was what the script covered. The
        extractor loses the bit on EVERYTHING it unpacks.
      • WHAT MADE IT COST A SECOND CYCLE: yesterday's fix WORKED, and working is what made it
        look complete. `java/` came back 133 of 133 correct, so every check aimed at Java was
        green while the game still would not open. A fix that covers the tree you looked at
        proves nothing about the tree you did not.
      • The package was renamed with `git mv` to `curseforge-fix-perms` and now sweeps the whole
        `Install/` tree. It reads the 4-byte ELF magic in bash itself, with no `file` and no
        fork per candidate, because a list of names (`*/bin/*`, `*.so`) would have to guess the
        name of the next binary, and the tree grows on its own with every MC version and every
        modloader. `assets/` is pruned: 8879 content-addressed Mojang blobs, never executed, and
        the only subtree that grows without bound. That takes the sweep from ~1.0s to ~0.13s on
        every activation.
      • `Instances/` stays OUT on purpose, even with two 644 `.so` sitting in there
        (`libEffekseerNativeForJava.so`, `epicfight/.../ServerCommunicationHelper.so`): those
        are unpacked from their own jars by the MODS, at runtime, 644 on every distro, and
        `dlopen` does not look at the exec bit. That is not a lost bit, it is how those mods
        ship. The `.so` under `Install/` do get `+x` for the opposite reason: the original
        tarballs ship them 755, and restoring what the extractor lost is more defensible than
        judging one by one which ones would load anyway.
      • Rule 17 came along for the ride: renaming the package touched `flake.nix`,
        `home/apps/curseforge.nix`, `pkgs/curseforge.nix`, `README.md` and `pendencias.md`, and
        each of them was left in en-US in the same commit. The `checks.pacotes` attribute kept
        its pt-BR name for two more commits, because `.github/workflows/nix.yml` cited it BY
        NAME and that file was not touched here; it became `checks.packages` when that workflow
        was translated, later the same day.

- [x] The FAI OneDrive mounted on Linux: BUILT, MEASURED AND REMOVED, because the tenant does
      not allow it (15/08/2026). The idea was `~/OneDrive` as a normal folder in Dolphin, the
      same way as `~/Drive` and `~/FAI-workstation`: onedriver (FUSE, on-demand) through the
      official path, Microsoft Graph plus an Entra ID login, since Microsoft never published a
      OneDrive client for Linux. The module was finished and the login was actually attempted.
      It stopped at **"Need admin approval"**, and the measurement showed there is nothing to be
      done from this side. The code went out entirely (the zero-legacy rule); it can be
      resurrected with `git show 4a14cd6:home/services/onedrive-mount.nix`.
      • THE PERMISSION WAS NOT THE PROBLEM, and this is where intuition goes wrong:
        `Files.ReadWrite.All` is `type=User` in the Graph catalog (`AdminConsentRequired = No`),
        which means an ordinary user COULD consent. What blocks it is the intersection of two
        things in the FAI tenant: the policy is
        `ManagePermissionGrantsForSelf.microsoft-user-default-low`, which only allows it when
        **all** the permissions are classified as low-impact, and the ones classified there are
        only the FIVE factory ones (`User.Read`, `openid`, `email`, `profile`,
        `offline_access`). onedriver asks for `user.read files.readwrite.all offline_access`, so
        the `.All` falls outside the list and user consent dies right there.
      • CHANGING THE `clientId` DOES NOT CURE IT, and that was the obvious way out, which I
        had written in the module itself as the remedy. Registering an app INSIDE the tenant
        (possible: `allowedToCreateApps` is `true`) satisfies the policy's "apps registered in
        your tenant", but it CLASSIFIES no permission, so the same approval screen comes back.
        Necessary and insufficient. Consenting on my own was not an option either, since
        `/me/memberOf` returns only groups, no directory role.
      • HOW TO MEASURE THIS IN 3 COMMANDS, which is what was worth learning:
        `az rest --url ".../v1.0/policies/authorizationPolicy"` gives the policy;
        `az rest --url ".../servicePrincipals(appId='00000003-0000-0000-c000-000000000000')/delegatedPermissionClassifications"`
        gives what is low-impact; and `onedriver -a -n <mnt>` prints the auth URL with the exact
        `scope=`. Reading the scope from the URL, and not from a code comment, is what closed
        the case.
      • WHAT WOULD UNBLOCK IT, and both go through IT: admin consent on the app, or classifying
        the permission as low-impact. `Files.ReadWrite` (the user's drive only) would be a far
        easier ask to approve than the `.All`, but it would require patching onedriver, which
        buries the scope in the binary. With no access to IT, neither one is mine to pull.
      • WHY REMOVE IT INSTEAD OF LEAVING IT ON STANDBY: a module that is not imported is NEVER
        EVALUATED, so it does not enter `nix eval`, nor `checks`, nor the rebuild. It would rot
        silently (a package disappearing from nixpkgs, a home-manager option changing name) and
        it would give the false sense of "it is ready, just turn it on". It sat like that for 4
        days, orphaned since `6600ad0`, with nobody noticing. And there is no operational pain
        holding it: OneDrive through the web works.
      • THE MOUNT (and not sync) DECISION stays recorded here because it outlives the module: it
        is an INSTITUTIONAL account, and sync PROPAGATES a delete, so a local wipe would become
        a wipe on the FAI OneDrive, which is not mine to recover. If this ever comes back, it
        comes back as a mount.

- [x] CurseForge replaces PrismLauncher, and "missing Java" was PERMISSIONS (14-15/08/2026).
      Prism imports a modpack `.zip`, but what keeps the library and UPDATES the pack is the
      CurseForge app, which is the real use here. It is not in nixpkgs (unfree, binary-only), so
      the repo repackages the official AppImage in `pkgs/curseforge.nix`
      (`home/apps/curseforge.nix` on the user side), the same vendored-binary pattern as
      claude-desktop.
      • THE ROOT CAUSE, and it has NOTHING to do with NixOS: the app downloads its own JRE
        (`OpenJDK21U-jre_x64_linux_hotspot_21.0.4_7.tar.gz`) and unpacks it with a .NET
        extractor that does NOT PRESERVE PERMISSIONS. The binaries come out `rw-r--r--`, the
        first `java -version` dies with `Permission denied`
        (`System.ComponentModel.Win32Exception`, in the agent log) and the interface announces
        **"Java Runtime Environment is missing or out of date"**, a message that points the
        wrong way. On no distro would that Java open; the bug is CurseForge's.
      • AND IT DOES NOT HEAL ITSELF: when trying to reinstall the JRE to fix it, the
        extraction fails at `The file '…/Jre_21/NOTICE' already exists.`, because the extractor
        does not overwrite either. Which means the interface's "Retry" button runs forever
        without moving. There were TWO bugs in a cascade, and the second is what turns the first
        into a dead end.
      • THE FIX IS `curseforge-fix-java` (pkgs/), which gives the `+x` back. It runs in the
        home-manager activation on every rebuild and also by hand, because the download that
        breaks can happen IN THE MIDDLE of a session, and then it is a matter of running the
        command and reopening the app. It is idempotent and silent when there is nothing to fix.
        In the real directory it fixed **88** files, far more than the obvious manual `chmod` in
        `bin/`: there were `.so` files in subdirectories, including `lib/server/libjvm.so`.
      • THE MISTAKE THAT COST A WHOLE CYCLE, and the lesson is worth more than the fix: I
        read "No Java executable found" and concluded **"so Java is missing"**. I declared three
        Temurin JREs (8/17/21) in the FHS, with `/usr/lib/jvm` and a stable path, a pretty
        solution for a problem that did not exist. It changed NOTHING, because the app only
        consults the JRE it manages: with all three installed, the agent log went on citing
        **ITS java 18 times and ours ZERO times**. The JREs went out in the same commit they
        came in (rule 16). A third party app's error message is a HYPOTHESIS, not a diagnosis,
        and the difference between "Java is missing" and "the Java that exists does not execute"
        is a whole afternoon.
      • What pushed me into the mistake was Overwolf's support doc ("the app installs Java
        automatically") plus the `adoptium`/`java-runtime-*` strings in the asar. Both were TRUE
        and they still took me to the wrong place: it does install it, just broken. Reading the
        AGENT log (`~/.config/CurseForge/agent/logs/`, JSON, separate from the Electron log) is
        what solved it, and it should have been the first step.
      • THE FINAL TALLY: `curseforge` +340.2 MiB against `prismlauncher` -17.6 MiB and `openjdk`
        (8, 17, 21 and 25, which the Prism wrapper bundled) **-1.8 GiB**, for a total of
        **27.2 to 25.7 GiB**. The system shrank by 1.5 GiB swapping a native launcher for an
        Electron one, because nobody declares Java here: the provider is the app.
      • AppImage and NOT the `.deb`, and the reason is the same Java, from the other side.
        Both sources exist and are the same release, but what matters here is a binary the app
        DOWNLOADS at runtime (the JRE, the Forge installer, Minecraft), and none of that goes
        through `autoPatchelfHook`, which only reaches what is in the store. This system's
        `programs.nix-ld` covers the LOADER (the `/lib64/ld-linux` here points at it, and that
        is why the app's JRE ran on the host after the `+x`), but not each one's libraries.
        `appimageTools` wraps it in `buildFHSEnv`, where the loader exists and
        `container-init.cc` also puts `/run/opengl-driver/lib` in the `ld.so.conf`, so Minecraft
        launched as a child inherits the FHS **and** the Arc B580 driver. It is the FHS that
        makes the package work, not patchelf.
      • THE `.zip` THE TUTORIALS TELL YOU TO DOWNLOAD IS DEAD:
        `curseforge-latest-linux.zip` has a `last-modified` of **10/08/2025** and carries
        1.285.2. The `.AppImage` and the `.deb` in the same folder are from **05/08/2026** and
        bring 1.316.0-37372, confirmed by the app's own updater on the first boot ("latest
        version: 1.316.0-37372"). Following the popular tutorial would install an app a year
        behind.
      • THE LOGIN DEPENDS ON AN ASSOCIATION THE APP CANNOT MAKE ON ITS OWN. It tries to
        register as the handler for `cfauth://` at runtime (Electron
        `setAsDefaultProtocolClient`), and that will NEVER work here:
        `~/.config/mimeapps.list` is managed by home-manager and points into the store, which is
        read-only (rule 14). The log says right at startup `Failed subscribing app protocol.`
        and `Failed to register login scheme 'cfauth'`. Since `cfauth://` is the login CALLBACK
        (the app opens the browser and waits for the redirect), with no handler the login comes
        back to nothing, hence the three schemes declared in `xdg.mimeApps` in the app's module.
      • A POINTER URL, the same hole as VS Code's `/latest/`: Overwolf only publishes
        `curseforge-latest-linux.AppImage` (tested `-1.316.0-`, `~37372` and `latest.yml`, all
        404). The pinned hash keeps the build reproducible, but it rots on their next release.
        The remedy is `pkgs/curseforge-bump.nix`, a sibling of `vscode-bump`, on the `update`
        alias. With one aggravating factor: there it was enough to change the number, here the
        HASH has to be RECOMPUTED. To avoid downloading 139 MiB on every `update`, what answers
        "did it change?" is a 256 KiB range request on the `.deb` (the `control` sits in the
        first few KiB); the AppImage is only downloaded when the answer is yes.
      • That is why `curseforge` is the ONLY exception in `checks.packages` (flake.nix): leaving
        it there would paint the CI red on every Overwolf release, for something that is not in
        this repo. `curseforge-bump` DOES enter the check, because its shellcheck is stable.
      • TWO THINGS I HAD WRITTEN WRONG AND MEASUREMENT KNOCKED DOWN: (1) that `--no-sandbox` was
        necessary, when running `bin/curseforge`, which passes no flags at all, the app opens
        and loads the library normally, because the `buildFHSEnv` bwrap already gives Chromium
        the namespace it wants; the flag stayed only because it came from the upstream
        `.desktop`. (2) that GNU tar would autodetect the compression in a pipe, when it only
        autodetects if it can seek, so `ar p … | tar -xO` dies with "Archive is compressed. Use
        -J option". The bump goes through a file, which as a bonus makes it survive the day
        `.xz` becomes `.zst`.

- [x] Hovering the VPN pill shows the tunnel's quality (14/08/2026). The pill only answered "is
      there a tunnel?"; what was missing was "and is it any good?", which is the question of
      whoever has SSH or a call depending on it. Now HOVER opens `bar/VpnStatsPopover.qml`
      (latency, jitter, loss, a graph of the series, session traffic, uptime) and CLICK still
      opens the usual `VpnPopover`, with connect/disconnect. Information on hover, ACTION on
      click.
      • DIVISION OF LABOR: `vpn stats-json` (new) delivers the STATE (iface, IP, MTU, uptime,
        session bytes and WHICH host serves as the probe target) and the bar MEASURES the
        latency with a continuous ping. It did not become a field of `status-json` because that
        one is the 5s polling that paints the pill and has to be cheap; this one only runs with
        a tunnel up. Discovering a target (sweeping routes, testing candidates, memorizing) is
        shell work; observing all the time is the work of whoever stays open.
      • THE OBVIOUS PROBE TARGET DOES NOT WORK: the FAI ppp peer is `192.0.2.1`, which is
        TEST-NET-1, a facade address of the SonicWall, and it ignores ICMP (MEASURED: 100%
        loss). What answers is `200.136.209.236` (fai.ufscar.br): a public IP, but the
        `200.136.209.128/25` route goes out through ppp0, so the ping measures the TUNNEL. A
        baseline measured at 1 packet/s: ~34ms average, 0.8ms mdev, 0% loss, and that is where
        the verdict's cutoffs come from (stable / slow / unstable / bad).
      • The `ping -I <iface>` is not a style detail: it pins the packet to the tunnel
        (SO_BINDTODEVICE). Without it, a target that stopped being routed through the VPN would
        go out over the home internet and the panel would display a GREAT latency that is not
        the tunnel's. A wrong number is worse than a missing number, and with the bind that case
        becomes "no probe". MEASURED PROOF: the same target pinned to `enp7s0` gives 100% loss,
        so the displayed number cannot come from outside the tunnel.
      • THE 1st VERSION MEASURED IN BURSTS AND THE NUMBERS WERE PRETTY AND FALSE. The panel
        was already finished and approved ("it is all correct") when the question "are these
        numbers reliable?" knocked down half of it. It pinged 3 packets every 20s. MEASURED side
        by side at the same hour: the burst gave an mdev of **0.4ms**; a 20s window gave an mdev
        of **3.3ms with a peak of 54.7ms**. Which means it observed 0.6s out of every 20s (3% of
        the time), so a 2s hiccup was invisible in 97% of cases, and the loss, with 3 packets,
        had a RESOLUTION OF 33%: 1 to 3% of real loss showed up as "0%". Only the average
        survived the audit (33.6 against the 34.4 of the 40 packet reference). The lesson: a
        short sample does not answer a question about STABILITY, and a panel displaying half a
        second of jitter with a monitoring look lies by omitting the scale.
      • THE FIX was turning it into a CONTINUOUS probe at 1 packet/s (the VpnProbe component, in
        `Bar.qml`) with statistics over a window of the last 60 packets: real jitter, loss with
        1.7% resolution and one bar per second in the graph. Measured cost: 84 B/s, and 30
        packets at 1/s gave 0% loss, so the target does not rate-limit at that cadence.
        The ping's `-O` is MANDATORY: without it, a lost packet is SILENCE and the series would
        contain only the ones that came back, an eternal 0% loss, the same kind of lie again.
      • `ping` is line-buffered even when writing to a pipe (verified: one line per second, with
        no `stdbuf`), which is what makes reading the stream viable.
      • A WATCHDOG, because a dead probe is the worst possible failure HERE: with `-O` the ping
        speaks every second even when the target disappears, so SILENCE is not packet loss, it
        is the process broken. Without a watchdog the panel would freeze displaying the last
        good window, looking "stable", which is exactly the lie it exists not to tell. 5s
        without a line means marking the hole in the series and resurrecting the ping. TESTED by
        killing the probe: it came back in 10s.
      • THE TUNNEL DROPPED AND CAME BACK in the middle of the work, and it taught two things.
        (1) The `ping -I` does NOT die on the reconnect: ppp0 is called ppp0 again and the bind
        re-resolves, verified through the process's `wchar`, which kept growing at ~1 line/s.
        (2) Precisely because of that, the series would splice two different tunnels as if they
        were one; the IP entered the probe's key (it changed from 192.168.50.2 to .3) to force a
        new series.
      • To VALIDATE a QML change here, use `qs-restart`: the hot-reload kept a Timer from the
        old tree ALIVE (a debugging `console.log` kept coming out after the file was already
        clean and the log said "Configuration Loaded"). quickshell.nix already warns that the
        hot-reload does not reapply everything, and that holds for an object with a
        Timer/Process, not only for a Repeater delegate.
      • THE GRAPH exists because "is it stable?" is a question about TIME: a lone "34 ms" does
        not distinguish a smooth tunnel from one that swung 30 to 900ms in the last minute. The
        scale starts at ZERO (the ceiling is 60ms, or 15% above the peak), because auto-scaling
        from the minimum would turn 0.5ms of variation into a dramatic sawtooth, the opposite of
        an honest reading.
      • Two QML traps, both with a silent symptom: a `readonly property real top` in the
        delegate dies with "Cannot override FINAL property" (the name collides with the Item
        inheritance) and became `scaleTop`; and an INLINE COMPONENT DOES NOT SEE THE `id` OF THE
        DOCUMENT that declares it, so the `root.vpnStats[...]` inside VpnProbe blew up with a
        ReferenceError, the instance was never born, and what complained was the POPOVER, an
        `undefined` three files away from the cause. The data started ARRIVING through a
        property.
      • The target is memorized in `$XDG_RUNTIME_DIR/vpn-probe-<id>`, keyed by iface+IP: a new
        tunnel means a new probe, and "not found" is reevaluated every 5 min (otherwise a target
        that was down at the instant of connection would condemn the panel to "no probe" until
        disconnecting).
      • The panel was born at 300px and the footer cut off the probe's IP ("200.136.209…"). It
        went to 360 with a two-line footer: a diagnostic panel that elides data is
        self-contradictory, because whoever opens it is precisely after the detail.

- [x] Azure MCP Server, and ONLY on the FAI account (14/08/2026). The request was to work on
      portal.azure.com by command instead of clicking through the interface. It became
      `pkgs/azure-mcp.nix` (the `azmcp` binary) plus an `mcp` field in the `profiles` of
      `home/shell/claude-code.nix`.
      • WHY PACKAGE IT instead of following Microsoft's recipe: the docs say
        `npx -y @azure/mcp@latest server start`, which rule 13 forbids twice, an implicit
        "latest" AND a fetch with no hash ON EVERY SERVER START, which means the MCP could
        change version in the middle of a session. The npm `@azure/mcp` is only a JS shim that
        picks, in the postinstall, one of the six `@azure/mcp-<os>-<arch>`; what has the server
        is the platform package, and inside it comes ONE self-contained .NET binary of 150 MB.
        So we fetch the platform tarball directly and `nodejs` leaves the closure entirely.
      • THE FINDING THAT COST THE FIRST TWO ATTEMPTS: `runtimeDependencies` (RPATH) does NOT
        resolve this binary's libs, and the error does not say why. With nothing:
        `Couldn't find a valid ICU package`. With icu+openssl in the RPATH: ICU passes and then
        comes `No usable version of libssl was found` plus a core dump. The reason is that it is
        single-file and it UNPACKS the native .NET libs into `~/.net/azmcp/<hash>/` on the first
        start (`libpal_azure_c_shared_openssl3.so` is there), and it is that extracted .so,
        outside the store and with none of our RUNPATH, that does the dlopen. LD_LIBRARY_PATH
        through `makeBinaryWrapper` is inherited by the extracted libs and resolves it; and
        `makeBinaryWrapper` (execv in C) and not a shell wrapper, because .NET finds
        `Instrumentation/Resources` through /proc/self/exe, which is only right AFTER the exec.
      • `azure-cli` IS NOT NECESSARY FOR THE LOGIN, and that is worth recording even though it
        came in later for another reason (the item that follows): Microsoft's docs and azmcp's
        own error message tell you to install it, but the DefaultAzureCredential chain ends in
        DeviceCodeCredential, the "open login.microsoft.com/device and type ABC123" one, which
        works on its own. It was only failing with `Persistence check failed`, which is NOT a
        credential issue: it is the MSAL token cache trying to talk to the Secret Service.
        `libsecret` and `dbus` were missing, and this machine already has both through the
        keyring. With those two in LD_LIBRARY_PATH the device code came out immediately
        (verified: the code was emitted, with no login). The `msalruntime`/libX11 in the error
        log are the WAM broker, which only exists on Windows, so ignore them.
      • AND THEN CAME THE CORRECTION THAT KNOCKED DOWN THE PREMISE: the Azure MCP Server
        does NOT COVER APP REGISTRATION, which was the REAL reason for all of this ("I do not
        want to touch that interface anymore"). I had delivered the MCP without checking whether
        it did the one thing that was asked. MEASURED in `tools/list`: among the 68 tools there
        is no App Registration, no service principal and no Graph; `role` is Azure RESOURCE
        RBAC, not an Entra app; and `extension_cli_generate` only GENERATES the text of the `az`
        command, it never executes. Microsoft does not publish an Entra MCP either, since
        `microsoft/mcp` only has Azure, Fabric and a template. The `entra-app-registration` from
        `microsoft/azure-skills`, which looked like the missing piece, is a SKILL (guidance
        markdown) and not a tool: what it teaches the agent to do is run
        `az ad app create/list/show/permission add/…`. Which means what does the work is
        `azure-cli`. It went in (home/packages.nix), and the cost is 0.95 GiB MARGINAL and not
        the 1.19 of the closure, since 0.24 was already on the system.
        THE LESSON, and it is about method, not about Azure: "the official tool for service X"
        does not imply "it covers the part of X you want". The tool list is cheap to read (a
        JSON-RPC handshake over stdio) and it should have come BEFORE the package, not after.
      • WHY THE MCP IS PER ACCOUNT and not global: the cloud is the work one, and there are 68
        tools in `--mode namespace` (counted through a JSON-RPC handshake straight at the
        binary) that have nothing to do on the personal account. So
        `profiles.fai.mcp = [ azureMcp ]` and `profiles.pessoal.mcp = [ ]`, and the account that
        does not declare it does not get the flag.
      • THE `--mcp-config` TRAP, measured on CC 2.1.222, and the rule is the OPPOSITE of the
        intuition: the flag is VARIADIC, so it swallows everything until it finds a token
        starting with "-". With no terminator, `claude-fai mcp list` dies with
        `MCP config file not found: …/mcp` (it read `mcp` and `list` as two more files). But the
        `--` fixes ONLY the subcommand and BREAKS the flag: with it, `claude-fai --version`
        opens a session with "--version" as the prompt. Hence the `case` in the wrapper:
        starting with "-" (or empty) goes without `--`; a bare word goes with it.
      • THREE PATHS REFUSED: (1) the root `.mcp.json`, which is where the two Cloudflare MCP
        servers live, because it is PROJECT scope, so Azure would only exist when running
        `claude` inside the dotfiles, which is precisely where we will never touch Azure;
        (2) user scope in `.claude.json`, which is app state, since CC rewrites the whole file
        (rule 14); (3) `/etc/claude-code/managed-mcp.json`, which LOOKS like the right place for
        being the sibling of the hooks' managed-settings.json, and is a trap: whoever deploys
        that file gains EXCLUSIVE control and CC stops loading everything else, including the
        MCP servers from the `github` and `atlassian` plugins, which are in use. It would gain
        one and lose two.
      • AS A BONUS, THREE ROUGH EDGES IN THE MODULE: plain `claude` became a wrapper (it was the
        raw binary, and without this the MCP would not reach the VS Code extension, which calls
        the binary from the PATH); the `.claude-fai` that was written twice became
        `defaultProfile` (rule 11); and `claude-pick` stopped repeating the CLAUDE_CONFIG_DIR
        logic, since the menu now carries the WRAPPER PATH and it only does an `exec`, so it
        inherits the MCP and the variable for free.
      • THE LOGIN HAS TWO TRAPS, and both LIE about what happened. The first: a plain
        `az login`, on an account whose tenant has no subscription, ends in
        `No subscriptions found` and PERSISTS NOTHING. The authentication passed; it was `az`
        that aborted afterwards, and the following `az account list` says "Please run az login",
        which reads as "your password failed". The right form is
        `az login --allow-no-subscriptions --tenant <id>`, and it is not a corner case: an App
        Registration is a DIRECTORY object, so the work tenant here legitimately has no
        subscription at all. The second: `az ad app list` on its own lists nothing, it requires
        a selector (`--show-mine` for the ones you own, `--all` for the whole tenant, which then
        asks for an admin role in Entra).
      • TWO IDENTITIES, with OPPOSITE roles, and that decides which tool serves what:
        `FAIUFSCar` (80241bb1-cb3b-4da2-98ae-3029430fdbcd) is directory only, which is where the
        App Registrations live and is the target of `az ad`;
        `BHS` (92247c24-8a8c-47f3-a7f1-85df939ad4b6) is the one with a subscription, and it
        requires MFA (`AADSTS50076`, tenant configuration, not a defect here). Which means: App
        Registration = `az ad` on FAIUFSCar; the MCP's 68 tools, which operate over a
        subscription, only have work to do on BHS.
      • VALIDATED END TO END: `nixos-rebuild build` OK; the server comes up (`initialize` plus
        `tools/list` through JSON-RPC over stdio); the `system/init` of a headless session lists
        `{"name":"azure","status":"connected"}` next to the plugins; `az ad app list
        --show-mine` returned the tenant's 3 apps; and `azmcp subscription list` started
        answering `status 200` with `subscriptions: []` instead of 401, which proves that
        AzureCliCredential closes the chain and the device code became plan B, not the path.

- [x] The hyprsunset curve comes down again after 18:00 (13/08/2026). The question that opened
      this was a different one: "is hyprsunset starting along with the PC? because it does not
      look like it". **There was no defect at all in the autostart**, and the reason it "does
      not look like it" is the config itself.
      • THE MEASUREMENT THAT DISPROVED THE SYMPTOM: boot at 11:58:58, the service active at
        11:59:05, 7 s later, and the FIRST thing it did was `Applying profile from: 8:0` then
        `Resetting the matrix (--identity passed)`. Which means it came up and applied the
        filter TURNED OFF, because from 08:00 to 17:30 the profile is `identity`. Nothing
        visible at boot was the CORRECT behavior. The service is `enabled`, 8 h up, 234 ms of
        CPU, zero restarts.
      • A GENERAL TRAP, which holds beyond this service: an automation whose correct state is
        "no visible effect" canNOT be audited by eye. I came close to treating perception as
        evidence of failure; what closed the question was the journal (`Switched to new profile`
        hour by hour: 17:30 to 5500K … 20:00 to 3200K) plus `hyprctl hyprsunset temperature`
        matching the profile for the clock time.
      • THE CTM REACHES BOTH SCREENS, and that was VERIFIED, not presumed: an A/B through IPC
        (`identity`, then 3000K, then back to the profile) with me watching. It changed on DP-2
        and on the LG TV over HDMI. It mattered to confirm that before touching the curve,
        because if one output did not receive the CTM, no Kelvin adjustment would solve
        anything, and the 08/08 history already records that hyprsunset applies to ALL outputs
        or to none (it cannot target an output).
      • THE CHANGE, then, is one of PREFERENCE and not a fix: every step after 18:00 came down
        ~200 to 400K (18:00 4200 to 3800, 19:00 3500 to 3200, 20:00 3200 to 3000, 22:00 2800 to
        2600, 23:00 2500 to 2400). There are still 13 profiles and the biggest step is still at
        18:00 (now 5000 to 3800).
      • THE COLOR AXIS WAS CHOSEN AGAINST WHAT ideas.md RECOMMENDS. It is recorded there that
        reducing BRIGHTNESS comes before color temperature, and that "night mode does not
        replace adequate brightness"; the post-18:00 curve still touches only Kelvin, with gamma
        entering only at 22:00. It was a conscious choice of mine after seeing both proposals
        side by side, not carelessness: the automatic gamma dim existed and was REVERTED on
        08/08 along with the DDC, and reintroducing it is a bigger change than lowering Kelvin.
      • WHAT STAYS OPEN and is noted in the module header: if this curve is not enough, the next
        step is progressive gamma from 18:00 on, and **not** continuing to lower Kelvin, which
        from here down makes the color worse with no proportional relief.
      • THE ACCEPTED PRICE: the curve now crosses ~3200K on purpose, and the `hyprsunset.nix`
        header warned that below that the color ruins a film, a game or a photo. From 19:00 on
        that becomes the NORM, so SUPER+SHIFT+F9 (`identity`) stops being a rare escape hatch
        and becomes a routine gesture for opening media at night. The next profile on the clock
        resumes the curve by itself.

- [x] `/mnt/arch-antigo` mounted ALWAYS, and `arch-browse` died (11/08/2026). The symptom was
      opening the Dolphin bookmark and seeing an empty folder. There was no defect: the secrets
      were readable, the repo answered, and the mount came up in ~20 s when asked. The defect
      was the DESIGN, an automation with no declared owner (rule 15), alive only while the
      alias's terminal stayed open. It became a service:
      `home/services/arch-legacy-mount.nix` (the unit that mounts) plus
      `system/services/arch-legacy.nix` (the mountpoint and the path's SSOT, which the bookmark
      started reading, rule 11).
      • WHY TWO FILES, and it is not rule 4 fussiness: whoever MOUNTS has to be the user (a FUSE
        mount is private to whoever mounted it; `sudo restic mount` produces a folder Dolphin
        cannot open), but whoever CREATES the directory has to be root, because /mnt is root's.
        And the option is born on the system side because a system module cannot read a
        home-manager option, while the reverse does not exist.
      • The directory left `restic.nix`, where it was created along with /mnt/backup. There it
        was tied to the `restic` toggle: turning the backup off would start taking down a mount
        that is now PERMANENT, and the failure would show up far from the cause.
      • `--no-lock`, and this was MEASURED, not economized: every `restic mount` creates a
        non-exclusive lock and renews it every ~5 min, and a mount that does not exit cleanly
        leaves the lock STUCK. The repo had 3 locks: one from the live mount and leftovers from
        `arch-browse` on 05/08 and 08/08. Permanently, that would only get worse, and it would
        also write to the offsite repo every 5 min forever. The lock protects concurrent reads
        against PRUNING, and this repo is static: nothing has written to it since 01/08 and no
        routine prunes it (`forget --prune` only looks at the HOME repo). Checked afterwards:
        the mount is up, 0 locks.
      • The `Type = "notify"` from ~/Drive canNOT be copied: `restic mount` does not speak
        sd_notify (there is no "notify" in the 0.18.1 `--help`). With Type=simple, systemd would
        declare the unit ready before the mountpoint existed, reproducing the very symptom the
        change came to kill. Hence the ExecStartPost that waits for `mountpoint -q`
        (writeShellApplication, rule 7), with TimeoutStartSec=180 so the wait fits.
      • The rclone binary goes PINNED in `-o rclone.program=`: the `rclone:` backend EXECUTES
        rclone and a systemd unit does not inherit the PATH, the same trap that already killed
        the backup service ("executable file not found in $PATH"), solved without depending on
        the PATH. And the rclone.conf is a WRITABLE COPY in `%t`, in a file of its own (not
        ~/Drive's): without that, the renewed OAuth token produces `Failed to save config` in
        the journal, and in a 24/7 service a recurring ERROR hides a real one.
      • THE PRICE, measured: ~195 MiB of resident RSS (115 from restic with the index of the
        44.6 GiB snapshot plus 79 from `rclone serve restic`). On the network, idle, it is ZERO,
        because restic does not poll. The bookmark comment said a permanent mount would be "an
        open connection and a lock on the repo for nothing": the connection is real and became a
        conscious choice, and the lock stopped existing. And the Dolphin thumbnail warning got
        MORE important, not less, because previews read content, every read downloads packs, and
        now the folder is always one click away.
      • An empty folder there stopped being a normal state and became a SYMPTOM: the diagnosis
        starts at `systemctl --user status arch-antigo-mount`.

- [x] The `switch` that activated but did not become the boot, because of an UNRELATED unit
      (11/08/2026): the `rebuild` for the mount above ended with `Activation (test) failed`
      (exit 4) and the culprit was `vpn-fai`, which had nothing to do with the change. It was
      already flapping before (a restart counter at 43) because the FAI server answers
      `"Password change needed"`, an expired institutional password. `nh` runs the activation in
      `test` BEFORE pinning the generation, and it aborted the `boot` phase.
      • THE DAMAGE IS SILENT and does not show up at the time: `/run/current-system` was
        already the new generation (everything working in the session), but
        `/nix/var/nix/profiles/system` stayed on the OLD one, which means the next boot would go
        back to the system without the change. Whoever does not compare the two does not see it.
        A one-command diagnosis:
        `readlink -f /run/current-system /nix/var/nix/profiles/system`, and equal means it
        closed.
      • THE LESSON, which is bigger than this case: a unit failing for an EXTERNAL reason (an
        expired password, a remote service down) hijacks the entire switch. A `systemctl stop`
        on it plus rebuilding again solved it, since `vpn-fai` is `linked` with no `WantedBy`,
        so stopping it loses nothing, because it does not come up at boot anyway.
      • Pending on the FAI side: change the password in the portal and update `fai_vpn_password`
        in sops (it feeds the `nxbender-fai.conf` template, `system/net/vpn.nix`) plus a
        rebuild. Until then, `~/FAI-workstation` and `ssh workstation` stay out.

- [x] `claude-fai` / `claude-pessoal`: TWO Claude Code accounts, and `~/.claude` stopped being
      one of them (11/08/2026). On Arch that was two aliases and a shell function in `~/.zshrc`
      (`_claude_share_projects`), running on every terminal open. It became
      `home/shell/claude-code.nix`: a `profiles` attrset that is the accounts' SSOT and
      generates everything, the wrappers, the `claude-pick` menu, the `settings.json` symlink
      and the `projects/` symlink. A new account is one entry in it plus a
      `settings-<name>.json`.
      • I GOT THE FIRST VERSION WRONG, and the mistake is instructive: I created an EMPTY
        `~/.claude-fai` next to `~/.claude`, which ALREADY WAS the FAI account
        (`oauthAccount.emailAddress` = victor.ferreira@…, a nonprofit premium seat). That would
        be two logins for the same subscription, and the "third account" would exist purely by
        accident of naming. I copied the Arch topology (default + 2) without checking WHO each
        folder was HERE. The lesson: in a migration, the question is not "which folders existed
        there", it is "what each folder IS here", and the answer was one
        `jq .oauthAccount ~/.claude.json` away.
      • Plain `claude` became FAI, through `home.sessionVariables.CLAUDE_CONFIG_DIR`. It catches
        everything that calls the binary without going through the wrappers: the VS Code
        extension, a script, cron.
        It only applies in a NEW shell (hm-session-vars.sh is read at the start of the
        session), so the terminal that ran the `rebuild` stays on `~/.claude` until it is
        closed. The same trap as NH_FLAKE on 03/08, with the difference that here a new terminal
        already solves it.
      • `~/.claude` STILL EXISTS, now as the ARCHIVE and not as an account: `projects/` (200 MB,
        13 projects, 39 memories from this repo) belongs to the MACHINE, not to a subscription.
        Staying on the canonical path lets third party tooling find it by itself and prevents
        retiring an account from one day orphaning the archive. Considered and refused: moving
        it inside `.claude-fai` (asymmetric) and moving it to a neutral path (200 MB moved with
        a live session writing there).
      • WHAT MIGRATED from `~/.claude` to `~/.claude-fai`, because it is the SAME account: the
        installed plugins (8.1 MB, `github`/`atlassian`/`frontend-design`, which the repo's
        `settings-fai.json` started declaring instead of the Arch ones, otherwise the migration
        would silently turn them off), `settings.local.json` (permissions already approved),
        the `.claude.json` WITHOUT `oauthAccount`/`claudeCodeFirstTokenDate` (17 trusted folders
        preserved, the account fields left for `/login` to rewrite) and `history.jsonl`
        concatenated with the Arch one, 128 + 1705 lines, and the concatenation is chronological
        for free because the windows do not overlap (Arch ends in june, this machine starts in
        july).
      • A WRAPPER INSTEAD OF AN ALIAS, and the difference is not cosmetic: an alias only exists
        in an INTERACTIVE zsh, so on Arch `claude-fai` did not work over non-interactive SSH,
        inside a script, in a VS Code task or in a Hyprland keybind. Now they are binaries
        generated by `writeShellApplication` (rule 7: the logic in the build), which for free
        PINS the version of the `claude` being called, and that matters here, because this
        machine has an orphan native install in `~/.local/bin` that `claude doctor` complains
        about and that the PATH could resolve first.
      • WHAT DECIDED THE `settings.json` DESIGN, and it was MEASURED instead of assumed: the
        file is linked into the repo through `mkOutOfStoreSymlink`, the same contract as VS Code
        (home/apps/vscode.nix), and that is only safe if CC does not replace the symlink with a
        regular file on save. It writes ATOMICALLY (tmp + rename), which would KILL the link,
        but it resolves the realpath FIRST: running `claude auto-mode reset` in a test profile,
        the symlink stayed intact and what changed inode was the TARGET (593793 to 593844). In
        other words: the TUI's `/config` keeps working and every adjustment lands as a
        `git diff` instead of invisible drift (rule 16). If CC ever loses that guard, the
        symptom is `~/.claude-fai/settings.json` no longer being a symlink and the repo no
        longer receiving anything.
      • Do NOT point `CLAUDE_CONFIG_DIR` at `~/.claude` to "reuse" the default account: the
        `.claude.json` (project/MCP config, distinct from `settings.json`) lives at the ROOT of
        `CLAUDE_CONFIG_DIR`, which in the default case is the home's `~/.claude.json`, and with
        the variable pointed at `~/.claude` it would become `~/.claude/.claude.json`, a SECOND
        divergent file. Verified on 2.1.222, along with the rest: `claude mcp add` with a
        symlinked `.claude.json` wrote THROUGH the link.
      • TWO CONFIGS DIED IN THE CROSSING (rule 16) and that is why the `settings-*.json` are not
        a faithful copy of the Arch ones: the `permissions.allow` with `mcp__pencil` and the two
        user MCP servers that were in both accounts' `.claude.json`, `pencil`
        (`/opt/pencil-dev-bin/…`, an AUR package that does not exist on NixOS) and `atlassian`
        (through `npx mcp-remote`, today done by the `atlassian@claude-plugins-official` PLUGIN,
        which the default account already uses). Migrating a permission for an MCP server that
        does not come up is declaring the nonexistent.
      • `projects/` IS STILL SHARED, now through a declared symlink: it is where the transcripts
        AND the per-project memory live (`…/projects/<slug>/memory/`), so any account resumes
        the same conversations and reads the same memories. A known price: `ccusage` does not
        separate cost per account, because it reads the common archive, so the number belongs to
        the machine, not to the subscription.
      • THE STATE CAME FROM RESTIC, NOT FROM THE REPO (rule 6): the `history.jsonl` of both
        accounts (128 and 179 prompts) came out of the Arch backup through `restic dump`, with
        nothing mounted, which is the better path when you want a specific file and not to
        browse. The `.credentials.json` was NOT restored on purpose: a 7 week old token from a
        decommissioned machine is worth less than a clean `/login`, and a credential is neither
        declared nor copied by a script (rules 6 and 12).
      • The `writeShellApplication` shellcheck failed the first build with SC2155
        (`export X="$(cmd)"` masks the command's exit code). Rule 7 paying for itself in the
        build instead of in a runtime bug.

- [x] VT-x turned on in the BIOS, and the next step this history told me to take is NOT
      necessary (11/08/2026). The Cowork entry (08/08) closed with "turn VT-x on and ONLY THEN
      add `users.users.v1cferr.extraGroups = [ "kvm" ]`, which did not go in because it is not
      validatable without the device". The device exists now, so it could be validated, and the
      validation DISPROVED the plan.
      • VT-x confirmed: `vmx` in the `/proc/cpuinfo` flags, `kvm_intel` loaded, `/dev/kvm`
        created at 07:11. The `VMX (outside TXT) disabled by BIOS` lines are gone from the log.
      • The `kvm` GROUP DOES NOT GO IN: `/dev/kvm` is born in **mode 666** (a udev rule NixOS
        already ships), group `kvm`. It was measured that `v1cferr` has read AND write on it
        WITHOUT being in the group. Adding the `extraGroups` would declare a permission the
        system already gives everyone, which is dead config by rule 16, on the same day the rule
        was born.
      • THE LESSON is about the shape of the note, not about kvm: "do X and THEN do Y" records a
        HYPOTHESIS about Y as if it were a plan. When X finally happens, Y gets executed with
        nobody rechecking whether it still makes sense, and here it did not. A note about a
        future step should carry the TEST that decides whether it is needed
        (`test -w /dev/kvm`), not only the action.
      • Secure Boot is still `Disabled` and that did NOT regress: `Setup Mode: Disabled` says
        the keys are still enrolled, so only Phase 4 of the guide remains, flipping the switch.
      • As a bonus, the colorize diagnosis confirmed itself: **19 h without a single abort**
        (the last one on 10/08 18:30) against one every 30 to 60 min before. The coredumps that
        still show up in `coredumpctl` all predate the removal, so they are a record, not
        activity.

- [x] GNU coreutils across the whole `cesar` machine, and nothing had to be installed
      (11/08/2026). Git for Windows already bundled the complete userland (coreutils 8.32,
      grep 3.0, sed 4.9, awk, less, vim) in `C:\Program Files\Git\usr\bin`; it just was not
      exposed, because the Git installer puts only `Git\cmd` on the PATH. The change was ONE
      entry in the machine PATH.
      • **The whole decision is in the ORDER: append at the END, never at the front.** That
        directory brings `find.exe`, `sort.exe`, `tar.exe`, `link.exe` and `echo.exe`, all with
        a Windows namesake of different semantics. Prepending, which is what the Git installer
        offers as an option, with a warning, breaks `.bat` scripts and MSVC builds, because the
        MSYS `link.exe` is not Microsoft's linker. At the end, you gain everything that does not
        conflict and lose nothing. MEASURED with `where`: `find`/`sort`/`tar` still resolve to
        System32, and `ls` resolves to the GNU one because only one exists.
      • IN POWERSHELL THIS PAYS OFF LESS THAN IT LOOKS, and it is not a PATH problem: `ls`,
        `cat`, `cp`, `rm`, `sort`, `curl` and `echo` are native ALIASES, and an alias always
        beats the PATH. There it is `ls.exe` by hand. In `cmd` there are no aliases and it works
        directly; inside bash the question does not even come up.
      • Applied through `powershell -EncodedCommand` (base64 UTF-16LE) instead of nested quotes:
        the command crosses zsh, ssh, cmd and powershell, and each layer eats a level of
        quoting. A `dir /b "C:\...\usr\bin" | find /c` even reported "path not found" on a
        directory that EXISTED, purely from cmd's mangling in the pipe, and it almost became
        "this Git installation is minimal and does not have the utilities".
      • The script is idempotent (`-split ";" -notcontains`), because a machine PATH is exactly
        the kind of thing you apply twice without noticing.
      • **The guide was born**:
        [`docs/guides/cesar-windows-manual-steps.md`](../../guides/cesar-windows-manual-steps.md),
        covering the authorized key, the PATH, Scoop and Claude Code. Those are the steps Nix
        does NOT reach (the machine is not NixOS and is not mine), and without them written down
        a Windows reinstall would become rediscovery from scratch. The same nature as the
        OpenWrt router's `authorized_keys`.
      • VERIFIED as a bonus that `SetEnv TERM` is still unnecessary: inside Git Bash, `TERM`
        already comes as `xterm-256color`, set by the shell itself. The 10/08 decision not to
        send the variable holds now that the shell has changed.

- [x] `ssh cesar`: my brother's PC became a declarative host (10/08/2026). Access already
      worked by hand (`ssh v1cferr@192.168.1.40`); what went into home/shell/ssh.nix was the
      alias and, above all, the record of WHY this host looks like none of the other three: it
      is the only **Windows** one in the file.
      • **Inheriting `faiResilience` would be cargo cult.** That block exists to tolerate the
        SonicWall tunnel's routing hole within VS Code Remote-SSH's 17 s budget. Here it is a
        LAN hop, <1ms, the same decision already taken for `router`, and the file's pattern
        becomes "resilience is opt-in, not default".
      • **No `SetEnv TERM`, unlike the other three hosts.** The default shell of the Windows
        sshd is **cmd.exe**, which does not read TERM, and their sshd does not carry
        `AcceptEnv`, so the variable would be discarded at the server. Copying it for symmetry
        would give a line that does nothing and that the next reading would try to "fix".
      • **The post-quantum warning on every connection is NOT our error.** The server is
        `OpenSSH_for_Windows_9.5` (measured with `-v`), and `mlkem768x25519` only exists from
        OpenSSH 9.9 on; Windows 11 build 26200 still ships 9.5. It only goes away when MS
        updates Win32-OpenSSH. REFUSED to silence it with `WarnWeakCrypto = "no"` (it exists in
        our 10.4): silencing it per host hides the server's real lag, and the day it gets fixed
        would go unnoticed. The warning is honest noise.
      • **`ssh-copy-id` does NOT work against Windows**, because it assumes a POSIX shell on
        the other side, and on the other side there is cmd.exe. The manual step is run ON my
        brother's machine, and WHICH file depends on whether the user is an administrator: if
        they are, the Windows sshd **ignores** their `~/.ssh/authorized_keys` and only reads
        `C:\ProgramData\ssh\administrators_authorized_keys`, which still requires `icacls`
        restricting inheritance, otherwise sshd refuses the file and falls back to the password
        **silently on the client side**. DONE the same day, and validated with
        `ssh -o BatchMode=yes ... "echo OK"`: `BatchMode` forbids the password prompt, so the
        `OK` proves it was the KEY that authenticated; without it the test is ambiguous, because
        you type the password and conclude the key worked.
      • `Add-Content -Encoding ascii` is not fussiness: PowerShell's default for a file is
        UTF-16, and sshd does not read `authorized_keys` in UTF-16, a SILENT failure that falls
        back to the password without saying why. The same class of trap as the `icacls` one:
        both ways of getting this wrong are silent and indistinguishable from each other.
      • The account PASSWORD was changed along with it, and the decision was MEASURED first:
        Windows distinguishes CHANGING a password (with the old one in hand, which re-wraps the
        DPAPI master key) from RESETTING it (`net user v1cferr *`, which makes it unrecoverable
        and takes Credential Manager, browser passwords and EFS along with it, all silently).
        There is no "change" path from the command line without P/Invoke, and over SSH there is
        no Ctrl+Alt+Del. The reset was safe because `cmdkey /list` came back `* NONE *` (nothing
        to lose) and `Get-LocalUser | Select PrincipalSource` came back `Local`; had it come
        back `MicrosoftAccount`, neither `net user` nor `Set-LocalUser` would change anything,
        because the password would belong to the MS account.
      • A literal IP (192.168.1.40) and not a `my.*` option: it is cited in a single place, the
        same justification as `router`, since a lone literal does not trigger rule 11. But it is
        DHCP: if the router hands out another address, the alias breaks, and the fix is a DHCP
        reservation on OpenWrt, not one more option here.
      • **The shell became GIT BASH, and bash had been there the whole time.** `RequestTTY` plus
        `RemoteCommand` pointing at `C:\Program Files\Git\bin\bash.exe`, tested, landing in
        `v1cferr@Cesar MINGW64 ~$`. `where bash` LIES on that machine: the only `bash` on the
        PATH is `C:\Windows\System32\bash.exe`, which **is not bash**, it is the legacy WSL stub,
        and there is no distro installed. The real bash does not show up in `where` because only
        `Git\cmd` is on the PATH and the binary lives in `Git\bin`. It almost became "this
        machine has no bash", when it did.
      • **And the coreutils came with it, with nothing installed.** Git for Windows bundles the
        entire GNU userland (`ls`, `grep`, `sed`, `awk`, `find`, `less`, `tar`, `curl` and so
        on), so the complaint about "missing coreutils" was really the complaint about landing
        in cmd.exe.
      • REFUSED to change the shell through the registry
        (`HKLM:\SOFTWARE\OpenSSH\DefaultShell`): it is GLOBAL, it would change the shell of
        every SSH session on the machine, including its owner's. On the client side the choice
        is only ours and it disappears along with this repo.
      • REFUSED to install WSL, even with `v1cferr` being an admin: my brother's project is
        Windows-native Gradle/Java (`gradlew.bat`), and running it from WSL against `/mnt/c`
        crosses the I/O boundary that is exactly where WSL is slow, on top of planting GB of VM
        on somebody else's machine. THE ACCEPTED COST: Claude Code's sandboxing only exists on
        WSL2, so on native Windows the permission is the only barrier.
      • `RemoteCommand` and a command line are MUTUALLY EXCLUSIVE in ssh ("Cannot execute
        command-line and remote command"), so the block above on its own would BREAK `scp`,
        `rsync` and `ssh cesar <cmd>`. Hence the twin `cesar-cmd`, the same host with no
        `RemoteCommand`: `cesar` to sit down and work, `cesar-cmd` to copy a file. The
        alternative was memorizing `-o RemoteCommand=none` on every invocation.

- [x] A disk growth audit: Docker was the only one with no ceiling, and btrfs/GC needed
      nothing (10/08/2026). The question was "is btrfs fine? is there swap? does the GC clean
      up properly?". All three answers were "yes, do not touch it", and the real problem was in
      a fourth place nobody had looked at.
      • **Docker: 11.35 GB of build cache, 8.5 GB recoverable, ZERO policy.** Every neighbor
        already had a ceiling: journald at `SystemMaxUse=2G`, coredumps vacuumed by systemd,
        btrbk with `snapshot_preserve`, nix with a weekly `gc`. Docker was the only one with
        nothing, and the `grad-radar.nix` that came in the day before made it WORSE: it runs
        `docker compose build` in ExecStartPre, on every boot. Solved in
        system/services/docker.nix; the manual prune recovered 8.501 GB (the cache went from
        11.35 to 2.85).
      • TWO OPTIONS REFUSED, and both destroy data in the SAME window, with the stack STOPPED at
        the time of the weekly prune. Neither raises an error; they successfully delete what
        they should not. `allVolumes.enable` prunes NAMED volumes, which is where
        `duo_duo-db-data` and `grad-radar_db_data` live: with the compose down, the prune would
        delete both Postgres instances. `flags = ["--all"]` removes a TAGGED image with no
        running container, and the local images do not come from a registry, so gone means a
        rebuild, which in grad-radar includes a `pnpm install` inside the container (the unit
        has `TimeoutStartSec = 1800` for that reason). The `--all` is what most public configs
        use; here it does not pay off.
      • systemd's `weekly` is **Mon 00:00**, which is exactly the `nix-gc` minute. It became
        `Mon 04:30`, after restic (03:00 plus up to 30 min) and nix-optimise (03:45). Two heavy
        I/O cleanups on the same NVMe in the same minute gain nothing from coinciding.
      • **btrfs: nothing to do, and one popular piece of advice NOT to follow.** The mount
        options are `noatime,compress=zstd:1,ssd,discard=async,space_cache=v2`, which is the
        correct set. Do NOT add `fstrim.timer`: `discard=async` is already continuous TRIM, and
        the timer is not enabled precisely for that reason. Allocation is healthy with ~398 GiB
        unallocated (Data 548 GiB allocated / 530.7 used; Metadata DUP 7 GiB / 3.99), so there
        is no pending `balance` either, which is what bites btrfs users in the long run.
      • **Swap exists, in two layers**: zram 7.7 G at priority 5 (hot, compressing 2.7 G into
        981 MB as measured) and a 16 G swapfile at priority -1 (cold), the latter with **0 B
        used**, so the fast layer handles it alone. The proof that the swapfile is correctly
        NOCOW is not `lsattr`, it is the kernel having accepted the `swapon`: btrfs REFUSES to
        activate a swapfile that is CoW or compressed, so being active is the validation.
      • **The GC was already right**: weekly plus `--delete-older-than 30d`, plus a daily
        `nix-optimise`. Recommended NOT to tighten it, since the whole `/nix/store` is 53 GB out
        of 953 GB, which means it is not what grows; shortening the window would cost rebuild
        cache and rollbacks to recover space that is not missing.
      • A MISTAKE ALONG THE WAY, and the mechanics are worth more than the mistake: a
        `caddy.nix` and a `services.nix` from other work were already in the INDEX; a `git add`
        of the two files for this change plus a commit took the WHOLE index along, so unrelated
        work landed in this commit. Undone with `reset --soft HEAD~1` plus
        `git commit -- <paths>`, which commits only the given paths and leaves the rest of the
        index alone. THE RULE: in a tree with other work staged, ALWAYS commit by pathspec.
      • The `--dry-run` that had been written in the module's comment DOES NOT EXIST in Docker
        29.6.2 (checked in the `--help` before committing). The real preview is
        `docker system prune` WITHOUT the `-f`, which lists the categories and asks y/N.

- [x] `wg-status`: WireGuard visibility with no password, and a sysupgrade bug it revealed
      (10/08/2026). There was no way to answer "is the phone connected?" without the root
      password, and a ping only proves reachability, not a handshake.
      • A WRAPPER, NOT THE BINARY: `/usr/bin/wg-status` = `exec /usr/bin/wg show`, with a fixed
        subcommand and WITHOUT forwarding `"$@"`. Putting the whole `/usr/bin/wg` in NOPASSWD
        would give `wg set`, which REPLACES A PEER KEY, so whoever had only the SSH key could
        enroll themselves into the VPN with no password at all. With no argument forwarding
        there is no `wg-status set`.
      • root:root 0755 and OUTSIDE /home. If the user could write to the file, rewriting it
        would give arbitrary root with no password and the wrapper would become the hole it
        exists to avoid. That is why it did NOT go into /home/v1cferr/bin/, which would be the
        convenient place for already being preserved. The form is copied from
        /usr/bin/wake-desktop, which already lived here the same way.
      • A PRE-EXISTING BUG FOUND ALONG THE WAY: `/usr/bin/wake-desktop` was NEVER in
        `/etc/sysupgrade.conf`. sysupgrade preserves `/etc/sudoers.d/` but NOT `/usr/bin/`, so
        the next upgrade would delete the binary and LEAVE the NOPASSWD rule pointing at
        nothing, with Wake-on-LAN through the router dying silently and the config looking
        right. The rule and its target have to be preserved TOGETHER. Both were listed.
      • WHAT THE FIRST `wg show` SHOWED, and it is worth more than the wrapper:
        1. The phone is connected (a 1m57s handshake, 3.14 GiB sent), but the endpoint is
           `186.219.82.216`, which is **UFSCar (AS52888)**, block `186.219.80.0/20`. Which means
           it is on the campus WiFi, NOT on mobile data. That corrects the reading I had made of
           the RTT: the 80 ms with 20 ms of jitter are not 4G, they are the same path as the
           notebook (35 ms) plus the WiFi hop.
        2. THERE IS A THIRD UFSCAR BLOCK, and it is NOT in the `moonlightSources` of
           system/services/sunshine.nix. The practical consequence: DIRECT Moonlight from the
           phone would be refused. Today it works only because WireGuard's 51820 has no
           `src_ip`. DECISION: do not widen the allowlist now, because the phone already has a
           path that works, and opening another range for a device that does not need it is a
           bad trade. It is recorded here for when somebody asks "why does the phone not connect
           directly?".
        3. In 17 DAYS of uptime, only ONE peer did a handshake. `notebook` (.2) never did, which
           is consistent, since that is exactly what today's direct access replaced. But
           `fai-workstation` (.5) has `persistent_keepalive = 25`, meaning it was configured to
           keep the connection alive, and it did not connect once. Either it is off, or the peer
           is legacy. See the open items.

- [x] Router: `/etc/init.d/firewall` enters NOPASSWD (10/08/2026). The
      scripts/router-moonlight-forward.sh needed a password only for the `reload` at the end,
      and that made it interactive for nothing.
      • THE INCREMENTAL RISK IS ZERO, and it is MEASURED, not assumed, and that is what
        unblocked the decision: `/usr/sbin/nft` ALREADY was NOPASSWD (confirmed with
        `sudo -n nft list tables`), and `nft flush ruleset` takes the whole firewall down. The
        power to turn the firewall off with no password already existed, through a WORSE path.
        The change only makes the legitimate path usable. Without that measurement this would
        have been refused as "privilege escalation", and the refusal would have been wrong.
      • METHOD, which holds for any sudoers change: validate with `visudo -c -f` on the
        CANDIDATE file in /tmp, BEFORE touching what works, because a malformed sudoers makes
        sudo refuse everything, and the fix would require precisely the root that sudo would
        give. A second check of the whole set (`visudo -c`) after installing, with a rollback.
      • THIS IS NOT MIRRORED. `router-sync` covers `/etc/config/` and nothing else, so this
        entry is the ONLY record of the change in the repo. `sysupgrade` preserves
        `/etc/sudoers.d/` (it is in the 38 keep.d entries), so it survives an upgrade, but not a
        clean reinstall.
      • The final state: `v1cferr ALL=(ALL) NOPASSWD: /sbin/reboot, /usr/sbin/nft, /sbin/uci,
        /etc/init.d/dnsmasq, /etc/init.d/firewall`. An arbitrary command still asks for the
        password (`(ALL) ALL`), which is correct.

- [x] Moonlight with no VPN: a direct port forward, restricted to UFSCar (10/08/2026). The
      request was "connect to Sunshine from outside without joining the VPN, and directly, with
      no intermediate servers". The second half of the request was already true and nobody knew.
      • THE PREMISE WAS WRONG, and that is worth more than the implementation: **WireGuard is
        not an intermediate server**. Its endpoint is the home router ITSELF, so both the tunnel
        and the port forward travel exactly `UFSCar → internet → 177.52.84.188`. There was no
        alternative route to eliminate. That WAS a risk with Tailscale (it could fall into DERP)
        and it left along with it on 08/08, so the fear outlived the cause. Do not rewrite this
        as a routing gain.
      • WHAT IS ACTUALLY GAINED is MTU: 1492 from PPPoE against ~1420 through the tunnel.
        Latency is noise.
      • WHAT MOTIVATES IT ANYWAY, and it is a good reason: the FAI notebook already runs
        nxBender + openconnect. Adding a third VPN client there is a routing conflict waiting to
        happen, and its owner refused to install WireGuard for that reason, and they are right.
      • THE PORTS WERE CHECKED IN THE BINARY, not in a blog post: the offsets were read from the
        web UI of the build in use (2026.516.143833, `assets/web/assets/config-*.js`): tcp
        `port-5`/`port`/`port+1`/`port+21`, udp `port+9` through `port+11`. Almost every list on
        the internet includes a **UDP 48002 ("mic") that DOES NOT EXIST in this version**. There
        are three UDP ports, not four.
      • 47990 (the admin panel) was left OUT of both lists on purpose. The
        `origin_web_ui_allowed = "wan"` is only safe because it is not forwarded, and the
        comment that justified that value ("only the WireGuard range reaches this port") stopped
        being true today and was rewritten.
      • TWO LOCKS, and the host's `-s` is not redundant with the router's `src_ip`: it is the
        one that survives somebody touching LuCI without reading the repo. The lists HAVE to
        match, because diverging gives "the router forwards, the host drops", a symptom
        indistinguishable from any other failure.
      • A NEW CONSTRAINT the change created: `packet_size` is GLOBAL and it now serves two
        paths with different MTU. The useful ceiling becomes the SMALLER one (the tunnel), so
        1024 stopped being conservatism and became a lock. It only unlocks if the tunnel is
        retired.
      • ENCRYPTION does not regress, and that was not obvious: Sunshine classifies a client by
        IP. Through the tunnel it arrives as 10.10.10.x = LAN, so `lan_encryption_mode = 0` (the
        tunnel encrypts). Direct it arrives public = WAN, so `wan_encryption_mode = 1`, on by
        default.
      • VALIDATED THE SAME DAY, with a real session of 21m58s plus 9min. The full
        measurements and method are in
        [tests/moonlight-direct.md](../../tests/moonlight-direct.md); the essentials: 0% loss
        across 100 packets of 1 KB, RTT 35.5 ms, jitter 0.54 ms. The proof that the session
        works end to end was Claude itself starting to run WITHOUT `SSH_CLIENT` and with
        `DISPLAY=:0`, inside the graphical session being streamed.
      • UDP GETS THROUGH, and the method of proof is worth keeping: the router's DNAT counter
        marked `Moonlight-Stream-Campus → packets 3`. That counter only counts the FIRST packet
        of each new flow (after that conntrack bypasses dstnat), so 3 is exactly video 47998 +
        audio 47999 + control 48000. After the reconnect it became 6, which is how it was
        confirmed that there was ONE reconnect and not several.
      • `ping_timeout = 20000` absorbed an 18.9 s hole at 11:47 without dropping the session.
        The proof is indirect and it holds as a method: the hypridle guard did NOT cycle (a
        `Stopped` at 11:25, no `Started` at 11:47), which means the prep-cmd `undo` never ran,
        so Sunshine did not tear the session down.
        CORRECTION (same day): the 1st version of this line concluded "the hole was on the
        UFSCar side", because nothing had blinked on the home side. I confirmed afterwards that
        it was ME reconnecting, on both drops that day (18.9 s and 104 s). "It was not here"
        does not imply "it was the network": the third hypothesis, the user, was missing, and it
        was the right one. The `ping_timeout` mechanism is still measured and true; what was
        invention was the attributed cause. There is no sign of instability on this route, with
        0% loss in every test.
      • THE ROUTE, measured and with the owners through RDAP: router → **Alcans (AS52783, the
        ISP)** → Algar (AS16735, Alcans's TRANSIT) → IX.br/NIC.br (AS26162) → RNP (AS1916) →
        UFSCar (AS52888). Five autonomous systems, and NONE is an intermediate server, since
        they all forward packets and none terminates the connection. IX.br and RNP cannot be
        removed: UFSCar's internet comes from RNP. It is the empirical answer to the "no
        intermediate servers" request, and it confirms that the tunnel did not have any either.
        CORRECTION (same day): the first version of this line said Algar was the ISP, because
        it was the 1st PUBLIC hop in the traceroute. Wrong: the home IP (177.52.84.188) is in
        `177.52.80.0/21`, which is **ALCANS TELECOM (AS52783)**. Algar is its transit. Reading
        "first public hop" as "my provider" is the same class of error as the traceroute read as
        proof of CGNAT: the hop says where the packet went through, not whose the subscription
        is. What answers that is RDAP on the home IP, not the traceroute.
      • LATENCY: noise, as predicted. The 35 ms belong to the physical path, which the tunnel
        travelled all the same. Recorded explicitly so nobody attributes a gain to this later.

- [x] ~~CGNAT~~ the dead item that outlived its own correction (10/08/2026): the 07/08 entry in
      `docs/open-items.md` ("THERE IS NO INBOUND … NO port forward rule can work") stayed there
      for three days AFTER the 08/08 entry in this file had already disproved it entirely.
      Deleted.
      • THE COST WAS NOT THEORETICAL: it is the first thing you read when asking "can I expose a
        port?", and the answer it gives is "no, give up". Today's work started by having to
        prove that the repo's own docs were wrong.
      • DISPROVED TODAY, with a method that does not lie (an independent external vantage point,
        not the FAI network): `check-host.net` from Austria, Canada and Iran connects to 2222 on
        `177.52.84.188`. A control in the same tool: 47984 gave `Connection refused` before the
        redirects, which is what makes the positive interpretable instead of merely optimistic.
      • AND THE TRACEROUTE STILL LOOKS LIKE CGNAT: hops 2 to 4 in `172.31.x` and hop 5 in
        `100.127.255.225`, which is the `100.64/10` range, the range DEFINED for CGNAT. It still
        is not: it is the ISP's internal transport. This is exactly the instrument that misled
        on 07/08, it has not improved, and whoever repeats the reading will get it wrong again.
      • THE PROCESS LESSON: correcting the history does not correct the open item. A reverted
        item has to die in BOTH places in the same commit, otherwise the repo ends up with two
        answers and the wrong one is in the file people read first.

- [x] Tailscale auth keys revoked: the 05/08 exposure is closed (09/08/2026). The orphan
      `.env` at the repo root held `TAILSCALE=tskey-auth-kLXAR6…` in plain text, mode 644, and
      the key was **reusable**, the worst case, because whoever had the string could join the
      tailnet as many times as they wanted. Deleting the file (05/08) reduced the local exposure
      and invalidated NOTHING; only revoking it in the admin console does that. I deleted every
      key on 09/08.
      • Tailscale fell out of use on this machine along the way: `tailscaled` is `inactive` and
        the `tailscale` binary does not even exist on the PATH, which made the revocation an act
        with zero blast radius. Recorded because it is the argument that unblocks this kind of
        item: when nothing depends on the secret, revoking has no downside and the only reason
        to postpone disappears.
      • The external access route is still the CGNAT open item, not this one.

- [x] A general audit of the setup, and what it found: the restic prune had been stopped for 4
      days (09/08/2026). A complete hardware and software sweep asked for in the open ("is my
      system healthy?"). The verdict was healthy, but two findings only existed because nobody
      had looked: both were hiding behind noise that had already become routine.
      • **restic: `forget --prune` had not run since 05/08 15:46.**
        `error: lstat /home/v1cferr/Drive: permission denied`, so restic exits 3, so the
        `unlock` and the `forget --prune`, which are the 2nd and 3rd ExecStart, never get to
        run. It is the SAME trap as `~/FAI-workstation` on 05/08 (a user FUSE mount, with the
        backup running as root), with a mountpoint nobody remembered to exclude. Fixed in
        system/services/restic.nix.
      • THE FIX RAN and the result DISPROVED the estimate of whoever wrote this: I warned that a
        delayed prune could take a while and need more than one run, because of repacking on a
        remote repo. It took **14 s**: it removed 1 snapshot, repacked 1 pack and freed 4.9 MiB.
        6 snapshots / 26.1 GiB were left.
      • WHY IT WAS SO CHEAP, which is what keeps the next case from being overestimated: with
        `--keep-daily 7` and only 5 distinct days in the repo, NOTHING had aged out of the
        window in 4 days, and the only excess was the same-day duplicate. The cost of dead
        retention does not grow linearly with the days stopped: it is ZERO until the repo passes
        7 distinct days, and only then does each new day start pushing one out.
      • AND THAT REORDERS WHAT THE REAL RISK WAS. It was not space on the Drive, it was the
        `unlock`, the other ExecStart that also was not running. A stuck lock from an
        interrupted run blocks the ENTIRE backup, not the prune, and that damage does not depend
        on how much time passed, it happens the first time a run dies mid-way.
      • WHY IT WENT UNNOTICED, and this is the part worth keeping: FAI-workstation only mounts
        with the VPN up, so it failed INTERMITTENTLY, and it was precisely the intermittency
        that made somebody investigate. `~/Drive` mounts on EVERY boot, so the failure became
        constant, daily and silent. A failure that happens ALWAYS is easier to ignore than one
        that happens sometimes: it becomes the service's normal state. The data was never at
        risk (a snapshot saved every day, 41.8 GiB, 297,740 files); what died was the retention.
      • **VS Code: 15 coredumps in 2 days, and it is not the editor.** What aborts with
        SIGABRT is the language server of the `kamikillerto.vscode-colorize` 0.17.1 extension
        (`coredumpctl info` hands over the whole command line, with the path to
        `server/out/server.js`). The price measured PER abort: 58 s of CPU, 2.6 GB of peak RAM
        and 2.7 GB written to the NVMe just to record the dump, on a 15 GB machine and on a disk
        whose wear we track. The 09/08 cadence: 10:38, 15:01, 15:43, 15:57, 16:49, 16:55, 17:07.
      • DO NOT CONFUSE this with the 90 s "stop job" in the entry below, even though both say
        "VS Code": there it is the `app-code-*.scope` ignoring SIGTERM at SHUTDOWN; here it is a
        child process aborting IN THE MIDDLE OF THE SESSION. Independent causes, independent
        fixes, and the real risk was the first finding "explaining" the second and the
        investigation stopping there.
      • DISPROVED BY MEASUREMENT, which is what prevents useless work: (a) "15 GB of RAM is not
        much", when memory PSI is ~0, the on-disk swapfile has 0 B used and zram compresses
        2.7 G into 981 M; what freezes is colorize, not the RAM. (b) "the NVMe is hot", when
        Composite is 52.9 °C under load (a game + 7 containers + ollama), against the 77 to
        80 °C that generated the heatsink open item; the `Sensor 2` at 79.8 °C is still the
        known false alarm (an unimplemented sensor, pinned).
      • The rest is green and checked: 0 failed units, `is-system-running: running`, btrfs
        `no errors found`, 58% disk, fwupd with no pending update, `nix flake check` passing.
        Secure Boot and VT-x are still off, the same BIOS trip, already tracked.

- [x] Shutdown from 90 s to ~5 s: the "stop job" was ONE app, not the system (09/08/2026). The
      complaint was "it takes almost 5 min to shut down". The journal disproved the number and
      handed over the culprit: 90.3 / 90.4 / 90.5 / 90.6 s across the last 10 boots. A round
      number like that is not work, it is a TIMEOUT, systemd's default
      `DefaultTimeoutStopSec` of 90 s, hitting in full, every boot.
      • A SINGLE culprit and always the same one: `app-code-*.scope: Stopping timed out.
        Killing.`. VS Code runs in a USER SESSION scope (GLib creates `app-<name>-<pid>.scope`
        when launching the `.desktop`) and it does not answer SIGTERM. Searching the pattern
        across the whole journal: 8 occurrences of VS Code and 6 of Chromium before it, so it is
        Electron behavior, not this machine's. Everything ELSE (docker, jellyfin, network,
        unmounts, swap) stops in under 2 s, which closes the arithmetic: 90 s of shutdown = 88 s
        of waiting.
      • WHERE THIS CHANGES THE DIAGNOSIS: the instinct was to touch the SYSTEM services. There
        was nothing to gain there. The adjustment that solves it is on the USER side, 5 s in
        `systemd.user`, where the tenant is a desktop app and whoever was going to save on
        SIGTERM already saved in under 1 s.
      • THE SYSTEM stayed at 30 s and did not go to 5 s along with it: `duo` and `grad-radar`
        have `docker compose down` in their ExecStop, and `down` gives EACH container 10 s of
        grace. Tightening too much here would SIGKILL those stacks' Postgres in the middle of
        the down, which does not corrupt anything but comes back doing WAL recovery, and the
        price shows up far from the cause.
      • WHAT THE CHANGE DOES NOT DO, because the easy reading is "now it kills the apps": the
        SIGKILL already happened, 90 s later. Nothing that died a natural death started being
        killed; we only stopped paying the wait for someone who was never going to answer.
      • THE TRAP RULE 8 CAUGHT, and it fails SILENTLY: `systemd.extraConfig` WAS REMOVED
        (26.05 wants `systemd.settings.Manager`). Writing to the removed option, the `nix eval`
        of the generated `system.conf` PASSES and comes out without the line, with zero errors
        and zero warnings, and the shutdown would still take 90 s with the config "applied". It
        only showed up because the validation was READING the generated file, not asking whether
        it built.
        And the asymmetry is the non-obvious part: on the user side `systemd.user.extraConfig`
        is still the ONLY form, since `systemd.user.settings` does not exist (checked in the
        `options`, not deduced from the system side).
      • NEXT TIME the shutdown drags, the global ceiling will not be the answer: a unit with its
        own `TimeoutStopSec` ignores the default (today qbittorrent has 30 min, jellyfin 15 s,
        caddy 5 s, `user@.service` 2 min from upstream). Look there first with
        `systemctl show <unit> -p TimeoutStopUSec`.

- [x] The bar clock shows the date AND the time, and the calendar rolls the year over by
      itself, measured (08/08/2026). The clock used to be a TOGGLE: a click alternated between
      `󰥔 HH:mm:ss` and `󰃭 dd/MM/yyyy`, never both. Seeing the date cost two clicks (there and
      back), which is expensive for the most consulted piece of data on the bar. Now they come
      out together in the same pill.
      • THE FORM: the time first in mauve, the date after it in `Theme.colDim`. That is
        HIERARCHY, not separation: the time sits on the left edge, which is where the eye enters
        the pill, and the date follows without competing. It was born as a new `sub` in
        `widgets/Pill.qml` (secondary text in the same pill), reusable for any pair that travels
        together.
      • TWO DECISIONS: no YEAR (redundant, since the calendar popover has it, one hover away),
        and the weekday from the file's own `dowAbbr` instead of Qt's `"ddd"`. Qt's format
        depends on the PROCESS locale, so if the bar comes up without `LC_TIME`, autologin for
        instance, "sáb" silently becomes "Sat". The local table does not have that risk.
      • RULE 8 CANNOT BE SATISFIED HERE, and that is worth knowing: the Quickshell tree is
        `mkOutOfStoreSymlink`, so it does NOT go through `/nix/store` and `nixos-rebuild build`
        does not exercise these files, which means there is no build to validate. The substitute
        I used: `qmllint` (syntax) + headless `qml` (behavior) + a screenshot of the real
        result. A QML error here only shows up with the bar already running.
      • THE QUESTION THAT WAS WORTH THE NIGHT: "and when it is 2027, does the calendar update on
        its own?". Yes: `SystemClock` ticks every second, `updateClock()` compares `yyyy-MM-dd`
        against `calDayKey` and calls `refreshCalendar()` on the first tick after midnight. I
        did not take that on faith: I simulated the 31/12/2026 to 01/01/2027 rollover with the
        REAL functions extracted from `Bar.qml` (not a rewrite), and the header becomes 2027,
        "today" jumps to 01/01, and Carnival is painted on 08-09/02. Easter was checked through
        2032, including the Carnival of 29/02/2028, a leap day. The algorithm has a built-in
        self test: if it slipped in some year, the WEEKDAY would give it away (Easter is always
        a Sunday, Corpus Christi always a Thursday).
      • THE MOST VALUABLE FINDING, and it was the link I had only REASONED about: the popover
        reads `calMap` through a binding (`Repeater { model: bar.monthCells(...) }`), and a QML
        binding only reevaluates when the PROPERTY is reassigned. Measured in headless `qml`
        (6/6): reassigning propagates, MUTATING the object from the inside (`calMap[k] = v`)
        emits no signal at all. Which means the calendar only rolls the year over because
        `refreshCalendar` does `root.calMap = root.buildCalMap(...)`. Whoever "optimizes" that
        into writing into the existing object FREEZES the calendar silently: nothing breaks,
        nothing logs, it just stops rolling the year. Noted in the code, next to the function.
      • HOLIDAYS REVERIFIED (national + SP + São Carlos) and the result was: NOTHING CHANGED.
        The list was already correct and complete for 2027, with no new holiday since Law
        14.759/2023 (Consciência Negra, national since 2024 and no longer only state level). An
        independent confirmation: the non-optional ones on the list add up to 14, which is the
        number the city hall and the local press publish for São Carlos.
      • WHAT CHANGED ABOUT THE HOLIDAYS was the DOCUMENTATION, which was worse than the code:
        the header said "see the workflow notes", a pointer outside the repo, which is to say to
        nowhere. The laws went into the file (662/1949, 6.802/1980, 9.093/1995, 14.759/2023, the
        state 9.497/1997 and the MUNICIPAL 7.502/1974 for Corpus Christi).
      • THE TWO TRAPS that calendar sites fall into and this list does not, and the first search
        I ran got both wrong: (1) CARNIVAL and Ash Wednesday are neither a national nor a
        municipal holiday in São Carlos, they are optional days off; (2) CORPUS CHRISTI is
        FEDERALLY optional but a MUNICIPAL holiday here, through the law above, and in another
        city it would be `fac`.
      • WHAT DOES NOT UPDATE ITSELF, and it is the only part of the calendar like that: the
        `holidayDefs` list. The MOVABLE ones derive from Easter and scale forever; the FIXED
        ones are LAW written by hand. A new law, or the municipality changing a holiday, leaves
        the grid wrong silently. Review it when news of a new holiday appears, not at the turn
        of the year, because nothing there depends on the year.

- [x] DDC/CI backlight REVERTED: worse dimming on both screens beats great dimming on one
      (08/08/2026). `ddcutil` worked, the curve worked, and it went out anyway. The reason is
      not technical, it is ERGONOMIC, and it is worth more recorded than the code.
      • WHAT WORKED: `hardware.i2c.enable` plus ddcutil gave REAL backlight control on DP-2 (LG
        ULTRAGEAR, MCCS VCP 2.1). The measurement that motivated everything is still valid: the
        monitor was at **100%** at 20:00 in a dark room, and THAT was the cause of the burning
        eyes, not the blue filter. The hourly curve applied 40% and the monitor obeyed.
      • WHAT KILLED IT: the LG TV on HDMI has no way to follow along. It does not speak DDC/CI
        (`x37 unresponsive`), it is NOT ON THE NETWORK (checked in the router's DHCP: the only
        unnamed device is Amazon, not LG, so not even webOS), and HDMI-CEC does not cover
        brightness, which is a spec matter. Three paths, three closed.
      • THE REASONING BEHIND THE REVERSION, which is the point: one screen at 32% next to
        another at 100% forces the pupil to readapt every time the gaze switches, and that tires
        the eyes MORE than the gain on the good screen. Worse dimming on both beats great
        dimming on one, when both are in the field of view. The hyprsunset gamma is technically
        worse (it darkens the SIGNAL, with the backlight at full) but it reaches BOTH, and
        uniformity won.
      • THE ALTERNATIVE that still holds, if the discomfort ever comes back: adjust the TV's
        backlight ONCE with its own remote (it is device config, it persists, and it falls into
        the same category as docs/guides/bios-*.md) and resume DDC on the monitor. It was
        REFUSED for not being automatic, not for not working.
      • WHAT STAYED from the experiment: `wayland-utils` (wayland-info), which came in along
        with it and is useful on its own; and the correction to the hyprsunset.nix header about
        the shader and about the 13 profiles.
      • THE MONITOR WENT BACK TO 100% ON ITS OWN, and I had written the opposite: I actually
        warned that "it stayed at 40% and persists in hardware". FALSE, because `setvcp` without
        `--save` does not write to the EEPROM, so the value is lost on the first screen
        power-off. The reversion ended up complete, with no orphan state. It counts as an
        inverted trap: whoever automates DDC needs to know that the change is VOLATILE by
        default, which is actually good (a service that reapplies at login is enough) but
        surprises anyone expecting `setvcp` to stick.

- [x] ~~Gamma leaves the hyprsunset curve~~ REVERTED along with the DDC (08/08/2026): a side
      effect of DDC/CI coming in was that `hyprsunset` does NOT know how to target a specific
      output. I searched for `output`/`monitor`/`display` in the source: ZERO occurrences. It
      applies the CTM to ALL outputs at once.
      • THE PROBLEM THAT CREATED: with DP-2's real backlight coming from DDC/CI, keeping the
        gamma auto-dim would give DOUBLE dimming on the good monitor (backlight 32% times gamma
        0.9 at 22:00) in order to deliver weak relief on the TV. It was a regression I
        introduced by adding brightness.nix, and it only showed up when asking "and the TV, how
        would that work?".
      • THE SPLIT THAT REMAINED: DP-2 (LG ULTRAGEAR) gets real backlight through DDC/CI;
        HDMI-A-3 (LG TV) gets its backlight adjusted with ITS OWN remote, since it does not
        speak DDC/CI. A TV is an appliance, not a computer: picture config persists there and
        does not need the repo.
      • `max-gamma = 150` STAYED: the SHIFT+VolUp/Down keybinds still adjust gamma through IPC,
        now as MANUAL fine tuning instead of an automatic curve.
      • HDMI-CEC was discarded without testing, and the reason is a spec matter: the protocol
        covers power, volume and input switching, and brightness is not in the standard. What is
        left is network control (webOS, a 2017 TV), which stays open: I do not know its IP, and
        the `192.168.1.20` from the `TV-Samsung-Sala` lease does not answer (and it is not even
        certain that is this TV).

- [x] ~~REAL monitor brightness: DDC/CI + an hourly curve~~ REVERTED (08/08/2026):
      `ddcutil getvcp 10` returned **100** at 20:00, in a dark room. The monitor spent the whole
      day at full, and NO Kelvin curve solves that. It was the cause of the burning eyes.
      • THE INVERSION THAT MOTIVATED IT: the ergonomics literature puts REDUCING BRIGHTNESS
        above color temperature, and "night mode does not replace adequate brightness". I
        expected the opposite, and the config expected it too: `hyprsunset` covered color with
        13 carefully tuned profiles and luminance with nothing.
      • The hyprsunset `gamma` was NOT BRIGHTNESS: it darkens the SIGNAL sent to the panel while
        the backlight stays at full. The light reaching the eye does not change. The july
        history itself already recorded "no real backlight", so the gap was written down and
        nobody had connected the dots.
      • `hardware.i2c.enable` (system/hardware/ddc.nix) loads `i2c-dev`, which was not loaded
        because NOTHING ASKED FOR IT. Without `/dev/i2c-*` ddcutil has nothing to speak through.
      • ONLY DP-2 ANSWERS: the LG ULTRAGEAR speaks MCCS (VCP 2.1); the LG TV on HDMI returns
        "does not support DDC/CI, I2C slave address x37 is unresponsive". And I WAS WRONG in
        predicting that: I said HDMI "exposed ZERO i2c buses", but ddcutil found its
        `/dev/i2c-7`. My test looked at per-connector symlinks in sysfs, which is a different
        thing. The conclusion was right for the wrong reason: the TV HAS a bus, it is the one
        that does not speak the protocol.
      • `home/desktop/brightness.nix`: an hourly curve mirroring the hyprsunset structure (90%
        during the day, 55% at 18:00, 40% at 20:00, 28% overnight). A 5 min --user timer, and it
        writes ONLY when the target changes, so a manual adjustment holds until the next step,
        the same contract as hyprsunset, and it does not keep writing DDC for nothing (it is
        slow and it makes the monitor blink). `--model` and not `--display N`: the number
        changes if another DDC monitor comes in.
      • REFUSED: the `ddcci-driver` (it exists in nixpkgs, exposes the monitor as a standard
        backlight and would let `brightnessctl` work). It is an out-of-tree kernel module and it
        breaks on every bump. For infrastructure that has to last, calling ddcutil from a timer
        is less elegant and far less fragile.
      • The curve values are a STARTING POINT, not truth. The criterion from the literature is
        comparing against a sheet of white paper next to the screen.

- [x] LocalSend declarative, open ONLY to the LAN (08/08/2026): an open source "AirDrop" (MIT,
      1.17.0) for moving files between the phone and the PC with no cloud and no account. Three
      pieces: `programs.localsend` in system/net/localsend.nix, port 53317 allowed by SOURCE,
      and an entry in the `my.autostart` panel.
      • WHY IN `system/` and not in `home/`, against rule 4: what unites the PACKAGE and the
        PORT is the nixpkgs module, and a firewall is system level. The same case as
        `programs.steam`. The package is NOT repeated in home/packages.nix: the autostart reads
        `osConfig.programs.localsend.package`, and the store path of `sw/bin/localsend_app` and
        of the unit's `ExecStart` MATCH (the same `5vzlv6k…`), which is the proof that nothing
        was duplicated. As a bonus, that kills the spotify trap by construction: switching to
        `unstable` in system/ takes the autostart along, instead of requiring me to remember to
        keep two files in sync.
      • `openFirewall = false` AGAINST the module's default, and the threat is not the
        internet: the router only forwards 80/443/2222, so 53317 was never exposed to the world.
        Who would reach it is the VPN, because `openFirewall` opens the port on EVERY interface,
        and with the FAI tunnel up (`ppp0`) the whole corporate network would start seeing the
        service and reading `/api/localsend/v2/info` (device name, model, fingerprint) with no
        authentication at all. It becomes trust by SOURCE, the same as Sunshine's: only
        `my.net.lanSubnet`.
      • The WireGuard peers get in FOR FREE, with no rule of their own: they arrive with source
        10.10.10.x and the net/network.nix rule already accepts that range before any decision.
        The fifth consumer of the SSOT, validated by the sentinel ritual (rule 11): swapping the
        range for 172.31.99.0/24 changed both new rules along with fail2ban's `ignoreip`, and
        reverting gave back an IDENTICAL store path (`i0kvjns…`).
      • UDP is mandatory alongside TCP, and it is not a detail: TCP is the transfer and the
        `/info`; UDP 53317 is the multicast announcement on 224.0.0.167, which is what makes the
        devices DISCOVER each other. Without it the app opens and works, but only through "add
        by IP" by hand, a failure that looks like "my phone cannot find me", not "the port is
        closed".
      • The port is REPEATED in my module because the nixpkgs one does not expose it as an
        option (it is a `firewallPort = 53317` internal to their file). Changing the port INSIDE
        the app (Settings, Network) makes reception die SILENTLY: no build error, no log.
      • AUTOSTART with `--hidden` (a flag confirmed in the `libapp.so` strings, not guessed): it
        comes up with no window, only the SNI icon in the quickshell tray. Without it the app
        receives nothing, because LocalSend only listens while it is open, and sending from the
        phone would require walking to the PC to open it. An explicit price: the tray becomes
        the ONLY way to bring the window back.
        Do NOT turn on "Autostart after login" IN THE APP'S SETTINGS: that writes a
        `.desktop` into `~/.config/autostart` and would become a SECOND owner of the same
        automation (rule 15), with two instances fighting over 53317.
      • A CORRECTION TO A WRONG COMMENT that this work uncovered, in net/network.nix: I had
        written that the `nixos-fw` chain "ends in a refuse, so `-A` is never reached". FALSE
        for `extraCommands`: read in the GENERATED `firewall-start`, it is injected BEFORE
        `-A nixos-fw -j nixos-fw-log-refuse` (nixpkgs 26.05, line 235 vs 238), so `-A` would
        work. The sentence only holds for a rule typed BY HAND into a firewall that is already
        up. The `-I 1` is still right, but for ANOTHER reason: it is what reproduces the
        semantics of `trustedInterfaces`. The same class as "`~/.profile` is not read on
        OpenWrt", an old note I was about to cite as if it were a measured fact.
      • The nickname, the destination folder and "save without confirming" stay in the app
        (rules 6 and 14: it rewrites its own `shared_preferences` at runtime, so Nix does not
        own it).

- [x] `my.ingress`: exposure becomes a TOGGLE (08/08/2026). The Caddyfile stopped being written
      by hand. Each service declares itself in `my.ingress` (the schema in
      system/net/ingress.nix, the panel in hosts/nixos-kingston/services.nix) and the vhosts are
      GENERATED. Switching reach means changing one word: `expose = "lan"` becomes `"public"`.
      • WHAT THIS FIXES: before, the reach was implicit and asymmetric. `duo`/`ai` had a
        hand-written `respond @externo 403`, `jellyfin`/`torrent` did NOT, and the decision to
        expose only existed as an ABSENCE in the middle of 60 lines. Encoding security by
        omission is the worst case: forgetting to write it became "exposed", silently. Now the
        `expose` default is `lan`, so forgetting CLOSES.
      • The TAILNET in the home matcher (100.64.0.0/10): it is what gives REAL remote access
        today, since CGNAT prevents direct inbound. A tailnet peer is as much "home" as the LAN.
        It went along into fail2ban's `ignoreip`, because getting the password wrong on the
        phone cannot ban yourself.
        That range is the same one carrier CGNAT uses; today it is harmless because nothing
        from the internet reaches the process, but on the day of the tunnel it requires
        distinguishing the path, not trusting the IP.
      • `remote_ip` became `client_ip` BEFORE any tunnel exists: today they are identical (with
        no trusted proxy, the client is the connection). It cost nothing and it disarms the trap
        of cloudflared delivering over loopback and all the tunnel traffic becoming "home",
        bypassing basic_auth silently.
        Do NOT add `trusted_proxies` while there is no tunnel: without it the
        X-Forwarded-For is ignored (which is correct); with it, any local process forges the
        source IP.
      • The fail2ban failregex became DERIVED from whoever has `auth`, instead of the literal
        `pos\.`: a new service with basic_auth enters the jail by itself.
      • A NIX TRAP that bit on the first generated file: the target is the literal `{$VAR}`
        (a Caddy env var), and `"{$${v}}"` in a Nix string is a SYNTAX ERROR, not an escape, so
        the generated file came out with a raw `{$${v}}`, which would become an EMPTY hash at
        runtime. The unambiguous form is concatenating: `"{$" + v + "}"`. It was caught by eye,
        in the generated Caddyfile; there would have been no build error.
      • VALIDATED: `caddy validate` with the custom binary and real bcrypt hashes returned
        `Valid configuration`; the generated file is semantically identical to what was there by
        hand; and the sentinel ritual (rule 11) held, since flipping `jellyfin` to `lan` made
        the 403 appear and reverting gave the store path back byte for byte.

- [x] `router-sync`: the router config comes out of the blind spot (08/08/2026). The ~750
      lines of UCI from the Cudy WR3000 now live in `router/uci/*.conf`, versioned, with the
      secrets redacted. It is NOT a declarative router: it is a VISIBLE one with DETECTABLE
      drift, which was the real complaint. `router-sync pull` mirrors, `router-sync diff`
      compares and exits 1 if they diverge (tested in all three states: in sync 0, diverged 1,
      reverted 0).
      • WHY IT DOES NOT PUSH CONFIG, and why this half came first: writing UCI over SSH
        requires commit-confirm (apply, schedule a rollback, confirm if there is still access).
        Without that, one wrong network or firewall line locks you out and the way back is
        failsafe mode with PHYSICAL access. The read half delivers nearly all the value with
        none of the risk, and the export becomes input for ANY push tool later.
      • FAIL-SAFE REDACTION, and the direction is the point: it redacts by DEFAULT anything
        whose name suggests a credential, and only lets through what it recognizes,
        `public_key` (public by definition) and a value starting with `/` (that is a PATH, not
        a secret). A blocklist would do the opposite and leak silently the day a new package
        brought a new option. Validated: the 7 secrets came out redacted, and the 2 predicted
        false positives (`luci.flash_keep.passwd='/etc/passwd'`,
        `uhttpd.main.key='/etc/uhttpd.key'`) stayed intact through the `/` rule. An extra sweep
        for high-entropy strings only found the peers' 3 `public_key` values, a DHCPv6 DUID and
        a path.
      • `uci show` and not `uci export`: one line per option makes the git diff point at the
        LINE that changed instead of the whole block.
      • `__file__` does NOT find the repo root: the script is copied into /nix/store, so a
        path relative to it points inside the store (read-only). It bit on the first run. The
        right idiom is the one in `sync-secrets.sh`: `git rev-parse --show-toplevel`.
      • WHAT `sysupgrade` ALREADY PRESERVES: 38 entries in keep.d, and I got this wrong TWICE
        by reading the list truncated at 12 lines and concluding from what I did not see. It
        preserves ALL of `/etc/config/`, `/etc/profile.d/`, `/etc/dropbear/`,
        passwd/shadow/group AND ALSO `/etc/sudoers.d/`, which I had been saying was lost. The
        real gap is only `/home/`.
      • A TRAP that only showed up when reading `/sbin/sysupgrade`: `/etc/sysupgrade.conf`
        itself is NOT in keep.d. `list_static_conffiles` reads the paths LISTED INSIDE it but
        does not include it, so the 1st upgrade preserves what you asked for and the 2nd loses
        everything, because the file doing the asking disappeared in the first one. The fix:
        list `/etc/sysupgrade.conf` inside itself.
      • BEST PRACTICES researched, for when the push decision comes: an image
        (nix-openwrt-imagebuilder + /etc/uci-defaults) and a push (nuci/Dewclaw/your own) are
        COMPLEMENTARY, not alternatives, because the image is the disaster artifact and the
        push is the daily cycle. `nuci` (github.com/lonerOrz/openwrt-nix) is the best designed
        one (it validates first, an anti-brick watchdog with a boot hook, sops, `nuci diff`)
        and it is ALIVE (a push on 30/07/2026), but it has 1 contributor and recent commits
        still refactoring the CLI, which is API churn in the tool that controls the network.
        Dewclaw is older and its author declared that they do not support it.

- [x] `my.net.{lan,vpn}Subnet`: the home ranges become an SSOT (08/08/2026), the last loose
      end of the Tailscale removal. "From home" is a SECURITY decision (it separates who gets
      in directly from who needs a password) and it was spelled out in FOUR places: Caddy's
      `@externo` matcher, the caddy-pos jail's `ignoreip`, sshd's `ignoreIP` and the firewall
      rule that replaced `trustedInterfaces`. Diverging there raises no build error, it just
      starts treating as a stranger somebody who should get in, or the other way around.
      • TWO options and not a single list: the firewall that keeps Sunshine reachable trusts
        ONLY the WireGuard one. Sunshine is closed on the LAN by decision, and merging the
        ranges would open it to the whole home network without anybody noticing.
      • Validated by the sentinel ritual: swapping `vpnSubnet` for 172.31.99.0/24 changed all
        FOUR consumers together; reverting gave the store path back.
      • A BONUS FINDING, two dead configs the sentinel exposed: fail2ban's `[DEFAULT]` came out
        with `127.0.0.1/8 ::1` DUPLICATED (the nixpkgs module already prepends both, so
        declaring them again repeated them), and the caddy-pos jail's `ignoreip` became
        identical to the DEFAULT once both started reading the SSOT. A jail with no `ignoreip`
        inherits the default: one fewer copy to diverge.
      • These values MIRROR the router, which is what really defines them (it serves the LAN
        DHCP and it is the WireGuard server). Nix does not reach in there, so changing the range
        on OpenWrt and forgetting it here leaves the repo lying silently.

- [x] Tailscale REMOVED, WireGuard only (08/08/2026): remote access becomes the WireGuard the
      ROUTER already served, and the third party mesh leaves the repo entirely.
      • WHY, and the premise I had wrong: the Tailscale client ALREADY is FOSS (BSD-3); what is
        proprietary is the CONTROL plane. So the swap does not remove closed software from the
        machine, it removes the dependency on a third party coordinator that knows which devices
        exist and can turn the network off. Headscale would solve that too, but it costs a
        critical service to maintain; plain WireGuard costs zero, because the server was already
        on the router (`wg0`, 10.10.10.0/24) and Caddy already trusted that range.
      • WHAT KNOCKED DOWN THE ONLY ARGUMENT AGAINST IT: the fear was a corporate network
        blocking UDP and forcing the DERP relay, which is exactly the use case (Moonlight from
        work). MEASURED: 3 UDP 51820 packets fired from FAI, and the nftables `Allow-WireGuard`
        counter on the router went from 0 to 3. It gets through. And with no relay the video
        always goes direct, which for streaming is pure gain, since the path is even shorter,
        given that FAI and home are both in São Carlos.
      • THE TRAP THAT ALMOST SLIPPED THROUGH: `tailscale.nix` carried
        `trustedInterfaces = [ "tailscale0" ]`, and Sunshine runs with `openFirewall = false`.
        Deleting the module without replacing that would have left Sunshine UNREACHABLE from
        everywhere, silently. The replacement is in net/network.nix and it is by SOURCE, not by
        interface: the WireGuard server is the ROUTER, so there is no local `wg0` to trust, and
        the peer arrives over the LAN with source 10.10.10.x. The rule is inserted with
        `-I nixos-fw 1`: the chain ends in a refuse, so `-A` would never be reached.
      • WHAT DIED ALONG WITH IT, and this is the point of "zero legacy": the
        `sunshine-path-probe` subsystem (~82 lines plus 2 systemd units) and the
        `moonlight-stats` sections that cross-referenced the tailscaled journal. All of that
        existed to answer "was this session direct or did it fall into DERP?", and with
        WireGuard there is no relay, so the question LOST ITS OBJECT. It was not code that
        broke; it was code that stopped making sense. The report kept what is still true: the
        session durations and the short/long split.
      • Also gone: the `after = tailscaled.service` of cloudflare-dyndns. That DNS race existed
        because resolv.conf pointed at the 100.100.100.100 served by tailscaled itself. The
        RETRY stayed, since the other cause (DHCP taking ~6.5s after network-online) is
        independent and still holds.
      • FUNCTIONAL ADJUSTMENTS in sunshine.nix: `csrf_allowed_origins` pointed at the tailnet IP
        and the MagicDNS name, both dead, so it became `https://192.168.1.10:47990`, which is
        where the peer arrives. It is still a SNAPSHOT (an IP cannot be derived at build time),
        so it is worth guaranteeing a static lease on the router. `packet_size = 1024` STAYED:
        it was calibrated for tailscale0's MTU 1280 and there is room to spare in WireGuard's
        ~1420 MTU, but it is a proven value and raising it would be optimizing without
        measuring, risking reintroducing the SILENT drop that cost the 29/07 debug.
      • WHAT IS LOST, and it is real: Tailscale re-resolved the endpoint by itself when the
        home IP changed. WireGuard stores the resolved endpoint and does NOT re-resolve, so if
        the IP changes while you are away, the session dies and the client does not come back on
        its own. There is a fix (a timer that re-resolves and reapplies), but it is work, not
        third party magic.
      • `tailscale_authkey` left the Bitwarden index. The ENCRYPTED value is still in
        secrets.yaml until somebody removes it by hand, which is harmless but is residue.

- [x] OpenWrt router: access, cleanup and `owfetch` (08/08/2026). The Cudy WR3000 became
      administrable over SSH with no password, and it gained a system summary. NONE of this is
      declarative, and the record exists for that reason: OpenWrt is not NixOS, so everything
      below is a MANUAL step that disappears in a clean reflash (it survives a `sysupgrade`
      with keep settings).
      • The CLIENT is declarative, the rest is not: `home/shell/ssh.nix` gained the `router`
        host. Without `faiResilience`, because that dimensions keepalive and multiplexing for
        the SonicWall tunnel; on a <1ms LAN hop it would be cargo cult.
      • THE FIVE MANUAL STEPS, in order: (1) `ssh-copy-id` for the key; (2)
        `@includedir /etc/sudoers.d` in `/etc/sudoers`, which was NOT there, so a drop-in in
        there was ignored SILENTLY; (3) the restricted NOPASSWD rule; (4) the script in
        `~/bin/owfetch`; (5) the call in `/etc/profile.d/99-owfetch.sh`. Adding
        `/etc/sudoers.d/` to `/etc/sysupgrade.conf` makes step 3 persist.
      • There is NO `su` in BusyBox and `sudo cmd > file` does NOT work (the `>` belongs to
        the unprivileged shell, before sudo). The pattern is `| sudo tee`. And editing sudoers
        means copy, edit the COPY, `visudo -c -f`, and only then install: with `sudo` broken and
        no `su`, the way out would be failsafe with physical access.
      • SUDO SCOPE: it started as `ALL` and was NARROWED to `/sbin/reboot, /usr/sbin/nft,
        /sbin/uci, /etc/init.d/dnsmasq`. The reason is that `NOPASSWD: ALL` plus an SSH key
        makes the KEY equivalent to root, and root login over SSH was already disabled in
        dropbear (the `-w -g` flags), so the broad version undid the protection that already
        existed.
      • LOCAL DNS: 13 entries became 1. Only `/v1cferr.dev/192.168.1.10` did any work, since in
        dnsmasq that covers the domain AND every subdomain. The 12 specific ones were
        redundant, several pointing at services dead since Arch
        (bazarr/prowlarr/radarr/sonarr/jellyseerr/spendflow/chat/dash/files), and none covered
        `pos` or `duo`. A backup is in `/etc/config/dhcp.bak-limpeza`. An accepted effect: the
        wildcard also catches the APEX, so `https://v1cferr.dev` from inside the house gives a
        TLS error (the wildcard cert does not cover the bare domain). From outside it goes to
        Vercel normally.
      • `scripts/owfetch.sh`: a fetch in pure ash, ~4 KB, with ZERO dependencies. It is not
        fastfetch because /overlay has 1.4 MB free out of 6.1 MB, and fastfetch weighs 1 to
        2 MB while neofetch would drag bash in; either one fills the flash, and a router with
        full flash does not even save config. The field order mirrors
        `home/shell/fastfetch.nix` on purpose.
      • AUTOSTART in `/etc/profile.d/99-owfetch.sh` (`/etc/profile` scans that directory).
        Mandatory guards: `[ -t 1 ]` (otherwise it pollutes `scp` and commands over SSH) and
        `-x` (otherwise it errors if the script disappears in a reflash). `$HOME` and not a
        fixed path: the directory is read by EVERY user who logs in, so whoever does not have
        the script simply sees nothing.
      • METHOD, and the lesson is worth more than the result: I actually WROTE DOWN HERE
        that "`~/.profile` is not read on OpenWrt". FALSE, it is read, and the real login showed
        the fetch running TWICE with just that. What fooled me was the test:
        `echo exit | ssh -tt` is NOT an interactive session (ash looks at `isatty(0)`, and stdin
        came from a pipe), so it returns nothing both for "not configured" and for "configured
        and working". A method that does not distinguish the two hypotheses is not a test, and
        it was the SAME class of error as the CGNAT one: a blind instrument read as evidence.
      • printf pads by BYTE: the "Memória" label misaligned because `ó` is 2 bytes in UTF-8.
        It became "RAM". And ARM does not expose `model name` in /proc/cpuinfo, so the CPU name
        comes from `DISTRIB_ARCH`.
      • The `shellcheck` hook entered `flake.nix` because of this script:
        `scripts/sync-secrets.sh` already got verification for free through
        `writeShellApplication`, but `owfetch.sh` runs in ash ON THE ROUTER and no derivation
        wraps it, so it would be the only `.sh` in the repo executing on somebody else's
        machine WITHOUT verification. Turning the hook on required `# shellcheck shell=bash` in
        `.envrc`, which has no shebang (SC2148).

- [x] ~~CGNAT~~ FALSE ALARM: external access ALWAYS worked (08/08/2026). This entry was born
      WRONG on 07/08 and it stays rewritten instead of deleted, because the value is in the
      method that failed. Yesterday's conclusion ("there is no inbound route, it is CGNAT") was
      false on all THREE legs:
      • There is NO CGNAT. The router has the public IP directly on `pppoe-wan`. The
        `172.31.43.240` I read as "the ISP's NAT" in the traceroute is the PEER of the PPPoE
        link. RFC 1918 hops in a traceroute do not prove CGNAT, because an ISP uses private
        space in transport, and that looks the same in both cases. It was inference, sold as
        proof.
      • The ISP does NOT block. Proven by the nftables counter (`nft list chain inet fw4
        dstnat_wan`): 3 hits from outside gave counter +3. The packets always arrived.
      • External access WORKS. Proven by Cloudflare's edge: a temporary `proxied` record, and CF
        connected to Caddy and got the `404 Subdomínio não configurado` in 0.39s, with the
        router counter going up along with it. Case closed.
      • WHAT BLOCKS IS THE FAI NETWORK. It was my only external vantage point, and it is not
        neutral: the SYN leaves there and arrives here, the router's conntrack shows `SYN_RECV`
        (which means Caddy DOES answer the SYN-ACK), and the final ACK never comes back. The FAI
        firewall drops the SYN-ACK.
      • METHOD, three ways for the test to LIE, all of them committed here:
        1. FROM INSIDE THE LAN: the router does hairpin and the port "opens". A false positive.
        2. THROUGH THE FAI VPN with the tunnel ACTIVE on the target:
           `ip route get 200.136.209.229` goes out through `ppp0` with source `192.168.50.1`, so
           the answer comes back by another path and the client discards it. A false NEGATIVE,
           and the most treacherous one, because it looks like a legitimate external test.
        3. A SINGLE EXTERNAL VANTAGE POINT: if it is the one blocking, everything looks broken.
           A corporate network cannot judge its own case, which demands a SECOND independent
           point.
      • THE TOOL THAT SOLVED IT, keep it for next time: create a `proxied` record on Cloudflare
        and hit it. CF becomes a NEUTRAL external vantage point that is already yours, with no
        third party and no VPN. The catch-all `404` is the perfect signal, since you do not even
        need a service up. Delete it afterwards.
      • CONSEQUENCES: `expose = "public"` WORKS today. There is no need for cloudflared, no need
        to call the ISP, and the `trusted_proxies` trap becomes theoretical again (but the
        `client_ip` stays, because it is still correct).
      • AND THE REAL RISK INVERTS: `jellyfin` and `torrent` are exposed to the internet NOW,
        with the app's own login as the only barrier. Yesterday that was theoretical ("nothing
        reaches it"); today it is a fact. The wildcard resolves here, 443 is forwarded and Caddy
        serves both with no gate. Decide consciously: keep it, or switch to `expose = "lan"` in
        the panel.

- [x] Cloudflare in Claude Code: CLI + MCP (07/08/2026), to close Caddy's "pending discovery"
      (the wildcard answering with a private IP) without me reading the zone in the dashboard by
      hand. Two pieces: `.mcp.json` at the root and `.claude/settings.json`.
      • `wrangler` CAME IN AND WENT OUT the same day, and the reason is worth recording because
        I was about to repeat it: I assumed the "official Cloudflare CLI" would serve for DNS.
        IT DOES NOT. The entire help is Workers/Pages/KV/R2/AI/Queues, and there is no
        `wrangler dns` and nothing about zones. And the price was 2.2 GiB of closure, FOUR
        copies of nodejs-24 (slim, -npm, -corepack and the full one): on its own, +1.91 GiB of
        the +2.10 GiB of that switch. It contradicted the very criterion I used two lines below
        to refuse the Workers skills. What does DNS is the MCP.
      • THE SCOPE IS PROJECT, and NOT global, against what I had asked for, because global and
        declarative are MUTUALLY EXCLUSIVE here, and the why is worth recording. The three MCP
        scopes in Claude Code: `local` and `user` (=global) live in `~/.claude.json`; only
        `project` lives in `.mcp.json`, versioned. And `~/.claude.json` is the file that holds
        `numStartups`, `tipsHistory`, `projects` and a feature cache, which the app REWRITES at
        runtime, so by rule 14 Nix cannot own it. Global = imperative. End of story.
      • THE ESCAPE HATCH EXISTS AND WAS REFUSED: `/etc/claude-code/managed-mcp.json` would be
        declarative (`environment.etc`) AND global, the only way to have both. But it takes
        EXCLUSIVE control: "Claude Code loads only the servers that file defines. Users cannot
        add, modify, or use any other MCP servers, including plugin-provided servers." That
        would KILL github, atlassian and the claude.ai connectors. Trading 4 working servers for
        1 is a terrible deal, and project scope solves 100% of the use case, since the DNS/Caddy
        work is IN THIS repo.
      • The official plugin (`cloudflare/skills`, which the docs tell you to install) was OPENED
        and REFUSED: it brings 5 MCP servers and 13 skills, and 11 of them are
        Workers/Durable Objects/Pages/Turnstile, a dev platform I do not use. What was left is
        what serves: `cloudflare-api` (DNS, zones, tokens) and `cloudflare-docs`. The 3
        discarded ones were `bindings`, `builds` and `observability`. The marketplace was
        removed after being inspected, it was not left orphaned.
      • `enabledMcpjsonServers` in `.claude/settings.json` PRE-APPROVES both: without it Claude
        asks on every session. It only holds in a trusted workspace, since a cloned repo does
        not self-approve.
      • Auth is OAuth in the browser, on the FIRST tool call, so there is no token in the repo
        (rule 12). It is a credential SEPARATE from the `cloudflare-dyndns` sops token; do not
        confuse the two.
      • `.mcp.json` is strict JSON, with no comments, which is why the "why" is here and not
        there.

- [x] Caddy is back, declarative (07/08/2026): "Phase 4, Homelab" started. The Arch ingress
      (`caddy/etc/caddy/Caddyfile` on the `main`/`arch` branch) had been left behind in the
      migration. `services.caddy` now serves `*.v1cferr.dev` with a WILDCARD LE cert through
      Cloudflare DNS-01, and `my.net.domain` (system/net/domain.nix) became the domain's SSOT:
      before, the literal existed in a single place (the DDNS), which did not justify an option;
      with the proxy the consumers became four and triggered rule 11.
      • The reason for the biggest hack of the old setup DIED: building with xcaddy and hiding
        the binary in `/usr/local/bin` existed because "a `pacman -Syu` once overwrote the custom
        binary and took the whole proxy down". On Nix it is `caddy.withPlugins` with the vendor
        pinned by hash, so the package IS the declaration.
      • `propagation_timeout -1` was PRESERVED literally. It is not a preference: certmagic's
        local propagation check fails on this host, and without turning it off the issuance
        hangs.
      • The repo's FIRST `networking.firewall.allowedTCPPorts` (80/443). Everything else uses
        the upstream module's `openFirewall`, but `services.caddy` does not have one. The router
        had been forwarding 80/443/2222 since the Arch days; what blocked was the NixOS
        firewall.
      • AUTO-GATE on the 4 secrets (the duo.nix pattern), because an empty `{$VAR}` becomes an
        empty basic_auth hash and Caddy would refuse the ENTIRE config, and inert is better than
        taking the proxy down on the switch.
      • Validated WITHOUT a switch: the rule 11 sentinel ritual (the DDNS + the vhost + 5
        matchers + the failregex all changed together) and `caddy validate` on the generated
        Caddyfile, with the custom binary, returning `Valid configuration`.
      • ~~Pending discovery: the wildcard answers with a private IP~~: SOLVED on 07/08/2026, and
        the diagnosis was WRONG. There was no wildcard at all on Cloudflare: the zone had 10
        records and no `*`. What answered `192.168.1.10` was the ROUTER (192.168.1.1), which has
        a local wildcard `*.v1cferr.dev` pointing to 192.168.1.10 configured on it, outside Nix,
        as split-horizon so the LAN does not hairpin through the WAN. The mistake was MEASURING
        FROM INSIDE THE NETWORK: `dig @1.1.1.1` also returned the private address because the
        router hijacks port 53. What broke the tie was DNS-over-HTTPS (port 443, unhijackable):
        from outside, `ssh` always resolved correctly to the public IP, and a random name gave
        NXDOMAIN. `cloudflare-dyndns` was never broken. LESSON: to validate public DNS from
        inside your own LAN, use DoH, because `dig` lies when there is interception.
      • WILDCARD ADDED (07/08/2026): `*` CNAME to `ssh.v1cferr.dev`, DNS-only. A CNAME and not an
        A on purpose: `cloudflare-dyndns` only manages `ssh.${domain}` (network.nix:67), so the
        wildcard INHERITS the dynamic IP for free, while an A would be frozen at the first IP.
        That matches the design the Caddyfile already had: a wildcard cert plus the catch-all
        `respond "Subdomínio não configurado" 404`. Before that, NONE of the five vhosts
        (pos/duo/ai/jellyfin/torrent) had a record, so from outside the whole proxy was
        unreachable.
      • The wildcard plus DNS-01 risk was TESTED, not assumed: if the wildcard ran over
        `_acme-challenge.*`, the cert renewal would break in ~60 days, silently. Queried through
        DoH, an explicit TXT under the wildcard is still returned as a TXT (RFC 4592: an
        explicit record takes precedence). Renewal is safe.
      • ZONE CLEANED the same day: 10 records became 3. Out went the two orphan `_acme-challenge`
        TXTs (`prowlarr`/`torrent`, leftovers from Arch, since certmagic did not clean up), the
        `tv` A pointing at 179.135.127.74 (a DEAD IP: the DDNS only manages `ssh`, and being
        explicit, `tv` beat the wildcard and stayed broken, so it was removed and now inherits
        the live IP) and the `ap`/`dash`/`files` CNAMEs to `ssh`, which the wildcard made
        redundant. What was left is `A ssh` (the target of both the DDNS and the wildcard),
        `A v1cferr.dev` proxied (the site on Vercel) and the `CNAME *`.
      • The `ns1/ns2.dns-parking.com` NS records also went out. They were leftovers from the
        HOSTINGER import, and the check that authorized removing them: the REAL delegation lives
        at the REGISTRAR, not in the zone, and `dig NS` already returned only
        `bruce/zoe.ns.cloudflare.com`, proving Cloudflare never served those two. Nothing from
        Hostinger needs to exist in the zone; the link is their dashboard pointing at
        Cloudflare. (If email ever comes to the domain, then yes: MX + SPF.)
      • A split-horizon TRAP: the ROUTER's wildcard also covers the APEX, so from inside the
        LAN `https://v1cferr.dev` hits Caddy and gives a TLS ERROR, because the `*.v1cferr.dev`
        cert does NOT cover bare `v1cferr.dev` (a wildcard does not match the domain itself). It
        is not broken: through Cloudflare's edge the apex answers a normal 307. It just cannot
        be tested for the apex from home.

- [x] `arch-browse` opens again (07/08/2026): the alias was RIGHT, what broke it was the
      backup. `restic-backups-home-gdrive` runs as ROOT and the `rcloneConfigFile` option only
      sets `RCLONE_CONFIG=/run/secrets/rclone_gdrive_conf`. rclone renews the OAuth token and
      PERSISTS it over the file it was pointed at, which as root works, and the recreated file
      is born `root:users`, erasing the sops `owner = "v1cferr"`. Then the alias, which runs as
      the user (a FUSE mount is private to whoever mounts it), could not read rclone.conf
      anymore.
      • A treacherous symptom: it FIXES itself on reboot (sops reapplies it) and breaks on the
        first backup. The day's timeline closed exactly: boot 07:29:47, `~/Drive` read OK
        07:30:10, the delayed 03:00 run (`Persistent = true`) ran 07:54:39, the secret became
        root's 07:54:40.
      • How it was found: comparing `/run/secrets/*` against the sops `manifest.json` from
        `/run/current-system/activate`. Only `rclone_gdrive_conf` diverged. It is worth keeping
        as a recipe, since secret drift does not show up in `nixos-rebuild`, only at runtime.
      • Fix: a writable copy in `/run/restic-backups-home-gdrive/rclone.conf` (the
        `RuntimeDirectory` the module already declares), the same pattern as `~/Drive`. restic
        never touches the secret again. `mkBefore` on `preStart`, NOT `mkAfter`: the
        `initialize = true` injects `restic cat config || restic init` at the beginning of the
        SAME script and that already talks to the Drive, so copying after it would kill the
        service right at the start.
      • No token was lost: `/run` is tmpfs, so root's write was already discarded on every
        reboot. sops was always the source of truth.

- [x] Dolphin closer to **Windows Explorer** (07/08/2026): 6 keys, and only the ones where the
      Dolphin default DIVERGES from Explorer. Each default was read in the package's
      `config.kcfg`, not guessed; `HighlightEntireRow` and `SortFoldersFirst` already came
      right and stayed out.
      • `[DetailsMode] ExpandableFolders=false`: the `▶` markers and the tree lines were the
        most jarring thing, since Explorer has no expander in that view.
      • `[General] ShowSelectionToggle=false` (on Win11 "checkboxes" comes off),
        `AlwaysShowTabBar=true`, `ShowFullPath=true`, `ShowStatusBar=FullWidth`.
      • `[KDE] SingleClick=false` (double click) came in and went OUT the same day. The request
        is INTERFACE similarity, and clicking is BEHAVIOR, so it does not change a pixel.
        Worse: it lives in kdeglobals, so it would change EVERY KDE app because of the file
        manager. It works as a ruler for the rest: touch what you SEE, not what you USE.
      • The "pixel-perfect" guide that circulates (vrunox-9714/dolphin-win11-theme) was
        REFUSED, and not out of laziness: it depends on a **KWin** rule to remove the title bar
        (here it is Hyprland, there is no KWin) and on a QSS through `--stylesheet`, which
        would fight the Kvantum that already draws all of Qt. Before copying a theme recipe,
        check whether it presumes Plasma.
      • An Explorer-style TOOLBAR: TRIED AND REFUSED the same day (07/08/2026). Not committed,
        and `~/.local/share/kxmlgui5/dolphin/dolphinui.rc` was deleted. The primary reason: I
        did NOT LIKE the result. Explorer has TWO strips (the address on top, the commands
        below) and Dolphin has only ONE toolbar, so everything piles into a single line and it
        ends up worse than the clean default. It is not a config limitation, it is Dolphin's.
        There was also a cost that on its own already called for caution: the `.rc` carries
        `version="48"` and when Dolphin goes to 49, KXMLGUI DISCARDS the file silently, so the
        toolbar would go back to the default with no error at all. The same class of drift as
        the ViewMode.
        If somebody insists: it is an idempotent activation and never `home.file` (rule 14,
        since Dolphin rewrites the file in "Configure toolbars"). But the verdict is NO.
      • Where the look STOPPED: icons plus the 5 keys above. What would be left requires
        fighting Kvantum (QSS) or a KWin that does not exist here, which means nothing cheap is
        left.

- [x] Dolphin icons: Fluent to **Win11** (07/08/2026). The request was "as similar to Windows
      11 as possible", and the starting point ALREADY WAS a Windows 11 theme
      (`fluent-icon-theme` is Fluent Design). So it was not a fix, it was fidelity:
      `Win11-icon-theme` redraws Microsoft's icons, while Fluent is an authorial interpretation
      of Fluent Design.
      • Decided by LOOKING, not by reading: I put together a comparison with the real icons of
        the 3 candidates (Fluent / Win11 / We10X), 19 names each, at the same size and
        background. `We10X` is out for being Windows **10X**, the previous generation; it shows
        up in lists for being popular, not faithful.
      • The argument that decided it: `Win11-icon-theme` is by the SAME author
        (yeyushengfan258) as the `Win11OS-kde` we already vendored for Kvantum, so widget and
        icon match out of the box.
      • The price: it leaves nixpkgs (vendored, pinned by commit `a5b460a`), so bumping became
        MANUAL.
      • Three traps paid for in the build, all invisible in the upstream docs:
        1. `nativeBuildInputs = [ gtk3 ]` is MANDATORY. install.sh calls
           `gtk-update-icon-cache` at the end of EACH variant and the `set -eo pipefail` kills
           it right there, after installing the 1st. Without that, `Win11-dark`, which is the
           one we use, did not even exist. And it is not about the cache: no `icon-theme.cache`
           survives in the output.
        2. `noBrokenSymlinks` fails the build with 147 dead links per variant. Silencing it is
           NOT a workaround: they are color variant names (`folder-green.svg`,
           `folder_color_yellow_wine.svg`) whose target does not exist in ANY installation, not
           even on Arch, because `colors/color-<X>/` uses `folder-*.svg` names to override and
           never creates the prefixed ones. A cosmetic upstream bug. Prune it with
           `find "$out" -xtype l -delete`.
        3. `-t <color>` stays OUT: it copies `colors/color-<X>/` OVER `places/scalable` and
           would recolor the folders. The empty variant is precisely the one that was approved.
      • Comments citing "Fluent-dark" in launcher.nix/clipboard.nix now point at
        `my.theme.iconTheme`. A hardcoded theme name in a comment is drift waiting its turn.
      • AND THE THEME ALONE WAS NOT ENOUGH: in the 1st screenshot after the rebuild the folders
        came out as monochrome LINE ART. The theme has colored art in `places/16` and
        `places/scalable`, but `places/22` is `fill="currentColor"`, and 22 is the default. It
        was not a Win11 regression: Fluent had the SAME monochrome 22, it just did not show
        because the view was Compact (a big icon, so it fell into scalable). Which means what
        revealed it was the switch to Details, which landed the same day, two changes together
        disguising the cause.
        The key is `[DetailsMode] PreviewSize`, NOT `IconSize`. I got it wrong twice before
        reading `dolphinitemlistview.cpp:172`: `previewsShown() ? previewSize() : iconSize()`,
        so with previews on, `IconSize` is IGNORED. Both went to 32 so the size does not jump
        when the preview is turned off to dig through the archive. It lives in
        `home/apps/dolphin.nix`.
      • A repeated lesson: `grep currentColor` on the SVG made me conclude that the 16 was
        monochrome when it is COLORED (a 28 KB file, with the color outside the fill). Only
        rendering the three sizes side by side made the picture appear. For an icon, RENDER it,
        do not read the XML.

- [x] "Always Details" was never Details (07/08/2026): it had been **Compact** since 18/07.
      The `dolphin.nix` pin always worked, it pointed at the wrong mode. `DolphinView::Mode`
      (`src/views/dolphinview.h`) is `0 = Icons, 1 = Details, 2 = Compact`, and NOT the menu
      order (Icons/Compact/Details = Ctrl+1/2/3). The kcfg `whatsthis` still calls 2 "column"
      (Compact's old name) and reinforces the mistake.
      • The diagnosis came from a SCREENSHOT, not from reading config: I opened Dolphin and
        looked. A "correct" config with the wrong effect cannot be seen by reading the
        `.directory`. If you are going to check a view mode, look at the screen: the name to
        the right of the icon plus a second column means Compact; Details has column headers
        and one line per item.
      • The raw number became a named `viewModeDetails`, so it does not mislead again.
      • Migrating 2 to 1 required a new branch in the activation: over an ALREADY immutable key
        kwriteconfig6 exits 2 and `set -e` would take the rest of home-manager down, so it
        rewrites with sed directly.
      • This is rule 14 proving itself for the SECOND time in the same file: nothing failed, it
        was just wrong, for 3 weeks. A KConfig pin with no verification is drift waiting its
        turn.

- [x] A THUMBNAIL on the restic mount costs a DOWNLOAD from the Drive: measured on
      07/08/2026, this is not theory. `PreviewsShown` has `<default>true</default>` in
      `dolphin_directoryviewpropertysettings.kcfg` (26.04.3) and it is not set here, so the
      preview is ON. I opened Dolphin in the snapshot's `Pictures/Screenshots` (30 files,
      3.9 MiB): +30 thumbnails in `~/.cache/thumbnails` and **+3.68 MiB read from the network**
      by `rclone serve restic`, which means it downloaded the whole folder just to draw icons.
      • KDE's `MaximumRemoteSize` (default 0 = do not preview remote) does NOT protect, and the
        test PROVES it: it is unset and the preview happened anyway. A FUSE mount in `/mnt`
        looks to KIO like a LOCAL path, so the "remote" guard is not even consulted.
      • And the local limit (`[PreviewSettings] MaximumSize`) does not work as a guard: it is
        global and the images were ~130 KiB each, far below any sensible ceiling.
      • There is no PER-PATH guard in Dolphin/KIO, checked in the kcfg and in the binary's
        symbols. With `GlobalViewProps=true` there is no way to turn the preview off only in
        `/mnt` either.
      • DECIDED: the preview stays ON everywhere. A global `PreviewsShown[$i]=false` was
        refused, because a thumbnail is worth more day to day than protection against a rare
        lookup. The mitigation is manual: turn previews off before digging through the archive.
        Recorded with a warning in the "Old Arch Linux configs" section, which is where you land
        when opening the repo.

- [x] VS Code always on the latest stable, with no manual edit (06/08/2026): this closes the
      loose end yesterday's URL change left. The request was "I would rather always keep it on
      latest", and the answer is NOT going back to `/latest/`: a pointer plus a pinned narHash
      is exactly the per-release breakage we fixed yesterday. An input that updates itself does
      not exist with a pinned hash; what exists is an AUTOMATED BUMP.
      • `pkgs/vscode-bump.nix` (`writeShellApplication`, rule 7, since the build IS the
        shellcheck): it queries
        `update.code.visualstudio.com/api/update/linux-x64/stable/latest`, reads the
        `productVersion` (and NOT the `version`, which is the commit hash), rewrites the number
        in `flake.nix` and runs `nix flake update vscode-tarball`. It is a NO-OP when already on
        the latest, because it runs on every `upgrade`.
      • The repo path comes as an ARGUMENT (rule 11): the SSOT is `programs.nh.flake`, read by
        zsh.nix through `osConfig`, so the package holds no literal.
      • A scheduled Action was discarded: the repo would stay current on its own, but it would
        require a `git pull` before the `upgrade` to be worth anything, and each bump would
        trigger the 1.43 GiB CI. The moment the version matters is the REBUILD, so the right
        trigger is the alias.
      • Along for the ride, the aliases stopped repeating themselves: `rebuildCmd`/`updateCmd`
        are composed in the `let` and `upgrade` = `${updateCmd} && ${rebuildCmd}`. Before,
        `upgrade` spelled both out, which is the same rule in two places, and on the day only
        one copy changes, `upgrade` stops being what its name says (rule 11).
      • VALIDATED with a round trip, and that is the proof that matters: I downgraded
        `flake.nix` by hand to 1.131.0, ran the bump and `flake.lock` came back BYTE-IDENTICAL
        to the committed one (the `sha256-PLpT3k…` narHash of 1.132.0). `nix flake check`: all
        checks passed.
      • What this does NOT solve: the extensions and settings still come from Settings Sync (a
        Microsoft account), not from Nix, so only the PACKAGE is declarative.

- [x] earlyoom was NOT protecting the compositor (05/08/2026): the most serious finding of the
      cleanup, and it turned up by accident. `waybar` and `mako` were in the `--avoid` list and
      are ghosts (they left in the migration to Quickshell). When taking them out, I measured
      the regex against the LIVE processes and it matched 5 out of 10, with Hyprland left out.
      • THE CAUSE: earlyoom matches `comm`, the KERNEL field truncated at 15 chars. The nixpkgs
        `wrapProgram` leaves the script with the original name and the real ELF as
        `.X-wrapped`, and what RUNS is the ELF, so the comm is `.Hyprland-wrapp` and
        `.quickshell-wra`. `^(Hyprland|…)$` never matched. The comment promised "the compositor
        never dies" and the effect was the opposite of what was written.
      • Now it is `^[.]?(…)` with no `$`, matching 16 live processes. `quickshell` came in
        (today it is the bar, the OSD AND the notification daemon), along with `hyprpaper`.
      • A TRAP INSIDE THE TRAP: I wrote `"^\\.?"` first, and the backslash DOES NOT ARRIVE,
        because the module delivers the args through `Environment=EARLYOOM_ARGS=…` and systemd
        discards `\.` as an invalid escape. The daemon logged `'^.?(…)'`. A character class
        `[.]` has no backslash to lose. LESSON: check what the DAEMON parsed, never the .nix:
        `journalctl -u earlyoom | grep 'avoid killing'`.

- [x] The backup migrated from the HDD to Google Drive, verified (05/08/2026): the Seagate
      held the ONLY copy of the live home, on a ~2009 Momentus 7200.4 with 840 thousand load
      cycles and 348 CRC errors, INSIDE the machine. It was not about space: the Drive has
      4.95 TiB free out of 5 TiB. An offsite copy wins on the failure modes that actually
      happen (the disk dies, theft, fire); it loses on restoring over the network and it starts
      depending on the Google account.
      • Measured: the 1st snapshot read 40.6 GiB, becoming 23.6 GiB on the wire, in 15 min,
        across 255 thousand files. The next incremental: 33 s and 170 MiB. `check --read-data`
        rereading 189 packs: "no errors were found".
      • Three things a REMOTE repo requires and a local one does not: `--pack-size=128` (on the
        Drive the cost is per API CALL, not per byte), `checkOpts = []` (the local
        `--read-data-subset=10%` REREADS, and rereading remotely is DOWNLOADING, which would be
        GB/day forever) and `--max-repack-size=2G` (remote pruning repacks).
      • A BUG this uncovered: the backup FAILED INTERMITTENTLY with
        `lstat /home/v1cferr/FAI-workstation: permission denied`, so restic exits 3. It is a
        USER FUSE mount and the backup runs as ROOT, which does not enter somebody else's FUSE;
        it only happened with the FAI VPN up. And since `backup` is the 1st of THREE
        ExecStart entries, `forget --prune` did NOT run, so retention silently did not apply on
        those days.
        `--one-file-system` does not save you: it prevents DESCENDING, but the lstat of the
        mount point still happens.
      • The Seagate repo was NOT deleted: the Drive has 1 snapshot and it has 13, with a 6 month
        window. Deleting it today would lose every version older than today.
      • New aliases: `backup-browse` (it mounts the repo as a folder, one dir per snapshot) and
        `backup-verify`. rclone does NOT decrypt restic; what decrypts is restic.

- [x] ~/Drive = the Google Drive root MOUNTED, not synced (05/08/2026): I started with
      `rclone bisync` and switched to `rclone mount` after LISTING the remote, which is the
      step I should have taken FIRST. The root has ~19.6 GiB of real archive (Documentos,
      César, Mãe, SENAC and so on), and the dedicated folder I had invented would have been
      born EMPTY, which did not solve "I need a file that is on the Drive".
      • Mount wins here: zero download (bisync would pull the 19.6 GiB onto the NVMe for the
        SAME access) and sync PROPAGATES, so deleting locally would delete on the Drive,
        including family folders.
      • `Type=notify` (it is in `rclone mount --help`): the unit only becomes "started" after
        the mountpoint is ready, otherwise Dolphin opens first and caches "empty".
      • `--exclude BACKUPS_EX-B560M-V5/**`: it hides ~48 GiB of restic blobs from the file
        manager. It is not cosmetic, because an accidental Delete in there CORRUPTS the backup.
      • Two traps paid for: (1) bisync does not create the destination folder and the remedy it
        suggests fails too; (2) rclone RENEWS the OAuth token and tries to persist it into the
        config file, and against the sops secret (0400) that becomes
        `Failed to save config`, so the unit copies it into `%t` (tmpfs, 0600) and passes
        `--config` on the command line. `--config` on the command and not `RCLONE_CONFIG` in
        the environment, because exporting it would make the FAI mount look for the `faiws`
        remote in the wrong file.
      • And the mount would not come up because `~/Drive` had an orphan 0-byte `RCLONE_TEST`
        that the bisync version had created: rclone refuses a non-empty mountpoint, and
        `--allow-non-empty` stays out on purpose (mounting over it HIDES the file). If it does
        not come up: `ls -a ~/Drive` before suspecting the network.

- [x] An option is DECLARED in system/ and DEFINED in hosts/ (05/08/2026): this became
      convention 6 in the README. The monitor connectors (`DP-2`/`HDMI-A-3`) had a `default` in
      system/desktop/monitors.nix and the `my.services` panel lived in
      system/services/toggles.nix. With a single host that is invisible; on host number 2,
      system/ starts LYING (a laptop would inherit connectors it does not have and would bring
      Jellyfin/Sunshine up by default). Now system declares the options and
      `hosts/nixos-kingston/services.nix` answers them. The monitor defaults were removed on
      purpose: a host that forgets them BREAKS at eval, loudly and early.
      The `my.services` declaration is still central and was NOT distributed per module,
      because `osConfig` only sees the NixOS namespace, so the keys read by home/ (dropbox,
      discord-rpc, cs2-backup) need a SYSTEM module either way.

- [x] The gate started BUILDING, not only evaluating (05/08/2026): `nix flake check` builds
      what is in `checks` and of `nixosConfigurations` it only requires that the toplevel BE a
      derivation. Measured: it printed "running 1 flake checks" and only pre-commit was built.
      What is fragile here is not evaluation, it is PACKAGING: nxbender's 3 patches, vscode's
      `sourceRoot = "source"` and the wrapProgram over claude-desktop's .deb are assumptions
      about SOMEONE ELSE'S tree, so they break at build time, after an `update`, and since
      `upgrade` is `update && nh os switch`, the breakage landed in the middle of the switch.
      Now `packages.x86_64-linux` exposes all four (`nix build .#nxbender`) and
      `checks.packages` builds them. Deliberately NOT system.build.toplevel: that would drag
      quickshell (Qt/C++) onto the runner.
      And it caught its first victim the same day: the VS Code `/latest/` URL is a POINTER.
      1.132.0 shipped, the pointer moved and the pinned narHash (1.131.0's) stopped matching.
      Here it passed because the old tarball was in the store; on a CLEAN machine the flake did
      not evaluate anymore. It was not a 2032 risk, it broke on every release. Swapped for a
      versioned URL (`/1.132.0/`), which is immutable, and the price is that `nix flake update`
      does not bump the version on its own, since bumping means editing the number.

- [x] Hunting down dead code and dead docs (05/08/2026): deleted `pkgs/README.md` (it said
      "empty for now" with 2 derivations inside, and pointed at a "phase 5 of the README" that
      does not exist), `home/desktop/quickshell/bar-preview.qml` (the file itself defined when
      to die: "once the bar reaches parity, it is wired into shell.qml and Waybar goes away",
      and both things happened), `scripts/healthcheck.sh` (zero references in any .nix and a
      header calling itself "gitignored" while being VERSIONED, the loose `.sh` that rule 7
      forbids) and the orphan `.env`.
      Plus ~6 comments describing a world that does not exist (the "PHASES" in Bar.qml,
      `nvidia-smi` on an Intel machine, `waybar` in two category lists).
      AUDITED and clean: zero orphan `.nix`, zero flake input with no consumer (12 checked),
      every `my.*` option with a consumer.
      LESSON: the worst legacy is not a leftover file, it is a LIST ENUMERATING A REMOVED
      PROGRAM. The dead `waybar`/`mako` in earlyoom's `--avoid` hid the fact that the
      compositor was never protected. Dead docs there were not clutter, they were a disguised
      bug.

- [x] The `nixos-sandisk` node REMOVED from the tailnet (05/08/2026): it had been sitting
      offline for 4 days, belonging to a machine that no longer exists (the SanDisk became
      Windows 11), and a dead node is an ACL and a route nobody audits. Done in the admin
      console; 2 were left (nixos-kingston, faidell6035).
      • WHY THESE TWO DID NOT BECOME DECLARATIVE (researched on 05/08/2026, rule 1): the
        OFFICIAL CLI does neither. `tailscale --help` on 1.98.10 (the installed one) has 30
        subcommands and none of them is `key` or `device`. The closest is `logout`, which
        expires THIS machine's node key, not removes somebody else's node. The official
        "Remove a device" doc says console or API, with no CLI, and the upstream FR
        (tailscale/tailscale#8844) is still open. Both actions belong to the v2 API:
        `DELETE /api/v2/device/{id}` and `DELETE /api/v2/tailnet/{tailnet}/keys/{keyId}`, at
        `https://api.tailscale.com`.
      DECISION: do it in the admin console and do NOT store an API token. Automating it would
      require a token or OAuth client with write access to the whole tailnet, kept in sops, a
      PERMANENT secret more powerful than the auth key you want to revoke, created for a
      ONE-TIME task. It only pays off if a recurring routine ever exists (pruning idle nodes,
      say), and then the right thing is an OAuth client with minimal scope, not an admin API
      key.
      (A doc detail that matters: revoking the key does NOT deauthorize whoever already joined
      with it, since they are independent actions, and that is why both are on this list.)
      The CLI, by the way, ALREADY is declarative: it comes from `services.tailscale.package`
      (system/net/tailscale.nix), not from a package list. Putting `tailscale` in
      `system/packages.nix` would be the same package in two places, which breaks rule 4.

- [x] The Arch archive VERIFIED and the module DELETED (05/08/2026): the end of the lifecycle
      that `system/services/restic-arch-kingston.nix` itself had written down: "once the
      check --read-data passes and the Kingston is formatted, delete this file".
      • `sudo restic-arch-kingston check --read-data` returned `no errors were found`, reading
        the **189 packs** (1 snapshot, 7 indexes) of the repo on the Drive. That is what
        separates "it uploaded" from "it can be restored": it rereads the data, not just the
        index.
      • Out went the module, the import in `system/services/default.nix`, the
        `arch-kingston-archive` key in `toggles.nix` and the `true` in the host panel.
      • KEPT on purpose: the repos, the `restic_password_arch_kingston` secret (the Bitwarden
        index) and `rclone_gdrive_conf`. They are the KEY to a live archive, and the module was
        what WROTE to it, not what gives access.
      • A side effect that became a fix: deleting the module took the `restic-arch-kingston*`
        wrappers with it, and `restic` was NOT on the PATH, because the nixpkgs
        `services.restic` only generates a wrapper per repo. The archive would have been
        unreachable without a `nix shell`. `restic` went into `system/packages.nix` (the
        "rescue" criterion), and the wrapper-less commands are in the "Old Arch Linux configs"
        section above.
      • The Seagate leg was NOT read-verified and will not be: on 05/08 it was decided to keep
        ONLY the Drive copy. Verifying a repo that is going to be deleted is wasted work.

- [x] A second age recipient in the sops vault (04/08/2026): `.sops.yaml` had ONE key, and
      sops has no recovery, so losing that key means losing EVERY secret in the repo, forever.
      Its only backup was Bitwarden, so the design had a point of failure capable of permanent
      damage (the repo's other risks cost time, not data). Now there are two recipients:
      `host_nixos_kingston` (the usual one, in /var/lib/sops-nix/key.txt) and
      `backup_offline`.
      • `creation_rules` only applies to a NEW file, so adding the key to `.sops.yaml` does NOT
        re-encrypt what already exists. What does that is
        `sops updatekeys -y secrets/secrets.yaml`, run as root (the current key is root's) and
        with `chown v1cferr:users` plus `chmod 644` afterwards, otherwise the repo file ends up
        owned by root.
      • VERIFIED by decrypting the vault with the backup key in ISOLATION (`SOPS_AGE_KEY_FILE`
        pointing only at it). Without that test the backup would be imaginary, and `updatekeys`
        prints "already up to date" even when it does the job, so its message is not proof. The
        proof is decrypting, or the two `recipient:` entries inside secrets.yaml.
      • A good side effect: `restic_password` lives INSIDE the vault, so recovering the vault
        recovers the restic password, and losing Bitwarden no longer turns the repos into
        bricks.
      • The anchor was renamed from `nixos_seagate` to `host_nixos_kingston`: the key was born
        on that host and was carried over in the cutover (01/08), so it is the same key on a
        new host, and the old name was confusing.
      MISSING is the OFFLINE copy (USB or paper in another physical place): both copies of the
      private key today are on the same machine and in the same cloud account (~/ and
      ~/Dropbox, in plain text, a conscious choice). While that is the case, the second
      recipient protects against losing the host key, not against losing the account or the
      machine.

- [x] The CI started running `nix flake check` FOR REAL (04/08/2026): the workflow ran
      statix/deadnix/nixfmt straight from nixpkgs because the private `duo-streak-daemon` input
      would make `flake check` require a deploy key (Nix fetches ALL the lock's inputs when
      evaluating, not only the ones the output uses). That left two holes: the CI did not
      verify that `nixosConfigurations` EVALUATES (a module error stayed green until the
      rebuild), and the three `nix run` calls were a THIRD definition of the same rule that
      flake.nix and pre-commit already defined, rule 14 drift waiting to happen.
      • The way out was `--override-input duo-streak-daemon path:./ci/stub-duo`: it swaps the
        input BEFORE the fetch, so no credential enters the CI. An EMPTY directory is enough
        because the only consumer (`system/services/duo.nix`) uses the input purely as a Docker
        build context, which is path interpolation with no `readFile` at eval time. If some day
        a module READS a file from the private repo, the stub needs that file (or plan B, the
        deploy key, comes back; it is recorded at the end of the workflow).
      • The `env NIXPKGS` that existed only to pin the linters' version is gone: they now come
        from flake.lock, identical to the local ones by construction. Touching the flake.nix
        hooks changes the CI by itself, with no workflow edit.
      • ACCEPTED COST: the check fetches the ~1.43 GiB of inputs and evaluates the whole config,
        so the CI went from seconds to minutes. Machine time in exchange for coverage and for a
        single definition.

- [x] An offline archive of the flake inputs (04/08/2026): `nix flake archive --to
      file:///home/v1cferr/flake-archive`, which enters the home restic (`restic.nix` covers
      /home/v1cferr and does not exclude that path), so it ends up versioned and verified by
      the machinery that already exists, instead of a raw copy. Measured: 18 inputs, 1.43 GiB
      in the store, becoming **319 MiB** in the archive (the `file://` cache compresses with
      xz, which is why it takes a few minutes).
      • VERIFIED for real, not by "the files are there": each input was QUERIED back with
        `nix path-info --store file:///home/v1cferr/flake-archive <path>`, with 0 missing.
      • A TRAP when verifying: `--dry-run` also lists the ROOT flake path, which with a DIRTY
        tree changes on every edit, so it shows up as "missing" from the archive with nothing
        actually wrong. The archive is of the INPUTS; the repo itself has git as its backup.
      • WHY: `flake.lock` pins IDENTITY, not AVAILABILITY, and flakes have no mirrors (there is
        no `?mirrors=` like in fetchurl). Half the inputs come from a single maintainer or are
        self-hosted, and `quickshell` only exists at git.outfoxxed.me. If that server goes
        down, the input is unfetchable and the pinned rev helps with nothing.
      • What this does NOT buy: a complete offline rebuild. The sources of each nixpkgs package
        still come from the cache/upstream. To boot without building anything, what you archive
        is the system closure (a `nix copy` of system.build.toplevel), which is tens of GB, a
        different decision.
      PENDING becoming declarative (rule 3): today it is a manual command and it ages on the
      next `nix flake update`. The natural owner is a systemd timer re-archiving, and restic
      deduplicates, so re-archiving only adds the inputs that changed.

- [x] BTRFS properly configured (02/08/2026): the FS was audited after the cutover. What
      existed (noatime, space_cache=v2, subvolumes, a monthly scrub) was right; what was
      missing became system/hardware/btrfs.nix (POLICY, machine-agnostic behind "is the root
      btrfs?") plus system/services/btrbk.nix (snapshots). The LAYOUT stays in disko.nix.
      • SNAPSHOTS (the biggest gap): btrfs with no snapshots is ext4 with checksums. An hourly
        btrbk of @home, retention 48h/7d/4w, `snapshot_create=onchange` (otherwise an idle
        machine generates 24 identical snapshots a day and pushes the useful ones out). It does
        NOT replace restic, since it lives on the SAME disk; it covers "I overwrote it 20 min
        ago", restic covers "the disk died". @home only: the root already has per-generation
        rollback in GRUB, and a snapshot of `/` would not even catch /nix (a separate
        subvolume, since a snapshot does not descend into a nested subvolume).
      • zstd:3 to zstd:1: on a ~7 GB/s Gen4 drive the bottleneck becomes the COMPRESSOR.
        Decompression has the same speed at both levels, so reading loses nothing and every
        rebuild gains. It only applies to NEW writes; rewriting would require
        `defragment -czstd`, which BREAKS reflinks.
      • fstrim.timer TURNED OFF: `discard=async` (a kernel default since 6.2, now explicit in
        disko) is already the same operation, queued and rate limited. Both together means
        duplicate TRIM. If discard=async is removed from disko, turn fstrim back on in the SAME
        commit.
      • Automatic block group reclaim turned on (dynamic_reclaim + periodic_reclaim, kernel
        6.11+, both came as 0). It is the IN-KERNEL replacement for btrfsmaintenance's
        `btrfs balance -dusage=N` cron, and better, because it knows when relocating is NOT
        worth it. bg_reclaim_threshold stays untouched: it is mutually exclusive with the
        dynamic one (EINVAL).
      • Alarm: the scrub failed SILENTLY. Now OnFailure sends a critical notification to every
        live session plus the journal. On top of that, a DAILY check of
        `btrfs device stats -c`: the scrub is monthly, so an NVMe that starts dying on day 2
        would go 28 days with no warning. The counter does not reset itself, so acknowledge it
        with `device stats -z` AFTER investigating.
      • `+C` (nodatacow) on the database directories (Docker volumes, the Jellyfin SQLite):
        CoW plus random 8 KiB writes fragments endlessly. It only takes effect on NEW files,
        and it turns the checksum off for those files, a conscious trade-off, since both are
        rebuildable.
      A SINGLE MANUAL STEP (a subvolume is not born in a rebuild, since disko only runs at
      install time):
        sudo mount -o subvolid=5 /dev/nvme0n1p2 /mnt && sudo btrfs subvolume create /mnt/@snapshots && sudo umount /mnt
      The `nofail` on /.snapshots exists so that forgetting that step costs "btrbk does not
      run" (RequiresMountsFor) instead of "the boot drops into an emergency shell".
      Do NOT turn qgroups/quota on: it kills btrfs performance and it is the reason for half
      the "btrfs is slow" reports. Nothing here needs them.

- [x] DUALBOOT with the minegrub theme + SECURE BOOT (02/08/2026): systemd-boot became GRUB,
      with the Minecraft "world selection" theme, Windows 11 in the menu and Secure Boot on in
      both OSes. system/core/boot.nix (the dormant boot-grub.nix was absorbed) plus
      system/core/secureboot.nix.
      WHAT DECIDED THE ARCHITECTURE, and it was not taste: **the two ESPs are on different
      disks** (NixOS on nvme0n1p1, Windows on sdb1). systemd-boot only loads an EFI binary from
      its OWN ESP, so it is incapable of listing Windows, and switching OS would become F8 at
      POST every time. That takes LANZABOOTE down with it, since it is systemd-boot-only and it
      is the official Secure Boot path on NixOS. What is left is GRUB (it reads both ESPs, and
      it is what the theme requires) plus signing by hand through sbctl. There is no NixOS
      module that signs GRUB.
      HONESTY ABOUT WHAT THIS PROTECTS: the firmware verifies GRUB and Microsoft's bootmgfw;
      GRUB loads the kernel and initrd WITHOUT verifying them (it has no shim). It satisfies
      the firmware and Windows and it blocks a bootloader swapped from outside; it does not
      block someone who already has root. The whole chain only with lanzaboote, and then with
      no menu and no theme.
      `enroll-keys -m` (with the Microsoft certificates) IS NOT OPTIONAL: without it,
      erasing the factory keys takes down Windows AND the Arc B580's option ROM. And the timing
      matters: Microsoft's 2011 CA EXPIRED in june/2026. Checked on this machine on 02/08: BIOS
      2803 already carries both generations in the `db` (2011 plus the three 2023 CAs) and
      sbctl 0.18 embeds all six, so the `-m` also covers post-rollover Windows.
      `--firmware-builtin` would NOT work: this firmware's `dbDefault` is empty.
      A THEME TRAP: the icons match by `--class`, NOT by title, and it fails silently (a
      generic icon with no text). `nixos` comes from the default `entryOptions`; `windows` is
      derived by 30_os-prober from the FIRST word of the "Windows Boot Manager" label (so
      "windows", never "windows11"); `submenu` is the one for old generations. The 2-line text
      is RENDERED INSIDE the PNG in the Minecraft font, and the GRUB title is pushed off screen
      by the theme (`item_icon_space = 2000`), which is why every generation shows the same
      description: they share the `nixos` class. A theme limitation.
      THE THEME CHOICE: the original link was minegrub-theme (the Minecraft main menu), passed
      over for minegrub-world-sel-theme (the same author), because the world selection screen
      gives an icon plus a description PER OS, which is what a dualboot wants; in the main menu
      an entry is just a button.
      MEASURED BEFOREHAND: the 1 GiB ESP holds all 10 generations. install-grub.pl turns
      copyKernels on by itself (/boot is on a different filesystem from /nix/store, which also
      avoids depending on GRUB reading btrfs+zstd) and names files by store hash, so
      generations sharing a kernel occupy space once: 13 MiB plus 47 MiB per kernel version.
      The runbook of the MANUAL steps (Setup Mode can only be entered through the BIOS) is in
      the secureboot.nix header, along with the why of each one.

- [x] Remove every other host and keep only the current one: today there is only
      hosts/nixos-kingston/. nixos-sandisk left on 02/08/2026, because its disk became Windows
      11, so the host was no longer a rollback and no longer a target. A template for a new
      host can be taken from the git history.

- [x] Add Duolingo running automatically with Nix: the duo-streak-daemon stack (a Playwright
      daemon + api + web + Postgres) through docker compose managed by systemd
      (system/services/duo.nix). The code is a private flake input (git+ssh, pinned in
      flake.lock); the secrets come through sops (the duo.env template); the login uses a saved
      SESSION (duo-login once, because headless falls into Duolingo's anti-bot). The streak is
      kept alive on its own once a day (catch-up). Helpers: duo-login, duo-run-once.
  - [x] Install Ollama or another recommended way to run AI models locally: NATIVE Ollama
        (system/services/ollama.nix), **on the GPU (Arc B580) through Vulkan** since
        06/08/2026. qwen3:4b (the text solver) plus bge-m3 (embeddings) through loadModels. It
        is the local solver for duo-streak-daemon (localhost:11434), with no quota and no
        cloud.
  - [x] Ollama on the Arc B580 GPU (06/08/2026): this was the "explore later" left pending
        from the card swap. `services.ollama.acceleration` does NOT exist anymore
        (`mkRemovedOptionModule`): acceleration became a PACKAGE choice, and plain `pkgs.ollama`
        is the same as `-cpu` when there is no rocmSupport/cudaSupport, which means the old
        "CPU-only" was not a nixpkgs limitation, it was the default. A 1-line solution:
        `package = pkgs.ollama-vulkan` (0.32.3, already in 26.05).
        VULKAN and not SYCL/ipex-llm because Vulkan uses the Mesa ANV that is already on the
        system, so there is nothing new to package (ipex-llm is not in nixpkgs).
        Measured at startup: `library=Vulkan description="Intel(R) Arc(tm) B580 Graphics
        (BMG G21)" type=discrete total=11.9 GiB available=9.7 GiB`. `llvmpipe` (Vulkan on the
        CPU, showing up as GPU1 in vulkaninfo) is discarded by ollama itself, so
        `GGML_VK_VISIBLE_DEVICES` was not needed.
        The module's hardening already allows the card: `DeviceAllow` has `char-drm`
        (major 226 = /dev/dri/*) and `SupplementaryGroups = [ "render" ]`.
        A known risk: the Vulkan backend crashing on Arc under high-frequency decode
        (ollama#14207). The fallback is `pkgs.ollama-cpu`, 1 line.
        An ARCHITECTURAL CONSEQUENCE: Mesa is now a critical path for AI, not only for games,
        which reinforces the driver/unstable item below.
  - [x] Claude Desktop (GUI: Chat/Cowork/Code), 02/08/2026. The research changed its answer
        halfway through: on **30/06/2026 Anthropic started publishing an OFFICIAL Claude
        Desktop for Linux** (beta, a `.deb` in an APT of its own, with only Debian/Ubuntu
        supported). That RETIRES the projects that reverse engineered the macOS/Windows binary,
        which was the entire state of the art until then. It is NOT in nixpkgs: issue #366213
        (a package request) was CLOSED and the channel only has claude-code/claude-monitor.
        CHOSEN: `aaddrick/claude-desktop-debian` (5.3k stars, automatic releases following the
        upstream version), which REPACKAGES the official .deb since v3.0.0, using `dpkg-deb`
        plus `autoPatchelfHook`, the nixpkgs vendored-binary pattern (discord/vscode). PASSED
        OVER: `k3d3/claude-desktop-linux-flake` (the pioneer and the most cited in searches,
        but it reverse engineered the native module and has been IDLE since nov/2025, which
        predates the official release) and `heytcass/claude-for-linux` (it extracts from the
        macOS DMG; 6 stars and 77 open issues).
        A criterion beyond popularity: aaddrick does NOT use the nixpkgs electron (it keeps the
        tree co-located so `/proc/self/exe`/`resourcesPath` resolve) and does NOT turn the
        sandbox off. `chrome-sandbox` ships SUID, the store carries no SUID, and instead of the
        `--no-sandbox` most forks use, it relies on the userns sandbox.
        The **FHS** variant and not the plain one: the MCP servers need to find node/uv, and
        Cowork brings up a real QEMU VM looking for `/usr/share/OVMF/*.fd` and
        `/usr/bin/virtiofsd` at HARDCODED FHS paths, so outside the FHS it only answers
        `virtualization_tools_missing`. MEASURED closure: 2.9 GiB (qemu_kvm is the biggest
        slice).
        Integrated through **`overlays.default`** and not through `packages.<system>` (which is
        the zen-browser/browser-previews pattern here): I checked FIRST that the 13 attributes
        the package uses (libgbm, addDriverRunpath, qemu_kvm, OVMF and so on) exist in 26.05,
        so it can be built against the stable base instead of dragging a 3rd nixpkgs into the
        lock. Its input is `nixpkgs-unstable`, and `follows` alone would NOT solve it (the
        overlay uses the consumer's `final`, ignoring its own input).
        COWORK DOES NOT WORK on this machine until a MANUAL BIOS step: the kernel says
        `x86/cpu: VMX (outside TXT) disabled by BIOS` and `kvm_intel: VMX not enabled`, so
        `/dev/kvm` does not exist. Turn "Intel Virtualization Technology (VT-x)" on (the same
        visit as Secure Boot) and ONLY THEN add
        `users.users.v1cferr.extraGroups = [ "kvm" ]`, which did not go in here because it is
        not validatable without the device. `/dev/vhost-vsock` ALREADY exists. Chat and Code
        work with none of this.
        Runtime findings: `--doctor` is NOT a recognized flag in this version (it opens the
        GUI); the app comes up in NATIVE Wayland by itself, so the `CLAUDE_USE_WAYLAND=1` the
        official docs tell you to use is unnecessary here. Missing from the Linux beta:
        Computer Use and dictation.
        STATE (rule 6, so restic): the session/login and
        `~/.config/Claude/claude_desktop_config.json`, and the app REWRITES that JSON at
        runtime, so by rule 14 Nix does not own it.
        KEYRING: on the 1st login the app warns "your sign-in won't be saved" and asks for a
        login EVERY time. It is NOT the keyring (checked: `org.freedesktop.secrets` on the bus
        and `collection/login` present, so it is not the keyring-after-restore case). It is
        Electron autodetecting the secret backend from XDG_CURRENT_DESKTOP: "Hyprland" matches
        no case in Chromium's os_crypt, it falls back to "basic text" and safeStorage declares
        itself unavailable. The SAME bug and the SAME remedy as VS Code, but without
        `commandLineArgs` (this is not the nixpkgs electron), so it comes in through a wrapper
        (`overlayClaudeKeyring` in flake.nix). Only `claude-desktop` is wrapped: the upstream
        overlay builds the `-fhs` on top of `final.claude-desktop`, which is the FIXPOINT one,
        so the FHS variant inherits the wrap by itself and their fhs.nix did not have to be
        touched. The general rule: EVERY new Electron app here will need
        `--password-store=gnome-libsecret`.

- [x] Swap the RTX 3050 for an Intel Arc B580 (Battlemage): DONE. The Arc is validated (`xe`
      loaded, fastfetch/vainfo OK) and NVIDIA is REMOVED for good: system/hardware/gpu.nix is
      now pure Intel (xe + Mesa, VA-API iHD), with no `my.gpu`, no specialisation and no CUDA.
      Battlemage is fine on kernel 6.18/Mesa 25.x. Ollama stayed on the CPU through the swap
      and WENT BACK to the GPU on 06/08/2026 through `pkgs.ollama-vulkan` (see the Ollama item
      above).
      To resurrect NVIDIA: the git history of system/hardware/gpu.nix.

- [x] The Intel driver from the UNSTABLE channel: TRIED, TESTED and REJECTED (06/08/2026).
      The idea was "the driver always on the latest version, because Intel updates it every
      week". It dies on the fact that a graphics driver on NixOS is not a normal lib: it is a
      PLUGIN loaded impurely from `/run/opengl-driver/lib`, and the LOADER comes from the base
      channel. A loader accepts a driver equal to or OLDER than itself, never newer, because
      `libva` sweeps `__vaDriverInit_1_<minor>` from its own minor down to `1_0` and does not
      try above. Measured: the unstable `intel-media-driver` exports `1_24`, the stable `libva`
      2.23.0 stops at `1_23`, so `vaInitialize failed with error code -1`, and ALL
      decode/encode falls back to the CPU **silently** (rule 14: nothing fails, it just ends
      up wrong). A known community problem (nixpkgs #263940, #216361).
      **MESA IS THE EXCEPTION**, measured AFTERWARDS, and it is the opposite of what I had
      concluded: `libgbm` became a SEPARATE package (a stub that links the host's at runtime)
      and 25.05 introduced `hardware.graphics.package` precisely to "manage the global Mesa
      version without a mass rebuild". Tested: the `unstable.mesa` ICD plus the system
      vulkan-loader gives `deviceName = Arc B580` and `driverInfo = Mesa 26.1.6`; EGL the same,
      no error. In other words: **Mesa CAN cross channels** (the Vulkan/GL loader negotiates
      the version), `libva` CANNOT (it only goes down in minor). It is not the same class of
      problem, even though it looks like it.
      And the gain did not exist: nixpkgs BACKPORTS point releases to the release branch. Mesa
      26.1.5 vs 26.1.6, and kernel 6.18.42 + linux-firmware 20260622 are IDENTICAL on both
      channels. The only divergence is the Intel userspace (media-driver 26.1.6 to 26.2.4,
      compute-runtime 26.18 to 26.27, vpl-gpu-rt 26.1.6 to 26.3.0), and that is exactly the one
      that cannot cross channels.
      **THE RULE THAT STAYS**, per lever: (a) kernel goes to `pkgs.linuxPackages_latest`, from
      the OWN stable channel, with no crossing (done, see the kernel item); (b) Mesa goes to
      `hardware.graphics.package = pkgs.unstable.mesa` (plus
      `package32 = pkgs.unstable.pkgsi686Linux.mesa`, in that order, since
      `pkgs.pkgsi686Linux.unstable` is wrong, see flake.nix), a proven mechanism but ONLY worth
      it when the delta is a real minor: review ~sep/2026, when unstable goes to 26.2+ and
      26.05 pins to 26.1.x; (c) VA-API/oneVPL/compute stays on stable and only moves with the
      base (26.11, ~nov/2026); (d) do NOT adopt mesa_git or a third party cache.
      The warning is recorded in the `extraPackages` header in system/hardware/gpu.nix.
      Extra weight since 06/08: Mesa became a critical path for AI too, because Ollama started
      running through Vulkan/ANV, so it is not only game performance anymore.

- [x] Mainline kernel (`linuxPackages_latest`, 7.1.x): 06/08/2026, in system/core/boot.nix.
      It is lever (a) of the item above and the ONLY driver one that does not cross channels,
      because `linuxPackages_latest` comes from 26.05 itself, and the Arc's `xe` driver lives
      in the kernel, so a new kernel means a new driver with no loader ABI risk. It is safe on
      this machine because there is NO out-of-tree module (no zfs or virtualbox to version
      match, audited) and Secure Boot here signs GRUB, not the kernel (core/secureboot.nix), so
      it asks for no key re-enroll.
      It goes from 6.18.42 (the release default) to 7.1.6. Rollback is the previous generation
      in the GRUB menu. `boot` is PREFERABLE to `switch` on a kernel change, but `switch` does
      not break it: I had written "NEVER switch" and I was wrong, because NixOS keeps
      `/run/booted-system/kernel-modules` with the tree of the RUNNING kernel, and that is what
      happened in practice (switch 6.18.42 to 7.1.6, `systemctl --failed` empty, modprobe
      resolving under .../6.18.42). The advantage of `boot` is only not restarting a service in
      a generation whose kernel has not come up yet.

> Add all of them as the default

- [x] Centralized UI FONT (rule 10): `my.fonts.ui` in system/hardware/fonts.nix is the SSOT,
      so switching = 1 line plus the package. It lives in system/ (not in my.theme) because the
      PACKAGE is system level and fontconfig needs the name, since a system module cannot read
      an HM option while the reverse works.
      7 consumers, all through `osConfig.my.fonts.ui`: fontconfig (defaultFonts
      mono/sans/serif), GTK (dconf + gtk.font) and Qt in theme.nix, kitty, hyprlock, the rofi
      launcher + clipboard, and Quickshell through the SAME palette JSON (the .qml is a
      hot-reload symlink, Nix does not write inside it).
      The SIZE stays with each consumer (11pt GTK, 12pt kitty/rofi, per widget on the lock),
      because that is context. Validated with a sentinel: I changed the value, all 7 changed,
      and the revert came back to the same store path.
      JetBrainsMono Nerd Font is confirmed as the #1 recommendation for dev work in 2026 (Fira
      Code is 2nd, with ligatures; Iosevka is narrower, ~20% more code per line). A rofi TRAP:
      inside the .rasi, '#' opens a COLOR literal, not a comment, so commenting in there kills
      the parse of the WHOLE theme and rofi only warns on stderr, falling back to the defaults
      silently.
  - [x] FALLBACK CHAIN (02/08/2026): emoji, CJK, math and dingbats turned into a PIXELATED
        LITTLE SQUARE (a stream title on Twitch, a spreadsheet in Chrome). The diagnosis
        knocked down the obvious hypothesis: the emoji, CJK and color fonts were ALREADY
        installed, coming for free through `fonts.enableDefaultPackages = true`. The defect was
        the chain having ONE LINK ONLY: `sansSerif`/`serif`/`monospace` = the SSOT alone, a
        MONOSPACED font covering Latin/Greek/Cyrillic plus the patched symbols and nothing
        else. Everything outside that was resolved by fontconfig's own ordering, which is to
        say by ACCIDENT, and at the end of that queue sits `unifont`, a 16px bitmap that is the
        only one covering ranges like U+0870 and U+2FFC (measured with
        `fc-list ":charset=<cp>"`). The little square was it.
        FIX: `noto-fonts` (which brings NotoSansMath/Symbols/Symbols2, where the mathematical
        letters 𝗥 and the dingbats ⁎ come from), `noto-fonts-color-emoji` and
        `noto-fonts-cjk-sans`, all DECLARED even the ones already coming from
        enableDefaultPackages, because rendering cannot depend on a NixOS default nobody asked
        for. And each generic became a list: the SSOT first (appearance untouched), Noto in the
        middle, `Noto Color Emoji` at the END (at the end it never wins over a text font, but
        it is reached directly instead of by luck in the queue).
        A MEASUREMENT TRAP that almost made me conclude wrongly TWICE: `fc-match` LIES. With an
        explicit family (`fc-match "Noto Sans:charset=1F534"`) it returns the requested family
        even if it does not have the glyph, since charset only weighs on the ordering. And with
        no valid charset it answers anything (it answered `unifont` for everything when my loop
        broke the parsing). What filters BY REAL COVERAGE is `fc-list ":charset=<cp>"`.
        NOT A BUG: `❤` (U+2764) stays monochrome on purpose, because it is a TEXT PRESENTATION
        emoji and it only becomes colored with the VS16 selector (`❤️`). Forcing color would
        require a rule of its own.

- [x] Download a MEGA link through a proxy/Tor (03/08/2026): `mega-tor <link> [destination]`
      (home/net/mega.nix) plus a client-only Tor daemon with SOCKS on 127.0.0.1:9050
      (system/net/tor.nix, the `my.services.tor` toggle).
      THE TOOL: megatools (`megadl`), 139 KiB of closure, maintained (1.11.5, jul/2025). It is
      the only maintained one that opens a PUBLIC LINK from the CLI **and** has a NATIVE
      `--proxy socks5h://`, since its own man page uses `socks5h://localhost:9050` (Tor) as the
      example, so it needs no torsocks or LD_PRELOAD. Discarded: rclone (the `mega` backend
      talks to an ACCOUNT; a link with the key in the fragment is not a remote path,
      rclone#7088 open), MEGAcmd (official, a big closure and `proxy` only over HTTP(S): SOCKS
      is issue #204, open since 2019, and with no SOCKS there is no Tor) and megabasterd (a
      Java GUI; its proxy is a LIST of proxies for beating the quota, a different goal).
      THREE THINGS FROM THE NIXOS WIKI THAT DO NOT HOLD HERE (checked in the nixpkgs module,
      not assumed): (a) `services.tor.enable` without `client.enable` brings the daemon up with
      NO outbound port, so it stays `active` and nothing can use it; (b) the
      `openFirewall = true` from the example is for a RELAY, since the listener is 127.0.0.1,
      there is nothing to open, and opening it would become an open proxy on the LAN; (c) the
      "second fast port 9063" DOES NOT EXIST, because the module generates ONE SOCKSPort from
      `client.socksListenAddress`, and 9063 is only the default of the `torsocks-faster`
      wrapper (services.tor.torsocks), which without a hand-declared SOCKSPort points at a port
      where nobody listens. That is why torsocks was left out.
      `SafeSocks 1`: it refuses SOCKS4 and SOCKS5-with-IP, so whoever resolves DNS locally gets
      an ERROR instead of leaking the query, and that is why the consumer uses socks5h.
      A PATIENT LOOP (there is a single wrapper, `mega-dl`, with the transport as a flag; the
      `mega-tor` of the 1st version became `--tor`): it tries, and on failure it RESUMES until
      the file completes or until the 48h ceiling. Resuming is what makes this worth it: the
      partial lives in `.megatmp.<id>` at the destination, resume is the DEFAULT
      (`--disable-resume` is what turns it off) and it is keyed by the FILE ID, not by the
      transport. MEASURED: I started over Tor and continued directly from the same partial. The
      `--tor` proves the circuit first (the exit IP through check.torproject.org) so it fails
      with the right cause when the daemon is down.
      THE QUOTA IS THE REAL LIMIT, and no transport changes it: an anonymous download gets
      ~5 GB per IP in a ~6 h SLIDING window, counted per IP and not per account (logging out
      does not reset it). The real test was a 17.4 GiB file = ~4 windows. That is why the loop
      distinguishes "over quota" (a megatools string) and WAITS 30 min instead of switching IP:
      a sliding window frees up gradually, so knocking every 30 min yields more than waiting 6h
      idle, and slicing the file across different IPs is exactly what the quota exists to
      prevent (it is what megabasterd does with a proxy list). Urgency is solved with a Pro
      account (`megadl -u/-p`, the password through sops), not with rotation.
      QUOTA DETECTION through a `case` on a variable and NEVER `| grep -q`: with the
      writeShellApplication pipefail, grep exits on the 1st match, tail dies of SIGPIPE and the
      pipeline returns an error DESPITE the match (the same trap as the Sunshine healthcheck).
      And `du -shc` on a glob that matches nothing ALREADY prints "0 total" **and** exits with
      an error, so the fallback's `|| echo 0` came out added to it, printing "0" twice on the
      line.
      MEASURED RESULT (04/08, the 17.4 GiB test file): it completed THROUGH TOR in 3h19m, at
      ~1.5 MB/s on average, well above the 709 KiB/s of the initial moment. And the quota NEVER
      hit, contrary to my prediction: Tor rotates circuits over hours (MaxCircuitDirtiness =
      10 min for a new stream) and megadl opens a connection per chunk, so the traffic went out
      through several exit IPs with nobody asking. A side effect of Tor's design, not
      configuration from here, and that is why the prediction "17 GB anonymously will not
      happen" was wrong ON THIS PATH; on a fixed IP (direct or a single VPN) it holds.
      CHECKING THE FILE, and the order matters: (1) megadl already verifies MEGA's MAC and
      aborts with "MAC mismatch", so finishing with no error is CRYPTOGRAPHIC proof that the
      bytes are the server's, which is worth more than any file test afterwards; (2) `file`
      plus the signature at offset 0; (3) the final 8 bytes, which in a complete RAR5 end in
      `03 05 04 00` (the HEAD_ENDARC header, type 5 = end of archive), which is what separates
      "truncated download" from "whole file".
      A p7zip TRAP: `7z l` said `Type = gzip` and "There are data after the end of archive"
      on a PERFECT RAR v5. The nixpkgs p7zip comes with `enableUnfree ? false` and the
      postFetch RIPS OUT the unRAR code, so without the codec it does not recognize the
      signature, scans the file and matches the first blob that looks like gzip. It almost
      became "the download got corrupted". To really test a RAR CRC:
      `nix shell nixpkgs#unrar -c unrar t` (unfree, and this repo's allowUnfree is already
      true).
      MEASURED THROUGHPUT (04/08): what was slow was TOR, not MEGA and not the line:
        Hetzner (USA): 1 stream 17.2 MB/s | 8 streams 42.2 | 16 streams 33.9 (worse)
        MEGA (gfs206n184): 1 stream 27.7 MB/s | 4 parallel ranges 53.5 (449 Mbps)
        Tor (the real download): ~1.5 MB/s
      The NIC is gigabit, so the ceiling is the plan (~450 Mbps). The 17.4 GiB that took 3h19m
      through Tor would come down in ~11 min on a direct stream, ~5.5 min with 4 ranges.
      AND THIS IS WHERE SPEED AND QUOTA OPPOSE EACH OTHER: direct is 18x faster and stops at
      the window's ~5 GB; Tor is slow and in practice unlimited (circuit rotation). There is no
      free "fast AND 17 GB": whoever wants both uses a Pro account, and only then do the
      parallel ranges start to pay off (11 min to 5.5).
      THAT IS WHY I DID NOT BUILD A PARALLEL CLIENT: the gain is 2x over sequential megadl on a
      file that already takes minutes, and it would cost the MEGA API plus AES-CTR per chunk
      plus the meta-MAC reimplemented by hand (megadl already verifies it for free), which is
      debt of ours on every MEGA protocol change. If it ever becomes worth it, megabasterd does
      multi-slot out of the box, but it is 948 MiB of closure (it drags in a JRE) as measured in
      the cache.
      TOR ONLY FOR A SMALL FILE: I measured 709 KiB/s on the circuit (3 volunteer hops), which
      would mean ~7h and 17 GiB of DONATED bandwidth for a single file; the Tor project
      discourages bulk (the network is dimensioned for low latency, not for throughput) and
      MEGA also blocks part of the exit nodes (an immediate and repeated failure means a
      blocked exit, not a bad link; a new circuit is `systemctl restart tor`).
