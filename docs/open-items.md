# Open items

What is still open. A finished item migrates to [historico/](history/):
this file only grows with new work, and shrinks when work ends.

Convention inherited from the single-file era: every item explains the WHAT, the WHY and the
known trap. The paragraph is worth more than the title.

- [x] HEVC on Moonlight: TESTED AND DROPPED for the FAI notebook (10/08/2026). Turned on at
      14:43, it negotiated `hevc_vaapi` / clean Rec. 709 against `h264_vaapi` / Rec. 601, and I
      turned it off at 14:57 because in practice it was **"way too buggy"**. **H.264 is the
      final choice for this machine**, and it is DELIBERATE, not a forgotten default.
      • THE FAILURE MODE IS THE WORST POSSIBLE ONE TO DIAGNOSE, and that is why this item
        survives closed: on the HOST side everything looked right. The journal recorded
        `Creating encoder [hevc_vaapi]`, the colorimetry even IMPROVED (Rec. 601 to 709, which
        is an actual correction, since 601 on HD content shifts color), and the delivered image
        was still bad. The host encodes; who decodes is the client, and the host cannot see
        that. A clean negotiation is not the same as good playback.
      • THIS CONTRADICTS THE 03/08 NOTE in system/services/sunshine.nix FOR THIS CLIENT.
        There it says that turning on HEVC/AV1 "is worth more than any tweak in this file", and
        it is, where the decode is any good. Here it is not. Without this record, the next
        person (or me) follows that advice and loses the afternoon again.
      • TWO WRONG TURNS BEFORE GETTING IT RIGHT, and the lesson is the same in both directions:
        1. I closed it as "no action" based on a REPORT ("it has no dedicated GPU"), and the
           measurement disproved that in 10 min, because an Intel iGPU has decoded HEVC since
           ~2015;
        2. I reopened it as "it works" based on a HOST MEASUREMENT, and real use disproved that
           in 15 min.
        Neither instrument answered the right question, which was "how does the image look on
        the client". Only the eye of whoever uses it answered.
      • What is left for this machine: the bitrate ceiling and FEC, both on the host.

