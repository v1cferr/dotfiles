# router-log: the router's syslog, kept on this machine

`modules/nixos/network/router-log.nix`. The OpenWrt keeps its log in a 128 KB ring in RAM: it is
gone at the next power cut, and a busy DNS log would rotate it away in minutes. Since 08/10/2026
this machine receives it over the LAN and keeps 30 days in `/var/log/router/router.log`, the first
step of phase 1 of the threat monitoring plan (docs/open-items.md).

## Why it is built the way it is

- **The router only.** A log receiver open to the house is a way to forge the record it exists to
  keep. The firewall admits UDP 5514 from `my.router.address` alone (the `localsend.nix` idiom), and
  rsyslog's ruleset drops any line whose source is not that address, so a forgery needs both.
- **Not 514.** An unprivileged, unusual port, so no device on the LAN mistakes this machine for a
  general syslog sink.
- **No local rules.** `defaultConfig = ""`: this machine's own logs stay in the journal, where they
  were; rsyslog exists here only for the router's.
- **30 days, compressed, readable by wheel.** The retention the owner chose, because the DNS log
  is everyone's browsing; `wheel` so the glance band can read it without root.

## The order is the point

1. This receiver, BEFORE anything changes on the router.
2. `log_ip` on the router (`system.@system[0].log_ip`, `log_port='5514'`, `log_proto='udp'`).
3. Only then `logqueries` on dnsmasq: turned on first, the query log would only churn the 128 KB
   ring and push the router's own warnings out of it.
