# network and remote access

Modules: [`system/net/network.nix`](../../system/net/network.nix),
[`system/net/fai-gateway.nix`](../../system/net/fai-gateway.nix),
[`system/net/localsend.nix`](../../system/net/localsend.nix)

NetworkManager, the exposed SSH, fail2ban, dynamic DNS and "never suspend". The theme: this is a
machine for remote access.

## Trust is by SOURCE, not by interface

The WireGuard server is the ROUTER (OpenWrt), not this machine, so there is NO local `wg0` to put
in `trustedInterfaces`. The peers' traffic arrives over the LAN with source `10.10.10.x`, and that
is what the rule matches.

This REPLACED the `trustedInterfaces = [ "tailscale0" ]` that died with Tailscale (08/08/2026),
and it is what keeps Sunshine reachable THROUGH THE TUNNEL, since Sunshine runs with
`openFirewall = false` on purpose. Whoever deletes this has to open its ports.

It is no longer the only path: direct access from UFSCar, with no VPN, has its own rules in
[`sunshine.md`](sunshine.md). The two coexist deliberately. This one covers the phone and any new
peer; that one covers the FAI notebook, where adding a third VPN client would be a routing
conflict. Deleting either does not take the other down.

**`-I nixos-fw 1` and not `-A`, with a correction attached** (08/08/2026): this used to claim that
"the chain ends in a refuse, so `-A` is never reached", which is FALSE for `extraCommands`. Read
in the GENERATED `firewall-start`, it is injected BEFORE the
`-A nixos-fw -j nixos-fw-log-refuse`, so `-A` would work. The sentence only holds for a rule typed
BY HAND into a firewall that is already up. `-I 1` is still right for another reason: it is what
reproduces the `trustedInterfaces` semantics, since the whole range passes before ANY other
decision in the chain. (The backend here is iptables; `networking.nftables.enable = false`.)

## Wake-on-LAN was armed on the wrong end

Found on 10/08/2026, and the symptom was invisible. The router had ALL the pieces to wake this PC
(the `/usr/bin/wake-desktop` script, its NOPASSWD rule, and the target MAC `7c:10:c9:a1:f4:e5`,
which matches this `enp7s0`) and nothing happened, because the RECEIVER was disarmed. Measured:
`Wake-on: d`, with `Supports Wake-on: pumbg`, so the `g` for magic packet exists on the card.
Three correct pieces pointing at a fourth that does not listen. It raises no error anywhere, it
just does not wake.

**Declarative and not `ethtool -s enp7s0 wol g`**: the r8169 RESETS WoL on every boot, so the
imperative form is lost on the next reboot, which is exactly when it is needed. The option becomes
`linkConfig.WakeOnLan`, applied by udev on every link up.

**It does not cover a power outage**, and that is the misunderstanding to avoid: a real cut takes
away the +5VSB and the NIC loses the armed register. For "the power went out" the answer is the
BIOS (*Restore on AC Power Loss* = Power On), which this repo does not reach. WoL serves a NORMAL
shutdown, which is the common case.

NetworkManager has its own `connection.wol`; its default is not to touch it, but if it ever resets
on a link change the symptom is WoL working right after boot and stopping later, which only shows
up by actually powering off and sending the packet.

A contrast worth keeping: [`wake-workstation`](../../home/net/fai-workstation.nix) solves the SAME
problem and could NOT be declared, because there the receiver is somebody else's Ubuntu and the fix
is netplan by hand. Here the receiver is this machine.

## Dynamic DNS: one anchor, one wildcard

The DDNS keeps `ssh.<domain>` pointing at the current public IP, so `ssh …@ssh.<domain>` works
from anywhere with no VPN. The token stays out of git through sops. `proxied=false` means a
DNS-only record, because SSH does not go through Cloudflare's HTTP proxy.

**That record is the whole zone's IP anchor, and the only one the DDNS touches.** The services do
NOT each get a record: the zone uses a `*.<domain>` WILDCARD CNAME pointing here, so a new
subdomain works with no DNS work at all.

**Do NOT add `*.<domain>` to the DDNS.** Tested on 07/08/2026: the tool only knows how to create
and update an A record, and the API refuses with code 81054 (`A CNAME record with that host
already exists`). The service enters a restart loop and exits 3. The wildcard has to stay a CNAME.

**Do NOT trust `dig` from inside the house to audit this zone.** The router does split-DNS of
`*.<domain>` to 192.168.1.10 and answers BEFORE any external server, including when you point dig
straight at the authoritative one (`dig @bruce.ns.cloudflare.com`). The symptom is a TTL of 0 on
an answer that should come from Cloudflare. It cost an entire investigation on 07/08/2026: the
zone was RIGHT and looked broken. To see the real DNS, go out through DoH, which the router does
not intercept:

```sh
curl -s -H 'accept: application/dns-json' \
  'https://cloudflare-dns.com/dns-query?name=ssh.<domain>&type=A' | jq
```

The cache (`/var/lib/cloudflare-dyndns/ip.cache`) compares the current IP against what IT wrote
last, never against the real record, so a change made through the dashboard leaves it blind
("Every domain is up-to-date", without calling the API). Deleting it forces a real write.