- [ ] Quality probe for the UFSCar VPN: no measured target (opened on 14/08/2026). The pill's
      hover popover measures latency/jitter/loss by pinging a host INSIDE the tunnel. For FAI
      the target is pinned and measured (`200.136.209.236`, see today's history); for UFSCar
      there is none, because I never brought that tunnel up with the panel ready to find out
      who answers in there. Meanwhile `vpn stats-json` falls back (the gateways from the tun
      routes) and, if nobody answers, the panel says "no probe".
      • DO NOT GUESS A UFSCar IP to "solve" it: a target that is not routed through the
        tunnel would measure the home internet. The `-I <iface>` protects against that (it
        turns into silence instead of a wrong number), but the silence is the symptom of
        guessing.
      • HOW TO CLOSE IT: connect (`vpn connect ufscar`), look at `ip -4 route show dev tun0`,
        ping candidates with `ping -I tun0 <ip>` and pin whichever answers in
        `probe_candidates()`, in `system/net/vpn.nix`, together with the measurement, the way
        the FAI one is.

- [ ] WireGuard peer `fai-workstation` (10.10.10.5): alive or legacy? (opened on 10/08/2026)
      Measured with the new `wg-status`: in **17 days** of router uptime it did not do ONE
      handshake. And it is not a forgotten passive peer: it has `persistent_keepalive = 25`,
      which exists precisely to keep the connection up.
      • The two possible readings, and they call for opposite actions: either the workstation
        has WireGuard stopped (and someone counts on that tunnel without knowing it never comes
        up), or the peer is residue and should leave the router by the zero-legacy rule.
      • DO NOT DELETE BEFORE CHECKING: the `~/FAI-workstation` mount (rclone SFTP) comes up
        with the FAI VPN, not with this tunnel, so the peer LOOKS orphaned without being it.
        Check from over there with `wg` before deciding.
      • The `notebook` peer (.2) has no handshake either, but that is EXPECTED and is not an
        item: it is exactly what the direct access from 10/08 replaced.

- [~] ACTUALLY TEST Wake-on-LAN (opened on 10/08/2026). The config is applied and the
      `40-enp7s0.link` is generated with `WakeOnLan=magic`, but NONE of that proves the machine
      wakes up. Only powering it off and sending the packet proves it.
      • DO NOT CLOSE THIS ITEM WITHOUT THE TEST. It is the same mistake as today's HEVC, in
        reverse: there I closed by report without measuring; here the temptation is to close by
        applied config without triggering it. Correct config and real effect are different
        things, which is exactly what fw4 taught today by ACCEPTING a `src_ip` as a list and
        DISCARDING the section.
      • SCRIPT: `sudo poweroff`, then from the phone over WireGuard,
        `ssh v1cferr@192.168.1.1 'sudo wake-desktop'`, and the machine has to come on.
      • CURRENT STATE, measured: `power/wakeup = disabled` and `Wake-on: d`. The `.link` is only
        applied by udev when the interface APPEARS, that is, from the next boot on. To arm it
        before that, without dropping the link: `ethtool -s enp7s0 wol g`.
      • IF IT DOES NOT WAKE, the next suspect is the BIOS: "Wake on LAN / Wake on PCIe" has to
        be on there too. The OS arms the NIC; the motherboard decides whether it accepts the
        signal.
      • THIS WILL NEVER COVER A POWER OUTAGE, and that is not a WoL failure: a real cut takes
        away the +5VSB and the NIC loses the armed register. For "the power went out" the answer
        is *Restore on AC Power Loss* in the BIOS, and then WoL becomes irrelevant, because the
        machine turns itself on.

- [ ] Tunnel MTU: measure and write it down (inherited from the 10/08/2026 test). The protocol
      is in [guides/wireguard-moonlight.md](guides/wireguard-moonlight.md).
      • Impossible to test from home: there is no WireGuard interface on this machine (the
        tunnel terminates at the ROUTER), so a ping to 10.10.10.1 goes out over the cable and
        measures the LAN. The sign of an invalid test: ~0.3 ms of latency.
      • IT CHANGED IN VALUE ON 10/08/2026, and it is worth saying why: this test existed to
        decide whether `packet_size = 1024` could go up. It cannot anymore, because with the
        direct path live the value is GLOBAL and serves TWO paths with different MTU (tunnel
        ~1420, direct 1492), so the useful ceiling is the lower one. The number only becomes
        actionable again if the tunnel is retired. Measuring anyway is worth it: it is what says
        WHICH of the two is the lower one.

- [~] Tray: the CLICK already worked (30/07). The Bar.qml delegate has left `activate()`, middle
      `secondaryActivate()`, right opening the native SNI menu (TrayMenu) and it handles
      `scroll()`. The item was marked pending while being done, the inverse of the
      wallpaper/screenDP1/ws-pill pattern, and just as misleading.
      What WAS broken in there was something else: the right-click fallback for an SNI with no
      DBusMenu (xembedsniproxy: wine/Battle.net, pamac) called
      `$HOME/.config/waybar/scripts/tray-native-menu.sh`, a WAYBAR path, and Waybar was removed
      in the migration; the dir does not exist and the script was not in the repo. Ported from
      the legacy tree to writeShellApplication (rule 7) and called BY NAME through the PATH.
      HOVER ON THE MENU (30/07): the tray menu opened and did NOT receive ONE pointer event, no
      hover at all, and it closed after 4s with the mouse sitting on top of it. It was NOT color
      and NOT QML: hyprwm/Hyprland#6682, a Qt popup RESIZED after being shown ends up with the
      wrong input region. It fits exactly, because openAt() makes the window visible BEFORE
      QsMenuOpener populates the items, so the card is born small and grows. Reproduced with
      Quickshell ITSELF, CLOSED as "not planned". FIX: PopupWindow to PanelWindow (a layer
      surface), which does not go through xdg_surface::set_window_geometry. It was in plain
      sight: it was the ONLY PopupWindow in the shell, the other 4 panels are PanelWindow and
      all of them had hover. As a bonus it also covers opening a SUBMENU, which grows after
      being shown too. The price: positioning by hand (no anchor.rect/PopupAdjustment.Slide),
      X comes from the icon plus a clamp.
      THE MEASUREMENT that closed the case: sampling `hyprctl layers` every 0.4s (the menu now
      IS a layer, so it SHOWS UP there, observability the popup did not give), one window stayed
      up for 7.46s, past the 4s timer, so the HoverHandler does see the cursor. Before that
      EVERY window died in ~3.7s.
      VISIBLE HOVER: the highlight existed and was INVISIBLE. `border`@20% over the menu
      background gives 1.11:1 of contrast (measured). Swapped for `accent`@30% = 1.77:1 AND a
      HUE change (gray to blue), which is what the eye catches. Tokens colMenuHoverBg{,Danger}
      in the Theme, plus a 3px accent bar sliding in from the left (the background is an AREA
      signal, the bar is a POSITION signal). The measurement also disproved a choice of mine: I
      had made the text light up in accent, which over the lit background drops to 3.83:1
      against colText's 5.97:1, so it made legibility worse as a side effect.
      XEmbed TO SNI BRIDGE (30/07): the comments in this repo cited `xembedsniproxy` in 3 places
      as if it existed, and it was NEVER INSTALLED. The tray-native-menu was dead code, because
      no icon without DBusMenu ever came to exist. A legacy X11 app (Wine/Bottles to Battle.net)
      publishes its icon over XEmbed, not SNI; with no XEmbed host, Wine draws the tray in a
      LITTLE WINDOW of its own (measured: class=explorer.exe, 160x20, floating). Now the proxy
      is declared (home/desktop/quickshell.nix). Causality demonstrated in BOTH directions:
      proxy up = 4 items in the watcher and explorer.exe=0; proxy dead = 3 items and the little
      window is back. COST measured and accepted: 758 MiB added to the closure (429 of them
      qtwebengine, plus kwin/breeze/oxygen), because the binary only exists inside
      kdePackages.plasma-workspace. Alternatives discarded with a reason: `snixembed` goes the
      OPPOSITE way (it publishes SNI as XEmbed) and therefore tries to be the watcher, dying
      with "could not acquire watcher name" (Quickshell already is one); there is no standalone
      in nixpkgs; extracting the binary does not escape it (plasma-workspace references
      kwin/breeze/oxygen DIRECTLY); stalonetray = a floating window all over again.
      LIMITATION of the icon that comes over the bridge, measured: no name and no menu. `Id` is
      the X11 window ID in decimal ("14680083"), `Title`/`ToolTip` are empty, `Menu` does not
      exist. Right-click falls into tray-native-menu (which only NOW has a real use) and the
      pending tooltip cannot settle for the `Id`: for these it would have to resolve the
      WM_CLASS.
      GHOST ICON (30/07): closing Battle.net left the icon on the bar, answering no click at
      all. It was NOT a proxy bug: `battle.net.exe` exits without removing its registration and
      Wine's `explorer.exe` keeps holding the window (xprop: WM_CLASS=explorer.exe,
      `_NET_WM_PID` alive). On the X side the window exists; on the app side there is nobody to answer. The
      helper works: `tray-native-menu <id>` returns exit=0, it found the item and called
      ContextMenu(). The fix: `wineserver -k` in the Bottles prefix (NOT a reboot); the proxy
      then CLEANS the item correctly (4 to 3 items, 0 windows, the unit intact). If some day an
      item is left with the window already dead, `systemctl --user restart xembedsniproxy`.
      MISSING: the TOOLTIP, which does not exist anywhere on the bar. Quickshell's SNI exposes
      `tooltipTitle`/`tooltipDescription` ready to use; the pattern to follow is the popovers
      (an anchored PanelWindow, see MetricsPopover.qml). MEASURED on today's items: Discord
      publishes a ToolTip with the title "Discord", Sunshine leaves it EMPTY and only has
      Title="sunshine", and the icon from the XEmbed bridge has neither, so the cascade needs to
      be tooltipTitle to title to id, and for the bridged ones, WM_CLASS.
      MEASUREMENT NOTE: I counted tray items with `busctl --user list | grep
      StatusNotifierItem` and got 0, which is FALSE, because an app that registers under a
      unique name (`:1.82`) does not match that pattern. The authoritative source is the
      watcher's `RegisteredStatusNotifierItems` property (which is what tray-native-menu reads):
      3 items.

