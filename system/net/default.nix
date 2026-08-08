# Rede.
{ ... }:

{
  imports = [
    ./domain.nix # INTERFACE: declara my.net.domain (SSOT do domínio público)
    ./subnets.nix # INTERFACE: declara my.net.{lan,vpn}Subnet (SSOT das faixas de casa)
    ./ingress.nix # INTERFACE: declara my.ingress (SSOT de quem é exposto e até onde)
    ./network.nix # NetworkManager, SSH exposto, fail2ban, DNS dinâmico, no-sleep
    ./tor.nix # Tor cliente: SOCKS5 local 127.0.0.1:9050 (saída anônima p/ CLI)
    ./vpn.nix # VPNs FAI (nxBender/SonicWall) + UFSCar (openconnect/GlobalProtect), sob demanda
  ];
}