The public IP does answer from outside: the router has it directly on `pppoe-wan` and forwards
80/443/2222. Proven on 08/08/2026 through Cloudflare's edge. There was a CGNAT scare on 07/08 that
proved FALSE; the diagnosis and the three ways that test can lie are in the august history.

## `network.target` is not connectivity

The nixpkgs module orders the DDNS only by `network.target`
(`services/networking/cloudflare-dyndns.nix:79`), and that target does NOT mean "there is
internet", it means "the network stack was started". What means connectivity is
`network-online.target`, and it requires BOTH ends: the `wants` (otherwise the target is not even
pulled in) and the `after` (otherwise there is no ordering).

Measured on the 01/08 boot: the service came up at T+3s and network-online was only ready at
T+9.8s, because NetworkManager-wait-online spends 6.5s waiting for DHCP. The result, EVERY boot:
the four "what is my IP" APIs came back unreachable, it DELETED the cache and exited with status
2. The 5 min timer fixed it afterwards, so this never showed up as broken, only as a `failed` at
boot that we learned to ignore. The real cost was `ssh.v1cferr.dev` pointing at the old IP at the
WORST possible moment: right after a power outage, which is precisely when the public IP tends to
change and when you want to get in from outside.

There was a SECOND cause that died with Tailscale (08/08/2026): `/etc/resolv.conf` pointed at
`100.100.100.100`, served by tailscaled itself, which came up 11ms AFTER this service, so the APIs
failed on resolution, not on routing. That required an `after = tailscaled.service` that now has
no target.

**The retry stays, and it is not residue**: the first cause (DHCP taking ~6.5s after the target) is
independent of Tailscale. Tolerating the race and trying again is more robust than guessing the
ordering, and the `Restart` keeps the stale-IP window at <=20s against the timer's <=5min. The
StartLimit is the brake so it does not become an infinite loop when the failure is real (an invalid
token, Cloudflare down): 6 attempts in 5min and it gives up, leaving the `failed` visible.

## fail2ban

Port 2222 is open to the world (a port forward on the OpenWrt) WITH passwords enabled, so fail2ban
is mandatory. It mirrors the Arch jail: ban after 4 failures in 10min, for 1h, never banning the
LAN or loopback.

## The FAI gateway: the counterpart is not declarable

`fai-gateway.nix` lets the home LAN reach FAI through `ppp0`. The request was "put the VPN on the
router", and that DOES NOT FIT: measured on 12/08/2026, the Cudy WR3000 has 1.3 MB free in
`/overlay` (of 6.1 MB, 78% used) and no python3, while nxBender is Python plus requests plus
pyroute2 plus configargparse plus colorlog, 15-25 MB on OpenWrt. Short by an order of magnitude.

So the tunnel stays here and this machine becomes the gateway. **MASQUERADE is mandatory, not an
optimization**: FAI has no route back to `192.168.1.0/24`, so with the NAT everything leaves as
ppp0's address, which is the only one FAI knows how to answer.

**FORWARD needs an explicit ACCEPT** because Docker sets the policy to DROP whenever it manages
iptables, and this host has docker0 plus two bridges. The `nat` module does not cover that: it only
hangs the `nixos-filter-forward` chain, which exists for port forwards.

**The anti-loop rule**, diagnosed on 13/08/2026, and the symptom did not look like this at all.
With the VPN OFF the router still sends FAI's ranges to 192.168.1.10 (its static route is fixed and
knows nothing about the tunnel); with no ppp0 this machine has no specific route, so it sends the
packet back out the default, back to the router, which sends it back here. A LOOP until the TTL
dies, and the user sees "The connection has timed out" after 15s with no hint that the cause is the
VPN being down.

`! -o ppp0` and not `-i enp7s0 -o enp7s0`: the condition that matters is "traffic for FAI that is
NOT entering the tunnel", regardless of where it was going to leave, and it names no NIC, so it
survives a card swap. REJECT and not DROP, on purpose: the ICMP net-unreachable makes the client
fail RIGHT AWAY with "no route to host" instead of hanging. There is no making the site work
without the VPN (measured: neither .236 nor .229 accepts a connection from outside), so the best
possible is failing fast and legibly.

The static routes and the split DNS live in the router's UCI, and
[`router.nix`](../../system/net/router.nix) refuses to push on purpose. The commands are in
[`../guides/fai-gateway-router.md`](../guides/fai-gateway-router.md).

## LocalSend is opened to the LAN only

`openFirewall = false` against the module's default, and the reason is NOT the internet: the router
forwards 80/443/2222 and the Moonlight ports, and 53317 is on none of those lists.

What would reach it is the VPN. `openFirewall` opens the port on EVERY interface, and with the FAI
tunnel up the whole corporate network would start seeing the service and reading `/info` (device
name, model, fingerprint) with no authentication at all.

The port is repeated in the rule because the module does not expose it as an option (it is an
internal `firewallPort = 53317`). If you change the port INSIDE the app, this rule stops matching
and RECEIVING DIES IN SILENCE: no build error, no log, just "the phone cannot find me".

