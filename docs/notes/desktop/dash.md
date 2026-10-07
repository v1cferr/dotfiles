# The glance band on the standing monitor

`modules/home/desktop/quickshell/dash/`. Everything that belongs to the band lives in that one
folder: the panel (`Dashboard.qml`), its pieces (`Tile.qml`, `ServiceStrip.qml`, `CiList.qml`), the CI
feed (`Ci.qml`) and, under `scripts/`, the shell behind it (`ci-status.sh`, packaged as
`ci-status-json` in `modules/home/desktop/quickshell.nix`). The shell sits in its own subfolder so
the folder reads as QML views on top and build inputs below. It is the top 30% of the standing secondary, reserved so
that no window lands in it.

The band is a part of the Quickshell tree and not a Nix module of its own on purpose: the QML has to
sit under the `mkOutOfStoreSymlink` that becomes `~/.config/quickshell`, or the `root:/` imports
and the hot reload stop working, and it reads every system number from the bar's Scope (`host`).

**Why it exists.** A 27" panel on its pivot is 597 mm tall, so its top third sits ABOVE eye level
for anyone sitting at the desk, while the ergonomic target is 0 to -30 degrees below the
horizontal. A window up there is a neck problem, not a layout preference. The split is 30/70 on
purpose: 768 px of band against 1792 px of work area, on the 2560 logical px that the 1920 px
panel becomes at `scale = 0.75`.

**How the space is taken: `exclusiveZone`, not a gap.** A workspace rule with
`gaps_out = { top = N }` reserves the same strip, and it was the first attempt, but N would then
have to be kept in sync BY HAND with the panel's height, and it only covers the workspaces it
names. A layer surface declares its own height and Hyprland tiles below it, so ONE number governs
both. That number subtracts the bar's own zone (`host.barExclusiveZone`) and the two 4 px margins,
which is what makes the bar and the band together add up to the 30%.

**What earns a place.** The top of a standing screen is for what is read in two seconds and never
clicked: the time, the month, the machine's vitals and what is playing. Everything that takes
a click stays in the 70%. The notification FEED is deliberately not there, only a bell with the
count: a feed in the eyeline is the opposite of a glance surface, so the centre opens on a click
and nowhere else.

**The vitals are tiles, not meter rows.** CPU, RAM, DISK, GPU, TEMP and NET sit in a 3x2 grid
(`dash/Tile.qml`) with a 36 px value, under an `UP · LOAD` line. The first version reused the
popovers' `MeterRow`, whose 10 to 12 px text is sized for a hover a hand away; at `scale = 0.75`
it was unreadable from the chair and left the left column half empty. GPU is power against its
own cap, because the Arc publishes no busy percentage, and NET is download against the link speed.

**No new data.** Every number is already collected in `Bar.qml` for the bar and its popovers, so
the component takes that Scope as `host` and reads it. The month is `monthCells()`, the same
function the year popover renders, at 18 px instead of 9, with the days already gone dimmed so the eye lands on what is ahead.

**The bottom strip was a CPU horizon, and it is now the services.** Until 07/10/2026 the band's
bottom edge was the CPU of the last 2 minutes as scrolling bars. Even after it learned to explain
itself, the owner found it the least useful thing on the band: the CPU tile already says the
number, and what the machine is RUNNING was nowhere. So the history moved INTO the CPU tile as a
sparkline beside its value (`Tile.series`), and the strip became the services carousel (below).
`Horizon.qml` was deleted with it (rule 16).

**The date block.** The clock shows HH:mm:ss, and BESIDE it the weekday spelled out over an ISO
line (`2026-10-07 · Outubro · W41`). It used to be three stacked lines; one row returned the height
the services strip needed. The weekday is what a person wants off a clock, and the ISO date plus the
ISO-8601 week are the precise record underneath. `isoWeek()` counts the week against the year its
THURSDAY falls in, which is what puts 01/01 on week 53 of the year before when it lands on a Friday.

**`host` is NOT a required property, and that is not sloppiness.** Quickshell's `Variants` creates
the delegate with `modelData` as the only initial property, so a SECOND required property fails the
creation with `failed to create variant with object` and the layer never appears at all.

## The CI pages: the right column rotates

