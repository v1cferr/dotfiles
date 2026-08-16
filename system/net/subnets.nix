# The home ranges (SSOT, rule 11): the LAN and the router's WireGuard, kept SEPARATE.
# They mirror the router, which is what really defines them; Nix does not reach it.
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
