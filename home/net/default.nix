# The user's networking: remote hosts and network CLIs (it mirrors system/net/, with no privilege).
{ ... }:

{
  imports = [
    ./fai-workstation.nix # the SSOT of the FAI workstation's host plus `wake-workstation` (WoL)
    ./mega.nix # megatools plus `mega-dl` (a MEGA link with patient resuming; --tor/--proxy)
  ];
}
