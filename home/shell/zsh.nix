# The zsh config (~/.zshrc). The LOGIN shell is set in system/core/users.nix.
# Why the aliases are composed and why the flake path is explicit: docs/notes/repo/shell.md
{ osConfig, ... }:

let
  # SSOT of the repo path (rule 11): programs.nh.flake, read here through osConfig.
  flake = osConfig.programs.nh.flake;

  # Composed, never written twice: `upgrade` IS `update && rebuild` by definition.
  rebuildCmd = "nh os switch ${flake} && { hyprctl -i 0 reload || true; }";
  # The order matters: vscode-bump raises the version BEFORE the lock update, and the `&&`
  # stops the chain if it fails, so nothing is applied with the repo half-edited.
  updateCmd = "vscode-bump ${flake} && curseforge-bump ${flake} && nix flake update --flake ${flake} && vscode-extensions-dump ${flake}";
in
{
  programs.zsh = {
    enable = true;
    enableCompletion = true; # completes commands and paths with Tab (compinit)
    autosuggestion.enable = true; # suggests from history in gray
    syntaxHighlighting.enable = true; # green = it exists, red = it does not
    autocd = true; # typing just the path does the cd

    history = {
      size = 50000; # lines kept in memory during the session
      save = 50000; # lines written to the history file
      ignoreDups = true; # no consecutive duplicate
      ignoreAllDups = true; # on a repeat, the older occurrence goes
      ignoreSpace = true; # a command starting with a space stays out
      expireDuplicatesFirst = true; # pruning kills a duplicate before a unique command
      share = true; # shared between tabs in real time
    };

    shellAliases = {
      # The `-i 0` is what makes this work over SSH: hyprctl otherwise demands
      # HYPRLAND_INSTANCE_SIGNATURE, which only exists inside the graphical session.
      rebuild = rebuildCmd;
      update = updateCmd; # bumps the lock plus the vendored versions
      # As the USER first (it holds the SSH key for private inputs), then root.
      upgrade = "${updateCmd} && ${rebuildCmd}";
      # CAREFUL: `-d` deletes ALL old generations, so there is no rollback afterwards.
      gc = "sudo nix-collect-garbage -d";

      # NO sudo on purpose: a FUSE mount is private to whoever mounted it, and a root mount
      # produces a folder Dolphin cannot open.
      backup-browse = "RCLONE_CONFIG=/run/secrets/rclone_gdrive_conf restic -r rclone:gdrive:BACKUPS_EX-B560M-V5/HOME --password-file /run/secrets/restic_password mount /mnt/backup";
      # Rereads the whole repo (~24 GiB) to prove a restore works. Manual: it is a full download.
      backup-verify = "sudo restic-home-gdrive check --read-data";

      # ls/ll/la/lt (eza) and cat (bat) live in cli.nix, next to the toolkit.
      ".." = "cd ..";
      "..." = "cd ../..";
    };
  };
}
