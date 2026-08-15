# Networking.
{ ... }:

{
  imports = [
    ./domain.nix # THE INTERFACE: it declares my.net.domain (the public domain's SSOT)
    ./subnets.nix # THE INTERFACE: it declares my.net.{lan,vpn}Subnet (the SSOT of the home ranges)
    ./ingress.nix # THE INTERFACE: it declares my.ingress (the SSOT of who is exposed and how far)
    ./fai-gateway.nix # NAT plus forward: the home LAN goes out through the FAI VPN (the manual counterpart is in docs/guides/)
    ./localsend.nix # LocalSend: the package plus 53317 (TCP/UDP) opened ONLY to the home LAN
    ./network.nix # NetworkManager, the exposed SSH, fail2ban, dynamic DNS, no-sleep
    ./router.nix # `router-sync`: it mirrors the OpenWrt's UCI into the repo (visibility, not push)
    ./tor.nix # the Tor client: a local SOCKS5 on 127.0.0.1:9050 (an anonymous exit for a CLI)
    ./vpn.nix # the FAI (nxBender/SonicWall) plus UFSCar (openconnect/GlobalProtect) VPNs, on demand
  ];
}
