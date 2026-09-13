# Router hardening: the audit of 13/09/2026 and what it changed

The router is the only piece of infrastructure with a foot on the public internet that Nix does
not reach, and it is the one that had never been audited. Everything below was **measured on the
device** that day, not read off the mirror, because the mirror had drifted in two places and a
hardening plan written against a stale copy hardens the wrong machine.

Same two reasons for being manual as
[`fai-gateway-router.md`](fai-gateway-router.md): `system/net/router.nix` refuses to push UCI
without commit-confirm, and the router's sudoers only carries `reboot`, `nft`, `uci`, `dnsmasq`,
`firewall` and `wg-status` as NOPASSWD. **That split decides who types what**: the firewall work
below runs unattended, because `uci` and `/etc/init.d/firewall` are both on the list; anything
touching dropbear, uhttpd, the network or the firmware asks for the password and has to be run by
hand.

## The state that was measured

Cudy WR3000 v1, OpenWrt 25.12.4 (kernel 6.12.87), 14 days of uptime, **1.3 MB free on the
overlay**, no USB port. WAN is PPPoE on a public v4 plus a global v6 on `pppoe-wan` and a /60
delegated to the LAN.

What the internet can reach: 80/443 and 2222 DNATed to the desktop, 2223 to the brother's PC,
51820/udp for WireGuard, and ICMP echo. The `input` policy is `drop` and `input_wan` ends in
`reject_from_wan`, **on both families**: the v6 rides `pppoe-wan`, which is inside the wan zone,
so there is no unzoned interface carrying the global prefix. That part was already right.

## The findings, in the order they were fixed

**STATUS as of 13/09/2026: all seven closed, and every one VERIFIED IN THE EFFECTIVE STATE**,
which on this device means the nft ruleset, the running process or the server's own answer, and
never `uci show`. The upgrade to 25.12.5 landed last and carried finding 3 with it, since the
reboot is what finally gave dropbear its `-s`. Finding 7 was not on the list at all: the upgrade
put adblock-fast's config in a diff and the diff had a password in it.

### 1. The firmware was one service release behind, and it mattered

25.12.5 (01/07/2026) fixes five CVEs in **odhcpd**, the DHCPv6/RA server that is enabled here
(`dhcp.lan.dhcpv6='server'`, `ra='server'`), among them CVE-2026-53921, a stack buffer overflow in
the DHCPv6 IA reply serialization reachable with a crafted REQUEST. **The WAN could not reach it
and the LAN and the tunnel could**: odhcpd listens on `:::546` and `:::547`, the wan zone only
accepts 546, and the wg zone accepted everything (finding 2). The same release fixes three request
smuggling CVEs in **uhttpd**, which listens on 80/443, fifteen in OpenSSL and Dropbear backports.

That is the shape worth remembering: the interesting attack surface of this router was never the
WAN side, it was everything that had already been let in.

### 2. Every WireGuard peer had full access to the router

`firewall.@zone[2].input` was `ACCEPT`, and `nft list chain inet fw4 accept_from_wg` confirmed it
with 56557 packets counted and not one rule filtering them. In practice the phone, the mother's
T480, `pc-trampo` and `pc-nizario` all reached the router's Dropbear, its LuCI **over plain HTTP**,
its ubus and its odhcpd. One compromised peer, or one leaked private key, and the attacker lands on
a login form that carries the root password in the clear.

This was the structural hole. The others are smaller than this one.

**The zone only governs traffic TO the router.** Moonlight to the desktop, RDP to the T480 and
general internet through the house are `forward`, untouched by this, which is why the change is
safe to make in the middle of the day.

```sh
sudo uci set firewall.@zone[2].input='REJECT'

# DNS is what the open zone was really being used for: the peers resolve through 10.10.10.1.
sudo uci set firewall.wg_dns=rule
sudo uci set firewall.wg_dns.name='WG-Allow-DNS'
sudo uci set firewall.wg_dns.src='wg'
sudo uci set firewall.wg_dns.proto='tcp udp'
sudo uci set firewall.wg_dns.dest_port='53'
sudo uci set firewall.wg_dns.target='ACCEPT'

# Ping stays, so a peer can still tell "tunnel down" from "router down".
sudo uci set firewall.wg_icmp=rule
sudo uci set firewall.wg_icmp.name='WG-Allow-Ping'
sudo uci set firewall.wg_icmp.src='wg'
sudo uci set firewall.wg_icmp.proto='icmp'
sudo uci set firewall.wg_icmp.icmp_type='echo-request'
sudo uci set firewall.wg_icmp.target='ACCEPT'

# Administration from the two peers whose private key I can account for.
sudo uci set firewall.wg_admin=rule
sudo uci set firewall.wg_admin.name='WG-Admin-Phone-And-Trampo'
sudo uci set firewall.wg_admin.src='wg'
sudo uci add_list firewall.wg_admin.src_ip='10.10.10.3'
sudo uci add_list firewall.wg_admin.src_ip='10.10.10.4'
sudo uci set firewall.wg_admin.proto='tcp'
sudo uci add_list firewall.wg_admin.dest_port='22'
sudo uci add_list firewall.wg_admin.dest_port='443'
sudo uci set firewall.wg_admin.target='ACCEPT'

sudo uci commit firewall && sudo /etc/init.d/firewall reload
```

