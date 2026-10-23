# The glance band on the standing monitor

`modules/home/desktop/quickshell/dash/`. Everything that belongs to the band lives in that one
folder: the panel (`Dashboard.qml`), its pieces (`BentoCard.qml`, `Tile.qml`, `ServiceStrip.qml`,
`CiList.qml`), the CI feed (`Ci.qml`, which reads glance-feed's cache), its height (`band.nix`, the
`my.dash.share` option) and, under `scripts/`, the services meta script and the pipeline hook's
store.

The band is a part of the Quickshell tree and not a Nix module of its own on purpose: the QML has to
sit under the `mkOutOfStoreSymlink` that becomes `~/.config/quickshell`, or the `root:/` imports
and the hot reload stop working, and it reads every system number from the bar's Scope (`host`).

**Why it exists.** A 27" panel on its pivot is 597 mm tall, so its top third sits ABOVE eye level
for anyone sitting at the desk, while the ergonomic target is 0 to -30 degrees below the
horizontal. A window up there is a neck problem, not a layout preference. The split is 35/65 since
17/10/2026 (30/70 before): 672 px of band against 1248 px of work area on the 1920 px panel, at its
native scale ([the share](#the-share-35-by-default-never-above-40)).

**It is drawn on a fixed canvas and scaled inside Quickshell.** The band was designed in the week
the LG ran at `scale = 0.75` (1440x2560 logical), and every size in `dash/` is a pixel of that
canvas. When the LG went back to native scale (commit `8ba3686`, the reason is in
[hypr](hypr.md)), the band got 1072x538 logical: the services strip had no room left, and the CI rows
and the weather line were cut. Instead of re-sizing ~250 literals across 15 files, `Dashboard.qml`
lays the content out on a 1432-wide `stage` (1440 minus the window's margins) and gives it
`scale: width / 1432`, 0.749 here. The difference from the compositor's 0.75 is WHERE the scaling
happens: Hyprland shrinks a frame already rasterized at the bigger size, which is what blurred thin
text; inside Quickshell, Qt's default distance-field text rasterizes every glyph at its final
on-screen size, so the same reduction comes out sharp (checked at 300% on 9 px text, 11/10/2026).
The physical sizes are exactly the ones of the 0.75 week. One trap met on the way: a size computed
from the WINDOW (`dash.width`) inside the stage is in the wrong units; the left column's 55% now
reads `stage.width`.

**How the space is taken: `exclusiveZone`, not a gap.** A workspace rule with
`gaps_out = { top = N }` reserves the same strip, and it was the first attempt, but N would then
have to be kept in sync BY HAND with the panel's height, and it only covers the workspaces it
names. A layer surface declares its own zone and Hyprland tiles below it, so ONE number governs
both: the share, reserved by the bar on this screen ([below](#the-share-35-by-default-never-above-40)).

**What earns a place.** The top of a standing screen is for what is read in two seconds and never
clicked: the time, the month, the machine's vitals and what is playing. Everything that takes
a click stays in the work area. Notifications are deliberately not there at all: a feed in the eyeline
is the opposite of a glance surface, and since 17/10/2026 they live behind the NixOS logo in the bar
above ([nixos-center.md](nixos-center.md)), so the band's old bell went with the others.

**The vitals are tiles, not meter rows.** CPU, RAM, DISK, GPU, TEMP and NET sit in one row of
six bento cells since 17/10/2026, a 3x2 grid before (`dash/Tile.qml`), each with a 36 px value and one
hint; load and uptime are in the CPU tile's tooltip.
The first version reused the
popovers' `MeterRow`, whose 10 to 12 px text is sized for a hover a hand away; on the band's
canvas it was unreadable from the chair and left the left column half empty. GPU is power against its
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

**The date block.** The band's own clock (HH:mm:ss and the weekday) left on 20/10/2026 for energy and
Claude, on the grounds that the bar already shows the time, and came back the same day in v5.1
([below](#the-left-card-the-time-the-weather-now-and-energy-v51-20102026)): read from the chair, the
band's large clock and the weather now were worth more than a Claude panel the rotation already had.
`isoWeek()` stays, for the month page's week numbers.

**`host` is NOT a required property, and that is not sloppiness.** Quickshell's `Variants` creates
the delegate with `modelData` as the only initial property, so a SECOND required property fails the
creation with `failed to create variant with object` and the layer never appears at all.

## The share: 35% by default, never above 40%

`my.dash.share` (`dash/band.nix`) is the share of the standing screen's height the band takes, the
bar INCLUDED: `0.35` by default, `0.30` for the compact profile. The option's type is
`numbers.between 0.25 0.4`, so a share above 40% does not evaluate, and `Theme.qml` clamps the
generated `~/.config/theme/dash.json` to the same range again, since a hand-edited file would
otherwise get past the type. Above 40% the band would take the work area it exists to protect.

```nix
my.dash.share = 0.30; # the compact profile: the 576 px band of the old 30/70 split
```

The arithmetic, on the 1920 px LG: `round(1920 x 0.35)` = 672 px reserved from the top edge. The
bar is the top 40 px (the continuous Powerline, flush with the edge), the band starts 8 px under it
at y = 48 (`Theme.bandTop`), so the band is 672 - 48 = 624 px tall and its last row is y = 671.
Windows start at 672 plus Hyprland's 12 px `gaps_out`, the same 12 px the band keeps from the sides,
so its cards line up with the windows below. Measured on 17/10/2026: the monitor's `reserved` is
`[0, 672, 0, 0]`, the band layer at y 48 with 624 px, and the first window's border at local y 684.
At 0.30 the same sum gives 576 and a 528 px band. Until the next rebuild writes `dash.json`, Theme falls back to 0.35 and logs that the file is
missing.

**One owner for the strip.** The BAR reserves it: on a screen where the band shows, its
`exclusiveZone` is the whole share minus its own 4 px gap, and the band draws inside that strip with
`exclusionMode: Ignore`. Two layers that each reserve their own zone are stacked by Hyprland in the
order they MAP, and on 17/10/2026 a re-created band mapped first and pushed the bar under itself.
With one owner the order no longer matters, and nothing is reserved twice.

## The bento grid (17/10/2026)

The band was one big card with two columns inside. It is now a grid of glass cards (`BentoCard.qml`
on the shared `GlassSurface`, [theme.md](theme.md#the-three-glass-levels)) with 8 px gutters, so the
photo shows between the cells:

```text
+--------------------------+ +--------------------------+
| the time, the weekday    | | month / weather / network|
| today's weather          | | / GitHub / FAI, rotating |
| what is playing          | |                          |
+--------------------------+ +--------------------------+
+------+ +------+ +------+   +------+ +------+ +------+
| CPU  | | RAM  | | DISK |   | GPU  | | TEMP | | NET  |
+------+ +------+ +------+   +------+ +------+ +------+
+-----------------------------------------------------+
| the services carousel                               |
+-----------------------------------------------------+
```

**The geometry is computed, in whole pixels, from the window.** With W and H the band's size and
g = 8 (`Theme.sp2`):

| Cell | Rule | On the LG (1056 x 624) |
| --- | --- | --- |
| left column | `floor((W - g) / 2)` | 524 |
| right column | `W - g - left`, so a spare pixel goes right | 524 |
| tile | `floor((column - 2g) / 3)`, a column's spare pixels to its last tiles | 169, 169, 170 |
| top row | `H - 104 - 100 - 2g`: whatever the share leaves | 404 |
| vitals row | 104 | y 412 to 515 |
| services row | 100 | y 524 to 623 |

**Three tiles plus their two gutters are exactly one column**, so every vertical line in the grid is
shared by the cells above and below it. Only the top row grows or shrinks with the share; the vitals
and the services keep their height, so the compact profile takes the room from the pages, which have
the most to spare.

**Checked on a screenshot** (17/10/2026, a script scanning a row and a column for the cards' 1 px
borders, re-run after the 40 px bar): all 12 vertical edges (12/180, 189/357, 366/535, 544/712,
721/889, 898/1067 in screen x) and all 6 horizontal ones (48/451, 460/563, 572/671) on the exact
computed pixel.

**Frames in pixels, content in design units.** A card's frame (position, size, radius, border) is
in real pixels, so the hairlines land on whole pixels and stay crisp. Its CONTENT keeps the 1432
design canvas described above, scaled by the same `k` inside the card, so nothing on the pages, the
tiles or the services had to be re-sized. That is the incremental half of moving off the global
transform: the chrome is in pixels now, and moving the content's ~250 sizes too would be a separate
change with nothing broken to fix.

**What changed in the cells** (17/10/2026; the left card changed again twice on 20/10, see below). The time grew to its own line (96 design px, about 72 on screen) for
reading from the chair, the weekday and the date under it; today's weather sits centered in the rest
of the card and the media line at its foot. RAM and TEMP briefly drew their 2-minute history and lost it the same day: they
barely move, and on the zero-based scale the sparkline keeps on purpose their history was a flat
slab that said nothing. NET's value is a step smaller (28 design px)
so `↓ 977 KB/s` stays whole in a 172 px tile. Every tile is aligned to the top, so the six labels
share one line. The sparklines are one canvas each since the same day
([motion.md](motion.md#measured-cost-and-what-was-not-measured)).

## The CI pages: the right column rotates

The month shares its column with two CI pages, one at a time: **month, GitHub Actions, the FAI
GitLab**, every 15 s, with dots on the header's right edge that say where the rotation is and jump
on a click, flanked by `‹ ›` arrows (`PageArrow.qml`); the mouse wheel over the column steps the
pages too. A CI alert clicked in the bar above turns to the forge with a failure and holds the
rotation for 30 s ([bar.md](bar.md#operational-chips)).
The pointer over the column HOLDS the page, because reading a row must not be a race against the
timer. The pin left of the arrows (`PinToggle.qml`) holds it until the next click, for
when one page is what to watch: lit while held, never saved, so a reload always rotates again. The
arrows, dots, wheel and a clicked alert still turn the page, and the pin stays on the new one. The clock and the vitals never rotate: they are what the band is for.

**One feed, one schema.** glance-feed's CI source (docs/notes/desktop/glance-feed.md) asks both
forges and stores ONE document in which a run is `{repo, name, ref, state, event, created, url}`
and `state` is one of six words. The QML never learns that GitHub says `completed/failure` and
GitLab says `failed`. A source that fails reports `{ok: false, error}` and never hides the other
one. It runs every minute while something runs or waits and every two otherwise, with an ETag on
every request, so an unchanged forge costs `304`s with no body; `Ci.qml` only reads the cache.

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

**Off the VPN it shows the last good picture.** A failed source keeps its last good runs in the
cached document, marked `stale` with the time it FIRST failed (`staleSince`, so the document does
not change on every failing run), and the page shows an `offline · 2 h` badge in peach, so old data
never passes for live. The page only
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
                                      ^  read by glance-feed when the API does not answer
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
same run object glance-feed's CI source writes (merge request pipelines become `!N` there too, the failed
build gives `job › stage · reason`), keyed by repo and ref. Hooks can arrive out of order, so an
OLDER pipeline id never overwrites a newer one. Its files are 0644 in a 0755 `StateDirectory`,
because glance-feed runs as me.

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

## The weather: the pill, the page and the week on the month

The weather is split by TIME, like the rest of the band: what it is now is the bar's pill (and its
popover), and what is coming sits on the calendar, where the days already are. A separate weather
card (the usual answer, Caelestia's dashboard has one) would have repeated the week the month
already shows. "Today" lived under the band's clock (`WeatherNow.qml`, with `WeatherAmbient.qml`
behind its glyph) until 20/10/2026; both were deleted with that card (rule 16).

**The model is pinned to ECMWF IFS.** Measured on 07/10/2026: Open-Meteo's `best_match` for São
Carlos returned the ECMWF IFS 9 km run hour for hour (and its ensemble for the rain chance), with
GFS, ICON, Météo-France and UKMO up to 2.6 °C apart from it. `my.weather.model = "ecmwf_ifs"` keeps
that choice if Open-Meteo's ever changes, both the bar and the lock screen ask for it, and the
weather page names it. Pinning lost no field: current, 25 hourly rain chances, 8 days, the sun.

**The data is glance-feed's** (docs/notes/desktop/glance-feed.md). The bar no longer calls
Open-Meteo itself: it reads the `weather` document from the SQLite cache (`Feed.qml`), which holds
the hourly run with feels like, humidity and wind, and derives "now" from it, interpolating by the
minutes past the hour and re-deriving every 5 minutes. `wHourly`, `wDaily` and `wForecast` keep
their shapes, so the pill, its popover, the month grid and the weather page did not change.

**The ambient layer** (deleted on 20/10/2026 with the card it lived in) taught the rule that stays:
a loop keeps the whole band repainting every frame, measured in a headless sway with rain forced at
72 to 83% of a core looping against 16% settled. Nothing on the band animates without an end.

**The week (in the month grid)** is the band's signature: today and the seven days after it carry
their own forecast INSIDE their cells, the number lifted to make room for the sky glyph, the max in
bold and the min dimmed. The month already had those days on screen, so the forecast costs no new
surface, and the days that pass take their weather with them. A filled cell (today, a holiday)
inks the forecast in the background color so it stays legible on the fill. The glyph's color
(`WeatherSky.qml`, shared with today's glyph) says the sky before the glyph is read: yellow sun,
blue rain, neutral otherwise.

## Motion

Chosen on 07/10/2026 as "ambient", and every piece of it carries a meaning:

- **~~Numbers roll.~~** Reversed on 17/10/2026. CPU, RAM, DISK, GPU and TEMP used to ease to their
  new value over 650 ms (`Tile.number`); with readings every few seconds a digit was rolling a third
  of the time, in the corner of the eye, on a band meant to stay calm while I work. The text now
  changes in place and the bar under it still eases (300 ms), so the change is shown by a shape and
  not by moving digits. NET never rolled: its unit flips between KB/s and MB/s. Why the whole
  desktop moved this way: [motion.md](motion.md).
- **A tile past its limit breathes** (CPU, RAM or DISK at 90% and up, the GPU at 90% of its power
  cap, a critical temperature) until it is back, so a hot tile is seen out of the corner of an eye.
  `alwaysRunToEnd` lets the last pulse finish instead of freezing half faded.
- **Pages slide.** The page coming in enters from the side being moved toward and the one leaving
  exits the other way (`offsetOf`, 56 px over 420 ms, under the existing fade), so the column reads
  as a strip of pages and not as a flicker. A wrap from the last page to the first slides forward.
- **The weather** draws its 12-hour curve in, and rains or shines behind today's glyph for 8 s
  when that sky begins (`WeatherAmbient.qml`, above). The draw-in plays on the first data and when the page comes
  around, and NOT on a feed refresh: until 17/10/2026 `onHoursChanged` replayed it, so the chart
  re-animated every few minutes on its own. A refresh now repaints in place.

## The services strip

The bottom of the band shows what this machine RUNS and what each thing costs, three cards a
page, turning every 10 s like the month column, held under the pointer or by its own pin, stepped by `‹ ›`, the
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
only trouble breathes), the name, `2/3 containers` only while it is not whole, the uptime and
`↻N` restarts when there were any. Then CPU as a share of the WHOLE machine (two decimals under 1%,
because idle and almost idle are different readings) with its own 2-minute sparkline scaled to its
own peak, and RAM. The tooltip holds what it is made of (`server · machine-learning · redis ·
postgresql`, or its kind when it is a single unit), the task count, disk read/write per second and
where a click goes (the site or the log).

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
showed was one of them). glance-feed fetches both (the text every 4 hours, the alerts only when
INMET's RSS set changes) and stores them already filtered; `Inmet.qml` only reads the cache.

- **Matched by IBGE code, never by name.** `my.weather.ibge = "3548906"`: the alerts list every
  municipality they cover, and "São Carlos" alone also matches São Carlos/SC (4216008). An alert
  is ours only when that code is in its `geocodes`.
- **Where it shows.** An alert in force rides on the condition line of today's block (no extra
  height), breathing slowly in INMET's severity color (yellow potential danger, orange danger, red
  great danger, from the theme). The weather page opens with ONE alert chip: the worst severity,
  until or from when, and `+N` for the others; each alert's risk text is in its tooltip. INMET's
  own words for today, per period, and the sources are glyphs at the foot of the page, on hover.
- **The week starts tomorrow** on the page: today already has the block under the clock and the
  start of the 24 h chart, and the row was worth more as height for the chart.
- **The API is undocumented and picky.** `apiprevmet3.inmet.gov.br` drops clients that do not look
  like a browser, so glance-feed sends a browser user agent; `riscos` arrives as a JSON string of a
  list or as the list itself. If it moves, the panel loses the text and the alerts and keeps the
  ECMWF numbers.

**Why two sources and not the "most reliable" one.** There is no single winner. For the hourly
temperature over the next two days, the global models are good and ECMWF tends to lead the
verification scores. For São Carlos' spring rain, isolated afternoon showers, every model
struggles, and the reference is INMET's forecasters and their alerts. On 07/10/2026 they disagreed
by 4 °C on Saturday (INMET 35°, ECMWF 31°); the page shows both instead of choosing silently.
CPTEC/INPE and the BrasilAPI wrapper were unreachable from here that day, and Climatempo's API is
paid.

## The network page

A page of the rotation (month, WEATHER, NETWORK, CLAUDE, GitHub, FAI), from glance-feed's `network`
document (docs/notes/desktop/glance-feed.md), added on 08/10/2026 as the first visible piece of the
threat-monitoring plan in docs/open-items.md, before any router change.

- **Four glyph chips:** devices online, new today, remote sessions now, open connections.
- **The exposed ports, last 24 hours,** one line: failed SSH logins, from how many IPs, fail2ban
  bans; the most persistent addresses are in its tooltip. It made the exposure concrete on day one:
  97 failures from 45 IPs against port 2222.
- **Threats, last 24 hours** (the `threats` document, from the router's own log): red when a device
  of the house asked a domain on the TIF list or reached a banIP-listed address, peach when it only
  tried a DoH server (a browser probing for its own DNS, which would skip the filtering), green
  when neither. Under it at most two events, contacts before DoH attempts, naming the device and
  what it asked or reached; the rest, the DNS volume and the scans banIP dropped (the background
  noise of a public IP) are in the tooltip.
- **Devices** as chips with only the name: NEW in peach first, then the ones not in the router's
  static DHCP list, then the known (green); address and MAC on hover. "Not in the list" is not
  "hostile": the family's phones are there too.
- **Remote access over WireGuard:** the connected peers as chips, by their description in the
  router's mirror (a handshake in the last 3 minutes), and ONE `N offline` chip whose tooltip says
  when each of the others was last seen. The endpoint is deliberately not shown.
- **An info glyph** whose tooltip says where the data comes from, how many threat domains the list
  holds, and how fresh the page is.

Until 11/10/2026 every one of those was spelled out, and the page ran past its column over the
services strip; the trim below is what made it fit.

## The left card: the time, the weather now, and energy (v5.1, 20/10/2026)

The left card opens with what the chair asks first and closes with what no other surface keeps in
view for long:

- **The clock and the weather now** (`ClockWeather.qml`): HH:MM:SS at 64 design px and the day
  spelled out, from the bar's own clock (`timeStr`, no second timer); on the right, the sky's glyph,
  the temperature and the condition from the bar's forecast (no second Open-Meteo request). The full
  forecast stays on the WEATHER page of the rotation.
- **ENERGY** (`EnergyPanel.qml`, data in `data/Energy.qml`), kept as it was and given the rest of the
  height: the MEASURED CPU package plus GPU board watts, their split, the power profile and the
  GPU's render idle, and the last 30 min as one bar a minute on a zero-based scale (a minute with no
  sample is a hole, drawn as one). The footnote says "CPU + GPU measured", never the PC's power: the
  board, RAM, disks, PSU and monitors have no sensor. The data is power-log's CSV once a
  minute, parsed by `data/EnergyMath.qml`: the SAME singleton the lock screen's LG card reads
  (docs/notes/desktop/lockscreen.md), so the two screens cannot disagree.

Claude is NOT in this card any more: the persistent panel repeated the CLAUDE page of the rotation
(the same numbers twice whenever that page was up), so it left with its `Ring.qml`, and the page
kept every detail.

Checked in a second Quickshell on a copy of the tree, inside a headless sway (1080x1920), before the
live tree changed. NOT checked there: HyprGlass (sway has no plugin), so the material on the real
band is the same as every other card's.

## The Claude page

The FAI account's `/usage`, live, from glance-feed's `claude_usage` document
(docs/notes/desktop/glance-feed.md) through the `ClaudeUsage.qml` singleton, as the CLAUDE · FAI
page of the rotation (month, WEATHER, NETWORK, CLAUDE, GitHub, FAI).

**One clear block per limit (21/10/2026).** The user found the page confusing: two big percentages,
their bars and "resets in" all on one line each, and a loose line of more percentages under them
("Fable 0% · team · max 5x · extra usage off"). Now each limit is three lines: its name and period
("Session · 5-hour window", "Week · 7-day limit") with the share on the right ("12% used"); the bar
across the width; and when it renews, as the clock will show it ("renews 23:10 · in 1h 51m", or
"Thu 00:00" another day). The models' shares, the plan and extra usage moved into the blocks' tip.
Both meters turn yellow at 75% (or when the server says `warning`) and red at 90%.

**The week as one picture** (`widgets/ClaudeWeek.qml`, shared with the lock): the share used as a STEP line (a running total:
each reading holds until the next) across the limit's own week, from its last renewal to the next,
so the line ends at now and the rest of the frame is the week still ahead. Guides at 50% and 100%,
the days at each local midnight, a dotted line where the share dropped (a reset), the value now at
the line's end, and "no data before …" in a gap the feed never saw (unknown is not zero). Under
the pointer: the day, the hour and the share in force, "Tue 15:18 · 54% used". It replaced 168
unlabelled hourly bars.

A window whose reset time passed reads 0% until the feed brings the new one: the old number would
be a lie. The countdowns tick every 30 s on the clock alone, with no re-read.

## Density and hover

On 11/10/2026 the band carried about 60 lines of text: label, value, bar and hint on every tile,
three lines per service, three weather detail lines, INMET twice. It was trimmed by one rule:
**an icon and the main number, at most ONE secondary line, and the rest in a tooltip.** This is
progressive disclosure, the usual answer for dashboards: the summary is read in seconds from the
chair, and the detail is there for the hand that asks.

- **Spacing** follows an 8 / 16 / 24 / 32 scale in design units (the 1432 canvas): 32 around the
  card, 24 between sections, 8 or 16 inside one.
- **What never hides in a tooltip:** an INMET alert in force, a service down or not whole, a failed
  CI run, a NEW device, threat contacts. A tooltip is invisible until someone hovers, so anything
  that must be noticed stays on the band; the tooltip only holds what explains it.
- **The timing** (`dash/Tips.qml`): a card opens after 350 ms of rest, so a pointer only crossing
  the band shows nothing, and for 300 ms after one closes the next opens at once. That is the
  common 300 to 500 ms open delay plus the "warm" window of OS tooltips, which makes running the
  pointer along a row of tiles read like one continuous tooltip.
- **One card per band** (`dash/TipWindow.qml`), fed by any `Tip` dropped inside an item
  (`dash/Tip.qml`). It is a layer surface on the overlay layer and not a `PopupWindow`, for the
  same Hyprland #6682 reason as the bar's popovers (docs/notes/desktop/quickshell.md), and its input
  region is empty, so it never takes the pointer from what it describes and a click still lands on
  the row under it. Where an item already has a hover `MouseArea` (service cards, CI rows) the
  `Tip` takes that area's `containsMouse` instead of a second hover handler.
- **The trap met building it:** the card first checked "is this target mine?" by walking the
  target's parents up to the root item and comparing it with the window's `contentItem`. It is the
  same object, but Quickshell returns a new JS wrapper for it, so `===` was always false and the
  card never opened. The stage now carries a `tipBand` property naming its band, and the walk stops
  there.

## Charts read out under the pointer (21/10/2026)

The user asked to interact with the charts, cleanly and usefully, unlocked as well as locked. Every
`widgets/Sparkline.qml` (the energy panel, the Claude page, the tiles, the service cards and the
bar's popovers) now reads out under the pointer: the bar under it stays lit, the others dim, and a
small label shows its value, and its clock time when the caller says how far apart the samples are
(`stepS`: 60 for energy, 3600 for the Claude week). The weather page's curve (`WeatherChart.qml`)
does the same per hour: a hairline, a dot on the curve, and `HHh · temperature · rain`. Nothing
moves and nothing needs a click; it is the same readout as the lock's charts
([lockscreen.md](lockscreen.md)), in the band's own type. Unlike a `Tip`, it shows at once: a
chart is read by sweeping the pointer along it, and a delay would break the sweep.
