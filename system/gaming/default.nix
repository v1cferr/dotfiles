# Jogos (nível-sistema): clientes/runtimes que precisam de FHS-wrap ou firewall.
{ ... }:

{
  imports = [
    ./steam.nix # cliente Steam + Proton-GE + gamemode (Remote Play/LAN c/ firewall)
  ];
}