- [ ] VS Code: the language server of `kamikillerto.vscode-colorize` aborts in a loop (found on
      09/08/2026). 15 coredumps in 2 days, roughly every 6 to 30 min of session. It is NOT the
      editor and NOT nix: `coredumpctl info` hands over the command line with
      `.vscode/extensions/kamikillerto.vscode-colorize-0.17.1/server/out/server.js`.
      • The price PER abort, measured: 58 s of CPU, 2.6 GB of peak RAM, 2.7 GB written to the
        NVMe just to record the dump. It is the freeze you can feel, and it is disk wear.
      • The immediate fix is disabling the extension (or restricting `colorize.include`). All
        that is lost is the color highlight. The extension comes from Settings Sync, NOT from
        nix, so the fix lives outside this repo while the declarative VSCode item is open.
      • It is NOT the same bug as the 90 s "stop job" (which also pointed at VS Code): there
        it is the `app-code-*.scope` ignoring SIGTERM at shutdown; here it is a child aborting
        in the middle of the session. Fixing one does not fix the other.

- [ ] SSOT still pending: all that is left is the HOME `/home/v1cferr` (5 files: dolphin.nix,
      Theme.qml, restic.nix, fai-workstation-mount.nix, home/default.nix) to `my.user.home`.
      LOW priority on purpose: unlike font/color/connector, the path does not change when the
      hardware changes.

