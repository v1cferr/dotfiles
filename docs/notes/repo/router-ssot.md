# router-ssot: the values the router repeats

`pkgs/router-ssot.nix`, wired into `checks` and into the pre-commit hooks. Run it by hand with
`nix run .#router-ssot`.

Rule 11 wants ONE owner per value, and the router is the single piece of infrastructure Nix does not
reach (6 MB of flash puts NixOS out of scale). So a handful of values live in BOTH places, and until
this existed the only thing keeping them equal was a sentence in
[`../network/sunshine.md`](../network/sunshine.md) admitting "there is a mirror to keep in sync by
hand".

On 19/08/2026 that sentence cost a morning. The work PC had moved to a UFSCar block the source list
does not declare, so the router matched no `src_ip`, dropped the packet BEFORE the DNAT, and left no
trace on the host: no conntrack entry, no refused packet, no connection attempt in Sunshine's log.
From the client it is indistinguishable from the host being broken.

## The seven checks

| Check | What it compares | Why the drift is silent |
| --- | --- | --- |
| subnet | the router's `lan.ipaddr` and `wg0.addresses` against `my.net.lanSubnet` / `vpnSubnet` | a range that moved keeps working for everything that already knows the old one |
| moonlight (sources) | the `Moonlight-*` `src_ip` against `moonlightSources` | the router forwards, the host drops, and neither side logs it |
| moonlight (ports) | the redirect ports against the offsets DERIVED from `basePort` | a translated port lets the client negotiate and then find nothing |
| moonlight (dest) | every `dest_ip` against this host's address | one DHCP change points eight rules at whoever took the address |
| fai | the `fai_r*` static routes against `faiSubnets`, and their gateway against the host | a route to an undeclared range sends traffic to a host that will not answer for it |
| ssh | that some redirect still sends `services.openssh.ports` to the host | the port is one number in two configs, and only the OUTSIDE notices |
| dns | every split-DNS answer inside the LAN against the hosts this repo declares | a name pointing at a machine that is not there breaks only by name |

## Two layers, and neither replaces the other

`router-sync diff` answers "is the mirror equal to the DEVICE?". This answers "is the mirror equal to
the REPO?". Both are needed, because a green `router-ssot` over a stale mirror proves nothing.

That is also why the mirror check reports ALONE when it fails: six findings about a truncated file
would send the next reader to the wrong place entirely.

## It reads the MIRROR, never the device

Three reasons, in this order:

1. It runs in a pre-commit hook, so it has to be fast and OFFLINE.
2. It must never be able to lock anybody out, so it opens no SSH connection at all.
3. Freshness is already somebody else's job, and duplicating it here would give two answers to the
   same question.

## It parses text, it does not evaluate Nix

The same choice `dead-config` made, for the same reason: evaluating the host would be more correct
and would cost seconds on every commit.

**The anchors are the price.** `declared()` finds each value by a regex tied to the name it has
today: `moonlightSources`, `basePort`, `faiSubnets`, `csrf_allowed_origins`, `ports = [ N ]`, the
`*Subnet` options. Rename one and the check does NOT quietly pass: an empty extraction becomes a
mismatch against a router that still has the value, and the subnet check says "could not read" in as
many words. Failing loudly on a rename is the only failure mode a checker is allowed to have.

## What the first run found, and it was a bug in the checker

Not drift. A false positive of the parser's own making: the extractor read the quoted strings of the
`moonlightSources` list literal, and the prose beside it quotes `the FAI range` inside a comment, so
the checker reported a third source block that does not exist.

The fix strips Nix comments before reading a list, ignoring a `#` that lives inside a quoted string,
because `127.0.0.1#5053` is a legitimate value elsewhere in these same files. It is worth writing
down because it is the shape of every text-based checker's failure: the weakest part is the parser,
never the comparison.

## What it deliberately does NOT do

**Push.** Applying UCI over SSH needs commit-confirm (apply, schedule a rollback, confirm only if
there is still access), and without it one wrong network line locks you out with failsafe mode and
physical access as the only way back. That decision stays open in [`../../open-items.md`](../../open-items.md).
This checker is what makes a push tool safe to write LATER, because it defines what "correct" means
before anything starts writing.

**Own the host's LAN address.** `192.168.1.10` appears ONCE in the Nix tree, as the CSRF origin, and
19 times in the mirror. One occurrence is not an SSOT yet by rule 11, so the checker treats the CSRF
origin as the anchor and measures everything else against it. The day it earns a `my.net.hostIp`,
`declared()` is the single place to move.

## Proving it can fail

A checker that only ever passes is decoration. Every check was verified in BOTH directions on
19/08/2026, with `ROUTER_SSOT_ROOT` pointed at a copy of the tree:

- **Eight mutations on the mirror side**: a swapped `src_ip`, a `dest_ip` pointing elsewhere, a port
  off the base, the LAN in another range, a FAI route outside the list, the SSH redirect on another
  port, a split-DNS answer for an undeclared host, and a truncated mirror. Each fired its own kind.
- **Six on the repo side**, which is the likelier accident: a new block in `moonlightSources`, a
  changed `basePort`, a changed host address, a range deleted from `faiSubnets`, a changed sshd port
  and a changed `lanSubnet`.

The host address is the most expensive value to get wrong: changing it fires **9 findings across 4
checks**, which is exactly the blast radius its 19 occurrences in the mirror predict.
