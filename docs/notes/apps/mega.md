# MEGA from the command line

`home/net/mega.nix`. `megatools` (`megadl`) plus the `mega-dl` wrapper, which is megadl with a
PATIENT loop, resuming on its own until the file finishes, quota crossings included.

## Why megatools, after looking at the three alternatives

| Alternative | Why not |
| --- | --- |
| rclone | the `mega` backend talks to an ACCOUNT, not to a public link (rclone#7088 still open). A `/file/<id>#<key>` link is not a remote path, it is a URL with the key in the fragment, and rclone has nowhere to fit that |
| MEGAcmd (official) | a huge closure for a one-off download, and its `proxy` is HTTP(S) only, since SOCKS5 is issue #204, open since 2019 |
| megabasterd | a Java GUI whose central feature is slicing the file across a LIST of proxies to get around the per-IP quota, which is not what this module does |

megatools is **139 KiB** of closure, maintained (1.11.5, jul/2025, and the MEGA protocol changes so
upstream keeping up matters), and it brings `--proxy socks5h://` NATIVELY: its own man page uses
`socks5h://localhost:9050` (Tor) as the example. A native proxy beats torsocks' `LD_PRELOAD`.

## The quota is the real limit, and no transport changes it

An anonymous download gets ~5 GB per IP in a SLIDING window of ~6 h, counted per IP and not per
account, so logging out does not reset it. A 17 GB file therefore does not come down in one go on a
single IP, it comes in ~4 windows.

That is why the loop WAITS for the window to turn instead of switching IPs: slicing the file across
different IPs is precisely what the quota exists to prevent.

Anyone in a hurry solves it with a Pro account (`megadl -u/--username` plus the password through
sops, rule 12), which is one extra line and the honest way to go fast.

The wait is 30 min per attempt and not 6 h idle, because the window is SLIDING: it does not turn
over all at once, it frees up bit by bit, so knocking on the door every 30 min downloads more.

## Resuming is what makes the loop worth it

megadl keeps the partial in `.megatmp.<id>` at the destination, and resuming is the DEFAULT
(`--disable-resume` is what turns it off). The partial is keyed by the FILE ID, NOT by the
transport, so you can start over Tor, stop, and continue directly or through another proxy from
where it stopped. Tested on this machine.

## The transport is the caller's choice, and the default is DIRECT

- `--tor` only makes sense for a small file where anonymity matters. A single circuit of 3
  volunteer hops gave 709 KiB/s here, so 17 GiB over that is ~7 h of donated bandwidth, and the Tor
  project itself discourages bulk (the network is sized for low latency, not throughput). On top of
  that MEGA blocks part of the exit nodes.
- `--proxy URL` takes any SINGLE proxy, a VPN's `socks5h://` for instance. **socks5h and not
  socks5**: the `h` makes the proxy resolve the DNS, since with plain socks5 the query goes out in
  the clear, and the `SafeSocks` in `system/net/tor.nix` would refuse the connection anyway.

The Tor circuit probe is NOT a safety net: megadl with `--proxy` does not fall back to a direct
connection. It is there to know WHERE it goes out (the exit IP) and to fail with the right cause
when the daemon is down, instead of with a curl error from megatools.

## Two shell traps recorded here

- **`case` and NEVER `| grep -q`.** With `writeShellApplication`'s pipefail, grep exits on the
  first match, `tail` dies of SIGPIPE, and the pipeline returns an error DESPITE the match. Same
  trap as the Sunshine healthcheck and the Dropbox watcher. The matched text comes from megatools:
  `Server returned %ld (over quota)`.
- **`|| true` and not `|| echo 0`** in `progress()`: with no partial at all, `du -c` ALREADY prints
  "0 total" and still exits with an error, so the fallback came out added to it, printing "0"
  twice on the line.
