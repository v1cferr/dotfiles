# THE CORE: Nix/flakes, the GC ceilings, the journal cap, nix-ld and the locale.
# Why each ceiling is the number it is: docs/notes/repo/core.md
{ ... }:

{
  # ── Nix / flakes ─────────────────────────────────────────────────────────
  nix.settings.experimental-features = [
    "nix-command"
    "flakes"
  ];
  # SCHEDULED dedup, not auto-optimise-store: on btrfs the per-build metadata churn is CoW.
  nix.optimise = {
    automatic = true;
    dates = [ "03:45" ]; # idle, and far from the weekly GC and the daily restic
  };
  nix.gc = {
    automatic = true;
    dates = "weekly";
    options = "--delete-older-than 30d"; # /nix/store does not grow forever
  };

  # nh: a build progress tree plus a package diff. `clean` stays OFF: nix.gc already owns the
  # GC, and two collectors on one store is rule 14's two-owners problem.
  programs.nh = {
    enable = true;
    # SSOT of the repo path (rule 11): zsh.nix reads it through osConfig instead of repeating it.
    flake = "/home/v1cferr/Projects/GitHub/v1cferr/dotfiles";
  };
  # Space-reactive GC. 15/50 GiB and not 1/5: the partition is shared with 506 GiB of games and
  # media, so 1 GiB left is already after the accident.
  nix.settings.min-free = 15 * 1024 * 1024 * 1024; # 15 GiB, the floor that triggers the GC
  nix.settings.max-free = 50 * 1024 * 1024 * 1024; # 50 GiB, the target to free when it triggers

  # The journal's cap. The default is 10% of the FS, which here would be ~92 GiB, growing
  # legitimately with nothing raising a flag.
  services.journald.extraConfig = ''
    SystemMaxUse=2G
    SystemMaxFileSize=128M
  '';
  # Idle priority: a build yields CPU and disk to the session, so it never freezes the stream.
  nix.daemonCPUSchedPolicy = "idle";
  nix.daemonIOSchedClass = "idle";
  nixpkgs.config.allowUnfree = true; # google-chrome, vscode, and so on
  # bitwarden-desktop is stuck on Electron 39 (EOL). Review this when bumping Bitwarden.
  nixpkgs.config.permittedInsecurePackages = [ "electron-39.8.10" ];

  # nix-ld: the loader generic dynamic binaries look for (VS Code Remote-SSH, python wheels).
  programs.nix-ld.enable = true;

  # en-US by preference; pt_BR is generated only for the lockscreen clock's LC_TIME (rule 17).
  time.timeZone = "America/Sao_Paulo";
  i18n.defaultLocale = "en_US.UTF-8";
  i18n.supportedLocales = [
    "en_US.UTF-8/UTF-8"
    "pt_BR.UTF-8/UTF-8"
  ];
  console.keyMap = "br-abnt2"; # the keyboard on the TTY (the GUI one is in desktop.nix)
}
