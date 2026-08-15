# ═══════════════════════════════════════════════════════════════════════════
# THE HOME NETWORK'S RANGES = the SINGLE SOURCE (rule 11). "From home" is a SECURITY decision, the
# one that separates who gets in directly from who needs a password, and it was written out in
# three different places.
#
# THE TRIGGER: with Tailscale leaving (08/08/2026) the list became a triple consumer: Caddy's
# `@externo` matcher, the fail2ban jail's `ignoreip` and the firewall rule that replaced
# `trustedInterfaces`. A literal repeated in 2+ places is exactly what rule 11 says to turn into an
# option, and here the cost of diverging is high: an outdated copy gives no build error, it just
# starts treating somebody who should get in as a stranger, or worse, the other way around.
#
# ITS OWN FILE, the same justification as ./domain.nix: the consumers are in TWO folders (net/ and
# services/), so no module is the obvious owner.
#
# THESE VALUES MIRROR THE ROUTER, which is what really defines them (the OpenWrt serves the LAN's
# DHCP and is the WireGuard server). Nix does not reach over there: changing the range on the
# router and forgetting here leaves the repo lying in silence.
# ═══════════════════════════════════════════════════════════════════════════
{ lib, ... }:

{
  options.my.net = {
    lanSubnet = lib.mkOption {
      type = lib.types.str;
      default = "192.168.1.0/24";
      description = "The home LAN's range (DHCP served by the OpenWrt router).";
    };

    # SEPARATE from the LAN on purpose, instead of both in a single list: there is a consumer that
    # needs ONE and not the other. The firewall that keeps Sunshine reachable trusts only this
    # one, since Sunshine is closed ON THE LAN by decision, and merging the two would open it to
    # the whole home network without anybody noticing.
    vpnSubnet = lib.mkOption {
      type = lib.types.str;
      default = "10.10.10.0/24";
      description = "The range of the WireGuard served by the ROUTER. It is how remote access gets in.";
    };
  };
}