- [ ] Check whether encrypted declarative state is possible

- [ ] IMPERMANENCE on the Kingston: my idea (30/07), inspired by
      <https://github.com/Misterio77/Foundry>. An ephemeral root (tmpfs or a subvolume wiped at
      boot) plus an EXPLICIT list of what persists. It fits two things this repo already has:
      rule 6 (Nix = app+config; state = restic) would stop being a convention and become
      ENFORCED by the system, since whatever is not declared as persistent simply does not
      survive the boot; and it answers the item above (encrypted declarative state), because the
      natural pair is impermanence + LUKS.
      POINTS TO DECIDE FIRST, measured today: the 567 GiB of non-Nix (Bottles 319, Jellyfin 132,
      Games 47) are LARGE and legitimate state. Impermanence does not erase them, but it forces
      declaring every path, and getting the list wrong means losing a save or a prefix on
      reboot. Candidates: the `impermanence` module (nix-community) or the Foundry scheme.
      THE MIGRATION ALREADY HAPPENED (01/08/2026) without turning impermanence on, so the
      original premise ("do it together, on a fresh install") has expired: now it is converting
      a machine in use, which was precisely the path I wanted to avoid. The btrfs layout saves
      most of the cost: what is missing is `@-blank` and the list, not a reinstall.
      DECIDED on 01/08/2026, while putting hosts/nixos-kingston together (the LAYOUT is already
      done):
      • btrfs YES, not out of taste, but because /nix and /persist need to be separate volumes
        FROM the install onward; flat ext4 would cost a second reinstall. Subvolumes created:
        `@ @home @nix @persist @log @swap`. It matches Foundry (root = a subvolume wiped at
        boot, not tmpfs; tmpfs would cap the root at the 15 GB of RAM).
      • LUKS NO: a passphrase at boot would kill the autologin that Sunshine depends on for
        remote access after a power outage. It is the deliberate difference from Foundry.
      • `@home` as a PERMANENT subvolume (Foundry does not have one), an intermediate stage on
        purpose: turn impermanence on at the root first, and only then decide whether to extend
        it to home. It locks nothing in: extending it is wiping @home through the same
        mechanism, with no reinstall. It is the answer to the 567 GiB risk above, since
        declaring everything on the first try is where you lose.
      • `/var/lib` is NOT a subvolume, and that is deliberate: if it were permanent, nothing
        would force declaring anything. A consequence to remember: the service state the cutover
        copies in there (uid-map, NetworkManager, bluetooth...) is WIPED on reboot once the
        feature lands, so it has to move to /persist and be declared. That is the work, not a
        bug.
        `/var/lib/sbctl` IS FIRST ON THE LIST and the only one that makes the machine NOT
        BOOT if it is forgotten: those are the Secure Boot keys (see system/core/secureboot.nix).
        Without them the next switch does not sign GRUB, and with Secure Boot on the firmware
        refuses the bootloader. Recovery = turn SB off in the BIOS + `sbctl create-keys` +
        `enroll-keys -m` again, with the BIOS in Setup Mode. Declare it BEFORE turning the
        ephemeral root on.
      MISSING only: the `@-blank` snapshot (the base of the rollback) and the persistence list.
      The blank is NOT now-or-never, since an empty subvolume created later is identical to a
      blank snapshot.
      ── HAVING READ THE FOUNDRY CODE (02/08/2026), what changes in the plan ──────────────
      PREMISE CORRECTION: btrfs is NOT mandatory for impermanence. The most common path in the
      community is a tmpfs root, and with a bind mount it even runs on ext4. The choice is still
      RIGHT, but for the right reason: btrfs gives an ephemeral root without spending RAM, and
      RAM is exactly what is short here (15 GB). Do not repeat "it is mandatory".
      It is only two files in Foundry: `hosts/common/optional/ephemeral-btrfs.nix` (the wipe) and
      `hosts/common/global/optin-persistence.nix` (the list). The rest of the persistence is
      DISTRIBUTED: each service module declares what it needs to keep (openssh.nix, podman.nix,
      jellyfin.nix...). That is the pattern to copy, and it matches system/services/*.nix.
      `/srv` IS THE BIGGEST RISK, and it was not written down: it is NOT a subvolume, it lives
      in `@`, and it is where the Jellyfin library lives (132 GiB). Foundry persists `/srv`
      explicitly. Turning the ephemeral root on without that ERASES the library on the first
      boot. Before sbctl on the list.
      Foundry's minimum list, all of it applicable here: `/etc/machine-id` (a file, not a dir),
      `/var/lib/systemd`, `/var/lib/nixos`, `/srv`. The `/var/lib/nixos` one is the UID/GID MAP,
      and losing it means uid reassignment, which is the SAME class of bug that broke
      Docker/Postgres/Sunshine on the cutover (see the cutover damage). `/var/log` does NOT go
      in: Foundry lists it because it has no subvolume for it; here `@log` already handles it,
      and declaring both would put a bind mount on top of the subvolume.
      `neededForBoot = true` on `/persist` (Foundry sets it; today it is false in disko).
      `dont-wipe`: a marker file at the top of the filesystem that makes the script SKIP the
      wipe. COPY IT, it is the difference between "boot loop" and "I touch a file from the live
      USB".
      SYSTEMD INITRD FIRST, in a separate commit: Foundry runs `boot.initrd.systemd.enable` and
      the script has two paths, the `postDeviceCommands` one being the legacy path. Turn the
      systemd initrd on by itself, reboot and confirm, and only then add the wipe. Two boot
      risks in a single commit is how you end up not knowing which of the two broke.
      Adapt the names in the wipeScript: Foundry uses `root`/`root-blank`/`persist`; here it is
      `@`/`@-blank`/`@persist`. Getting that wrong does not produce an evaluation error, it
      produces a broken boot.
      Copy the impermanence#254 workaround too (`/var/lib/private` at 0700 +
      `RemainAfterExit = false` on systemd-tmpfiles-resetup), otherwise a service with
      DynamicUser breaks. And `@snapshots` (btrbk) survives by design: it is top-level, it does
      not live inside `@`.

- [ ] Set up WoW Ascension with Bottles so we can play, and configure the system along the way.
      (Written as "once I am on the SSD"; the cutover already happened on 01/08 and the daily
      driver is the NVMe Kingston, so this one is free to go.)

- [ ] **M.2 heatsink for the KC3000**: measured on 01/08/2026, 77 to 80 °C under load, and the
      thermal management counter GOES UP during heavy I/O (`T1 Trans Count` went from 17 to 18
      in a single benchmark; 24,781 s accumulated). It never crossed the controller's warning
      threshold and the disk is spotless (`media_errors: 0`, spare 100%, 4% of life used, reads
      at 6911 MB/s = 98.7% of the spec sheet), but Kingston specifies operation up to **70 °C**
      and it is now the daily driver, not the idle secondary disk anymore.
      Check first whether the board has a heatsink on the slot and what the airflow near the Arc
      B580 looks like. Prefer a PASSIVE one: a 30 mm fan fed by Molex runs at a fixed speed,
      whines, has no tachometer and dies in 1 to 2 years, and a dead fan inside a closed case is
      worse than a passive heatsink. Measure afterwards with
      `sudo nvme smart-log /dev/nvme0n1 | grep -E "^temperature|Sensor 2|T1 Trans"`.

- [ ] Turn off every LED on every piece of hardware in AFK mode

- [ ] Install the driver/software for my Razer Deathadder v2 mouse (add the notification for
      when my DPI changes, and so on)

- [~] Passwordless remote maintenance on the router and on the switch (OpenWrt).
      • ROUTER, done: SSH was already key-based (`ssh v1cferr@192.168.1.1` runs in BatchMode),
        and what was missing was `sudo`. Today the NOPASSWD ones are `/sbin/reboot`,
        `/usr/sbin/nft`, `/sbin/uci`, `/etc/init.d/dnsmasq` and `/etc/init.d/firewall` (this
        last one came in on 10/08/2026, with the justification and the method in the history).
      • A DECISION TO KEEP: an arbitrary command STILL asks for the password. Widening it to
        `(ALL) NOPASSWD: ALL` would be the change that actually escalates privilege, since the
        current ones do not escalate because `nft` already gives the same reach. Only add a
        binary with a reason, one at a time.
      • `/usr/bin/wg-status` came in along with them (a read-only wrapper over `wg show`); the
        whole `wg` binary does NOT go in, because `wg set` replaces a peer key.
      • MISSING: the SWITCH, which has never been touched.
      • NONE OF THIS IS MIRRORED: `router-sync` only covers `/etc/config/`. Sudoers and the
        SSH key live outside the repo, and the router's `/home/` does not even survive a
        `sysupgrade`.

- [~] Claude Code, what is LEFT of the two accounts (11/08/2026). The structure was declared in
      `home/shell/claude-code.nix` and the entry is in the [august
      history](history/2026/08-august.md): the `claude-fai`/`claude-pessoal` wrappers,
      `claude-pick`, a versioned `settings.json`, a shared `projects/` and plain `claude`
      falling through to FAI. Three ends are still open, and none of them is declarable:
      • The `/login` for each account. I did NOT restore `.credentials.json` (neither the one
        from the Arch backup nor the one in `~/.claude`): a token is not something you copy with
        a script, and the Arch one was 7 weeks old, from a machine that is decommissioned. Check
        later without spending quota: `claude-fai doctor` says whether the account is signed in.
      • PRUNE THE REST OF `~/.claude`. It stopped being an account and became just the archive,
        but `history.jsonl`, `settings.json`, `settings.local.json`, `sessions/`,
        `shell-snapshots/` and `plugins/` were left there (~40 MB outside `projects/`). What was
        worth keeping was copied to `~/.claude-fai`; the rest is legacy (rule 16). DO NOT
        PRUNE BEFORE the new account proves it walks: until the FAI `/login` happens, those
        leftovers are the only place where that account's state exists. And NEVER touch
        `projects/`, which is the archive, the target of both accounts' symlinks.
      • The header block of `system/services/claude-code.nix` states that the user's
        `settings.json` "CANNOT become a symlink". The sentence holds for a STORE symlink
        (read-only), which is what it was talking about, but today it reads as if it contradicted
        this module, which links to the repo through `mkOutOfStoreSymlink` and was measured.
        Rewrite the sentence (it is text drift, rule 16; the hooks in `/etc` are still right and
        still necessary).

- [ ] The Azure MCP has nothing to work ON yet (14/08/2026). The server is declared, connected
      and authenticated (see the [august history](history/2026/08-august.md)), but its 68
      tools operate over a SUBSCRIPTION, and the day-to-day tenant (`FAIUFSCar`) is a directory
      only: `azmcp subscription list` answers 200 with an EMPTY list. Who has a subscription is
      the `BHS` tenant, and getting into it requires MFA: `az login --tenant
      92247c24-8a8c-47f3-a7f1-85df939ad4b6`, which the browser resolves. Only after that is it
      possible to say whether the MCP pays for itself here or whether `az` alone would have been
      enough; until then it is ALIVE and IDLE, which is different from broken. The App
      Registration does NOT depend on this: it already works through `az ad` on FAIUFSCar, which
      was the goal.

- [ ] Keep setting up the dualboot with Secure Boot

- [ ] Release jump 26.05 to 27.05 (~may/2027). It is NOT a reinstall: it is TWO STRINGS in
      flake.nix, `nixpkgs.url` (nixos-27.05) and `home-manager.url` (release-27.05), which change
      TOGETHER (the HM release branch matches the base, otherwise there is an option mismatch).
      The other ~9 inputs have `inputs.nixpkgs.follows = "nixpkgs"` and come for free: the dedup
      that already exists because of the lock size is what makes the jump trivial, 1 input
      changes and 9 follow. Without it, each flake would drag its own nixpkgs 26.05 and I would
      end up with two bases coexisting after the jump.
      `upgrade` NEVER makes that jump, and that is a feature: `nix flake update` only moves
      INSIDE the pinned branch, and into `nixos-26.05` only BACKPORTS come, cherry-picked
      CVE/bugfixes that a maintainer marks with the `backport release-26.05` label. A new package
      version does NOT come in, except for the browser and the kernel (upstream only gives
      security support to the new version, so backporting a Firefox patch would mean rewriting
      Firefox). And `nixos-26.05` (the channel) is not `release-26.05` (the branch): the channel
      is a pointer that only advances after Hydra builds and the test suite passes, the same
      gating as nixos-unstable.
      The `stateVersion` DOES NOT CHANGE, not on the jump, not ever. It stays "26.05" forever
      in hosts/nixos-kingston/default.nix and home/default.nix. The name misleads: it is not "the
      version of my system", it is "the NixOS version my STATE ON DISK is compatible with". 54
      nixpkgs modules read that value, and the canonical case is postgresql.nix, which picks the
      Postgres MAJOR from it (`versionAtLeast stateVersion "26.11"` gives postgresql_18; "25.11"
      gives postgresql_17, and so on). Bumping it makes the module point at a major that does NOT
      READ the existing datadir: the service does not come up, and if something reinitializes the
      cluster the database is gone. A generation rollback does not save you: it brings back the
      SYSTEM, not the /var/lib that was already touched (the same class as the cutover damage,
      when copying /var/lib broke Docker/Postgres/Sunshine silently). That is why it exists in
      the config even being immutable: it is the state's BIRTH CERTIFICATE, not a button, and the
      modules need to know when the state was born precisely because they cannot migrate it on
      their own. It only changes if the release notes say so, and together with the manual
      migration (pg_upgrade and the like).
      Use `nixos-rebuild boot` and NOT `switch`: it applies on the next boot and the 26.05
      generation stays in minegrub as the emergency exit. And wait ~2 to 4 weeks after the
      release (the branch stabilizes as the backports arrive); the cost of waiting here is low,
      because what I want fresh already comes through `unstable.*` and through the direct
      upstream inputs.

- [ ] Make VSCode declarative with Nix and at the same time always keep the sync with my
      GitHub/Microsoft account updated (I want it centralized in
      <https://github.com/v1cferr/dotfiles>)

- [ ] Add the current public IP to Fastfetch?
