# Rede.
{ ... }:

{
  imports = [
    ./network.nix # NetworkManager, SSH exposto, fail2ban, DNS dinâmico, no-sleep
  ];
}
