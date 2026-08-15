# ═══════════════════════════════════════════════════════════════════════════
# THE CORE: Nix/flakes, nixpkgs (unfree/insecure), nix-ld, locale/language and the CEILINGS on
# disk growth (the store's GC plus journald).
# ═══════════════════════════════════════════════════════════════════════════
{ ... }:

{
  # ── Nix / flakes ─────────────────────────────────────────────────────────
  nix.settings.experimental-features = [
    "nix-command"
    "flakes"
  ];
  # Hardlink dedup on /nix/store. SCHEDULED (nix.optimise) and not auto-optimise-store: that one
  # runs the hardlinking on EVERY build, and on btrfs the metadata churn is CoW, which gets
  # expensive on a machine that rebuilds all day. Here the work leaves the critical path and goes
  # into an idle window.
  # It is NOT because of the fear that circulates ("auto-optimise corrupts the store"): the
  # NixOS/nix#7273 race was fixed, and the assert that claims it is nix-darwin policy. The reason
  # is only WHEN the work happens.
  nix.optimise = {
    automatic = true;
    dates = [ "03:45" ]; # idle, and far from the weekly GC and the daily restic
  };
  nix.gc = {
    automatic = true;
    dates = "weekly";
    options = "--delete-older-than 30d"; # /nix/store does not grow forever
  };

  # ── nh: the rebuild UX ─────────────────────────────────────────────────────
  # `nh os switch` instead of `nixos-rebuild switch` (see the aliases in home/shell/zsh.nix).
  # What it adds and `nixos-rebuild` does not give you:
  #   • a progress TREE for the build (it uses nix-output-monitor inside) instead of the wall of
  #     "building '/nix/store/…'" that does not say what is left;
  #   • a package DIFF between the current generation and the new one: what went up a version,
  #     what came in, what went out. It is the information I spent a whole day extracting by hand
  #     comparing store paths.
  # `--ask` is OPT-IN (checked in --help), so this does NOT become interactive: it stays safe over
  # SSH and inside a script, which matters on this remote-access machine.
  #
  # `clean` stays OFF on purpose. `programs.nh.clean` brings up a timer for `nh clean all`, and
  # the GC already has an owner right above (`nix.gc`, weekly, 30d) plus the space-reactive one
  # below. Two collectors on the same store is exactly rule 14's "two owners for the same
  # artifact": neither fails, and the real retention becomes the intersection of the two policies,
  # which is to say you think you have 30 days of rollback and you have whatever the other one
  # left. If you ever prefer nh's, TURN nix.gc OFF in the same commit.
  programs.nh = {
    enable = true;
    # The SSOT of the repo's path (rule 11): it becomes NH_FLAKE, and home/shell/zsh.nix reads it
    # through `osConfig` instead of repeating the path in every alias. The literal
    # ~/Projects/GitHub/v1cferr/dotfiles used to appear three times over there.
    flake = "/home/v1cferr/Projects/GitHub/v1cferr/dotfiles";
  };
  # A space-reactive GC (it complements the timer above): if during a build the free space drops
  # below min-free, it collects garbage until it frees max-free and the build goes on. It avoids
  # "no space left" in the middle of a big rebuild.
  #
  # RAISED from 1 GiB/5 GiB (30/07): 1 GiB is TOO LATE to be a safety net, since starting to
  # collect only when 1 GiB is left is arriving after the accident, and the build that triggered
  # the collection has probably already failed. Here the partition is SHARED with games and media
  # (measured: 506 GiB across Bottles/Jellyfin/Steam against 58 GiB of store), so the space can
  # disappear outside Nix and Nix needs real slack. A 15 GiB floor gives room for a big rebuild; a
  # 50 GiB target avoids collecting again on the next build.
  # THE NAMES: in this Nix (2.34.8) they are min-free/max-free. The rename to
  # gc-threshold/gc-limit plus auto-gc belongs to a newer version and does NOT exist here (checked
  # with `nix config show`).
  nix.settings.min-free = 15 * 1024 * 1024 * 1024; # 15 GiB, the floor that triggers the GC
  nix.settings.max-free = 50 * 1024 * 1024 * 1024; # 50 GiB, the target to free when it triggers

  # ── The journal's ceiling ────────────────────────────────────────────────
  # WITHOUT this journald uses the default: 10% of the filesystem. On this machine (915 G) that is
  # ~92 GiB it can occupy LEGITIMATELY, with nothing raising a flag, the kind of growth you only
  # discover with a full disk. Today it is 530 MiB, so 2 GiB is a roomy ceiling and still keeps
  # weeks of history. A concrete lesson from 30/07: two timers of mine wrote 2148 lines/DAY here
  # before they got LogLevelMax.
  # SystemMaxFileSize caps each file, so the rotation is gradual instead of in 1/8 steps.
  services.journald.extraConfig = ''
    SystemMaxUse=2G
    SystemMaxFileSize=128M
  '';
  # An IDLE priority for nix-daemon: the builds (which max out the cores compiling) YIELD CPU/disk
  # to the interactive session, so a rebuild/upgrade does not freeze the desktop nor the Moonlight
  # stream. With the machine idle, the build uses everything normally (idle only yields when
  # something else wants it).
  nix.daemonCPUSchedPolicy = "idle";
  nix.daemonIOSchedClass = "idle";
  nixpkgs.config.allowUnfree = true; # google-chrome, vscode, and so on
  # bitwarden-desktop (Electron) is stuck on Electron 39 (EOL). No channel has migrated yet, so we
  # allow ONLY this version. When bumping Bitwarden, review/remove this.
  nixpkgs.config.permittedInsecurePackages = [ "electron-39.8.10" ];

  # ── Compatibility with FHS binaries (nix-ld) ──────────────────────────────
  # NixOS does not run "generic" dynamic binaries (the ones that look for /lib64/ld-linux…).
  # nix-ld provides that loader, which makes VS Code Remote-SSH (vscode-server) work, along with
  # Python/CUDA wheels (uv pip install torch), and so on (a "day 1" item in the README).
  programs.nix-ld.enable = true;

  # ── Locale / language ──────────────────────────────────────────────────────
  # The system is in en-US (by preference: output/errors in English make debugging easier).
  # THE EXCEPTION: the LOCKSCREEN is fully pt-BR (by taste), which is why we generate pt_BR too,
  # used by the lockscreen's clock through LC_TIME for the spelled-out date
  # (home/desktop/lockscreen.nix). The timezone/keyboard follow BR (the local time zone plus the
  # physical ABNT2 keyboard).
  time.timeZone = "America/Sao_Paulo";
  i18n.defaultLocale = "en_US.UTF-8";
  i18n.supportedLocales = [
    "en_US.UTF-8/UTF-8"
    "pt_BR.UTF-8/UTF-8"
  ];
  console.keyMap = "br-abnt2"; # the keyboard on the TTY (the GUI one is in desktop.nix)
}
