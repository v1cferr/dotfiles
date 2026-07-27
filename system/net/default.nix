# Rede.
{ ... }:

{
  imports = [
    ./network.nix # NetworkManager, SSH exposto, fail2ban, DNS dinâmico, no-sleep
    ./tailscale.nix # mesh VPN (WireGuard) p/ acesso remoto seguro (chega no Sunshine/SSH)
  ];
}