**The named sections are deliberate**, like `ssh_cesar` before them. An anonymous `@rule[N]`
renumbers when anything above it is deleted, and these are the rules whose deletion by accident
costs remote access. Finding 5 proved it in the same session.

**`src_ip` as a LIST is legal here and illegal one section type over**, which is worth knowing
before widening the admin rule: in a `rule` fw4 accepts the list, in a `redirect` it silently
discards the whole section
([`../notes/network/network.md`](../notes/network/network.md), measured 10/08/2026). So the
verification reads `nft list chain inet fw4 input_wg` and never `uci show`, because `uci` displays
the bad version just as nicely as the good one.

`pc-trampo` (10.10.10.4) joined the phone on 13/09/2026, by decision: administering the router
from the work machine over the tunnel is worth more than the marginal narrowing. `pc-nizario` is
deliberately NOT on the list, and the desktop needs no rule at all because it reaches the router
through `input_lan`.

**Apply it from the LAN, never from the tunnel.** Getting this wrong costs the tunnel's access to
the router and nothing else, and from a LAN session the fix is one `uci` away. From the phone it
would cost the session that is applying the change.

### 3. Dropbear accepted passwords

`PasswordAuth='on'`, listening on `0.0.0.0:22`. Combined with finding 2, that is a password brute
force reachable from the tunnel. Root login was already off and the ed25519 key was already
installed for `v1cferr`, so the cost of closing it is a key that is already in use.

```sh
sudo uci set dropbear.main.PasswordAuth='off'
sudo uci commit dropbear
# DETACHED on purpose, see below.
sudo sh -c 'nohup /etc/init.d/dropbear restart >/dev/null 2>&1 &'
```

**`/etc/init.d/dropbear restart` OVER SSH DOES NOT TAKE, and it fails silently.** Measured on
13/09/2026: the commit landed, `uci show` read `PasswordAuth='off'`, and the daemon serving
connections was still **PID 1738 from boot**, fourteen days old, with flags
`-F -P ... -p 22 -g -w -K 300 -T 3` and no `-s`. The restart has to stop the listener that owns the
session issuing it, so the init script never gets past its own stop phase. **Detaching it with
`nohup` was tried and did NOT help either**: PID 1738 survived that too, which says the background
job dies with the session's process group rather than merely being hung up on.

**The config is right and only the birth is pending, and the running process is what proves it.**
The doubt worth resolving before rebooting anything is whether `'off'` validates as the boolean
zero the script tests for, since line 320 reads
`[ "${PasswordAuth}" -eq 0 ] && procd_append_param command -s`. It does, and the evidence needs no
experiment: the live process carries `-g` and `-w`, which are emitted by the identical test against
`RootPasswordAuth` and `RootLogin`, and both of those are stored as `'off'` in the same file.

So this one applied at the next boot, which the firmware upgrade provided the same evening.
**CONFIRMED after it**: the daemon came up as PID 1954 with
`-F -P ... -p 22 -s -g -w -K 300 -T 3`, and the server now answers
`Authentications that can continue: publickey` and nothing else. The deduction held, and what must
NOT happen is calling this done on the strength of `uci show`.

**So the verification cannot read `uci`, it has to read the PROCESS.** This is the same lesson as
the `src_ip` list one section above, in a different disguise: the config was correct and the effect
was zero.

```sh
ps w | grep '[d]ropbear -F'          # the running flags must contain -s
ssh -v -o PubkeyAuthentication=no router true 2>&1 | grep -i 'can continue'
```

The second line is the one that matters, because it asks the SERVER what it accepts: `publickey`
alone means it is done, `publickey,password` means it is not, whatever `uci` says.

**`Interface 'lan'` was considered and REJECTED**, and this is the part worth writing down.
Binding Dropbear to the LAN is the advice every hardening guide gives, and here it would delete the
phone's administration path, which is the only way in when nobody is home. The firewall is already
the thing deciding who reaches port 22 (finding 2), and adding a second mechanism for one decision
is two owners on one artifact, which is rule 14. **The firewall owns reachability; Dropbear owns
authentication.**

