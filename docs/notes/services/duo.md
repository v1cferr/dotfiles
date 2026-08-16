# duo-streak-daemon: the stack declared in Nix

`system/services/duo.nix`. The app's stack (a Playwright daemon + API + web + Postgres) through
Docker Compose, declared in Nix, brought up at boot by systemd. The solver is the host's NATIVE
Ollama (`system/services/ollama.nix`), reached on `localhost:11434` through `network_mode: host`,
exactly as the app was designed.

## Declarative end to end

- The code is the `duo-streak-daemon` flake input, a commit pinned in `flake.lock`. The compose
  builds straight from the store path: no mutable clone, no manual build.
- The secrets are a sops template rendered into `/run/secrets/rendered/duo.env`: never in plain
  text in git, never in `/nix/store`.
- The compose manifest itself is generated here (`writeText`), because the repo ships the DEV one
  and this is the DEPLOY one: contexts are store paths and the secrets arrive through `env_file`.
- A FIXED project name `-p duo`. Without it the project name would become the store path's hash
  and the volumes and containers would change on every bump.

## The auto-gate

The module only activates when the `duo_db_password` secret exists. Until it is provisioned it
stays INERT and the system keeps building normally. Same pattern as `caddy.nix`.

## Turning it on, once

1. Bitwarden, create the items. The VALUE always goes in the *password* field, because
   `sync-secrets` uses `bw get password`:

   | Item | Purpose |
   | --- | --- |
   | `Duo DB Password` | required; generate a strong one |
   | `Gemini API Key` | optional, a solver fallback |
   | `ntfy Topic` | the streak-at-risk alert, a shared topic |
   | `Duolingo` | optional, the account password (login fallback) |
   | `Duolingo Email` | the fallback's pair, in the password field |

2. Add the corresponding lines to `secrets/bitwarden-secrets.json`:

   ```json
   "duo_db_password":   "Duo DB Password",
   "gemini_api_key":    "Gemini API Key",
   "ntfy_topic":        "ntfy Topic",
   "duolingo_password": "Duolingo",
   "duolingo_username": "Duolingo Email"
   ```

3. `sync-secrets`, then `sudo nixos-rebuild switch --flake .#nixos-kingston`.

## The Duolingo session

A one-time interactive login, because the anti-bot does not like a headless one. `duo-login` opens
the browser through Xwayland, you sign in, and the session persists in the `duo_duo-data` volume.
After that the daemon keeps the streak alive on its own, once a day. To run it right away:
`duo-run-once` (it ignores the "it already ran today").

Status as of writing: the login is still REJECTED, the Duolingo password needs confirming.

## The Docker traps this module discovered

These three cost real debugging and were later inherited by `grad-radar.nix`:

1. **The socket-activation race.** `after = docker.service` is not enough: dockerd comes up
   through socket activation and BuildKit is still initializing on the first boot. Hence the
   wait-for-`docker info` loop.
2. **buildx is not discovered without a writable `DOCKER_CONFIG`.** The service's root does not
   find the plugin and `compose build` silently falls back to the LEGACY builder, which does not
   support `RUN --mount=type=cache`. That is the error that blocked everything. The fix is
   `/run/duo/cli-plugins` with the plugins symlinked in, plus
   `daemon.settings.features.buildkit = true`.
3. **It has to be `docker compose`, the PLUGIN.** Only the plugin routes to buildx/BuildKit; the
   standalone binary does not.

`TimeoutStartSec = 1800` because the first start builds three images (Playwright, Next.js).

## Two details that look like noise

- `sops.templates."duo.env".owner = "v1cferr"`: the service runs as root and reads everything, but
  `duo-login` runs as the user and needs to READ the file for its `--env-file`.
- `restartTriggers`: changing the compose OR the STRUCTURE of the `.env` makes the switch restart
  the service, and `up -d` recreates the affected containers. A change in the VALUE of a secret
  alone does NOT change the hash, so in that case you need `systemctl restart duo-stack`.
