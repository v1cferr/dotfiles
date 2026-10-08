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
- **Conditional GET everywhere a server allows it:** `http_cache` keeps each URL's `ETag` and body,
  so an unchanged resource answers `304` with no body. GitHub documents that a `304` to an
  authorized conditional request does not count against the rate limit.
- **A failure keeps the last document**, writes the reason to `feed.error`, and retries that source
  in 5 minutes instead of waiting for its full cycle.

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
