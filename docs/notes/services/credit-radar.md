# CreditRadar: why the most sensitive service on the panel never leaves the house

`hosts/nixos-kingston/services.nix` (the `credit` entry in `my.ingress`). CreditRadar is my
personal credit intelligence system (V1C-76): it consolidates what the credit bureaus, Banco
Central and my creditors each know separately, and keeps the history so a change in the profile
can be explained afterwards.

It answers at `https://credit.<domain>` from home and over WireGuard, with the wildcard
certificate Caddy already holds. From outside it answers 403.

## Why `lan` and not `public`

The same criterion as `ai`, and for a heavier reason. Ollama is `lan` because it has no native
auth, so the IP gate is the only protection. CreditRadar is in that same position, except that
what sits behind the gate is not a model: it is a CPF, the debts under it, the scores each bureau
assigns to it and the credit exposure reported to Banco Central SCR. `public` would not be
"exposing a dashboard", it would be publishing a credit report.

The app has no login of its own, and that is a deliberate design decision on its side rather than
an omission waiting to be fixed: it is a single-user system whose documentation states that it
binds to loopback and that exposing it on a routable interface has to be a conscious change.
This entry IS that conscious change, and `lan` is what keeps it honest.

The `pos` precedent does not transfer. GradRadar is `public` because the page shows only public
application dates and no personal data, with per candidate information gated behind a login that
the app itself will grow. There is no version of CreditRadar that shows something harmless while
the rest waits for a login: the page IS the personal data.

## `auth` would not have helped, and would have rotted

The instinct is to add `basic_auth` as a second layer and set `expose = "public"`, or to keep
`lan` and add the hashes anyway. Neither works with this module.

`system/services/caddy.nix` applies BOTH the 403 and the `basic_auth` to `@externo`, the "not
home" matcher. Under `lan` the 403 answers first, so the hashes would never be consulted: dead
config by rule 16, plus two Bitwarden items and two sops secrets that exist to do nothing. Under
`public`, `basic_auth` becomes the only thing between the internet and a credit report, which is
a single shared password protecting the most sensitive data on this machine.

Layering the two would mean changing the module so `auth` applies to every request and not only
to the outsider. That is a real option the day I want the dashboard reachable from a phone on
mobile data, and it belongs in the module rather than in this entry. Until then, `lan` is both
the stronger control and the one that needs no secret, which is why this service could be turned
on without touching Bitwarden at all.

## Why the `/health` route exists next to `/api/*`

The backend serves its whole surface under `/api/v1`, the interactive docs and the OpenAPI
schema included, precisely so that one proxy route covers all of it. `/health` is the single
exception, kept at the root because that is where an operator looks for it and where the
container healthcheck already points. Two routes, both explicit; the frontend keeps the domain
root.

The order does not matter here: Caddy resolves the most specific prefix first, so `/api/*` and
`/health` cannot shadow each other or the upstream.

## The stack at boot

`system/services/credit-radar.nix`. A `oneshot` with `RemainAfterExit` runs
`compose up -d --wait` at boot, the same shape as `grad-radar.nix` and for the same reason: Caddy
comes up on its own and so does Docker, but the containers do not, so without this the subdomain
answers 502 until somebody runs compose by hand. `--wait` blocks on the healthchecks, so a green
unit means the proxy actually has an upstream rather than a promise of one.

The three Docker traps are inherited unchanged from `duo.nix`, and each cost a debugging session
somewhere in this tree already: `after = docker.service` loses to socket activation, so the unit
waits on `docker info` in a loop; root does not discover buildx without a writable
`DOCKER_CONFIG` with the plugins linked in, and the build silently falls back to the legacy
builder; and `TimeoutStartSec` has to be generous because the first start builds two images with
a `pnpm install` and a full `next build` inside the frontend one.

### Two places where this differs from grad-radar, on purpose

**It serves a production build, not `next dev`.** GradRadar runs the dev server and its note
calls that out as a conscious compromise for three people checking a deadline. CreditRadar
already has a multi-stage image that produces Next.js standalone output, so there is no reason to
pay the dev server's memory and first-hit latency here.

**The compose keeps `restart: unless-stopped`.** GradRadar's dev compose declares `restart: "no"`
so that containers cannot resurrect as orphans after a daemon restart, which is the right call
for a file that a person also runs interactively with `just dev`. This compose is only ever
driven by the unit, and `ExecStop` runs `compose down`, which REMOVES the containers, so there is
nothing left for Docker to bring back. What `unless-stopped` buys instead is the thing the
oneshot cannot do: a crashed backend at 3am comes back on its own, because `RemainAfterExit`
makes systemd stop watching once the start succeeded.

### Why there is no collection timer yet

`grad-radar.nix` pairs its stack with a timer, because a monitor that depends on somebody
remembering to run it is not a monitor. The same argument applies here, and the historical series
is the whole point of the project, so this is a real gap rather than a decision.

It is deliberately not filled yet: collection today is only reachable as an HTTP endpoint, so a
timer would have to `curl` the app from outside itself, and a scheduled job whose interface is a
URL breaks the moment a route is renamed. The step is a collection command in the backend first,
then a timer that calls it, and re-ingestion is already idempotent (an unchanged value inserts
nothing) so the timer will be safe to run as often as it needs to be.