### 4. LuCI carried the root password in the clear

`redirect_https='0'`, so every login POST crossed the LAN and the tunnel unencrypted.

```sh
sudo uci set uhttpd.main.redirect_https='1'
sudo uci commit uhttpd && sudo /etc/init.d/uhttpd restart   # asks for the password
```

**Binding uhttpd to `192.168.1.1` and `10.10.10.1` was considered and REJECTED**, for a reason this
repo has already paid for once. uhttpd cannot bind an address that does not exist yet, and `wg0`
comes up after it: that is the exact trap the mother's T480 taught with
`ListenAddress 10.10.10.6` (see [`../notes/network/ssh.md`](../notes/network/ssh.md)), where a
service that fails to bind does not retry. A boot race that costs LuCI is a bad trade for a control
the firewall already performs. So the listen stays on `0.0.0.0` and the firewall decides who
arrives.

The cost of the redirect is the self-signed certificate (`commonname='OpenWrt'`), so the browser
warns on every visit. The warning is honest and the password is no longer readable, which is the
trade being made.

### 5. Two legacy holes from the WAN into the LAN

`Allow-IPSec-ESP` and `Allow-ISAKMP` forward ESP and udp/500 from any host on the internet into the
LAN. They are old OpenWrt defaults, there is no IPsec anywhere here, and `nft list chain inet fw4
forward_wan` showed **zero packets** on both since boot.

```sh
# Back to front, because deleting shifts the indexes of everything above.
sudo uci show firewall | grep -E '@rule\[(7|8)\]\.name'   # confirm the names first
sudo uci delete firewall.@rule[8]                          # Allow-ISAKMP
sudo uci delete firewall.@rule[7]                          # Allow-IPSec-ESP
sudo uci commit firewall && sudo /etc/init.d/firewall reload
```

**Deleting them RENUMBERED two named rules, and that is the argument for named sections proving
itself in the same commit.** `Allow-WireGuard` fell from `@rule[9]` to `@rule[7]` and
`WG-t480-allow-desktop` from `@rule[10]` to `@rule[8]`, because everything above a deleted
anonymous section slides down. Nothing here referenced them by index, so nothing broke. The lesson
is what it would have cost if something had: an index is not an identity, and a rule whose deletion
costs remote access must never be reachable only by one.

### 6. The exposed SSH had no rate limit, and it is the port being scanned

`SSH-CESAR-2223` has carried `limit='30/minute'` and `limit_burst='20'` since it was written, and
`SSH-PC-2222` never had any. The counters say what that means: **5411 packets on the 2222 DNAT
against 17 on the 2223**, in the same 14 days of uptime. That gap is not my brother using SSH less,
it is the internet scanning the port everybody scans.

```sh
sudo uci set firewall.@redirect[2].limit='30/minute'
sudo uci set firewall.@redirect[2].limit_burst='20'
sudo uci commit firewall && sudo /etc/init.d/firewall reload
```

**The limit applies to NEW connections only**, because a DNAT is only consulted for the first
packet and conntrack carries the rest, so an open session is never throttled by it. 30/minute is
far above anything a person does and far below what a brute force needs.

It does not replace what is on the other end: the desktop's sshd already demands a key or
password plus TOTP, refuses every user but one, and fail2ban escalates bans to a week
([`../notes/network/network.md`](../notes/network/network.md)). This just stops the noise one hop
earlier.

### 7. A system password was published, and the audit did not find it: the UPGRADE did

Not on the original list, because nothing on the router was wrong. The leak was in the tool that
mirrors it, and it only surfaced because the 25.12.5 upgrade moved adblock-fast to 1.2.4 and put
its config block in a diff somebody actually read.

`adblock-fast.config.rpcd_token` sat in the mirror in the clear, in a PUBLIC repo, since commit
`a2a7b6f` on 08/08/2026. Five weeks. `router-sync`'s `redact()` tested
`leaf not in SUSPECT`, and `in` on a set is EQUALITY, so `rpcd_token` was not `token` and walked
straight through a function whose docstring promises the opposite.

**And it is not a token.** `/usr/share/rpcd/ucode/luci.adblock-fast` says so in a comment: "Token
becomes the adblock-fast-api system password", and `rpcd.adblock_fast_api.password` holds
`$p$adblock-fast-api`, the form that authenticates against the system password. The published
string was a working credential for an account on the router.

**What it could and could not reach, measured rather than assumed.** Never the internet: the wan
zone has always rejected port 22, and 80/443 are DNATed to the desktop, so the router's own uhttpd
never answered from outside. It WAS reachable from the whole LAN and, until finding 2 landed that
same day, from every WireGuard peer. The account carries `/bin/false` and an rpcd ACL scoped to
adblock-fast, not root.

