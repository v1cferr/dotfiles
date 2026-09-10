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

## The collector, and why the window is a year wide

`credit-radar collect --quiet`, daily at 09:30. Up to here the historical series only grew when
somebody fired an HTTP request by hand, which for a project whose entire asset is the history is
the failure it exists to avoid, only quieter.

**A command and not a `curl`.** A scheduled job whose interface is a URL breaks the first time a
route is renamed, and this one has to keep working unattended for years. It is also the only
version that can be tested without standing up the API.

**The window is sized per indicator, not fixed.** Each run re-reads roughly thirteen months of a
monthly series and about a month of a daily one, taken from the frequency the app's own catalog
already records. The reason is that the point of collecting daily is not the newest point, which
would still be there tomorrow: it is the REVISION of a period already on record. IPCA is revised
after publication, so a narrow window would only ever confirm what the last run saw. Re-reading
costs one request and stores nothing when the value has not changed, because an unchanged
observation hits a unique constraint that spans the value itself.

**`--quiet` so silence means "nothing moved".** Seven "same as yesterday" lines a day is a
journal nobody reads, which is how a real failure goes unnoticed for a week. On a day with no
change the unit writes nothing at all.

**`Persistent = true`, for the reason that matters most here.** This desktop spends nights and
travel days off. A missed run has to happen late rather than vanish, because a hole in the series
is the one thing this project cannot repair after the fact: the VALUE of a Banco Central series
can be re-read at any time, but what was published on which day cannot, and the credit bureaus
coming later publish no history at all. What is not collected on the day is gone.

**Once a day, at 09:30.** The daily series move at most once per business day and the monthly ones
once a month, so more frequent runs would be load on Banco Central for nothing. The half hour is
because SGS publishes with a lag; asking before the business day has produced anything spends a
request to learn nothing.

### One failure is data, every failure is an incident

The command exits zero when a single indicator fails, and non-zero only when they all do.

That split is deliberate. A flaky upstream series is already recorded as a failed collection run
and shows up in the dashboard as a stale source, so it needs no second alarm; a unit that goes
red because Banco Central had a bad minute trains you to ignore red units, which is the same
lesson `ConditionPathExists` above is protecting. Every indicator failing at once is a different
claim: it points at the network or the configuration rather than at one series, and that is worth
a red unit.
