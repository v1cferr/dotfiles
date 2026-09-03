# Blocking a domain for ONE machine on the router

My brother asked, on 29/08/2026, to have Reddit blocked on his PC. The router is the only place
that covers both halves of his dual boot at once, so the block lives there and not in a
`/etc/hosts` on each system.

The mechanism is generic. Reddit is only the first tenant: any zone can be added to the same
instance, and any MAC can be added to the same chain.

**It is NOT installed right now.** He asked to be unblocked on 03/09/2026 and the whole thing came
down with it: the nft file, the second dnsmasq instance and the two pins. The page stays because
the recipe is what turns putting it back into a five minute job, and because the measurements in it
were expensive to get. The teardown, which has an order that matters, is at the end.

```text
his PC :53 ─ nft priority -110 ─→ dnsmasq `blocked` :5453 ─ NXDOMAIN for reddit
                                          └─ everything else → dnsmasq `main` :53
everyone else :53 ────────────────────────────────────────→ dnsmasq `main` :53
```

## Why the three obvious paths do not work

1. **dnsmasq has no per-client views.** There is no "answer this client differently" in it, the way
   Unbound or AdGuard Home have. A second instance is the only shape it offers.
2. **The `nftset` route needs a package that does not fit.** Measured 29/08/2026:
   `dnsmasq --version` prints `no-ipset no-nftset`, so "let DNS fill a set and block the IPs for
   one client" would need `dnsmasq-full`, and `/overlay` has **1.2 MB free of 6.1 MB**.
3. **A UCI `redirect` never matches.** `adblock-fast` and `https-dns-proxy` inject their force-DNS
   rules at the **TOP** of `dstnat_lan` through ubus, and `redirect to :53` is terminal for that
   packet, so anything created through UCI lands after them and its counter stays at zero. This is
   the fact that decides the whole design.

And blocking Reddit's addresses is not an option either: `reddit.com` answers `151.101.x.x`, which
is Fastly, shared with thousands of unrelated sites.

## The two pieces

**A second dnsmasq instance, `blocked`, on port 5453.** It is a thin forwarder: `server=127.0.0.1#53`
sends everything to `main`, so it inherits the ad blocklist, the `.lan` names and the local
overrides (`v1cferr.dev` → `192.168.1.10`) instead of duplicating them and drifting. On top of that,
one `server=/zone/` per blocked zone, which is dnsmasq's NXDOMAIN idiom and the same one the canary
domains in [`router/uci/dhcp.conf`](../../router/uci/dhcp.conf) already use.

**One nft chain at priority -110**, which is `dstnat - 10`, so it is evaluated before fw4's own
`dstnat` and therefore before the force-DNS rules described above.

**It matches the MAC, not the IP, and that is not a precaution.** Measured from his Windows session
on 29/08/2026, `nslookup` answers `Server: OpenWrt / Address: fd6f:8793:5988::1`: **his DNS leaves
over IPv6**, the router's ULA, because the house serves RA and DHCPv6. A rule written against
`192.168.1.40` would have matched nothing and the block would have looked installed while blocking
nobody. The MAC also covers both sides of the dual boot, and survives a lease renegotiation.

## The two traps found on the way

**The second instance was going to become a second DHCP server.** `filter_dnsmasq`, in the router's
`/etc/init.d/dnsmasq`, says it in four lines: a `config dhcp` section with no `instance` option is
used by **every** instance. So `dhcp.lan` needed an explicit owner, and giving it one required the
primary instance to have a stable name. Hence `uci rename dhcp.@dnsmasq[0]='main'`. Positional
addressing keeps working after the rename, so the `dhcp.@dnsmasq[0]` commands in
[`fai-gateway-router.md`](fai-gateway-router.md) are unaffected.

**`serversfile` is staged, and "it never commits" turned out to be false.** `adblock-fast` writes
`dhcp.main.serversfile=/var/run/adblock-fast/dnsmasq.servers` as a UCI change, and on 29/08/2026 it
sat there staged and uncommitted, which is why the recipe below reverts it before committing and
re-sets it after: persisting another service's runtime state is not this repo's business.

