# The zsh CONFIG (~/.zshrc), declared. The LOGIN shell becomes zsh in system/default.nix
# (users.users.v1cferr.shell plus programs.zsh.enable; NixOS requires the system-wide enable for
# /etc/shells and the base environment). Here it is only the interactive behavior. The prompt is
# starship (home/starship.nix) and the terminal is kitty (home/kitty.nix).
{ osConfig, ... }:

let
  # The SSOT of the repo's path: `programs.nh.flake` in system/core/core.nix (rule 11: the option
  # lives at the lowest level that needs it, and home reads it through osConfig). This path used
  # to be a literal in the three aliases below.
  flake = osConfig.programs.nh.flake;

  # The three maintenance aliases are composed here and not written three times: `upgrade` IS
  # `update && rebuild` by definition, and restating it in full (as it was until 06/08/2026) is
  # the same rule in two places, so the day only one of the copies changes, `upgrade` stops being
  # what its name says and nobody notices (rule 11).
  rebuildCmd = "nh os switch ${flake} && { hyprctl -i 0 reload || true; }";
  # vscode-bump BEFORE the flake update: the `vscode-tarball` input has a VERSIONED URL (the why
  # is in flake.nix), so it is the one that raises the number, and that is what keeps VS Code
  # always on the latest stable. A NO-OP when it already is. Did it fail (the API down, the repo
  # in another format)? The `&&` stops here and nothing is applied with the repo half-edited.
  # `vscode-extensions-dump` goes LAST and touches no input: it rewrites the mirror of the
  # installed extensions (home/apps/vscode/extensions.txt) so the repo shows in the diff which
  # extension came or went. The trigger is this alias and not `rebuild`, because `update` is the
  # maintenance ritual; the price is the mirror lagging between two `update`s, which is acceptable
  # for a record nobody consumes at runtime.
  # curseforge-bump next to vscode-bump, and for the same reason with an aggravating factor:
  # CurseForge's src is a POINTER URL (Overwolf does not publish a versioned URL), so changing a
  # number is not enough, the HASH has to be recomputed, otherwise their next release breaks the
  # build on a cold store. It costs a 256 KiB range request when nothing changed.
  updateCmd = "vscode-bump ${flake} && curseforge-bump ${flake} && nix flake update --flake ${flake} && vscode-extensions-dump ${flake}";
in
{
  programs.zsh = {
    enable = true;
    enableCompletion = true; # completes commands/paths with Tab (compinit)
    autosuggestion.enable = true; # suggests a command from history in gray (-> accepts it)
    syntaxHighlighting.enable = true; # colors as you type (green = it exists / red = it does not)
    autocd = true; # typing just the path already does the cd (with no `cd`)

    history = {
      size = 50000; # lines kept in memory during the session
      save = 50000; # lines written to the history file
      ignoreDups = true; # it does not keep a consecutive duplicate
      ignoreAllDups = true; # on a repeat, it removes the older occurrence
      ignoreSpace = true; # a command starting with a space does not enter the history
      expireDuplicatesFirst = true; # when pruning, it kills a duplicate before a unique command
      share = true; # history shared between tabs/terminals in real time
    };

    shellAliases = {
      # NixOS: with no `#host`, nixos-rebuild matches the current hostname against
      # nixosConfigurations.
      # && hyprctl -i 0 reload: it reloads hyprland.lua (a new config does not apply on its own).
      # The `-i 0` is what makes this work over SSH: without it hyprctl demands
      # HYPRLAND_INSTANCE_SIGNATURE, which only exists inside the graphical session, so rebuilding
      # from outside failed silently and the new config was NOT applied (29/07). The `|| true`
      # keeps the rebuild's exit code as the one that matters, even with no Hyprland running.
      # `nh os switch` instead of `sudo nixos-rebuild switch`: a progress tree for the build
      # (nix-output-monitor inside) plus a package DIFF between the current generation and the new
      # one. NO `sudo` in front on purpose, since nh elevates on its own at activation time, so
      # the build runs as the user and only the activation asks for a password.
      #
      # THE PATH GOES IN EXPLICITLY, and not through NH_FLAKE. Learned the hard way on
      # 03/08/2026: `programs.nh.flake` publishes the variable through `environment.variables`,
      # which becomes an `export` in /etc/set-environment and is only read at LOGIN. The graphical
      # session in progress does not have it, and a new terminal inherits the session's
      # environment (it does not reread /etc/profile), so the alias broke exactly after the switch
      # that introduced it, with the misleading message "no flake found at /etc/nixos/flake.nix",
      # as if the config were in the wrong place. Passing the path, it works on the first
      # `rebuild` and does not depend on logging back in. programs.nh.flake STILL holds (it is the
      # SSOT read here, and it serves a bare `nh`), it just is not a dependency of the alias
      # anymore.
      rebuild = rebuildCmd;
      update = updateCmd; # bumps flake.lock plus the VS Code version (vscode-bump)
      # upgrade = update plus rebuild (like `apt update && apt full-upgrade`). The `update` runs as
      # the USER first (it has the SSH key for private inputs, duo-streak-daemon for instance) and
      # ONLY on success (`&&`) goes on to the rebuild as root, so a broken lock never gets applied.
      upgrade = "${updateCmd} && ${rebuildCmd}";
      # BE CAREFUL with the `-d`: it deletes ALL the old generations, not just the ancient ones,
      # which means after running it there is no rollback to yesterday's generation, nor an entry
      # for it in GRUB. It is what you want when the intent is freeing the maximum; if the intent
      # is only hygiene, `--delete-older-than 7d` cleans nearly the same and PRESERVES the
      # emergency exit. (The automatic weekly GC, that one does use --delete-older-than 30d, in
      # system/core/core.nix.)
      gc = "sudo nix-collect-garbage -d"; # cleans the store's old generations by hand

      # FINDING A FILE INSIDE THE BACKUP. It mounts the repo as a read-only folder with one
      # directory per snapshot (`snapshots/latest/…`), so you open it in Dolphin and browse.
      # Ctrl+C unmounts. The repo is ENCRYPTED blobs: what decrypts is restic, not rclone.
      #
      # NO `sudo`, and that is the point: a FUSE mount is private to whoever mounted it, so
      # `sudo restic mount` produces a folder Dolphin does NOT open (that was the 1st version's
      # defect). Running as the user, the folder is theirs and the file manager gets in. It
      # requires the passwords to be readable without sudo, done in system/core/secrets.nix, and
      # the mountpoint created by tmpfiles in system/services/restic.nix.
      #
      # An alias and not a script (rule 7): it is a one-line command.
      #
      # Only the HOME one is left. The twin `arch-browse` (the old Arch archive) DIED on
      # 11/08/2026: that mount became permanent and has a declared owner now
      # (home/services/arch-legacy-mount.nix), so /mnt/arch-antigo is already mounted and there is
      # no command to run. This one stays on demand on purpose: the HOME repo is precisely the one
      # the daily prune needs to lock by itself.
      backup-browse = "RCLONE_CONFIG=/run/secrets/rclone_gdrive_conf restic -r rclone:gdrive:BACKUPS_EX-B560M-V5/HOME --password-file /run/secrets/restic_password mount /mnt/backup";
      # It rereads ALL the repo's data to prove a restore is possible (it downloads the whole
      # repo, ~24 GiB, ~4 min). It is deliberately manual: automated it would be a daily download.
      backup-verify = "sudo restic-home-gdrive check --read-data";

      # ls/ll/la/lt (eza) and cat (bat) live in home/cli.nix, next to the CLI toolkit
      ".." = "cd ..";
      "..." = "cd ../..";
    };
  };
}
