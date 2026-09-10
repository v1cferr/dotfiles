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
