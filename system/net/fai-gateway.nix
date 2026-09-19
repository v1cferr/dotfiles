# THE FAI GATEWAY: NAT plus forward so the home LAN reaches FAI through ppp0.
# Why it cannot live on the router, and the anti-loop rule: docs/notes/network/network.md
{
  config,
  lib,
  pkgs,
  ...
}:

let
  inherit (pkgs) writeShellApplication iproute2;

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

  # The list above MIRRORS somebody else's routing, so it can go stale with nothing here
  # changing. This reads what the IPCP actually handed over and says so: docs/notes/network/network.md
  faiRoutesCheck = writeShellApplication {
    name = "fai-routes-check";
    runtimeInputs = [ iproute2 ];
    text = ''
      # The interface FIRST: `ip route show dev ppp0` EXITS NONZERO when it does not exist, and
      # under writeShellApplication's `set -e` that kills the script with no message at all.
      if ! ip -o link show ppp0 >/dev/null 2>&1; then
        echo "fai-routes-check: ppp0 does not exist. Connect the FAI VPN first." >&2
        exit 2
      fi

      actual=$(ip -4 route show dev ppp0 | awk '$1 ~ /\// { print $1 }' | sort -u)
      if [ -z "$actual" ]; then
        echo "fai-routes-check: ppp0 is up but routes nothing yet. nxBender pushes them ~10s in." >&2
        exit 2
      fi

      declared=$(printf '%s\n' ${lib.escapeShellArgs faiSubnets} | sort -u)

      # Reported in BOTH directions on purpose: a range they dropped leaves a REJECT rule for
      # traffic that should now go out normally, which is the half nobody notices.
      missing=$(comm -13 <(echo "$declared") <(echo "$actual"))
      extra=$(comm -23 <(echo "$declared") <(echo "$actual"))

      if [ -z "$missing" ] && [ -z "$extra" ]; then
        echo "fai-routes-check: $(echo "$actual" | wc -l) ranges, all declared"
        exit 0
      fi

      echo "fai-routes-check: system/net/fai-gateway.nix disagrees with the tunnel" >&2
      if [ -n "$missing" ]; then
        while IFS= read -r r; do
          echo "  ppp0 routes it, faiSubnets does not: $r" >&2
        done <<< "$missing"
      fi
      if [ -n "$extra" ]; then
        while IFS= read -r r; do
          echo "  faiSubnets declares it, ppp0 does not: $r" >&2
        done <<< "$extra"
      fi
      exit 1
    '';
  };
in
{
  # Run it with the tunnel UP. It cannot be a gate: the build sandbox has no VPN.
  environment.systemPackages = [ faiRoutesCheck ];

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
