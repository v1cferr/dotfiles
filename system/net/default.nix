# Rede.
{ ... }:

{
  imports = [
    ./domain.nix # INTERFACE: declara my.net.domain (SSOT do domínio público)
    ./ingress.nix # INTERFACE: declara my.ingress (SSOT de quem é exposto e até onde)
    ./network.nix # NetworkManager, SSH exposto, fail2ban, DNS dinâmico, no-sleep
    ./tailscale.nix # mesh VPN (WireGuard) p/ acesso remoto seguro (chega no Sunshine/SSH)
    ./tor.nix # Tor cliente: SOCKS5 local 127.0.0.1:9050 (saída anônima p/ CLI)
    ./vpn.nix # VPNs FAI (nxBender/SonicWall) + UFSCar (openconnect/GlobalProtect), sob demanda
  ];
}
