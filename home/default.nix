# THE USER (home-manager): the user's PACKAGES AND CONFIG, by CATEGORY. Breaking home does NOT
# take the boot down, which is the separation that makes these dotfiles reproducible.
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
