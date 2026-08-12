# Rede.
{ ... }:

{
  imports = [
    ./domain.nix # INTERFACE: declara my.net.domain (SSOT do domínio público)
    ./subnets.nix # INTERFACE: declara my.net.{lan,vpn}Subnet (SSOT das faixas de casa)
    ./ingress.nix # INTERFACE: declara my.ingress (SSOT de quem é exposto e até onde)
    ./fai-gateway.nix # NAT+forward: a LAN de casa sai pela VPN FAI (par manual em docs/guias/)
    ./localsend.nix # LocalSend: pacote + 53317 (TCP/UDP) aberta SÓ pra LAN de casa
    ./network.nix # NetworkManager, SSH exposto, fail2ban, DNS dinâmico, no-sleep
    ./router.nix # `router-sync`: espelha o UCI do OpenWrt no repo (visibilidade, não push)
    ./tor.nix # Tor cliente: SOCKS5 local 127.0.0.1:9050 (saída anônima p/ CLI)
    ./vpn.nix # VPNs FAI (nxBender/SonicWall) + UFSCar (openconnect/GlobalProtect), sob demanda
  ];
}