The month shares its column with two CI pages, one at a time: **month, GitHub Actions, the FAI
GitLab**, every 15 s, with dots beside the title that say where the rotation is and jump on a click,
flanked by `‹ ›` arrows (`PageArrow.qml`); the mouse wheel over the column steps the pages too.
The pointer over the column HOLDS the page, because reading a row must not be a race against the
timer. The clock and the vitals never rotate: they are what the band is for.

**One feed, one schema.** `ci-status.sh` (built as `ci-status-json`, so shellcheck runs at build
time, rule 7) asks both forges and prints ONE JSON in which a run is `{repo, name, ref, state,
event, created, url}` and `state` is one of six words. The QML never learns that GitHub says
`completed/failure` and GitLab says `failed`. A source that fails reports `{ok: false, error}` and
never hides the other one. `Ci.qml` is a singleton, so it polls once whatever the number of
screens: every minute while something runs, every three otherwise, which is about 15 API calls a
poll and far from GitHub's 5000 an hour.

**What counts as "recent".** Repos pushed in the last 7 days are the candidates, and from each one
the latest run of every workflow created in that window. Dependabot's update jobs (event `dynamic`)
are dropped: they are bookkeeping, not CI.

**What a run carries.** Besides its state, every run brings the commit or PR title that triggered
it, who did, when it started and ended, the attempt, and for a failure the first failed job and
its failed step (GitLab has no steps, so it gives the stage and the failure reason). The failure
costs one extra API call, and only failures pay it; GitLab also needs one call for the pipeline and
one for the commit title, since its list endpoint carries neither. A poll takes about 12 s.

**The row and the card.** A row is the repo, the title of the run that leads it (the worst one, not
the newest), and the workflows as tinted chips. A click opens the repo's CARD in place of the list
(`CiDetail.qml`): one box per workflow with state, ref, duration (live while it runs), title,
trigger, author, age, the attempt when it is a re-run, and in red `job › step` when it broke. A
click on a box opens that run in the browser, and `‹` goes back. While a card is open the rotation
stops, and the card closes itself 20 s after the pointer leaves, so the column never stays parked.

**One row per repo.** The first version had a row per workflow, and `dotfiles` filled five rows
saying one thing. A row now wears the WORST state of its workflows (failure, running, queued,
cancelled, skipped, success, in that order), lists each workflow tinted by its own state so the
broken one is found without a click, and a click opens the run that is wrong, not the newest one.
Only a running glyph breathes, so motion itself means "still going".

**GitHub** is `gh`'s own login, the same token git already uses, so there is no second credential.
It covers every repo the account can see, including the ones where it is a collaborator.

**The FAI forge is GitLab, and it is only reachable on the VPN.** The FAI repos on GitHub run no
Actions; the pipelines live on `git.sup.fai.ufscar.br`, the GitLab CE on the FAI workstation
(which replaced Forgejo on 05/10/2026), behind its Caddy. The API answers this machine directly
over the VPN, so the script talks to it over HTTPS and never through `ssh workstation`. It reads
a `read_api` token, `fai_gitlab_token`, which is user-readable in `/run/secrets` because the
script runs as the quickshell user. Off the VPN the name still resolves, so one 4 s probe decides
it, instead of a timeout per project.

**Off the VPN it shows the last good picture.** Every good answer of a source is stamped (`asOf`)
and kept in `~/.cache/ci-status/`, and a failed one serves that copy marked `stale`, with an
`offline · 2 h` badge in peach on the page, so old data never passes for live. The page only
leaves the rotation when the forge has never answered at all. A missing or refused token stays in the rotation with a line that says which, because
that one is mine to fix.

## The FAI pipelines without the VPN: a pipeline hook through the tunnel

The API is pull and lives behind the VPN, so the band gets the FAI pipelines PUSHED instead: each
GitLab project sends its **Pipeline Hook** to `https://ci.v1cferr.dev/hooks/gitlab`. The workstation
reaches the internet like any server, so nothing on it changes beyond the per-project webhook,
which is GitLab configuration and not the machine's.

```text
git.sup (FAI) --Pipeline Hook--> ci.v1cferr.dev (Cloudflare edge, Access: service token)
                                      |  tunnel, outbound from here
                                      v
                                 127.0.0.1:9123 webhook (checks X-Gitlab-Token)
                                      |  ci-webhook-store: payload -> the band's run schema
                                      v
                                 /var/lib/ci-webhook/gitlab/<repo>__<ref>.json
                                      ^  read by ci-status-json when the API does not answer
```