## The router half that Nix does not reach

`scripts/router-moonlight-forward.sh` opens the Moonlight ports on the OpenWrt, restricted to
UFSCar's blocks. It RUNS ON THE ROUTER, not here, in TWO steps:

```sh
ssh v1cferr@192.168.1.1 'cat > /tmp/ml.sh' < scripts/router-moonlight-forward.sh
ssh -t v1cferr@192.168.1.1 'sudo sh /tmp/ml.sh; rm -f /tmp/ml.sh'
```

The other half (the HOST's firewall) is declarative, in `system/services/sunshine.nix`, and **the
two source lists HAVE to match**, otherwise the router forwards and the host drops.

**Why two steps** and not the obvious `ssh … 'sudo sh -s' < script`: with the script coming in
through STDIN, sudo has no way to ask for the password, since stdin is already the script and not
the terminal, and it fails without even asking. Copying first and running afterwards frees stdin for
the prompt, which is also why the second command carries `-t` to force a pty.

**And why it needs a password**: this router's sudoers gives NOPASSWD only to `/sbin/uci`,
`/usr/sbin/nft`, `/sbin/reboot` and `/etc/init.d/dnsmasq`, measured on 10/08/2026 with `sudo -l`.
The `/etc/init.d/firewall reload` at the end is NOT on that list. It is also why `root@` does not
work: dropbear has `RootLogin='off'` and `RootPasswordAuth='off'`.

`/tmp` on OpenWrt is tmpfs, so copying there does not spend the ~1.4 MB of free flash.

### ONE REDIRECT PER SOURCE, and it is not style

In fw4 a `redirect`'s `src_ip` **cannot be a list**. In a `rule` it can, which is where the wrong
version came from. Measured on 10/08/2026, and the failure mode is the worst possible:

```text
Section @redirect[3] (Moonlight-HTTPS) option 'src_ip' must not be a list
Section @redirect[3] (Moonlight-HTTPS) skipped due to invalid options
```

`uci commit` ACCEPTS it, `uci show` DISPLAYS the redirect nicely, and fw4 DISCARDS it when
generating the ruleset. The config is present, the effect is none.

**So the verification reads the EFFECTIVE nftables ruleset, never `uci show`.** That was exactly
the first version's mistake: `uci show` reads the CONFIG, and the config was there. The script
printed "OK, the change is permanent" with ZERO rules live. The expected count is 4 port groups
times 2 sources, and without that number the script does not know whether it worked.

Both source blocks are UFSCar's (registro.br, CNPJ 45.358.058/0001-40); the label goes into the
redirect's name only to stay readable in LuCI. **Do NOT swap it for `0.0.0.0/0`**: the house is NOT
behind CGNAT (measured 10/08/2026, port 2222 answers from Austria, Canada and Iran), so that would
mean the planet.

The ports were checked against the Sunshine build in use (2026.516.143833), not copied from a blog:
the UDP 48002 ("mic") that almost every list includes does NOT exist in this version, and 47990 (the
web UI) stays OUT on purpose. See [`sunshine.md`](sunshine.md).

### Two safety details

**The watchdog uses `nohup … &` and not a `( … ) &` subshell.** The watchdog exists precisely for
the case where the change drops your SSH, and that is exactly when the subshell would take the
SIGHUP along and die, so the safety net would disappear in the accident it was supposed to cover. It
restores `/etc/config/firewall` if this shell dies halfway, if the final verification fails, or if
the change locks you out.

**The cleanup iterates back to front.** Deleting by index reindexes what comes after, so iterating
forward skips an entry on every removal, which is the classic UCI mistake. It counts SECTIONS
(`…@redirect[N]=redirect`) and not lines, because each redirect yields ~8 lines in `uci show` and
counting lines gives an inflated ceiling. That would not break, since a nonexistent index returns
empty, but it would loop dozens of times for nothing.

The whole script is IDEMPOTENT: it deletes any previous `Moonlight-*` redirect before creating, so
running it twice does not stack duplicates.

## owfetch: why a script and not fastfetch

`scripts/owfetch.sh`. This router's `/overlay` has ~1.4 MB free out of 6.1 MB. fastfetch weighs
1-2 MB and neofetch would drag bash along on top of that, so either one fills the flash, and a
router with full flash cannot even write its config. This uses only BusyBox: zero installation cost.

Pure ash, no bashisms: no arrays, no `[[ ]]`, no `${var^^}`. The field ORDER mirrors
`home/shell/fastfetch.nix` so the two read alike.

**A REAL ESC, and not the literal `\033` sequence**: the colors are passed as an ARGUMENT (`%s`) and
not inside printf's format string. A format with a variable inside is shellcheck's SC2059, and its
reason for existing is real, since a value containing `%` would become a formatting directive. Since
`%s` does not interpret escapes, the `\033` has to arrive already expanded.

It is also the only `.sh` in this repo that runs on SOMEONE ELSE'S machine, which is why the
shellcheck hook covers `./scripts` explicitly; see [`flake.md`](flake.md).