Then the service went and committed it itself. Read on 03/09/2026, `option serversfile` is line 47
of `/etc/config/dhcp`. The consequence this page feared did not happen either: the router rebooted
on 30/08/2026 with that line in place and dnsmasq came up normally, so a `servers-file` that does
not exist yet is a log line, not a fatal error. Keep the revert anyway, and do not go out of your
way to undo what the service decided to persist.

## Redoing it from scratch

The `uci` half needs no password (the NOPASSWD list is `reboot`, `nft`, `uci`, `dnsmasq`,
`firewall`, `wg-status`):

```sh
# The primary instance gets a name, and the DHCP pool gets an owner.
sudo uci rename dhcp.@dnsmasq[0]='main'
sudo uci set dhcp.lan.instance='main'

# The blocking resolver: thin forwarder plus one server=/zone/ per blocked zone.
sudo uci set dhcp.blocked=dnsmasq
sudo uci set dhcp.blocked.port='5453'
sudo uci set dhcp.blocked.localservice='1'
sudo uci set dhcp.blocked.noresolv='1'
sudo uci set dhcp.blocked.cachesize='0'
sudo uci set dhcp.blocked.domainneeded='0'   # let `main` decide, this one only forwards
sudo uci set dhcp.blocked.boguspriv='0'      # same reason: no second opinion on private answers
sudo uci set dhcp.blocked.rebind_protection='0'  # `main` answers 192.168.1.10 for v1cferr.dev
sudo uci add_list dhcp.blocked.server='127.0.0.1#53'
sudo uci add_list dhcp.blocked.server='/reddit.com/'
sudo uci add_list dhcp.blocked.server='/redd.it/'
sudo uci add_list dhcp.blocked.server='/redditstatic.com/'
sudo uci add_list dhcp.blocked.server='/redditmedia.com/'

# The blocklist and the DoH rewrite stay pinned to `main`: `*` would load the whole list into
# the second instance too (+22 MB of RAM) and would rewrite its `server` list on every restart.
sudo uci set adblock-fast.config.dnsmasq_instance='main'
sudo uci set https-dns-proxy.config.dnsmasq_config_update='main'

# The trap above: drop what belongs to adblock-fast, commit, put it back UNCOMMITTED.
sudo uci revert dhcp.@dnsmasq[0].serversfile
sudo uci commit dhcp && sudo uci commit adblock-fast && sudo uci commit https-dns-proxy
sudo uci set dhcp.main.serversfile='/var/run/adblock-fast/dnsmasq.servers'
sudo /etc/init.d/dnsmasq restart
```

The firewall half is a file, and `cp`/`chmod` are **not** in the NOPASSWD list, so this part asks
for your password. `/etc/nftables.d/` survives `sysupgrade` on its own (it is listed in
`/lib/upgrade/keep.d/firewall4`), so it needs no entry in `/etc/sysupgrade.conf`. It survives a
plain reboot too, proven on 30/08/2026: the router came back up and the chain was there, rebuilt
from the file with its counter at zero.

```sh
cat > /tmp/20-dns-block-reddit.nft <<'NFT'
chain dns_block_reddit {
    type nat hook prerouting priority -110; policy accept;
    iifname "br-lan" ether saddr 74:56:3c:f2:b6:48 meta l4proto { tcp, udp } th dport 53 counter redirect to :5453 comment "cesar PC"
}
NFT
# Syntax check the way fw4 sees it: the file is included INSIDE table inet fw4.
{ echo "table inet fw4check {"; cat /tmp/20-dns-block-reddit.nft; echo "}"; } > /tmp/check.nft
sudo nft -c -f /tmp/check.nft && echo "SYNTAX OK"

# `cp` and `chmod`, because BusyBox here has no install(1). Measured 29/08/2026:
# `sudo: install: command not found`.
sudo cp /tmp/20-dns-block-reddit.nft /etc/nftables.d/
sudo chmod 644 /etc/nftables.d/20-dns-block-reddit.nft
sudo /etc/init.d/firewall restart
```