**Two gates, one per layer.** At the edge, the `ci` hostname has an Access app whose only policy
is a SERVICE TOKEN (`gitlab-webhook`), and the GitLab webhook carries its `CF-Access-Client-Id` and
`CF-Access-Client-Secret` as custom headers. Behind it, the receiver only runs the store when
`X-Gitlab-Token` matches `fai_gitlab_webhook_token`. That token reaches the receiver through
`LoadCredential` and webhook's `credential` template function, so it is never in the store, and a
second rule demands a non-empty header, because `credential` yields "" when the file is missing.
The template uses Go's backtick strings on purpose: `builtins.toJSON` escapes a quote to `\"`,
and the template parser then refuses the whole file (caught by the end-to-end test below).

**The schema is the API's.** `ci-webhook-store` (`dash/scripts/`) maps the hook payload onto the
same run object `ci-status.sh` prints (merge request pipelines become `!N` there too, the failed
build gives `job › stage · reason`), keyed by repo and ref. Hooks can arrive out of order, so an
OLDER pipeline id never overwrites a newer one. Its files are 0644 in a 0755 `StateDirectory`,
because `ci-status-json` runs as me.

**Which source wins.** With the VPN up the API is the truth (`via: api`). Without it, the hook
copy is served live (`via: webhook`, a dim badge on the page). Only when neither has anything does
the stale cache answer, badged `offline`. The receiver is pure push, so it only knows pipelines
that ran AFTER the webhook was configured; the API remains the backfill.

**Self-activating.** `ci-webhook.nix` is inert until `fai_gitlab_webhook_token` exists in sops, and
the host's `ci` ingress entry follows `services.webhook.enable`, so the tunnel never maps the name
to a closed port.

Tested end to end on 06/10/2026 with the real binary and hook file (webhook 2.8.3): right token
200 and a file in the run schema, wrong, empty or missing token 403, and the token absent from
the verbose log.

## The weather: now under the clock, the week on the month

The weather is split by TIME, like the rest of the band: what it is now sits with the clock, and
what is coming sits on the calendar, where the days already are. A separate weather card (the
usual answer, Caelestia's dashboard has one) would have repeated the week the month already shows.

**Today (`WeatherNow.qml`)** fills what was an empty gap under the clock: the glyph and the
temperature in large type, the pt-BR condition, then one line of glyphs (max/min, feels like,
humidity, wind, rain chance) so it fits without truncating. It used to carry a small 12-hour curve;
that moved to the weather page, where a chart can be a chart. Its place went to ONE line for the
day: sunrise and sunset, the hours of daylight, and the next rain worth knowing about in the next
24 hours ("rain likely" from 40%, "a chance of rain" from 20%, otherwise "dry for the next 24 h" in
green). It answers "when does it get dark" and "will it rain today" without opening a page.

**The model is pinned to ECMWF IFS.** Measured on 07/10/2026: Open-Meteo's `best_match` for São
Carlos returned the ECMWF IFS 9 km run hour for hour (and its ensemble for the rain chance), with
GFS, ICON, Météo-France and UKMO up to 2.6 °C apart from it. `my.weather.model = "ecmwf_ifs"` keeps
that choice if Open-Meteo's ever changes, both the bar and the lock screen ask for it, and the
weather page names it. Pinning lost no field: current, 25 hourly rain chances, 8 days, the sun.

**The data is the bar's.** `Bar.qml` already fetched Open-Meteo every 15 minutes for its pill; the
same call now also asks for `hourly` (temperature, rain chance, sky and `is_day`, `forecast_hours=25`)
and the days' `sunrise`/`sunset`, and exposes `wHourly` and `wDaily` (keyed by ISO date, today
included). No second request, no second source (rule 11).

**The ambient layer (`WeatherAmbient.qml`)** lives behind today's glyph: drops falling while it
rains, a slow breathing glow while the sun is out, and NOTHING for clouds, fog or night, because
motion that never stops stops meaning anything. It is a handful of rectangles and no shader, since
the band already repaints often (rolling numbers, the services strip).

