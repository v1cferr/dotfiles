# INGRESS: the SSOT of who gets a subdomain and how far it reaches. Caddy is generated FROM here.
# The default is `lan`, so forgetting to declare `expose` CLOSES instead of exposing.
{ lib, ... }:

{
  options.my.ingress = lib.mkOption {
    default = { };
    description = "Services with a subdomain of their own under `my.net.domain`. It generates Caddy's vhosts (and, in the future, the tunnel's ingress).";
    type = lib.types.attrsOf (
      lib.types.submodule {
        options = {
          upstream = lib.mkOption {
            type = lib.types.port;
            description = "The port on 127.0.0.1 that serves everything not matching a `routes` entry.";
          };

          # A CLOSED default: forgetting to declare it cannot mean "open to the internet".
          expose = lib.mkOption {
            type = lib.types.enum [
              "lan"
              "public"
            ];
            default = "lan";
            description = "The reach: `lan` (home plus WireGuard) or `public` (the internet). A closed default, so omitting it NEVER exposes anything.";
          };

          # user -> the env var holding the bcrypt hash (from sops, rule 12). It applies only
          # to whoever comes from OUTSIDE.
          auth = lib.mkOption {
            type = lib.types.attrsOf lib.types.str;
            default = { };
            example = {
              v1cferr = "CADDY_POS_HASH_V1CFERR";
            };
            description = "The basic_auth required from whoever comes from outside: user -> the .env variable holding the bcrypt hash.";
          };

          # A path prefix -> a port, evaluated BEFORE the `upstream` (most specific first).
          routes = lib.mkOption {
            type = lib.types.attrsOf lib.types.port;
            default = { };
            example = {
              "/api/*" = 8006;
            };
            description = "Per-prefix routes that go to a different port from the `upstream`.";
          };

          proxyConfig = lib.mkOption {
            type = lib.types.lines;
            default = "";
            example = "flush_interval -1";
            description = "Extra directives INSIDE the upstream's `reverse_proxy` (SSE with no buffering, say).";
          };

          comment = lib.mkOption {
            type = lib.types.str;
            default = "";
            description = "Why this service exists and why this reach; it goes as a comment into the generated Caddyfile.";
          };
        };
      }
    );
  };
}
