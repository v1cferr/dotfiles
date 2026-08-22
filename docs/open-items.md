# Open items

What is still open. A finished item migrates to [history/](history/):
this file only grows with new work, and shrinks when work ends.

Convention inherited from the single-file era: every item explains the WHAT, the WHY and the
known trap. The paragraph is worth more than the title.

AUDITED on 16/08/2026 against the actual tree, because this file had drifted the way rule 16
describes: six items were already DONE and still sitting here, and one was carrying 70 lines of
finished work. What was closed is in the [august history](history/2026/08-august.md).

- [~] The T480 before it leaves the house (opened 22/08/2026). It is my mother's machine, it goes
      to another city, and after that every mistake here costs a phone call instead of a minute.
      The Windows side lives in that machine's OWN repo; what is listed here is either this repo's
      or a joint decision.
      • CLOSED THE SAME DAY, so nobody reads this item as untouched: the MASQUERADE toward
        10.10.10.6, the panel user, the Moonlight pairing, the DoH policy on her browsers and the
        watchdog's numbers. The reasoning for each is in the [august
        history](history/2026/08-august.md); what is left below is what genuinely cannot be closed
        from this side of the house.
      • THE ONLY VALID TEST IS FROM ANOTHER NETWORK, and none of today's proves anything about her
        house. With the machine on the home Wi-Fi the tunnel closes by hairpin on the router
        itself, and `wg show` even displays `192.168.1.1` as the endpoint while the file says
        `vpn.v1cferr.dev`. The protocol: phone hotspot, tunnel coming up on its own, `ssh t480`
        answering, and a Moonlight session lasting past 2 min (a drop at ~4 s is the MTU
        signature). Do it while the machine is still within arm's reach.
      • THE GHOST REAPER DOES NOT EXIST OVER THERE, and it bit once already on 22/08: a client
        that vanishes with no teardown leaves Sunshine answering `SUNSHINE_SERVER_BUSY` forever,
        and Moonlight then refuses to open a new session, so from the client the host is simply
        broken. The remedy is a `restart` and the pairing survives it, which is what makes a
        watchdog cheap to write. A flaky public Wi-Fi is a ghost factory, so this is not an edge
        case at her place.
        • THE WINDOWS VARIANT NEEDS A DIFFERENT SIGNAL. Here the reaper reads `BUSY` plus no bound
          UDP socket; over there the three sockets WERE bound with the client long gone, so that
          test would never fire. What did not lie is the traffic: `wg show <tunnel> transfer`
          barely moved. Condition: BUSY plus a byte delta under a floor, HELD for a few cycles so
          a session being born is not killed.
        • IT DROPPED IN PRIORITY THE MOMENT RDP LANDED, and that is worth writing down instead of
          just doing the work: a ghost used to mean the machine was unreachable, and now it means
          one service needs restarting through a path that does not depend on it. Convenience,
          not a lifeline.
      • NO REAL SESSION HAS RUN YET. Paired is not streaming: `moonlight list 10.10.10.6` answers
        `Desktop`, which proves the pairing and nothing about video. Until a session runs, the
        encoder, the packet size and the bitrate are all still theory.
      • `max_bitrate` IS A PLACEHOLDER at 10000. The bottleneck out of there is HER upload, which
        nobody has measured. Raise it after a real session, not before.
      • THE MACHINE'S REPO HAS NO REMOTE. It is a local git on a laptop that is leaving, so the
        inventory, the scripts and the reasoning die with the disk. It is not this repo's content
        and does not belong in it (rule 14, and it holds her machine's specifics), so the answer is
        a PRIVATE repository of its own, pushed before the trip.
      • THE LID QUESTION IS ANSWERED AND THE ANSWER COSTS NOTHING: a closed lid stops Sunshine's
        capture, because there is no panel to duplicate, so RDP is the headless path and both are
        declared. What remains is the DISPLAY TIMEOUT, 15 min on AC, which is the same class of
        failure and has not been tested: if a stream comes back black with the lid OPEN, that is
        the first suspect.
      • STILL OPEN OVER THERE, decided by whoever owns that machine: `PasswordAuthentication` is
        still `yes` on an sshd that only listens inside the tunnel, and BitLocker is
        `FullyDecrypted` on a laptop that will live in someone else's house.

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
      • The `notebook` peer (.2) WAS REMOVED on 19/08/2026, for the reason this item is still open
        about: nobody could say which machine held its private key, and the `wg` zone reaches the
        whole LAN. That one had never handshaked at all, which made the call easy. THIS one has a
        `persistent_keepalive`, so somebody expected it to be up, and that is the difference.

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

- [ ] Tray: the TOOLTIP, which does not exist anywhere on the bar (opened 30/07, narrowed
      16/08/2026). Everything else in this item was DONE and its reasoning now lives in
      [notes/desktop/bar.md](notes/desktop/bar.md) and
      [notes/desktop/quickshell.md](notes/desktop/quickshell.md): the click, the hover fix
      (PopupWindow to a layer surface, Hyprland#6682), the visible-hover contrast tokens, the
      XEmbed bridge and the ghost-icon diagnosis. The item had been carrying 70 lines of finished
      work, which is the drift rule 16 describes.
      • Quickshell's SNI exposes `tooltipTitle`/`tooltipDescription` ready to use; the pattern to
        follow is the popovers (an anchored PanelWindow, see UsagePopover.qml).
      • MEASURED on the live items, and it is why a single field will not do: Discord publishes a
        ToolTip with the title "Discord", Sunshine leaves it EMPTY and only has Title="sunshine",
        and the icon from the XEmbed bridge has NEITHER. So the cascade is tooltipTitle to title
        to id, and for the bridged ones it has to resolve the X11 WM_CLASS.
      • MEASUREMENT NOTE: counting tray items with `busctl --user list | grep StatusNotifierItem`
        gives 0, which is FALSE, because an app registered under a unique name (`:1.82`) does not
        match. The authoritative source is the watcher's `RegisteredStatusNotifierItems`.

- [ ] SSOT still pending: the HOME `/home/v1cferr` to `my.user.home`. RECOUNTED on 16/08/2026
      and the item was understating it: **8 files**, not the 5 written here before
      (dolphin.nix, Theme.qml, restic.nix, fai-workstation-mount.nix, home/default.nix, plus
      core.nix, drive-mount.nix and grad-radar.nix).
      LOW priority on purpose: unlike font/color/connector, the path does not change when the
      hardware changes. That is also why the count drifted unnoticed, and why `dead-config`
      cannot catch this one: a literal is not a dead declaration, it is a missing one.

- [ ] IMPERMANENCE on the Kingston: my idea (30/07), inspired by
      <https://github.com/Misterio77/Foundry>. An ephemeral root (tmpfs or a subvolume wiped at
      boot) plus an EXPLICIT list of what persists. It fits two things this repo already has:
      rule 6 (Nix = app+config; state = restic) would stop being a convention and become
      ENFORCED by the system, since whatever is not declared as persistent simply does not
      survive the boot; and it absorbs what used to be a separate one-line item ("check whether encrypted
      declarative state is possible"), because the natural pair is impermanence + LUKS, and LUKS
      is already decided against below.
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
      It is only two files in Foundry, and the paths below are THEIRS, not paths in this repo:
      `Foundry:hosts/common/optional/ephemeral-btrfs.nix` (the wipe) and
      `Foundry:hosts/common/global/optin-persistence.nix` (the list). The rest of the persistence is
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

- [ ] Turn off every LED on every piece of hardware in AFK mode. Nothing is declared for this
      yet (`dead-config` confirms there is no OpenRGB anywhere in the tree). The blocker is the
      Steel Legend B580's RGB, which OpenRGB does not support: reverse engineering it is a
      separate, bigger piece of work, and the fans are not controllable at all.

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
      (A third bullet lived here until 16/08/2026: the header of `system/services/claude-code.nix`
      claimed the user's `settings.json` "CANNOT become a symlink", which read as contradicting
      the module that links it. The rule 2 sweep rewrote that header, so the drift is gone.)

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

- [ ] Add the current public IP to Fastfetch?