**`sudo uci commit` leaves the file it touched as `0600`** (the trap recorded in
[`router/README.md`](../../router/README.md)). Measured again here on 29/08/2026: `adblock-fast` and
`https-dns-proxy` came out root-only while `dhcp`, committed in the same breath, stayed `0644`. It
does NOT break `router-sync`, which reads with `sudo uci show`, proven by the `pull` of the same day
going through both files. Repair it anyway, so a hand-typed `uci show` keeps working:

```sh
sudo chmod 644 /etc/config/adblock-fast /etc/config/https-dns-proxy
```

## How to verify

From any machine in the house, the two ports answer differently:

```sh
dig +short reddit.com @192.168.1.1            # the house: 151.101.x.x
dig reddit.com @192.168.1.1 -p 5453 | grep -i status   # the blocked instance: NXDOMAIN
dig +short v1cferr.dev @192.168.1.1 -p 5453   # 192.168.1.10, the local override survives
```

To test the redirect itself without waiting on him, add a second rule to the chain with your own
MAC, query, and delete it by handle:

```sh
sudo nft -a list chain inet fw4 dns_block_reddit
sudo nft delete rule inet fw4 dns_block_reddit handle <n>
```

That test is what proved the priority is right: with the rule in, `dig reddit.com @8.8.8.8` also
came back NXDOMAIN, which only happens if this chain runs before the force-DNS redirect that sends
every port 53 packet to the main instance.

The counter is the live evidence that the machine is still behind it:

```sh
sudo nft list chain inet fw4 dns_block_reddit
```

And the end of the chain, from his machine, which is the only test that proves all of it at once:

```sh
ssh cesar-cmd 'nslookup reddit.com; echo ----; nslookup github.com'   # Windows side
ssh cesar-linux 'dig reddit.com; dig github.com'                      # Arch side
```

Pick the alias that matches the side he booted. They verify different host keys on purpose, so the
wrong one fails with a host key warning instead of connecting: that warning is the answer to "which
system is up", not a reason to edit `known_hosts`.

## What it does not stop

DoH in the browser (Chrome's Secure DNS, Firefox's TRR), any VPN, the phone's hotspot, and DoT on
853, which nothing hijacks today. This is a speed bump, not a wall, and that is the right size for
what was asked: **the request came from him**. Turning it into a wall means blocking 853 and the
known DoH addresses for that MAC, and it stops being self-control the moment he has to fight it.

## Taking it down

**The order matters, and getting it backwards costs that machine its DNS entirely** instead of just
Reddit. The nft rule points at a port and the instance IS that port, so the rule goes first. Between
the two steps he is already unblocked, which is the point: the first command needs no password and
takes effect immediately.

```sh
sudo nft delete chain inet fw4 dns_block_reddit   # instant, NOPASSWD, unblocks right away
sudo rm /etc/nftables.d/20-dns-block-reddit.nft   # asks for the password, and THIS is the one
sudo /etc/init.d/firewall restart                 # that decides what comes back after a reboot

sudo uci delete dhcp.blocked
sudo uci set adblock-fast.config.dnsmasq_instance='*'
sudo uci set https-dns-proxy.config.dnsmasq_config_update='*'
sudo uci commit dhcp && sudo uci commit adblock-fast && sudo uci commit https-dns-proxy
sudo /etc/init.d/dnsmasq restart
```

Then `router-sync pull` and commit, because none of that is declarative.

Two things stay behind on purpose. The `main` name, because undoing the rename means deleting and
recreating the section that serves the whole house its DNS and its DHCP, which is real risk for
zero gain. And `dhcp.lan.instance='main'`, because an explicit owner for the pool is precisely the
guard against the first trap above, on the day a second instance shows up again.

A leftover to ignore: `/var/etc/dnsmasq.conf.blocked` stays in `/var` until the next reboot. It is
tmpfs and nothing reads it, the same way `dnsmasq.conf.cfg01411c` lingered after the rename.
