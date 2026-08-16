# LocalSend: the package (the module ties it to the firewall) plus 53317 opened to the LAN ONLY.
# Why openFirewall = false, and what changing the port breaks: docs/notes/network.md
{ config, ... }:

let
  # One port for TCP and UDP; it appears in 4 rules below.
  port = 53317;
in
{
  programs.localsend = {
    enable = true;
    openFirewall = false; # the port is opened ONLY for the LAN, in the rule below
  };

  # `-I 1` and not `-A`: it holds whether or not upstream keeps injecting before the refuse.
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
