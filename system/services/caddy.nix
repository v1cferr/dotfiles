# ═══════════════════════════════════════════════════════════════════════════
# CADDY: the reverse proxy for ALL exposed services, under `*.<domain>`, with a WILDCARD
# certificate from Let's Encrypt (the DNS-01 challenge through Cloudflare).
#
# It restores the ingress that existed on Arch (the `main`/`arch` branch,
# caddy/etc/caddy/Caddyfile) and that the migration to NixOS left behind. It is the
# "Phase 4, Homelab" of the nixos branch README, now declarative.
#
# WHY ONE WILDCARD SITE BLOCK and not a vhost per subdomain: it is ONE certificate instead of
# ~10 simultaneous ACME requests. Routing by name comes from the `@host` matchers below, and
# an unmapped subdomain falls into the 404 at the end.
#
# WHY DNS-01 and not HTTP-01: a wildcard is only issued through DNS-01. The price is a Caddy
# with the dns.providers.cloudflare plugin. On Arch that required building with xcaddy and
# HIDING the binary in /usr/local/bin, because "a `pacman -Syu` once overwrote the custom
# binary and took the whole proxy down" (scripts/caddy/build.sh of the old setup). On Nix the
# package IS the declaration: that problem stops existing, and the `hash` below pins the Go
# vendor.
#
# `propagation_timeout -1` is NOT a guess. certmagic's LOCAL propagation check fails ON THIS
# host even when forcing public resolvers, while the record does propagate for real (8.8.8.8,
# 1.1.1.1 and the authoritative server confirm it), and it is the world that LE queries. A
# fixed 30s wait plus the local check turned off makes LE validate directly. Without it the
# issuance HANGS.
#
# The fail2ban filters match the ORDER OF THE KEYS in the JSON access log (remote_ip, then
# host, then status, with a non-greedy `.+?`). A Caddy bump can break them SILENTLY: the
# service stays up and simply stops banning. Validate with `fail2ban-regex` on every bump.
#
# AUTO-GATE (the same pattern as ./duo.nix): it only activates when all FOUR secrets exist.
# Until they are provisioned it stays INERT and the system keeps building, which matters
# because an empty `{$VAR}` would become an empty basic_auth hash, and Caddy would refuse the
# entire config.
#
# Turning it on (once):
#   1. Cloudflare: an API token with `Zone:Read + DNS:Edit` ON THE ZONE. It is a token
#      SEPARATE from the DDNS one (the old setup also kept two).
#   2. `caddy hash-password` once per basic_auth user.
#   3. Bitwarden: create the items (the VALUE always goes in the *password* field):
#        "Caddy ACME Email"        (the Let's Encrypt notice email)
#        "Caddy Cloudflare DNS"    (the token from step 1)
#        "Caddy Pos Hash v1cferr"  (a bcrypt hash)
#        "Caddy Pos Hash jp"       (João Pedro's bcrypt hash)
#   4. secrets/bitwarden-secrets.json: add the four corresponding lines.
#   5. `sync-secrets` then `sudo nixos-rebuild switch --flake .#nixos-kingston`
#   6. DNS on Cloudflare: `pos.<domain>` = CNAME to `ssh.<domain>`, proxied=false (gray). The
#      `ssh` A record is the IP anchor, and what maintains it is the DDNS in
#      ../net/network.nix.
#
# THE LOOPBACK PORT MAP, inherited from the old setup. A new project picks a free one and
# WRITES IT DOWN here, otherwise the next collision is silent:
#   3000 open-webui · 3001 spendflow · 3003 homepage · 3004 filebrowser
#   3005 housing-radar · 3006 GRAD-RADAR (front) · 3010 duo-web
#   8000 spendflow-api (reserved) · 8006 GRAD-RADAR (api) · 8010 duo-api
#   8080 qbittorrent · 8096 jellyfin · 11434 ollama
#
# STATE (rule 6): /var/lib/caddy holds the ACME account and the certificates. It is not
# declared, and it is worth backing up, because LE limits 5 DUPLICATE certificates per week:
# losing the store costs a reissue window, not just a rebuild.
# The Caddyfile has ONE OWNER, Nix (rule 14), so no `caddy reload` writing over it.
# ═══════════════════════════════════════════════════════════════════════════
{
  config,
  lib,
  pkgs,
  ...
}:

let
  domain = config.my.net.domain;
  inherit (config.my.net) lanSubnet vpnSubnet;

  # Regex escaping: the domain goes into the fail2ban failregex, where `.` is a wildcard.
  # Escaping prevents `pos.v1cferr.dev` from matching `posXv1cferrYdev`.
  domainRe = builtins.replaceStrings [ "." ] [ "\\." ] domain;

  # AUTO-GATE: they are needed TOGETHER. With one missing, `{$VAR}` becomes an empty string and
  # Caddy refuses the config (an empty basic_auth hash), so being inert is better than taking
  # the proxy down on the switch.
  #
  # The hashes are NOT literals here: they are derived from whoever declares `auth` in the
  # SSOT. When they were fixed, removing basic_auth from a service left the gate requiring a
  # secret nobody read anymore, and the day that item left Bitwarden, Caddy would go inert,
  # taking jellyfin, torrent, ai and duo with it. A service that goes down because of a
  # password it does not use is the worst kind of coupling: invisible until the day it matters.
  authVars = lib.unique (lib.concatMap (s: lib.attrValues s.auth) (lib.attrValues config.my.ingress));
  requiredSecrets = [
    "caddy_acme_email"
    "caddy_cloudflare_dns_token"
  ]
  ++ map lib.toLower authVars;
  enabled = lib.all (s: builtins.hasAttr s config.sops.secrets) requiredSecrets;

  # ── The vhost generator, from `my.ingress` (system/net/ingress.nix) ────────
  # The Caddyfile stopped being written by hand: what decides reach is the SSOT, and forgetting
  # to declare CLOSES instead of exposing (the `expose` default is "lan").
  svcs = config.my.ingress;

  # A `handle` per prefix, before the upstream. Caddy resolves the most specific first, so the
  # order among them does not matter; the order AGAINST the upstream does.
  routeBlocks =
    s:
    lib.concatStringsSep "\n" (
      lib.mapAttrsToList (path: port: ''
        handle ${path} {
          reverse_proxy 127.0.0.1:${toString port}
        }'') s.routes
    );

  # CONCATENATION and not interpolation: the target is the literal `{$VAR}` (Caddy's env var
  # syntax), and `"{$" + v + "}"` is the only unambiguous form, because `$${v}` in a Nix string
  # is a SYNTAX ERROR, not an escape. It bit once already: the first generated file came out
  # with a literal `{$${v}}`, which would become an empty hash at runtime.
  authBlock =
    s:
    lib.optionalString (s.auth != { }) ''
          basic_auth @externo {
      ${lib.concatStringsSep "\n" (lib.mapAttrsToList (u: v: "      " + u + " {$" + v + "}") s.auth)}
          }
    '';

  # The 403 only exists for whoever is "lan". In "public" the gate is the `auth` (or nothing,
  # when the service has its own login, which is the jellyfin/torrent case).
  gateBlock =
    s:
    lib.optionalString (s.expose == "lan") ''
      respond @externo "Forbidden" 403
    '';

  vhostBlock = name: s: ''
    ${lib.optionalString (s.comment != "") "    # ${s.comment}"}
        # expose = ${s.expose}${lib.optionalString (s.auth != { }) " | basic_auth from outside"}
        @${name} host ${name}.${domain}
        handle @${name} {
    ${gateBlock s}${authBlock s}${routeBlocks s}
    ${upstreamBlock s}    }
  '';

  # With no `routes`, the upstream is the only route and `reverse_proxy` stands alone. The
  # fallback `handle` only exists to tie with the prefixes when there are any.
  upstreamBlock =
    s:
    let
      proxy = "reverse_proxy 127.0.0.1:${toString s.upstream}${
        lib.optionalString (s.proxyConfig != "") " {\n${indent}  ${s.proxyConfig}\n${indent}}"
      }";
      indent = if s.routes == { } then "      " else "        ";
    in
    if s.routes == { } then "      ${proxy}\n" else "      handle {\n        ${proxy}\n      }\n";

  vhosts = lib.concatStringsSep "\n" (lib.mapAttrsToList vhostBlock svcs);

  # Hosts that require basic_auth: those are the ones where a 401 means a wrong password, and
  # those are the ones the fail2ban jail has to read. Derived from the SSOT, so adding a service
  # with `auth` already enters the jail, with no hand-edited failregex.
  authHosts = lib.attrNames (lib.filterAttrs (_: s: s.auth != { }) svcs);
  authHostsRe = lib.concatStringsSep "|" (map (n: "${n}\\.${domainRe}") authHosts);
