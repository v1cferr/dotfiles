# FAI VPN gateway: the half that lives on the router

The manual counterpart of
[`system/net/fai-gateway.nix`](../../system/net/fai-gateway.nix). That file makes the PC
forward and masquerade; **this one makes somebody send traffic to it.** Without both sides,
nothing happens.

```text
phone/notebook → router → 192.168.1.10 → ppp0 → FAI
    (this guide)           (the .nix)
```

## Why it is manual

Two independent reasons, and neither of them is laziness:

1. **`system/net/router.nix` refuses to push UCI on purpose**: "one wrong network or
   firewall line locks you out and the way back is failsafe mode with PHYSICAL access".
   Applying over SSH with no commit-confirm is exactly what that decision avoids.
2. **The router's sudoers does not include `/etc/init.d/network`.** The NOPASSWD entries are
   only `reboot`, `nft`, `uci`, `dnsmasq`, `firewall` and `wg-status`. You can *write* the
   route with no password and you cannot *apply* it, which would leave
   `/etc/config/network` diverging from what runs, and `router-sync diff` would report drift
   that is not even live.

In other words: the `uci set` is free, the `reload` asks for your password. Run it yourself.

## Before starting

The PC side has to be active (`sudo nixos-rebuild switch --flake .`) and the VPN up
(`vpn connect fai`), otherwise there is nothing to test.

## Part 1: static routes

**The list of ranges belongs to FAI, not to us.** It comes down the tunnel on every
connection and it can change. Do not trust the list below blindly, pull the current one from
the tunnel itself:

```sh
ip route show dev ppp0 | grep via | awk '{print $1}'
```

**THIS PART IS ALREADY DONE** (verified 12/08/2026). The six routes exist as NAMED
sections `fai_r1` through `fai_r6`, see
[`router/uci/network.conf`](../../router/uci/network.conf). They predate this guide and sat
there for years with no effect, because they pointed at a `192.168.1.10` that did not
forward: **the missing half was the PC's**, not this one.

Because they are named and not anonymous, `uci show network | grep '@route'` **does not
show them**: that grep returns empty and it looks like there is no route at all. Look for
`=route` instead:

```sh
sudo uci show network | grep -E '=route|fai_r'
```

If they ever need recreating (a reflash without "keep settings"), this is the pattern, named
and with a `netmask` instead of CIDR, the way the device already has them:

```sh
i=1
for net in 192.168.90.0 192.168.100.0 192.168.110.0 192.168.130.0 192.168.223.0; do
  sudo uci set network.fai_r$i=route
  sudo uci set network.fai_r$i.interface='lan'
  sudo uci set network.fai_r$i.target="$net"
  sudo uci set network.fai_r$i.netmask='255.255.255.0'
  sudo uci set network.fai_r$i.gateway='192.168.1.10'
  i=$((i+1))
done
sudo uci set network.fai_r6=route
sudo uci set network.fai_r6.interface='lan'
sudo uci set network.fai_r6.target='200.136.209.128'
sudo uci set network.fai_r6.netmask='255.255.255.128'
sudo uci set network.fai_r6.gateway='192.168.1.10'
sudo uci commit network
sudo /etc/init.d/network reload   # <- asks for the password
```

## Part 2: split-DNS for the FAI zones

**APPLIED on 13/08/2026**: the three `add_list` entries below are already on the device
and verified. `fai2008.ufscar.br` resolves through the router returning
`192.168.130.2/.3`, and the home DNS plus internet stayed intact across the restart. They
stay here for reflash and rollback.

**ONLY THE AD ZONE NEEDS IT.** Measured on 12/08/2026, comparing the public answer
(1.1.1.1) with the FAI DC's (200.136.209.252):

| zone | public | FAI | split-DNS? |
| --- | --- | --- | --- |
| `fai2008.ufscar.br` | **nothing** | `.252`, `192.168.130.2/.3` | **yes** |
| `sup.fai.ufscar.br` | `200.136.209.236` | the same | no |
| `fai.ufscar.br` | `200.136.209.236` | the same | no |

