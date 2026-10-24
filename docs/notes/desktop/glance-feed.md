# glance-feed: the network cache behind the glance surfaces

`modules/home/desktop/glance-feed/`. One user timer fetches every network source the desktop shows
at a glance (the bar's weather, the glance band's weather page and INMET alerts, the CI pages, the
lock screen's weather) into ONE SQLite file, `~/.cache/glance/glance.db`, and the surfaces only
READ it. Built on 08/10/2026, when the owner asked for the panel to stop "spending internet" and to
stop arriving empty after every boot.

## What it cost before, measured

| Source | Per fetch | How often | Per day, PC on |
| --- | --- | --- | --- |
| CI (GitHub REST) | ~2.3 MB (repo list 478 KB, ~300 KB per repo) | every 1 to 3 min | up to ~1 GB |
| INMET (alerts + forecast) | ~1 MB (the alerts carry every polygon, the forecast base64 icons) | every 30 min | ~50 MB |
| Open-Meteo (bar) | 2.4 KB | every 15 min | ~0.2 MB |
| Open-Meteo (lock screen) | 0.5 KB | every 10 min | ~0.1 MB |

Everything lived in Quickshell's memory, so every boot and every shell restart started from
nothing, and the CI page waited ~12 s for its first answer. Nothing asked "did it change?" before
downloading: the forecast only changes when the model runs (ECMWF IFS: every 6 hours), yet it was
fetched 96 times a day.

## How it decides to download

The timer fires every minute, and each source keeps its own clock in the `state` table, so almost
every run touches no network at all.

- **Weather (Open-Meteo):** every 30 minutes it reads the model's `meta.json` (658 bytes), and
  downloads the forecast only when `last_run_availability_time` is new (or the document is over
  12 hours old). The forecast now carries `past_hours=3&forecast_hours=48` and the hourly feels
  like, humidity and wind, so "now" is derived from the run instead of being re-asked.
- **INMET forecast:** every 4 hours (the forecasters update a few times a day), 244 KB of which
  the icons are dropped before storing (821 bytes kept).
- **INMET alerts:** every 30 minutes the RSS (196 KB) is read only to hash its set of alert ids;
  the 775 KB list is downloaded only when that set changes, or every 6 hours, and only São
  Carlos' alerts (by IBGE code) are kept.
- **CI (GitHub and the FAI GitLab):** every 2 minutes, 1 while something runs or waits. Every
  request carries the `ETag` from the last answer, so an unchanged repo list, run list or pipeline
  is a `304` with no body; what never changes once it exists (a commit's title by its SHA, the jobs
  of a finished run) is fetched ONCE and served from `http_cache` forever after. The document holds
  no per-run timestamp of its own, so it changes only when a run does. Measured on 08/10/2026: a
  cold run downloaded 88 KB (the old `gh api` path moved ~2.3 MB per poll), and a warm one made 5
  requests, all `304`, 0 bytes.
- **Network (the house, LAN only):** every 2 minutes ONE ssh round to the router reads the DHCP
  leases, the IPv4 neighbour table, the conntrack count and `wg-status` (a fixed `wg show` that
  sudoers allows without a password, so its human output is parsed); `logread` is never used, it
  hangs unprivileged. Names, and what counts as KNOWN, come from the router's mirror in the repo
  (static DHCP hosts, WireGuard descriptions). A `devices` table keeps every MAC ever seen, so a
  device is "new" for its first 24 hours; the first run is the baseline and marks nothing new.
  The attacks on the exposed ports (failed SSH logins, fail2ban bans, last 24 hours) come from this
  machine's journal. No byte of it crosses the internet.
- **Threats (the router's log, local file):** every minute it reads `/var/log/router/router.log`
  (router-log.nix) from the byte where the last run stopped, finishing the rotated `.1` first after
  a rotation and leaving a half-written line for the next run; the position moves in the same
  transaction as the facts, so no line is counted twice. Each DNS query adds to `dns_daily`; each
  block is checked, by every suffix of the name, against the HaGeZi TIF and DoH lists the router
  itself uses (their URLs read from adblock-fast's mirror, refreshed every 12 hours with an ETag,
  ~1.7 MB the first time), so a THREAT block or a DoH bypass becomes a `threat_events` row and an ad
  is only counted. banIP's drops land there too, `ip-out` (a LAN device reaching a listed address,
  the compromised-device signal) apart from `ip-in` (the internet's scanners). Clients are named
  through `addresses`, which the network source fills from the router's IPv4 AND IPv6 neighbour
  tables (most phones ask DNS over IPv6). Kept 30 days, like the raw log.
- **Pushes to the phone** (`notify`, ntfy), at most one a day per device and threat (`alerts`):
  a threat domain asked or a banIP-listed address reached FROM the house (priority high), and a
  MAC never seen before (default). A DoH attempt and the internet's scans are not pushed, they are
  routine. Once a day after 08:00, a low-priority summary of the last 24 hours: DNS volume and
  blocks, threat contacts, DoH attempts, scans dropped, new devices, failed SSH logins and bans.
  An alert names the device and the threat, never a query history. Proven on 08/10/2026 by asking
  a TIF domain from this machine: blocked, stored and pushed within the minute.
- **Claude usage (the FAI account's `/usage`):** every minute, `GET /api/oauth/usage` on
  api.anthropic.com with the account's OAuth token from `~/.claude-fai/.credentials.json` (the
  path comes from `my.claude.configDirs`, claude-code.nix). These are the numbers Claude Code's
  `/usage` shows, per SUBSCRIPTION, which `ccusage` cannot give (docs/notes/apps/claude-code.md).
  The endpoint is internal and undocumented, so every field is read as optional. The token goes
  to curl through a header file in the run's private temp dir, never through argv, and never
  into `http_cache`. A `claude_usage` table keeps one row per change (8 days); the document
  carries the last 7 days plus the row before them, only as the value the week opens with.
  - **Token renewal.** The token lives about 8 hours and only a RUNNING Claude Code renews it, so
    without a session the source renews it itself, with the same endpoint and client id as Claude
    Code 2.1.296 (`platform.claude.com/v1/oauth/token`). The refresh token ROTATES: renewing
    under a live session would leave that session holding a dead one, and it would log out at its
    own next renewal. So the renewal is skipped while any `.claude-wrapped`/`claude` process of
    yours carries this account's `CLAUDE_CONFIG_DIR`. The variable alone proves nothing, because
    every login shell exports it. Otherwise it renews 5 minutes before expiry
    (`GLANCE_CLAUDE_REFRESH_MARGIN`), or once after a 401. It holds a `flock` on
    `.credentials.json.glance.lock`, re-reads the file (whoever renewed in the meantime wins),
    changes only `accessToken`, `refreshToken` and `expiresAt`, and swaps the file atomically,
    still 0600. Checked on 18/10/2026 with a forced margin under an open session: skipped, file
    byte-identical.
- **Conditional GET everywhere a server allows it:** `http_cache` keeps each URL's `ETag` and body,
  so an unchanged resource answers `304` with no body. GitHub documents that a `304` to an
  authorized conditional request does not count against the rate limit.
- **A failure keeps the last document**, writes the reason to `feed.error`, and retries that source
  in 5 minutes instead of waiting for its full cycle.

- **Disk (local, no network at all):** every 10 minutes, `df` of `/` and of the games disk, the
  heaviest `my.disk.watchPaths` and their growth from disk-insight's weekly `trend.tsv` (the same
  `disk-growth.awk` as `disk-report` and `disk-watch`), and the number of btrbk snapshots. It never
  runs `du`, so the sizes are as old as the last Sunday snapshot, and the page says so.

## How the UI learns something is new

`feed.updated_at` moves, and the file `~/.cache/glance/stamps/<name>` is rewritten, ONLY when a
source's document actually changed (it is compared with what is stored). The surfaces watch their
stamp and then run `glance-feed read <name>`; with nothing new, nothing is re-read or redrawn. At
startup they read the database first, so the panel paints the last known state at once and the
network only refreshes it (stale-while-revalidate).

## Why SQLite, and why a timer outside Quickshell

SQLite was the owner's choice, and it fits: one file with WAL for a writer (the timer) and several
readers (the shell, the lock screen), the HTTP validators next to the documents, and a `traffic`
table that records the bytes and the `304`s per source per day, which is the proof the cache works.
The fetching lives in a systemd user timer and not in QML so that it survives a shell restart, the
bar and the lock screen share ONE weather fetch instead of two, and every decision is in
`journalctl --user -u glance-feed`.

## Who reads it

- **The bar** (`Bar.qml`, through `Feed.qml`): the `weather` document, deriving "now" from its hours.
- **The glance band**: the same weather, plus `inmet_forecast` and `inmet_alerts` (`Inmet.qml`).
- **The lock screen** (`lockscreen.nix`): its 10-minute label job reads the current hour's sky and
  temperature from the same `weather` document (`my.glance.feed`, a read-only option, is how a
  module reaches the package). It used to call Open-Meteo on its own every 10 minutes; now the
  bar and the lock show the same run, and the lock costs no network at all.
- **The glance band, Claude:** `claude_usage` (`dash/ClaudeUsage.qml`), as a page of the rotation
  and a line in the clock card (docs/notes/desktop/dash.md).
- **The glance band, disk:** `disk` (`dash/DiskPage.qml`), a page of the rotation.
