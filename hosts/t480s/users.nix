# The t480s's accounts: cesar beside the shared v1cferr, and the password hashes of both.
# Why he is not in wheel and why the hashes are files: docs/decisions/0018-a-shared-laptop.md
{ config, ... }:

let
  # Root-only files written ONCE by the install, outside the store and outside git. They seed the
  # account; after that each person changes their own password with `passwd`.
  passwordFile = user: "/var/lib/login-passwords/${user}";
in
{
  users.users.v1cferr.hashedPasswordFile = passwordFile "v1cferr";

  # Cesar's home is HIS: standalone Home Manager from his own repository, applied as himself.
  users.users.cesar = {
    isNormalUser = true;
    description = "Cesar";
    extraGroups = [ "networkmanager" ];
    hashedPasswordFile = passwordFile "cesar";
  };

  # The same trap as v1cferr's home (modules/nixos/core/users.nix): tmpfiles, not only createHome.
  systemd.tmpfiles.rules = [
    "d ${config.users.users.cesar.home} 0700 cesar users - -"
  ];
}