That is why `dashboard.sup.fai.ufscar.br` worked with none of this: the zone is public, only
the route was missing. The split-DNS below serves the names that **only exist inside**: a
domain host, a share, an internal service. If a new name does not resolve, test before
touching anything here:

```sh
nslookup <name> 200.136.209.252    # does it resolve? then it is an internal zone, add it below
```

The DCs `200.136.209.252` and `.247` answer on port 53 through the tunnel (tested
12/08/2026).

**The trap is `rebind_protection`, which is set to `1`.** The FAI DNS returns
`192.168.130.2` for `fai2008.ufscar.br`, an RFC1918 address, and dnsmasq **discards private
answers coming from outside** as anti-rebind protection. Without allowing the zone, the
split-DNS looks configured and simply does not resolve, with no error anywhere.

```sh
sudo uci add_list dhcp.@dnsmasq[0].server='/fai2008.ufscar.br/200.136.209.252'
sudo uci add_list dhcp.@dnsmasq[0].server='/fai2008.ufscar.br/200.136.209.247'
sudo uci add_list dhcp.@dnsmasq[0].rebind_domain='fai2008.ufscar.br'
sudo uci commit dhcp
sudo /etc/init.d/dnsmasq restart   # NOPASSWD; it drops the home DNS for ~2s
```

The `noresolv='1'` does not get in the way: a `server=/zone/ip` entry is matched by the more
specific domain and takes precedence over the default forwarding to DoH.

**`https-dns-proxy` owns the `server` list.** Its init script uses `uci_add_list_if_new`
(additive, it does not delete), but it has a
`_dnsmasq_create_server_backup` / `_dnsmasq_restore_server_backup` pair: on *stop* it
restores the backup, and if the backup was taken **before** your entry, yours disappears.
The symptom: FAI names stop resolving after touching DoH or rebooting. Check with:

```sh
sudo uci show dhcp | grep fai2008
```

If this becomes recurrent, just re-run the `add_list` commands, since they are idempotent
through `uci_add_list_if_new`.

**Measured 29/08/2026: the backup currently HAS them.** The `doh_backup_server` in
[`router/uci/dhcp.conf`](../../router/uci/dhcp.conf) lists the four FAI and VPN entries,
because the service re-created the backup after they already existed (a side effect of the
dnsmasq restart in [`per-client-dns-block.md`](per-client-dns-block.md)). So the failure
mode above is disarmed right now, and it re-arms itself the day a new `server` entry is
added without the service taking a fresh backup afterwards.

**Do NOT use `serversfile` as a plan B.** That slot belongs to **adblock-fast**, which
points it at its own `/var/run/adblock-fast/dnsmasq.servers` and removes it when it stops
(seen happening in the `router-sync pull` of 12/08/2026). Overwriting it would take down ad
blocking for the whole house, and it would overwrite you back on the next reload.

## Verification

From **another** device on the network (not from the PC, which reaches it through the tunnel
anyway):

```sh
ip route get 200.136.209.229      # should go out through 192.168.1.10
nslookup fai2008.ufscar.br        # should return 192.168.130.2/.3
nc -vz 200.136.209.229 22         # should open
```

If the route is right and SSH does not open, check on the PC whether the VPN dropped: with
`ppp0` gone, traffic dies here and **fails silently**, with no message at all to the device.

## Rollback

```sh
# routes: remove them back to front (the indexes shift)
sudo uci show network | grep '@route' | tail -1     # check the index first
sudo uci delete network.@route[-1]                   # repeat 6x
sudo uci commit network && sudo /etc/init.d/network reload

# dns
sudo uci del_list dhcp.@dnsmasq[0].server='/fai2008.ufscar.br/200.136.209.252'
sudo uci del_list dhcp.@dnsmasq[0].server='/fai2008.ufscar.br/200.136.209.247'
sudo uci del_list dhcp.@dnsmasq[0].rebind_domain='fai2008.ufscar.br'
sudo uci commit dhcp && sudo /etc/init.d/dnsmasq restart
```

## After applying

```sh
router-sync pull && git -C ~/Projects/GitHub/v1cferr/dotfiles diff router/
```

Without the `pull`, the mirror in `router/uci/` becomes a copy of something that used to be
true, which is exactly what `router-sync diff` exists to prevent.