**The week (in the month grid)** is the band's signature: today and the seven days after it carry
their own forecast INSIDE their cells, the number lifted to make room for the sky glyph, the max in
bold and the min dimmed. The month already had those days on screen, so the forecast costs no new
surface, and the days that pass take their weather with them. A filled cell (today, a holiday)
inks the forecast in the background color so it stays legible on the fill. The glyph's color
(`WeatherSky.qml`, shared with today's glyph) says the sky before the glyph is read: yellow sun,
blue rain, neutral otherwise.

## Motion

Chosen on 07/10/2026 as "ambient", and every piece of it carries a meaning:

- **Numbers roll.** CPU, RAM, DISK, GPU and TEMP ease to their new value over 650 ms (`Tile.number`)
  instead of jumping. NET does not: its unit flips between KB/s and MB/s, and a rolling number
  across a unit change reads as a wrong number.
- **A tile past its limit breathes** (CPU, RAM or DISK at 90% and up, the GPU at 90% of its power
  cap, a critical temperature) until it is back, so a hot tile is seen out of the corner of an eye.
  `alwaysRunToEnd` lets the last pulse finish instead of freezing half faded.
- **Pages slide.** The page coming in enters from the side being moved toward and the one leaving
  exits the other way (`offsetOf`, 56 px over 420 ms, under the existing fade), so the column reads
  as a strip of pages and not as a flicker. A wrap from the last page to the first slides forward.
- **The weather** draws its 12-hour curve in, and rains or shines behind today's glyph
  (`WeatherAmbient.qml`, above).

## The services strip

The bottom of the band shows what this machine RUNS and what each thing costs, three cards a
page, turning every 10 s like the month column, held under the pointer, stepped by `‹ ›`, the
dots or the wheel, sliding as one long strip. Trouble sorts first (down, then degraded), then the
heaviest, so a broken service is always on page one, and the header says `all 18 up` or
`2 of 18 need a look`.

**"Heaviest" means RAM by default, and the order holds still.** The first version sorted by the
instant CPU, and on 07/10/2026 the owner read the strip as alphabetical: it effectively was. At idle
every service sits at 0.00% of a 16-thread machine (measured: seven services, ten seconds, all
zero), so the ties fell back to the catalog, which Nix emits sorted by name, and the few non-zero
readings reshuffled the pages every 3 s. RAM is what actually tells idle services apart (immich
390 MB against tor 4 MB) and it is steady. A click on `· by RAM ⇅` switches to CPU averaged over
each service's own 2 minutes, never the instant reading. The rank is recomputed every 30 s and on
a switch, not on every tick, so a card does not change page under the eye.

**A card, line by line** (`ServiceCard.qml`): a state dot (green up, peach degraded, red down, and
only trouble breathes), the name, `3/3 containers` or `4/4 units` when it is made of several, the
uptime, `↻ N` restarts when there were any, and where a click goes (`↗` the site, `󰆍` the log).
Then CPU as a share of the WHOLE machine (two decimals under 1%, because idle and almost idle are
different readings) with its own 2-minute sparkline scaled to its own peak, RAM and task count.
Then disk read/write per second (tinted once it passes 1 MB/s) and what it is made of
(`server · machine-learning · redis · postgresql`), or its kind when it is a single unit.

**What counts as a service: a catalog, not "everything running".** `dash/services.nix` maps each
`my.services` toggle to its units (`immich` sums four, `basic-memory` two, the user units are
looked up under `--user`) and to the `my.ingress` name a click opens, so a service turned off in
the host panel leaves the strip, and the URL is the same one Caddy serves. Tunnel-only names get
no URL, since Access has no browser login there. Docker compose projects are found LIVE by their
label, so one not in the catalog (`ascension-coa-scraper`) still shows up. "Everything running"
was rejected: pipewire, portals and hypridle are the desktop, not services.

**Two speeds, no daemon per tick.** `dash-services-meta` (`dash/scripts/services-meta.sh`) runs
every 30 s: one `systemctl show` per scope for state, `ActiveEnterTimestamp`, `NRestarts` and
`ControlGroup`, one `docker inspect` for the containers' state, health, restarts and start time,
and it decides `up`/`degraded`/`down` per service. Then every 3 s `Services.qml` reads those
cgroups' own counters in ONE `head` (`memory.current`, `cpu.stat`, `io.stat`, `pids.current`) and
computes the deltas itself. RAM is `memory.current`, the number `systemctl status` shows.

**The click** opens the site when the service has one, and otherwise a kitty with the live log:
`journalctl -u` (or `--user-unit`) for units, `docker compose -p <project> logs -f` for stacks.

## The weather page: the week as ranges, the day as one picture

A page of its own in the right column's rotation (month, WEATHER, GitHub, FAI), redone on
07/10/2026 after the owner found the first curve plain and pointed at MSN's forecast as the bar.
The research behind it: the modern weather charts (MSN, Apple Weather, the Blue app, meteoblue)
share three moves, and the page takes all three.

**The color IS the temperature.** `WeatherSky.temp()` maps degrees to the THEME's own hues (blue,
sky, teal, green, yellow, peach, red, from 8 to 34 °C, São Carlos' range and not the planet's, so a
19° night and a 31° afternoon look different), interpolated per degree. The chart paints its area
with a horizontal gradient that has one stop per hour, so the afternoon glows warm and the night
cools to teal without a legend. The same scale tints the hour labels and the week's bars.

