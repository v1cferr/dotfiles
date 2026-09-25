# tunnel

Modules: [`system/net/tunnel.nix`](../../../system/net/tunnel.nix),
[`system/net/ingress.nix`](../../../system/net/ingress.nix)

An outbound-only Cloudflare Tunnel, born for one consumer: ChatGPT on the web reaching the GENERAL
Basic Memory server through a Cloudflare MCP server portal (V1C-82). Nothing listens for it on the
router, and the fai server never gets an ingress rule, so it cannot be reached through here even
if every Access policy were wrong.

```text
ChatGPT --OAuth--> mcp.v1cferr.dev (MCP portal, Access: GitHub, only me)
                        |  tool allowlist, destructive tools hidden
                        v
                   memory.v1cferr.dev (Access app, managed OAuth, same policy)
                        |  tunnel, outbound from here
                        v
                   127.0.0.1:8765 (basic-memory-general)
```

## Why a tunnel, and not Caddy on 443

Caddy already publishes `*.v1cferr.dev` on the router's forwarded 443, so a vhost with `basic_auth`
looked like the short path. It fails twice:

- **ChatGPT only speaks OAuth** to a remote MCP server. `basic_auth` is not something it can send.
- **A proxied record does not close the origin.** The wildcard A record points at the home IP, so
  anything Caddy serves is reachable by IP with the right `Host`, skipping whatever Cloudflare puts
  in front. Basic Memory has NO auth of its own, no read-only mode and exposes every project it
  knows (see [basic-memory](../apps/basic-memory.md)), so the gate cannot be something a request
  can walk around.

With the tunnel, the only path to `127.0.0.1:8765` from outside is the Cloudflare edge, where Access
decides. That is also why `expose = "tunnel"` gets NO Caddy vhost ([caddy](caddy.md)): one would
reopen exactly the side door the tunnel exists to close.

## Why a public hostname, and not the private-network route

Since 22/09/2026 a portal can reach a PRIVATE MCP server through Gateway, with no public hostname at
all. It was rejected on 25/09/2026 for this upstream. A private route to loopback reaches EVERY port
on `127.0.0.1`, 8766 included, so keeping fai out would rest on a Gateway network policy instead of
on the topology. It also needs the Gateway proxy turned on for the whole account. The public
hostname maps ONE name to ONE port in an ingress rule that lives in git, and Access gates the name.

## Why locally managed, not a token

Cloudflare's default is a remote-managed tunnel run with a token, where the routing lives in the
dashboard. The NixOS module (`services.cloudflared.tunnels`) runs the other kind: a credentials file
plus an ingress DECLARED here, which is rule 3, and it lets the ingress be generated from
`my.ingress` like Caddy's vhosts. So the hostname-to-port map is reviewable in a diff, and the
dashboard only holds what cannot be declared (below).

The credentials JSON is single-line, so it goes through Bitwarden and `sync-secrets` like any other
secret (rule 12), as `cloudflared_tunnel_credentials`. Its index line enters WITH the first sync and
not before: `dead-config` refuses an index entry that has no value in `secrets.yaml`. The unit
reads it through `LoadCredential`, so a root-only `/run/secrets` file is fine under `DynamicUser`.
Rotating it needs a rebuild AND a restart of `cloudflared-tunnel-<id>`: the config file does not change, so the switch will not
restart it on its own.

The module is inert until THREE things exist: `my.services.tunnel`, `my.net.tunnel.id` in the host
panel, and the synced secret. The same order trap as every sops secret applies
([secrets](../repo/secrets.md)), which is why the id and the secret gate it instead of the toggle
alone.

## Creating the tunnel (once)

```sh
nix shell nixpkgs#cloudflared -c cloudflared tunnel login      # browser, writes ~/.cloudflared/cert.pem
nix shell nixpkgs#cloudflared -c cloudflared tunnel create basic-memory
# -> ~/.cloudflared/<id>.json: paste its ONE line into Bitwarden as "Cloudflare Tunnel Credentials"
# add "cloudflared_tunnel_credentials": "Cloudflare Tunnel Credentials" to secrets/bitwarden-secrets.json
sync-secrets
# then set my.net.tunnel.id = "<id>" in hosts/nixos-kingston/services.nix, build, switch
# CREATE THE ACCESS APP FOR THE HOSTNAME FIRST, and only then:
nix shell nixpkgs#cloudflared -c cloudflared tunnel route dns basic-memory memory.v1cferr.dev
rm ~/.cloudflared/<id>.json ~/.cloudflared/cert.pem              # Bitwarden is the copy now
```

**The order is the gate.** On 25/09/2026 the DNS route went in before the Access app existed, and
for about eight minutes (23:44 to 23:52 UTC) `memory.v1cferr.dev/mcp` answered `initialize` with a
200 to anyone, through the edge over IPv6. The server log for that window holds exactly two
requests, both my own probes. A tunnel with a live route and no Access app is a PUBLIC service, so
the Access app is created first, and the route is what turns it on.

The LAN does not see any of this: the router's split DNS answers `*.v1cferr.dev` with the host's
LAN address, so `memory` over IPv4 at home lands on Caddy and gets its 404, since a `tunnel` entry
has no vhost. Testing the edge from home means forcing IPv6 or another resolver.

The `cert.pem` is an account-wide credential for creating tunnels and editing DNS, which is why it
does not stay on disk.

## What lives on the Cloudflare side (NOT declarative)

None of this is in git, so this table is the record. Update it in the same commit as any change made
in the dashboard or through the API.

| Piece | Value |
| --- | --- |
| Tunnel | `basic-memory`, `3376a3fe-8193-489d-9cb2-8132ff65d74b` (created 25/09/2026) |
| DNS | `memory.v1cferr.dev` CNAME `3376a3fe-...cfargotunnel.com`, proxied, created by `tunnel route dns`; it overrides the `*` wildcard |
| Identity provider | GitHub (pending) |
| Access app (upstream) | `basic-memory (general)`, `7bbdfbfb-e8b7-4ed9-b78b-60c9a60d2cbd`, self-hosted on `memory.v1cferr.dev`. Policy `only me` by email over the one-time PIN until GitHub exists; managed OAuth pending |
| MCP server | `https://memory.v1cferr.dev/mcp` (pending) |
| MCP portal | `mcp.v1cferr.dev`, same policy (pending) |
| Tool allowlist | `default_disabled`, then only the eleven tools below |

The allowlist is inverted on purpose (`default_disabled: true`): a tool Basic Memory adds in a bump
stays hidden until it is listed here, instead of appearing in ChatGPT by default.

- **Exposed**: `recent_activity`, `search`, `search_notes`, `read_note`, `view_note`,
  `read_content`, `build_context`, `list_directory`, `list_memory_projects`, `write_note`,
  `edit_note`.
- **Hidden**: `delete_note`, `move_note`, `delete_project`, `create_memory_project`, `fetch`,
  `list_workspaces`, `basic_memory_diagnostics`, `schema_*`.

The three old tunnels on the account (`Homelab-Victor`, `ssh-tunnel`, `uptime-kuma`) are from the
Arch era, all down, and have nothing to do with this one.
