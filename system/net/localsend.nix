# ═══════════════════════════════════════════════════════════════════════════
# LOCALSEND: an open source "AirDrop", a file going straight between phone and PC over the LAN,
# with no cloud, no account and no middleman (end-to-end TLS with a self-signed certificate
# generated on each device).
#
# WHY IT LIVES IN system/ AND NOT IN home/ (rule 4): what ties the PACKAGE to the firewall PORT is
# the nixpkgs module (`programs.localsend`), and the firewall is system level. It is the same case
# as `programs.steam` (system/gaming/steam.nix): the upstream module is not optional, so the
# package comes with it. The package is NOT repeated in home/packages.nix: whoever needs the
# binary reads `osConfig.programs.localsend.package` (which is what home/desktop/autostart.nix
# does).
#
# 53317 is used by BOTH protocols, and both are mandatory: TCP is the transfer and the
# `/api/localsend/v2/info`; UDP is the multicast announcement on 224.0.0.167 that makes the
# devices DISCOVER each other. Without the UDP one the app works, but only through adding by IP by
# hand.
#
# `openFirewall = false` AGAINST the module's default, and the reason is NOT the internet: the
# router forwards 80/443/2222 and the Moonlight ports (47984, 47989, 48010/tcp plus
# 47998-48000/udp, these restricted to UFSCar since 10/08/2026), and 53317 is on none of those
# lists, so the world never reached it. What would reach it is the VPN: `openFirewall` opens the
# port on EVERY interface, and with the FAI tunnel up (`ppp0`) the whole corporate network would
# start seeing the service and reading the `/info` (device name, model, fingerprint) with no
# authentication at all. Trust here is by ORIGIN, just like the Sunshine rule in ./network.nix:
# the home LAN only, read from the SSOT (rule 11).
#
# The WireGuard peers come in FOR FREE and need no rule of their own: they arrive with origin
# 10.10.10.x and ./network.nix' rule already accepts the whole range before any other decision.
#
# The port is REPEATED here because the module does not expose it as an option (it is a
# `firewallPort = 53317` internal to its file). If you change the port INSIDE the app (Settings ->
# Network), this rule stops matching and RECEIVING DIES IN SILENCE, with no build error, no log,
# just "the phone cannot find me".
#
# IPv4 only, like every rule in this repo: LocalSend's discovery is IPv4 multicast and the home LAN
# has no routed IPv6.
#
# The app's settings (the alias, the destination folder, saving without confirming) and the
# received files are STATE (rule 6): the app rewrites its own `shared_preferences` at runtime, so
# Nix does not own it (rule 14).
# ═══════════════════════════════════════════════════════════════════════════
{ config, ... }:

let
  # The protocol's single port: it holds for TCP and for UDP, and it shows up in 4 rules below.
  port = 53317;
in
{
  programs.localsend = {
    enable = true;
    openFirewall = false; # see the header: the port is opened ONLY for the LAN, in the rule below
  };

  # `-I nixos-fw 1` and not `-A`, and the reason MEASURED in the generated firewall-start (26.05)
  # is narrower than what the neighbor in ./network.nix says: `extraCommands` is injected BEFORE
  # the `-A nixos-fw -j nixos-fw-log-refuse`, so today `-A` would be reached too. What actually
  # falls into the void is the same rule typed BY HAND into an already running firewall; there the
  # chain does end at the refuse. `-I 1` is what holds in both cases and does not depend on where
  # upstream decides to inject extraCommands tomorrow.
  networking.firewall = {
    extraCommands = ''
      iptables -I nixos-fw 1 -s ${config.my.net.lanSubnet} -p tcp --dport ${toString port} -j nixos-fw-accept
      iptables -I nixos-fw 1 -s ${config.my.net.lanSubnet} -p udp --dport ${toString port} -j nixos-fw-accept
    '';
    # Without this, a firewall `reload` piles up duplicates of the rules above.
    extraStopCommands = ''
      iptables -D nixos-fw -s ${config.my.net.lanSubnet} -p tcp --dport ${toString port} -j nixos-fw-accept 2>/dev/null || true
      iptables -D nixos-fw -s ${config.my.net.lanSubnet} -p udp --dport ${toString port} -j nixos-fw-accept 2>/dev/null || true
    '';
  };
}
