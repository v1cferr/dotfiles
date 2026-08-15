# ═══════════════════════════════════════════════════════════════════════════
# Tor: CLIENT ONLY, a SOCKS5 on 127.0.0.1:9050 to give an anonymous exit to a CLI that accepts a
# proxy (today's consumer is `mega-tor`, home/net/mega.nix).
#
# WHY here and not in home/: it is a system daemon with a user of its own and state in /var/lib/tor
# (rule 4). It sits in the service panel because the use is occasional; turning it off breaks
# nothing beyond the CLIs pointing at 9050.
#
# NEVER a relay/exit (ClientOnly): a relay gives away bandwidth and, in the exit case, third-party
# traffic goes out with MY IP. Here we only CONSUME the network.
#
# THE TRAPS (the first three contradict what the NixOS wiki shows):
#   1. `enable` on its own brings the daemon up WITH NO exit port; what opens the SOCKS is
#      `client.enable`. Without it the service sits "active" and nothing can use it.
#   2. The wiki example's `openFirewall = true` is for a RELAY. The listener here is 127.0.0.1, so
#      there is nothing to open, and opening it would become an open proxy for the LAN.
#   3. The wiki's "second fast port 9063" does NOT EXIST in this nixpkgs: the module generates ONE
#      SOCKSPort from `client.socksListenAddress` (9050 plus IsolateDestAddr). 9063 is only the
#      default of the `torsocks-faster` wrapper (services.tor.torsocks), so enabling torsocks would
#      install a wrapper pointing at a port where nobody listens. That is why torsocks stays OUT:
#      the consumer here speaks SOCKS natively. If a program with no proxy support ever comes in
#      (wget, say), then torsocks makes sense, and that commit has to bring a hand-declared
#      SOCKSPort 9063 along, otherwise the `-faster` is a trap.
#   4. SafeSocks refuses SOCKS4 and SOCKS5-with-an-IP, which means: whoever resolves DNS locally
#      and sends the ready IP gets an ERROR instead of leaking the query. The price is that every
#      consumer has to use `socks5h://` (h = the hostname resolved by Tor).
#   5. BANDWIDTH: a circuit is 3 volunteer hops, which in practice is hundreds of KB/s. The Tor
#      project itself discourages bulk (the network is sized for low latency, not for throughput).
#      For tens of GB the right path is a paid VPN, not this.
# ═══════════════════════════════════════════════════════════════════════════
{ config, ... }:

{
  services.tor = {
    enable = config.my.services.tor;
    client.enable = true; # this is what opens the SOCKS5 on 127.0.0.1:9050
    settings = {
      ClientOnly = true; # it locks the role: never a relay, never an exit
      SafeSocks = true; # DNS resolved outside Tor is an error, not a silent leak
    };
  };
}
