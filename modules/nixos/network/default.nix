# Networking EVERY host gets. A ROLE (remote access, the FAI gateway, the VPNs) is imported by the
# host that plays it, like a device module: docs/decisions/0018-a-shared-laptop.md
{ ... }:

{
  imports = [
    ./domain.nix # THE INTERFACE: it declares my.net.domain (the public domain's SSOT)
    ./subnets.nix # THE INTERFACE: it declares my.net.{lan,vpn}Subnet (the SSOT of the home ranges)
    ./ingress.nix # THE INTERFACE: it declares my.ingress (the SSOT of who is exposed and how far)
    ./nethogs.nix # nethogs as a capability wrapper (wheel only): the network panel's per-app traffic
    ./localsend.nix # LocalSend: the package plus 53317 (TCP/UDP) opened ONLY to the home LAN
    ./network.nix # NetworkManager, BBR and the redirect hardening
    ./router.nix # `router-sync`: it mirrors the OpenWrt's UCI into the repo (visibility, not push)
    ./tunnel.nix # the Cloudflare Tunnel (outbound only); its ingress is the `expose = "tunnel"` entries
    ./tor.nix # the Tor client: a local SOCKS5 on 127.0.0.1:9050 (an anonymous exit for a CLI)
  ];
}
