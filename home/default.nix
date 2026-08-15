# ═══════════════════════════════════════════════════════════════════════════
# THE USER (home-manager): MY DOTFILES, declared.
#
# This folder's rule: home-manager owns the USER's PACKAGES AND CONFIG. The idiomatic way is
# `programs.<tool>` (it installs plus integrates shell/config, versioned); packages with no module
# of their own go into `home.packages`. system/ keeps only the system level (services, drivers,
# root's packages). A separation of privilege: breaking home does NOT take the boot down, which is
# what makes these dotfiles reproducible.
#
# Organized by CATEGORY (a subfolder with its own default.nix importing its modules), so the top
# does not become a pile of loose files. A new module? Create home/<category>/<app>.nix and add 1
# line to the category's default.nix.
# ═══════════════════════════════════════════════════════════════════════════
{ ... }:

{
  imports = [
    ./packages.nix # the CENTRAL LIST of the user's apps/CLIs (it mirrors system/packages.nix)
    ./shell # terminal, shell and dev CLI (zsh/starship/cli/kitty/git)
    ./desktop # Hyprland plus Wayland plus appearance (hypr/quickshell/lockscreen/theme/xdg…)
    ./apps # user apps WITH a config of their own (dropbox/media/dolphin/flameshot/mangohud)
    ./services # the user's services/timers (cs2-saves-backup, claude-discord-rpc)
    ./net # remote hosts and network CLIs (the FAI workstation's SSOT plus wake-workstation)
  ];

  home.username = "v1cferr";
  home.homeDirectory = "/home/v1cferr";

  programs.home-manager.enable = true;

  # Fixed at the 1st switch: NEVER change it afterwards.
  home.stateVersion = "26.05";
}
