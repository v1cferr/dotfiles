# CLOUDFLARE TUNNEL: outbound-only cloudflared, its ingress GENERATED from `expose = "tunnel"`.
# Why locally managed, why no Caddy, and the Cloudflare-side state: docs/notes/network/tunnel.md
{ config, lib, ... }:

let
  id = config.my.net.tunnel.id;
  secret = "cloudflared_tunnel_credentials";

  entries = lib.filterAttrs (_: s: s.expose == "tunnel") config.my.ingress;

  # The same auto-gate as Caddy: inert until the id is set AND sync-secrets has brought the file.
  enabled =
    config.my.services.tunnel
    && id != null
    && builtins.hasAttr secret config.sops.secrets
    && entries != { };
in
{
  options.my.net.tunnel.id = lib.mkOption {
    type = lib.types.nullOr lib.types.str;
    default = null;
    description = "The tunnel's UUID. Not a secret (it is the CNAME target), and null keeps the module inert.";
  };

  config = lib.mkIf enabled {
    services.cloudflared = {
      enable = true;
      tunnels.${id} = {
        credentialsFile = config.sops.secrets.${secret}.path; # LoadCredential, so root-only is fine
        # One hostname, one loopback port, nothing else: an unmapped name gets a 404.
        ingress = lib.mapAttrs' (
          name: s:
          lib.nameValuePair "${name}.${config.my.net.domain}" "http://127.0.0.1:${toString s.upstream}"
        ) entries;
        default = "http_status:404";
      };
    };
  };
}