**The week (`WeatherWeek.qml`)** is seven rows: day, sky, rain chance when it is 20% or more, min,
a bar from min to max on ONE scale for the whole week painted from the min's color to the max's,
and max. A hot day reads as a long warm bar to the right before a number is read (Apple's move).

**The next 24 hours (`WeatherChart.qml`)**: a ruler every 2 hours (time, sky glyph by day or night,
temperature in its color), then a smooth hill (Catmull-Rom through the hourly samples, drawn as
Bezier segments) filled with the temperature gradient and faded toward its base with a
`destination-in` pass, a crisp crest in the same moving color, the NIGHTS shaded behind it as one
block each (sunset and sunrise become edges, with their times marked), a "now" line, and a ribbon
of eight 3-hour blocks with the rain chance, blue only from 10% up. The night shading is ours, MSN
has none: it is what makes "it cools after 18:12" visible instead of read.

**Two traps, both met.** The reveal animated the `width` of a clip, and a width animation captures
its target when it starts: the page was still 0 px wide, so it revealed nothing and the chart
looked broken. It now animates a 0 to 1 `progress` multiplied by the width. And one translucent
rectangle per night HOUR overlapped at the edges and drew stripes; contiguous night hours are now
one rectangle.

## INMET: the official second source, and its alerts

Open-Meteo gives the hourly numbers; INMET (`Inmet.qml`) gives what a forecaster wrote and, above
all, the ALERTS, the same official warnings Civil Defense acts on (the "Storm - Moderate" MSN
showed was one of them). Both are polled every 30 minutes, and a failed poll keeps the last answer.

- **Matched by IBGE code, never by name.** `my.weather.ibge = "3548906"`: the alerts list every
  municipality they cover, and "São Carlos" alone also matches São Carlos/SC (4216008). An alert
  is ours only when that code is in its `geocodes`.
- **Where it shows.** An alert in force rides on the condition line of today's block (no extra
  height), breathing slowly in INMET's severity color (yellow potential danger, orange danger, red
  great danger, from the theme). The weather page opens with up to two alerts, today's and the next,
  with the risk text and until or from when. Under the week, INMET's own words for today, per
  period. The page's last line names the sources.
- **The week starts tomorrow** on the page: today already has the block under the clock and the
  start of the 24 h chart, and the row was worth more as height for the chart.
- **The API is undocumented and picky.** `apiprevmet3.inmet.gov.br` drops clients that do not look
  like a browser, so the requests send a browser user agent; `riscos` arrives as a JSON string of a
  list or as the list itself. If it moves, the panel loses the text and the alerts and keeps the
  ECMWF numbers.

**Why two sources and not the "most reliable" one.** There is no single winner. For the hourly
temperature over the next two days, the global models are good and ECMWF tends to lead the
verification scores. For São Carlos' spring rain, isolated afternoon showers, every model
struggles, and the reference is INMET's forecasters and their alerts. On 07/10/2026 they disagreed
by 4 °C on Saturday (INMET 35°, ECMWF 31°); the page shows both instead of choosing silently.
CPTEC/INPE and the BrasilAPI wrapper were unreachable from here that day, and Climatempo's API is
paid.
