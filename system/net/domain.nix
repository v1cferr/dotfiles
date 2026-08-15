# ═══════════════════════════════════════════════════════════════════════════
# THE PUBLIC DOMAIN = the SINGLE SOURCE (rule 11). Every exposed service lives under a subdomain
# of this name.
#
# Before this option the literal `v1cferr.dev` appeared only once, in ./network.nix'
# `services.cloudflare-dyndns.domains`, and a lone literal does not justify an option. With Caddy
# back (system/services/caddy.nix) the consumers became four: the DDNS, the site block's address,
# the access matchers and the fail2ban filter. That is exactly rule 11's trigger: a value repeated
# in 2+ places becomes `my.<domain>.<thing>` and nobody holds a literal anymore.
#
# WHY ITS OWN FILE, and not inside the module that consumes it (the way `my.fonts.ui` lives in
# hardware/fonts.nix and `my.monitors` in desktop/monitors.nix): here the consumers are in TWO
# folders (net/ and services/), so no module is the obvious owner. It sits in net/ because a domain
# is a network fact.
#
# WITH a `default`, unlike `my.monitors`: a video connector is a HARDWARE fact, and a default
# there would be the lie that only shows up on host nº 2. A domain is an IDENTITY fact, the same
# criterion that gives `my.fonts.ui` a default.
# ═══════════════════════════════════════════════════════════════════════════
{ lib, ... }:

{
  options.my.net.domain = lib.mkOption {
    type = lib.types.str;
    default = "v1cferr.dev";
    description = "The public domain under which the services are exposed (SSOT, rule 11). Read by the DDNS, by Caddy and by the fail2ban jails.";
  };
}
