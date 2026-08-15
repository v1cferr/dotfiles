# ═══════════════════════════════════════════════════════════════════════════
# THE FAI VPN GATEWAY: it lets the home LAN reach the FAI network through ppp0.
#
# THE REQUEST WAS "put the VPN on the router", and that DOES NOT FIT. Measured on the device on
# 12/08/2026: the Cudy WR3000 has 1.3 MB free in /overlay (of 6.1 MB, 78% used) and no python3.
# nxBender is Python plus requests plus pyroute2 plus configargparse plus colorlog, which is
# 15-25 MB on OpenWrt. It is short by an ORDER OF MAGNITUDE. It is the same wall
# ../../docs/ideas.md already recorded for Jellyfin/Sunshine/Caddy, for the same numbers.
#
# So the tunnel stays HERE and this machine becomes the network's gateway:
#
#   phone/laptop → router → 192.168.1.10 → ppp0 → FAI
#      (a static route)      (this file)
#
# THE COUNTERPART IS NOT DECLARABLE, and without it this does NOTHING visible: the PC forwards,
# but nobody sends traffic here. The static routes and the split DNS live in OpenWrt's UCI, and
# ./router.nix refuses to push on purpose: "one wrong network or firewall line locks you out and
# the way back is failsafe mode with PHYSICAL access".
# The commands are in ../../docs/guides/fai-gateway-router.md.
#
# And the circuit was open on THIS side, not the other: the six `fai_r1..fai_r6` routes ALREADY
# EXISTED on the router (and committed in ../../router/uci/network.conf) pointing at
# 192.168.1.10, so with no NAT and no forward here, the packet arrived and died. A route pointing
# at a gateway that does not forward gives an error nowhere: it simply does not work.
# MEASURED on 12/08/2026, AFTER this module, from my brother's PC (192.168.1.40): 3x HTTP 200 on
# https://dashboard.sup.fai.ufscar.br. The "before" was not measured; it is inference, but a
# solid one: `grep -rn networking.nat` in the repo returned ZERO until today.
#
# NO TOGGLE in my.services, following the rule ../services/toggles.nix writes itself ("the VPN is
# on demand (out)"): the rules below are inert while there is no ppp0, and what turns the tunnel
# on and off is the `vpn` CLI in ./vpn.nix.
# ═══════════════════════════════════════════════════════════════════════════
{ config, lib, ... }:

let
  # The ranges FAI pushes through the tunnel. THIS LIST IS THEIRS, not ours: it comes in the IPCP
  # on every connection and can change with no warning. Confirm it with
  # `ip route show dev ppp0` (six ranges on 13/08/2026, identical to 12/08's). It only exists here
  # for the anti-loop rules below; the real route is installed by nxBender.
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
  # MASQUERADE IS MANDATORY, not an optimization: FAI has no route back to 192.168.1.0/24, so the
  # packet gets there with no return path. With the NAT, everything leaves as ppp0's address
  # (192.168.50.10 in the 12/08 session), which is the only one FAI knows how to answer.
  #
  # `internalIPs` and not `internalInterfaces`: the decision is by ORIGIN, not by NIC, the same
  # idiom as the WireGuard rule in ./network.nix ("trust has to be by ORIGIN"), and it reuses
  # ./subnets.nix' SSOT instead of pinning the range here.
  #
  # Do NOT declare ip_forward alongside: turning nat on already sets
  # `net.ipv4.conf.all.forwarding = mkOverride 99 true` (nixpkgs nat.nix:200). Today forwarding is
  # already at 1, but as a side effect of Docker, and depending on that would be config existing
  # by accident, which disappears the day Docker leaves.
  networking.nat = {
    enable = true;
    externalInterface = "ppp0";
    internalIPs = [ config.my.net.lanSubnet ];
  };

  networking.firewall = {
    # FORWARD needs an EXPLICIT ACCEPT because Docker sets the policy to DROP whenever it manages
    # iptables, and this host has docker0 plus two bridges. The `nat` module above does NOT cover
    # that: it only hangs the `nixos-filter-forward` chain, which exists for the port forwards
    # (nixpkgs nat-iptables.nix:184).
    #
    # `-I FORWARD 1` for the same reason as ./network.nix' `-I nixos-fw 1`: Docker inserts its
    # rules at the TOP of the chain, and an append would land after everything.
    #
    # The return path goes through conntrack, NOT a symmetric ACCEPT: FAI starting a connection
    # INTO the house is not the use case, and allowing that would give the FAI network access to
    # the whole LAN. Only what this house started comes back.
    #
    # ANTI-LOOP, DIAGNOSED ON 13/08/2026, and the symptom did not look like this at all. With the
    # VPN OFF the router still sends FAI's ranges to 192.168.1.10 (its static route is fixed and
    # knows nothing about the tunnel); with no ppp0 this machine has no specific route, so it
    # sends the packet back out the default, back to the router, which sends it back here. A LOOP
    # until the TTL dies, and the user sees "The connection has timed out" after 15s, with no hint
    # at all that the cause is the VPN being down.
    #
    # `! -o ppp0` and not `-i enp7s0 -o enp7s0`: the condition that matters is "traffic for FAI
    # that is NOT entering the tunnel", regardless of where it was going to leave. It names no
    # NIC, so it survives a card swap.
    #
    # REJECT and not DROP, on purpose: the ICMP net-unreachable makes the client fail RIGHT AWAY
    # with "no route to host", instead of hanging until the timeout. Trading 15s of mystery for an
    # instant, nameable failure is the point; there is no making the site work without the VPN
    # (measured: neither .236 nor .229 accepts a connection from outside), so the best possible is
    # failing fast and legibly.
    #
    # It only affects FORWARDED traffic: this machine's own access goes through OUTPUT, not
    # FORWARD, and stays untouched.
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
