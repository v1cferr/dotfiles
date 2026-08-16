# CADDY: the reverse proxy for *.<domain>, one wildcard cert through DNS-01.
# The auto-gate, client_ip vs remote_ip and the port map: docs/notes/network/caddy.md
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

  # AUTO-GATE: all four together, because one missing makes Caddy refuse the WHOLE config.
  # The hash list is DERIVED from the SSOT, never fixed: a stale one would take the proxy down.
  authVars = lib.unique (lib.concatMap (s: lib.attrValues s.auth) (lib.attrValues config.my.ingress));
  requiredSecrets = [
    "caddy_acme_email"
    "caddy_cloudflare_dns_token"
  ]
  ++ map lib.toLower authVars;
  enabled = lib.all (s: builtins.hasAttr s config.sops.secrets) requiredSecrets;

  # Generated from the ingress SSOT: forgetting to declare CLOSES instead of exposing.
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

  # Concatenation, because `$${v}` is a Nix SYNTAX ERROR, not an escape. It bit once.
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

  # Derived from the SSOT: a new service with `auth` enters the jail with no hand-edited regex.
  authHosts = lib.attrNames (lib.filterAttrs (_: s: s.auth != { }) svcs);
  authHostsRe = lib.concatStringsSep "|" (map (n: "${n}\\.${domainRe}") authHosts);
in
lib.mkIf (enabled && config.my.services.caddy) {
  services.caddy = {
    enable = true;

    # The `hash` is the Go vendor's: recompute with lib.fakeHash when the version changes.
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
      # JSON to journald, which is where the jail reads. Without `format json` nothing matches.
      logFormat = "format json";

      extraConfig = ''
                tls {
                  dns cloudflare {$CADDY_CLOUDFLARE_DNS_TOKEN}
                  resolvers 1.1.1.1 1.0.0.1
                  propagation_delay 30s
                  propagation_timeout -1
                }

                # "Home" = LAN plus the router's WireGuard plus loopback, defined once for the site block.
                # `client_ip` and NOT remote_ip: with a tunnel, remote_ip would make everything look local.
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

  # services.caddy has no openFirewall, so this is the repo's only allowedTCPPorts.
  # 80 stays open for the redirect and for a possible HTTP-01 one day.
  networking.firewall.allowedTCPPorts = [
    80
    443
  ];

  # The .env: config as text, secrets as placeholders. SINGLE QUOTES because bcrypt has `$`.
  # One line per `auth` in the SSOT, so a removed basic_auth cannot leave an orphan secret.
  sops.templates."caddy.env".content = ''
    CADDY_ACME_EMAIL=${config.sops.placeholder.caddy_acme_email}
    CADDY_CLOUDFLARE_DNS_TOKEN=${config.sops.placeholder.caddy_cloudflare_dns_token}
  ''
  + lib.concatMapStrings (v: "${v}='${config.sops.placeholder.${lib.toLower v}}'\n") authVars;

  # The jail lives HERE because it only exists because of this proxy: deleting the vhost has
  # to delete the jail. With no gated host there is NO jail: an empty regex would lie green.
  environment.etc."fail2ban/filter.d/caddy-pos.conf" = lib.mkIf (authHosts != [ ]) {
    text = ''
      # It depends on the ORDER of the log's keys, so revalidate with fail2ban-regex on a bump.
      [Definition]
      failregex = "remote_ip":"<HOST>",.+?"host":"(${authHostsRe})",.+?"status":401,
      journalmatch = _SYSTEMD_UNIT=caddy.service
    '';
  };

  # optionalAttrs and not mkIf: the module injects `enabled = true` into every DECLARED jail.
  services.fail2ban.jails = lib.optionalAttrs (authHosts != [ ]) {
    caddy-pos.settings = {
      enabled = true;
      filter = "caddy-pos";
      backend = "systemd"; # Caddy logs to journald, not to a file
      port = "http,https";
      maxretry = 5;
      findtime = "10m";
      bantime = "1h";
      # No `ignoreip` of its own: the jail INHERITS fail2ban's [DEFAULT], one fewer copy to diverge.
    };
  };
}
