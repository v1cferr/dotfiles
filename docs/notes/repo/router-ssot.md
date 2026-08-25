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

**That path was retired the same day**, which did not make these checks pointless, it INVERTED
three of them. The repo now declares zero Moonlight sources, so the contract reads "the router must
forward nothing", and a redirect that comes back through LuCI without the repo is a finding instead
of a surprise.

## The nine checks

| Check | What it compares | Why the drift is silent |
| --- | --- | --- |
| subnet | the router's `lan.ipaddr` and `wg0.addresses` against `my.net.lanSubnet` / `vpnSubnet` | a range that moved keeps working for everything that already knows the old one |
| moonlight (sources) | the `Moonlight-*` `src_ip` against `moonlightSources`, as SET EQUALITY | since the direct path was retired the repo declares NONE, so a redirect that reappears on the device is a port silently open to UFSCar |
| moonlight (ports) | the redirect ports against the offsets DERIVED from `basePort`, EMPTY while no source is declared | a translated port lets the client negotiate and then find nothing |
| moonlight (dest) | every `dest_ip` against this host's address | one DHCP change would point the rules at whoever took the address |
| fai | the `fai_r*` static routes against `faiSubnets`, and their gateway against the host | a route to an undeclared range sends traffic to a host that will not answer for it |
| ssh | that some redirect still sends `services.openssh.ports` to the host | the port is one number in two configs, and only the OUTSIDE notices |
| dns | every answer the router gives from its own tables, `address=` override AND `config domain` record, against the hosts this repo declares, inside the LAN or inside the TUNNEL | a name pointing at a machine that is not there breaks only by name |
| peer | every `ssh.nix` host at a tunnel address against the `allowed_ips` of the wg0 peers | the name resolves and nothing answers, which reads as "the machine is off" |
| dnat | every redirect's `dest_ip` against `vpnSubnet`, and the answer is always no | a port published for a machine that is off site, in somebody else's house, with no gate in front of it |

## What the t480 taught it (22/08/2026)

My mother's ThinkPad became a WireGuard peer and got a name in the router's DNS, and the checker
saw NEITHER of the two values that arrived with it. Not a bug in the comparison, a gap in what was
being read, which is the same failure shape as the parser bug below:

**dnsmasq answers a local name through two different mechanisms**, and the checker only knew the
first. `dhcp.@dnsmasq[0].address` is a SUFFIX override (`/v1cferr.dev/192.168.1.10`, the split-DNS
of the zone); `config domain` is a static A record for one name, expanded into `t480.lan` by
`domain=lan` plus `expandhosts=1`. LuCI writes the second one from the Hostnames tab, which is the
natural place to add a machine, so the mechanism the checker ignored is the one a human reaches for.

**And the range was hard-wired to the LAN.** `t480` answers 10.10.10.6, which is inside
`vpnSubnet`, so even reading the section would have skipped it. Both ranges are legitimate now, and
the option that owns each one already existed.

**The eighth check is the other half of the same value.** A DNS answer with no peer behind it
is worse than a wrong answer: the name resolves, the packet routes, and nothing replies, which from
the client is indistinguishable from the machine being off. It runs in ONE direction on purpose,
declared-host implies peer, because `celular`, `pc-trampo` and `fai-workstation` are peers with no
`ssh.nix` entry and always will be. It would have caught the `notebook` peer's removal on
19/08/2026 if that peer had ever had a host declared here.

**And the ninth is a rule from ANOTHER repo, checked here.** The T480 carries its own repo, and
its stated invariant is that no port of that host is exposed: SSH, Sunshine and RDP accept the
tunnel and the home LAN only. That rule is about a machine, and the only place it can be VERIFIED is
the router's mirror, so it lives here. It reads as a policy check rather than a mirror comparison,
which is why the expected set is a constant: nothing is ever forwarded into `vpnSubnet`.

**Writing it uncovered a hole in the checks that already existed.** `moonlight()` read only the
ANONYMOUS `@redirect[N]` sections, and a redirect typed by hand is born NAMED: `firewall.ssh_cesar`
is one, and it is the only redirect in this mirror that a human added. So a `Moonlight-HTTPS` coming
back as `firewall.ml_https` would have passed every Moonlight check in silence, which is precisely
the drift the retirement of the direct path made those checks exist for. Both forms are read now,
and the mutation below is the proof.

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

**And the `ssh.nix` addresses need one anchor each, as they stop being `HostName` literals.**
Two have left already: the T480's went into `my.t480` (a second consumer, the RDP wrapper), and the
brother's became the `cesarHost` binding on 25/08/2026, when his DUAL BOOT made three blocks share
one address. The second one was found BY THIS HOOK, in the commit that moved it: the dns check
reported `/cesar-ssh.v1cferr.dev/192.168.1.40 answers 192.168.1.40, which no host in this repo
declares`, which is precisely the loud failure the paragraph above promises.

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
- **Four more on 22/08/2026**, for the two checks added that day, and each fired exactly one
  finding: a `config domain` record moved to an undeclared tunnel address, a second one invented
  inside the LAN (which proves the new mechanism is read in BOTH ranges), the t480 peer's
  `allowed_ips` moved off .6, and the repo side of the same value, `ssh.nix` pointing at a .7 nobody
  serves. That last one fires TWO findings, one per check, which is the pair working: the address is
  unknown to the mirror and unserved by the router at the same time.
- **Two more the same day, for the ninth check and for the hole it uncovered**: a named
  `Sunshine-t480` redirect pointing at 10.10.10.6 fires `dnat`, and a `Moonlight-HTTPS` written as a
  NAMED section fires the two Moonlight checks that could not see it before.

The host address is the most expensive value to get wrong: changing it fires **9 findings across 4
checks**, which is exactly the blast radius its 19 occurrences in the mirror predict.
