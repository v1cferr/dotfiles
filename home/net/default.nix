# Rede do usuário: hosts remotos e CLIs de rede (espelha o system/net/, sem privilégio).
{ ... }:

{
  imports = [
    ./fai-workstation.nix # SSOT do host da workstation FAI + `wake-workstation` (WoL)
    ./mega.nix # megatools + `mega-dl` (link do MEGA com retomada paciente; --tor/--proxy)
  ];
}
