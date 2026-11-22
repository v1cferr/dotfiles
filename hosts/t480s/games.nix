# What THIS laptop needs to play WoW: the system's gaming stack, 32-bit graphics for Wine, and a
# plain games folder in place of the desk's Windows disk. Only my home plays; Cesar's is untouched.
{ ... }:

{
  # GameMode with the performance profile, ntsync, Steam and Hydra. `my.gaming.buildCpus` stays
  # unset: on 4 cores the game fence would leave a build next to nothing.
  imports = [ ../../modules/nixos/gaming ];

  # Wine runs WoW's 32-bit pieces too; on the desk the Arc module sets this, here nothing did.
  hardware.graphics.enable32Bit = true;

  # No Windows disk here: the WoW link and the add-on copy land in ~/Games/World of Warcraft, on
  # btrfs `@home`. Installed by copying the desk's folder: docs/guides/t480s-install.md
  home-manager.users.v1cferr.my.games.root = "/home/v1cferr/Games";
}
