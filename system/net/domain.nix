# The public domain (SSOT, rule 11), read by the DDNS, Caddy and the fail2ban jails.
# It has a default because a domain is an identity fact, unlike my.monitors.
{ lib, ... }:

{
  options.my.net.domain = lib.mkOption {
    type = lib.types.str;
    default = "v1cferr.dev";
    description = "The public domain under which the services are exposed (SSOT, rule 11). Read by the DDNS, by Caddy and by the fail2ban jails.";
  };
}