The fix is two halves and the second one is the one that matters:

```sh
# On the router, through the method that moves UCI and the system password together.
new=$(tr -dc 'A-Za-z0-9' < /dev/urandom | head -c 24)
sudo ubus call luci.adblock-fast setRpcdToken "{\"name\":\"adblock-fast\",\"token\":\"$new\"}"
```

**Rewriting git history was considered and REJECTED.** The value is in a public repo, so it has to
be assumed harvested whatever the history says, and a force push over a published tree damages
something real (every clone, every permalink) to hide something already gone. Rotation makes the
published string worthless, which is the only outcome that actually helps.

**The verification had to be built, because `result: true` proves nothing here.** The ucode calls
`system(... passwd ...)` and never checks its return, then returns true regardless. Four pieces
together are what closed it: the UCI value changed, `/etc/shadow` was rewritten at the rotation
minute, the leaked password draws `{"result":[6]}` (PERMISSION_DENIED) from
`https://192.168.1.1/ubus`, which is the path an attacker would use and needs no shell, and the
argument that ties it, that a silently failed `passwd` would have left the old password valid and
made that same login SUCCEED.

**Two verification attempts before that one were worthless, and the control is what exposed them.**
`ubus call session login` from the shell answered `Not found` for the leaked password, which read
like a denial and was not: `ubus list` cannot even see the `session` object as a non-root user, and
a deliberately nonexistent username produced the identical answer. A test whose failure mode and
success mode look the same measures nothing.

## What was found and NOT fixed the same day

**No preshared keys on the WireGuard peers.** `preshared_key` is absent from all five. It is the
standard defense against harvest-now-decrypt-later and a second factor if a private key leaks. It
is not a router-only change: every client config has to be updated in the same window or the peer
drops, and two of those clients are in other people's houses. Tracked in
[`../open-items.md`](../open-items.md).

**The dead `fai-workstation` peer.** Still declared, still never having completed a handshake, now
across 14 days of uptime. It was already open item 117 since 10/08/2026 and this audit is the
second measurement agreeing with the first. Removing it needs `/etc/init.d/network reload`, which
is not NOPASSWD.

**dnsmasq binds the public addresses.** `177.52.84.188:53` plus both global v6 addresses, tcp and
udp. `localservice='1'` makes it ignore queries from outside the local subnets and the wan zone
rejects the port, so this is covered twice already. Restricting the bind would remove the surface
instead of guarding it, at the price of the same boot race that finding 4 rejected, so it is a
deliberate no for now.

**The router keeps no log that survives a reboot.** `log_size='128'` KB in RAM and no remote
destination, so a compromise leaves no durable trace. The fix is `log_ip` pointing at the desktop
plus a syslog receiver there, which is a NixOS-side feature and not a `uci set`. Tracked in
[`../open-items.md`](../open-items.md).

## Verification

From the LAN, after the firewall reload:

```sh
sudo nft list chain inet fw4 input_wg      # REJECT at the end, three ACCEPTs above it
sudo nft list chain inet fw4 forward_wan   # no ESP, no udp/500
sudo nft list chain inet fw4 dstnat_wan    # 2222 now carries `limit rate 30/minute`
```

From the phone, over the tunnel, and this is the half that actually proves it:

```sh
nslookup openwrt.org 10.10.10.1   # must answer: DNS is the rule that breaks the house
ping 10.10.10.1                   # must answer
ssh router                        # must open, because the phone is the admin source
```

From a peer that is NOT on the admin list (the T480, `pc-nizario`), `ssh 10.10.10.1` has to be
**refused**. A peer that still gets in means `src_ip` did not match and the rule is decoration.

## Rollback

The whole firewall half is one line back, and it is worth knowing before starting:

```sh
sudo uci set firewall.@zone[2].input='ACCEPT'
sudo uci commit firewall && sudo /etc/init.d/firewall reload
```

Dropbear and LuCI, if the key ever stops working:

```sh
sudo uci set dropbear.main.PasswordAuth='on'
sudo uci commit dropbear && sudo /etc/init.d/dropbear restart
```

**If the key is gone AND the password is off**, the way back is failsafe mode with physical access.
That is why the key is tested from a second session before the restart, and why
`/home/v1cferr/` is in `/etc/sysupgrade.conf`: a reflash that loses the home directory loses
`authorized_keys` with it.

## After applying

```sh
router-sync pull && git -C ~/Projects/GitHub/v1cferr/dotfiles diff router/
```

Without the `pull` the mirror becomes a copy of something that used to be true, which is the exact
failure `router-sync diff` exists to catch.
