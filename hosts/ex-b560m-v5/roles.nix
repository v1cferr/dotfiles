# The ROLES the ex-b560m-v5 plays that another host would not: reached from outside, the house's
# gateway into the FAI VPN, always on, the vault's holder: docs/decisions/0018-a-shared-laptop.md
{ ... }:

{
  imports = [
    ../../modules/nixos/network/remote-access.nix # the exposed SSH plus TOTP, fail2ban, the login alert, WoL, no suspend
    ../../modules/nixos/network/fai-gateway.nix # NAT plus forward: the home LAN goes out through the FAI VPN
    ../../modules/nixos/network/router-log.nix # the router's syslog received here (router only, UDP 5514), kept 30 days
    ../../modules/nixos/network/vpn.nix # the FAI (nxBender/SonicWall) plus UFSCar (openconnect/GlobalProtect) VPNs, on demand
  ];
}