in
lib.mkIf (enabled && config.my.services.caddy) {
  services.caddy = {
    enable = true;

    # Caddy plus the Cloudflare DNS plugin (required by the wildcard's DNS-01). The `hash`
    # belongs to the Go vendor: it changes when the Caddy version or the plugin changes. A
    # rebuild complaining about the hash means recomputing it with lib.fakeHash and reading the
    # expected value in the error.
    package = pkgs.caddy.withPlugins {
      plugins = [ "github.com/caddy-dns/cloudflare@v0.2.4" ];
      hash = "sha256-7GoH8YLCoPmPExQxoga2FHB58zQDoZVf1BBwkVi0SsQ=";
    };

    # Secrets through the environment, never in /nix/store (rule 12): the Caddyfile holds only
    # the `{$VAR}` placeholders, resolved at runtime from this file.
    environmentFile = config.sops.templates."caddy.env".path;

    # The CA is pinned to PRODUCTION on purpose: an old staging state already made Caddy serve
    # an invalid certificate without warning.
    globalConfig = ''
      email {$CADDY_ACME_EMAIL}
      acme_ca https://acme-v02.api.letsencrypt.org/directory
    '';

    virtualHosts."*.${domain}" = {
      # A JSON access log to stderr to journald, which is where the fail2ban jails read from
      # (`journalmatch = _SYSTEMD_UNIT=caddy.service`). Without `format json` the filters match
      # nothing.
      logFormat = "format json";

      extraConfig = ''
                tls {
                  dns cloudflare {$CADDY_CLOUDFLARE_DNS_TOKEN}
                  resolvers 1.1.1.1 1.0.0.1
                  propagation_delay 30s
                  propagation_timeout -1
                }

                # The "home" network = LAN plus the router's WireGuard tunnel plus loopback.
                # Defined ONCE and reused by every handle below (a named matcher holds for the
                # whole site block).
                #
                # The 10.10.10.0/24 works because the WireGuard server is the ROUTER (OpenWrt)
                # and the wg to lan path does not NAT, so the source IP arrives preserved all
                # the way here. If WireGuard ever moves to the host, this range moves with it.
                #
                # On Arch this list was duplicated and DIVERGENT: `duo` included the WireGuard
                # range and `ai` did not, from a forgotten backfill. Unifying it here EXTENDS
                # `ai`'s access to the VPN clients, which is a conscious decision, not a side
                # effect.
                #
                # This range is what REMOTE ACCESS goes through ever since Tailscale left
                # (08/08/2026): you come in through the router's WireGuard and the `lan`
                # services answer as if you were on the couch. There used to be a 100.64.0.0/10
                # (the tailnet) here, and it went out with it, which is just as well: that
                # range is the SAME one carrier CGNAT uses, so an external client behind an ISP
                # NAT could present an address from it and be treated as home.
                #
                # `client_ip` and NOT `remote_ip`: today the two are identical (with no trusted
                # proxy in front, the client IS the connection). The difference shows up with
                # cloudflared, which delivers over LOOPBACK, and with `remote_ip` all the
                # tunnel traffic would become "home" and bypass basic_auth SILENTLY. Leaving
                # `client_ip` now costs nothing and removes the trap before it exists.
                # Do NOT add `trusted_proxies` while there is no tunnel: without it the
                # X-Forwarded-For header is ignored (which is what we want); with it, any local
                # process could start forging the source IP.
                @externo not client_ip ${lanSubnet} ${vpnSubnet} 127.0.0.1/8 ::1

                # ---- Vhosts GENERATED from `my.ingress` (the panel is hosts/*/services.nix) ----
                # Do not edit here: changing reach means changing `expose` in the SSOT.
        ${vhosts}

                # An unmapped subdomain gets a clean 404, instead of an ugly Caddy error.
                handle {
                  respond "Subdomain not configured" 404
                }
      '';
    };
  };

  # The repo's FIRST `allowedTCPPorts`. Everything else uses the upstream module's
  # `openFirewall`, but `services.caddy` does not have one. The router (OpenWrt) has been
  # forwarding 80/443/2222 since the old setup, and what blocked was the NixOS firewall, on by
  # default. 80 stays open because Caddy redirects to 443 and because one day it might be
  # needed for the HTTP-01 of a domain without DNS-01.
  networking.firewall.allowedTCPPorts = [
    80
    443
  ];

  # Renders Caddy's .env: config as text plus secrets through placeholders.
  # SINGLE QUOTES around the hashes: bcrypt contains `$`, and the old setup's `.env` already
  # documented that without them the value is mangled before reaching the process.
  # One line per `auth` variable declared in the SSOT, none written by hand. Leaving a
  # CADDY_*_HASH here after removing the basic_auth renders a secret nothing consumes, and the
  # next reader has no way to know it is leftover.
  sops.templates."caddy.env".content = ''
    CADDY_ACME_EMAIL=${config.sops.placeholder.caddy_acme_email}
    CADDY_CLOUDFLARE_DNS_TOKEN=${config.sops.placeholder.caddy_cloudflare_dns_token}
  ''
  + lib.concatMapStrings (v: "${v}='${config.sops.placeholder.${lib.toLower v}}'\n") authVars;

  # ── fail2ban: brute force against `pos`'s basic_auth ──────────────────────
  # It lives here and not in ../net/network.nix (where the service is declared) because the
  # jail only exists because of this proxy: whoever deletes the vhost has to delete the jail
  # with it, and the coupling stays visible.
  #
  # basic_auth only returns 401 when the password is wrong, so a 401 on the `pos` host is a
  # failed attempt, not normal browsing.
  # The hosts come DERIVED from the SSOT (whoever has `auth`), not as literals: declaring a new
  # service with basic_auth already puts it in the jail, with no need to remember to edit here.
  # With no host having basic_auth there is no 401 to count, and an empty `authHostsRe` would
  # generate `"host":"()"`, a failregex that matches nothing. The jail would stay green in
  # `fail2ban-client status` while protecting nothing, which is the silent failure mode this
  # module's header warns about. Better not to exist than to exist lying.
  environment.etc."fail2ban/filter.d/caddy-pos.conf" = lib.mkIf (authHosts != [ ]) {
    text = ''
      # Caddy basic_auth failures (hosts: ${lib.concatStringsSep ", " authHosts}), read from
      # the JSON access log in journald. It depends on the ORDER of the log's keys, so
      # validate with `fail2ban-regex` after a Caddy bump.
      [Definition]
      failregex = "remote_ip":"<HOST>",.+?"host":"(${authHostsRe})",.+?"status":401,
      journalmatch = _SYSTEMD_UNIT=caddy.service
    '';
  };

  # `optionalAttrs` and not `mkIf` on `settings`: the fail2ban module injects `enabled = true`
  # into every DECLARED jail, so emptying the settings still emitted `[caddy-pos]` in
  # jail.local, a jail with no filter pointing at a file this module had just stopped creating.
  # The service would come up complaining. The jail has to stop EXISTING, not stop having
  # content.
  services.fail2ban.jails = lib.optionalAttrs (authHosts != [ ]) {
    caddy-pos.settings = {
      enabled = true;
      filter = "caddy-pos";
      backend = "systemd"; # Caddy logs to journald, not to a file
      port = "http,https";
      maxretry = 5;
      findtime = "10m";
      bantime = "1h";
      # NO `ignoreip` of its own: fail2ban's [DEFAULT] (../net/network.nix) already exempts the
      # same list, and both came out identical in the generated jail.local once they started
      # reading the SSOT. A jail with no ignoreip INHERITS the default, which is the behavior
      # we want, and it is one fewer copy to diverge.
    };
  };
}
