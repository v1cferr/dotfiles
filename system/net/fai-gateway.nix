# THE FAI GATEWAY: NAT plus forward so the home LAN reaches FAI through ppp0.
# Why it cannot live on the router, and the anti-loop rule: docs/notes/network.md
{ config, lib, ... }:

let
  # THEIR list, not ours: it arrives in the IPCP and can change. `ip route show dev ppp0`.
  # It exists only for the anti-loop rules; nxBender installs the real route.
  faiSubnets = [
    "192.168.90.0/24"
    "192.168.100.0/24"
    "192.168.110.0/24"
    "192.168.130.0/24"
    "192.168.223.0/24"
    "200.136.209.128/25"
  ];
in
{
  # MASQUERADE is mandatory: FAI has no route back to 192.168.1.0/24.
  # Do NOT declare ip_forward too; enabling nat already sets it (nat.nix:200).
  networking.nat = {
    enable = true;
    externalInterface = "ppp0";
    internalIPs = [ config.my.net.lanSubnet ];
  };

  networking.firewall = {
    # FORWARD needs an explicit ACCEPT (Docker sets the policy to DROP) and `-I 1`, since Docker
    # inserts at the TOP. The REJECTs are the anti-loop: with the VPN off the router still routes here.
    extraCommands = ''
      iptables -I FORWARD 1 -s ${config.my.net.lanSubnet} -o ppp0 -j ACCEPT
      iptables -I FORWARD 1 -d ${config.my.net.lanSubnet} -i ppp0 -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT
      ${lib.concatMapStringsSep "\n" (
        net: "iptables -I FORWARD 1 -d ${net} ! -o ppp0 -j REJECT --reject-with icmp-net-unreachable"
      ) faiSubnets}
    '';

    # Without this, a firewall `reload` piles up duplicates (the same lesson as ./network.nix).
    extraStopCommands = ''
      iptables -D FORWARD -s ${config.my.net.lanSubnet} -o ppp0 -j ACCEPT 2>/dev/null || true
      iptables -D FORWARD -d ${config.my.net.lanSubnet} -i ppp0 -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT 2>/dev/null || true
      ${lib.concatMapStringsSep "\n" (
        net:
        "iptables -D FORWARD -d ${net} ! -o ppp0 -j REJECT --reject-with icmp-net-unreachable 2>/dev/null || true"
      ) faiSubnets}
    '';
  };
}
