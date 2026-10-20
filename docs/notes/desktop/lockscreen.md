# The lock screen: hyprlock plus hypridle

`modules/home/desktop/lockscreen/default.nix`, with its renderer and scripts in
`modules/home/desktop/lockscreen/scripts/`. Ref: <https://wiki.hypr.land/Hypr-Ecosystem/hyprlock/>

## Lockscreen v3: Tokyo Night Adaptive Glass+ (20/10/2026)

The lock is a continuation of the desktop's glass (see [theme.md](theme.md#tokyo-night-adaptive-glass-the-shells-design-system)):
the wallpaper stays sharp and visible, and only the regions under a card are frosted. v3 keeps the
v2 architecture below and changes what each monitor is FOR:

| Monitor | What it shows | What it never shows |
| --- | --- | --- |
| ASUS (`my.monitors.primary`) | my logo, name and handle; the time with seconds and the date; the password field; the quote of this lock | energy, Claude, the system, weather |
| LG (`my.monitors.secondary`) | a 2 x 3 grid: energy, Claude Code, system, processes, weather, media | the time, the quote, my name, a password field |

**The ASUS** is four cards on ONE vertical axis, 32 px apart, an 800 px composition
(`geometry.nix`): identity 384 x 160, clock 768 x 224, the field 480 x 80 (the field IS its card:
hyprlock draws only its state hairline on the baked glass), quote 960 x 240. The logo is STATE,
like the photos: `my.lockscreen.logo` points at my SVG outside git, the renderer rasterizes it with
`rsvg-convert`, crops it to its INK (the emblem sits off-center in its viewBox), fits it into 68 px
without distortion and recolors it in the palette's `text`. A missing or broken file renders the
card without it, and the lock never depends on it. Name and handle are labels read from
`programs.git.settings.user.name` and `home.username`, never typed again.

**The LG** is a 2 x 3 grid from 184 px down, 56 px margins, 24 px gutters, 472 px columns, rows of
368, 344 and 256 px; the lower 720 px stay photo. **Media** has all six; **Ambient** has no media
card and widens the weather across the row instead of leaving an empty card. Every card keeps its
position between the two, so the hyprlock config is still ONE file. What feeds it is in
[the LG while locked](#the-lg-while-locked).

**The material, Adaptive Glass+.** Three layers, all baked into the image before the lock: a
frosted core (blur sigma 28, the profile's tint, 6% of the palette's accent so the glass is Tokyo
Night's and not a gray, the bg-to-surface ease, ±1 dither); an optical rim (the hairline, plus
text-colored light at 28% that is full at the top edge and gone by mid-height, and a 6 px band
where the frost is magnified by 1.2%, a lens that never touches text); and a soft highlight (9%
light fading over the top 45%) with a soft shadow under the card (30%, sigma 14, 4 px down) that
darkens the photo without blurring it. Each card has its own BASELINE opacity, chosen CLEAR so the
photo shows through (identity 0.50, clock 0.54, field 0.66, quote 0.60, energy and Claude 0.56,
system and processes 0.58, weather and media 0.54), and rises from there only as far as its TEXT
zones need; labels carry a soft shadow (2 passes, size 4) for the same reason. Measured on
20/10/2026: over a dark print every card kept its baseline, over a bright one only the field
(0.88, for the red failure text) and the quote (0.70) went denser. The major radius is the
desktop's 12 plus 4.

**The cards are rich, not lists.** Each LG card opens with its glyph and title in its own color
(energy orange, Claude violet, system blue, processes teal, weather sky), every share is a thin
meter (`━` in the card's color over a dim track), energy draws its 30 min in two rows of blocks (16
levels), and the weather leads with its own glyph from `my.weather.icons`, the table the bar reads
too. On the ASUS the seconds are in the accent (one instant feeds both fields), the date carries a
calendar glyph, the field a lock, and the quote a quiet open-quote mark.

### Why the glass is pre-rendered, and not HyprGlass

HyprGlass decorates Hyprland WINDOWS and LAYER surfaces. hyprlock draws on
`ext-session-lock-v1` surfaces, which are neither, and its own widgets are textures inside that one
surface, so there is nothing for a compositor plugin to reach. hyprlock's built-in `blur_passes`
blurs the WHOLE background (that was v1), and a full-screen shader would repaint the photo on every
frame of a lock that redraws once a second.

So the glass is baked into the background image, once, by `modules/home/desktop/lockscreen/scripts/render.py` (Pillow), and
hyprlock only draws text and the field on top. The material is the desktop's, step for step:

1. the photo, cover-cropped to the monitor's live logical size around a focal point;
2. per card only: a Gaussian blur, HyprGlass's dark `brightness` and `contrast`, and its bg tint;
3. the GlassSurface gradient, the palette's `bg` at the top easing into its `surface` at the foot;
4. the hairline (`border` at 55%) and the 1 px sheen (`text` at 6%), with antialiased corners;
5. ±1 level of seeded noise, so the 8-bit gradient does not band over a dark blur.

**Adaptive opacity.** The profile gives a RANGE, not a number. For each card the renderer tries
opacities from the card's baseline up and keeps the first at which every text color on that card
keeps WCAG AA (4.5, plus a 10% margin) over the brightest 5% of the COMPOSITED pixels inside the
card's text zones (its inside past 24 px of padding unless the geometry names them), never an
assumed background. A dark photo keeps the baseline; a bright print gets denser glass, only as far
as contrast needs. The wallpaper outside the cards is never darkened, only shadowed under them.

| Profile (`my.theme.glass`) | Opacity range | Gradient | Tint | Brightness | Blur sigma |
| --- | --- | --- | --- | --- | --- |
| `clear-gradient` (this desk) | each card's baseline to 0.92 | bg into surface | 20%, plus 6% accent | 0.95 | 28 px |
| `perceptible` | 0.92 to 0.96 | flat | 33% | 0.85 | 24 px |
| `solid` | 1.0 | none | none | none | none |

The tint, brightness, edge and sheen MIRROR `Theme.qml` and `glass.lua`, and the desktop's own
opacity must sit inside the range: `test_render.py` reads both files and fails if either side moves
alone (rule 11, without editing two hot-reload trees to share a file). The blur sigma is the one
number set BY EYE against HyprGlass's `blur_strength`, not measured against its output.

**Is it as good as the desktop's?** Measured over the theme note's own backdrop (bright stripes,
white included), the baked glass passes 2% to 20% of the photo's contrast through
(`test_transmission_matches_the_desktop_measurement`), around the 10.9% measured live for kitty at
0.70 on HyprGlass. What it cannot do is refract: HyprGlass's rim refraction and specular need a
shader, and a static image of them would be wrong the moment anything moved. It is the honest half
of the material.

### The architecture

| Piece | Runs | Does |
| --- | --- | --- |
| `lockscreen-prepare.service` | after every unlock, 1 min after login, every 6 h; `Nice=19`, idle I/O, 1 GB cap | picks the next photos, renders every image the next lock can need, publishes `ready` |
| `hyprlock.service` `ExecStartPre` (`lock-start.sh`) | on every lock, about 10 ms | chooses the layout, points the session at images that already exist |
| `hyprlock.service` (`lockscreen-launch`) | while locked | finds the session's compositor, draws the images and the labels, runs PAM; on failure, an urgent push |
| `lockscreen-media.service` (`media-bridge.sh`) | only inside a Media lock, `BindsTo=hyprlock.service` | rewrites the media card's text on every MPRIS event |
| `lockscreen-weather.timer` | every 10 min | the weather card's markup, stamped with how long it is valid |
| `lockscreen-quotes.timer` | daily | the ZenQuotes batch, translated by DeepL, as JSON |
| `lockscreen-idle-lock.service` (`idle-gate.sh`) | when hypridle's 5 min fire | locks, unless fullscreen video is playing |

The data flow, end to end:

```text
photo pools ──┐
spec (Nix) ───┼─> render.py (background) ─> v2/assets/<key>.png ─> v2/sets/<id>/ ─> v2/ready
quotes.json ──┘                                                                      │
                                       lock-start.sh (on the lock path, ~10 ms) <────┘
                                         └─> v2/session/{primary,secondary,quote,layout}
glance-feed ─> weather timer ─> v2/weather ┐                                  │
MPRIS ─> media bridge ─> v2/session/media ─┼─> label.sh (builtins) ─> hyprlock labels
                                          ─┘           hyprlock backgrounds <─┘
```

**ONE geometry model**, `geometry.nix`: every card per monitor and layout as an offset from the
screen's CENTER (y down) and a size, in logical pixels. The renderer reads it through the spec
JSON; the hyprlock labels read it through `at`, which turns a point inside a card into hyprlock's
center-relative, y-up `position`. Center-relative is what keeps the two in step on any resolution:
the renderer lays the cards out for the LIVE size it reads from `hyprctl monitors` (rotation and
scale applied: the LG's 1920x1080 mode on its side is a 1080x1920 logical screen), and hyprlock
places the labels from the same center. A layout that would leave the screen or overlap keeps the
fallback for that monitor instead of rendering something misplaced.

### What the lock runs, and what it costs per tick

| Label | Cadence | Command | CPU per call (measured) |
| --- | --- | --- | --- |
| clock | 995 ms | a builtin inlined in `sh -c` (`modules/home/desktop/lockscreen/scripts/clock.sh`) | 2.0 ms (v1's `date`: 2.5) |
| date | 60 s | `lockscreen-label date` | about 3.7 ms |
| weather | 60 s | `lockscreen-label weather` | 4.0 ms |
| media | 3 s | `lockscreen-label media`, empty in Ambient | 4.2 ms |
| quote | once per surface | `lockscreen-label quote` | |
| hint | 5 s, every output | `lockscreen-label hint`, empty while the ASUS is connected | 3.8 ms |

Measured on 19/10/2026 as 200 to 300 runs through `/bin/sh -c`, the way hyprlock's `spawnSync`
runs them. A script costs about 1.7 ms more than a builtin only because `sh` has to exec a second
bash, which is why the one label that runs every second is inlined.

## The folder rule

USER apps go to `modules/home/`. `programs.hyprlock` installs hyprlock and `services.hypridle` brings the
daemon up (`systemd --user`, like hyprsunset), which is why hypridle left `modules/nixos/packages.nix`.

PAM (`modules/nixos/desktop/desktop.nix`) is MANDATORY: without it hyprlock does not authenticate and
LOCKS YOU OUT. v2 does not touch it. The `pt_BR` locale (`modules/nixos/core/core.nix`) is for the
date's spelled-out form.

## Language: a deliberate exception

The system is en-US, and the LOCKSCREEN is full pt-BR: the spelled-out date, the weather, "Digite a
senha…", "Nada tocando", the DeepL-translated quotes. That decision is recorded in the July history,
so those strings are NOT untranslated debt, they are the product.

## Hardware lessons, durable and independent of the GPU. Do NOT touch

1. **A STATIC wallpaper, never `path = screenshot`.** screencopy/DMA segfaults hyprlock when waking
   from idle, because the DMA frame is destroyed on exit. That is a lockout.
2. **No GIF and no continuous reload.** The asynchronous gatherer races with `exit()` and corrupts
   the heap (SIGABRT on unlock). v2 keeps it: every image is static for the whole lock, the glass
   is baked in BEFORE the lock, and no widget has a `reload_time`.
3. **dpms-off REMOVED (jul/2026).** Turning the screen off on idle BROKE remote access: Sunshine
   (wlr capture on the `xe` driver) got a BLACK SCREEN from the powered-off monitor, and toggling
   dpms under capture caused a GPU ENGINE RESET (xe RCS, which froze the scanout). Now idle ONLY
   locks. If dimming is ever wanted, use hyprsunset's gamma. See [`sunshine.md`](../network/sunshine.md).

## Locking cannot depend on hypridle

Until 10/08/2026 the only path to locking was `loginctl lock-session`, which does NOT lock anything
on its own: it only sets `LockedHint` and emits the `Lock` signal on D-Bus. What listened and
brought hyprlock up was hypridle, through `lock_cmd`.

The consequence: with hypridle stopped, the signal fell into the VOID. The bar's "Lock" button
clicked and nothing happened, with no error at all. That is what happened for 6 h on 10/08/2026,
with the Sunshine guard holding hypridle stopped after a client died with no teardown.

It is the wrong dependency. Locking the screen is a SECURITY FUNCTION and cannot be hostage to an
IDLE daemon that anything can stop (the Sunshine guard, the bar's pill, a crash). Now hyprlock is a
unit of its own and whoever wants to lock runs `systemctl --user start hyprlock.service`.

### Why a real unit and not a transient `systemd-run`

That was the previous trick. A real unit wins for the reason above PLUS three more:

- It stays OUTSIDE the `hypridle.service` cgroup, which is what prevents the REMOTE LOCKOUT
  diagnosed on 03/08/2026: the Sunshine guard's `systemctl --user stop hypridle` killed the whole
  cgroup (`KillMode=control-group`) and took hyprlock with it, leaving the compositor LOCKED WITH
  NO CLIENT to draw the password field.
- Idempotence for free, since `start` on an already active unit is a no-op, so the old
  `pidof hyprlock ||` goes away. Two session-lock surfaces confuse the keyboard grab and the
  password field stops typing; systemd guarantees one.
- The name is not left occupied after the unlock, which was `--collect`'s job.

The env (`WAYLAND_DISPLAY`, `HYPRLAND_INSTANCE_SIGNATURE`) comes from `systemd --user`, which the
session already imports. There is no `Restart`: a hyprlock that exits is an unlock, not a failure.

`ExecCondition` and not `ExecStartPre`, on purpose: failing there SKIPS the start silently and the
unit stays inactive, while a StartPre would mark it `failed`. It is the heir of the old
`pidof hyprlock ||` and today only covers a hyprlock that was NOT born from this unit, which is
just the TTY lockout rescue (`allow_session_lock_restore` in `hypr/lua/appearance.lua`).

**No `Install`/`wantedBy` on purpose**: what locks is the click or the idle, never the boot. The
hyprlock at boot is still the autostart one.

## Media and the idle lock

The 5 min timeout has no business landing in the middle of a movie, and music has no business
keeping the machine open. The gate is `lockscreen-idle-lock.service`: hypridle's `on-timeout`
starts it, and it calls `loginctl lock-session` unless FULLSCREEN VIDEO is playing.

**The policy, since 19/10/2026.** The lock is held back only while ONE process is both a window in
true fullscreen (Hyprland's state 2; maximized does not count) and the owner of an MPRIS name whose
`PlaybackStatus` is `Playing`. The PID of the MPRIS name comes from the BUS
(`GetConnectionUnixProcessID`), not from the player's own metadata, so the rule never trusts a
player name: a Spotify playing behind a fullscreen game is two processes and does not hold. The
hold is capped at 3 h in total, then it locks anyway, so a looping video cannot keep the session
open forever.

| Situation | Before 19/10/2026 | Now |
| --- | --- | --- |
| Spotify playing, nobody at the desk | never locked, all night | locks at 5 min |
| Anything paused | locked | locked |
| A film fullscreen in Zen or mpv | held until it stopped | held until it stops, at most 3 h |
| The same film in a window | held | locks at 5 min |
| A game fullscreen with music playing | held | locks at 5 min (the guard below covers streams) |
| Manual lock (`SUPER+L`, the bar) | always | always: the gate is only on the idle path |

**What it costs.** Music no longer keeps the screen open while I listen from the couch; the screen
locks, and the media keys keep working on a locked screen (`locked = true` in `keybinds.lua`).
That is the point of the change: audio playing is not evidence that someone is watching the screen.

IT WAITS, IT DOES NOT SKIP, and that is the whole design. Each hypridle listener fires ONCE per
idle cycle, so a gate that simply returned without locking would leave the machine open until the
next keystroke: a movie ending at 3 AM would mean an unlocked desktop until morning. Waiting keeps
the lock PENDING, and it lands up to 30 s after the video stops or leaves fullscreen, which is the
poll interval.

Coming back to the keyboard cancels it, through the listener's `on-resume` (`systemctl --user
stop`). The remaining race is the poll's width: the video would have to stop inside the same 30 s
window in which I come back, and the worst case there is a lock I was already getting anyway.

`PartOf = hypridle.service` because a PENDING lock belongs to the daemon that scheduled it. That is
what keeps the Sunshine guard working: `stream-begin` stops hypridle so the remote session does not
lock mid-way, and a gate left waiting in the background would fire the moment the video ended.

**Tested** by `nix build .#checks.x86_64-linux.lockscreen`, which runs the decision against
fixtures (`modules/home/desktop/lockscreen/scripts/test_idle_gate.py`): audio alone, paused video, a fullscreen game beside music,
a PID that is a prefix of another. Live and read-only on 19/10/2026, `lockscreen-idle-gate
--decide` answered `lock` with Spotify paused and nothing fullscreen, and the bus mapped Spotify's
MPRIS name to its main process. That a browser's fullscreen window and its MPRIS name share one
PID is REASONED from how Firefox and mpv register MPRIS (in the main process), not yet measured
with a film playing.

## Why `ignore_dbus_inhibit` stays true

Because the opposite looks like the obvious fix and is not. An app's inhibit is UNBOUNDED: a
browser that leaks one disables locking forever and in silence, and nothing on screen says so. The
gate is a single decision point, re-evaluated every 30 s, and it states its reason in the journal
(`fullscreen video is playing, the idle lock waits`, at notice priority).

Worth recording because it was not always so: the Arch `hypridle.conf` this module replaced carried
`ignore_dbus_inhibit = false`, and the port on 24/07/2026 flipped it to `true` with no reason
written down. It is a decision now, not a leftover.

## The quote, one per lock

The timer fetches a BATCH of ~50 from `zenquotes.io/api/quotes` (EN), filters it (non-empty,
<= 200 chars, without the rate-limit placeholder) and TRANSLATES it to pt-BR through DeepL in a
SINGLE batched request, with the key from `/run/secrets/deepl_api_key` (sops). The author stays in
the original. The batch is written atomically as `v2/quotes.json`; with no key or DeepL down it is
the ENGLISH batch, and a failed fetch keeps the previous one. Renewed once a day: ~50 quotes leaves
plenty of room in DeepL's free quota of 500k characters a month.

The renderer, not the lock, turns one quote into the card's text: escaped for pango, word-wrapped
by monospace COLUMNS (East Asian wide characters count two) to at most 4 lines of the card's width,
the next one drawn when a quote does not fit, and the author shown only when there is a real one
("Unknown" and "Anonymous" are never printed as if they were names). It is chosen ONCE for the
next lock and copied into the session at lock time, so it never changes while locked, and a
monitor plugged mid-lock shows the same one. With no batch at all it is the built-in Alan Kay
quote, so the card is never empty.

## The weather card, and when it refuses to show

The SOURCE and the pt-BR words are the SSOT in `my.weather` (`modules/home/desktop/weather.nix`),
the same forecast the bar draws (glance-feed's SQLite cache, one fetch per model run), and the
script's `case` arms are generated from it; the card's title is `my.weather.place`. It used to be
wttr.in with its own coordinates, and on 22/08/2026 the lock said 18°C while the bar said 22°C in
the same minute. The full reasoning is in [`weather.md`](weather.md).

**Freshness, so old data is never shown as current.** The timer writes three lines: until when the
value is valid (the end of its hour plus 15 min), when glance-feed fetched the forecast
(`updated_at`), and the markup. The label shows "Clima indisponível" when the hour is over (the
timer stopped) or when the forecast is older than 12 h, which is two missed ECMWF IFS runs: a
forecast up to about 6 h old is simply the newest model run. With no data the timer writes nothing,
and the old file ages into "unavailable" on its own.

## Media: the card and its bridge

Event-driven, with no new permanent service. `lockscreen-media.service` exists only inside a Media
lock (`BindsTo=hyprlock.service`, `ExecCondition` on the session's layout): it follows
`playerctl --all-players --follow` and rewrites `session/media` atomically on every change, so a
track change, a pause or a player leaving is on the card within the label's 3 s poll. Measured on
19/10/2026 with a throwaway mpv on null audio: the file was rewritten 66 to 96 ms after a play or a
pause (the first event after start took 2.3 s); the bridge costs about 15 MB (two bash and one
playerctl) and no CPU between events.

**Why the label polls a file instead of being pushed.** hyprlock 0.9.5 refreshes `cmd` labels on
SIGUSR2, but its handler (`handleForceUpdateSignal`) runs the label timers' callbacks INSIDE the
signal handler, which touches the resource gatherer's queue and mutexes from signal context. That
is the kind of race that corrupts a heap, and lesson 2 below is what a corrupted heap costs here.
A 3 s `cmd` label reading a file is the safe consumer of an event-driven producer.

What it shows: the state glyph, the title in bold and the artist under it, each cut by columns with
an ellipsis BEFORE pango escaping (so `&amp;` is never split), control characters dropped, markup
escaped (`patsub_replacement` is off, since bash 5.2 would expand `&` in the replacement). Which
player: whatever is PLAYING first, Spotify ahead of the rest, then a paused Spotify, then anything;
the bar puts Spotify first even when paused, but a lock card answers "what is playing". No player,
a stopped one or a dead bridge: "Nada tocando", never an empty card and never a stale title (the
bridge's PID heads the file and the label checks it is alive).

**Album art is deliberately left out.** An `image` widget that follows the track needs
`reload_time`, which is the continuous reload of lesson 2; loaded once, it would show the previous
track's cover after a change. Neither is acceptable on a lock.

## The layout is chosen once per lock

`lock-start.sh` asks `playerctl` (0.5 s timeout) whether anything is Playing as the lock begins:
yes is Media, anything else Ambient, and it holds for the whole lock. Switching would mean changing
the background under a running hyprlock, which only `reload_time` does. If the music stops mid-lock
the media card says "Nada tocando"; if music starts in an Ambient lock, the next lock shows it.

## The cache

Everything under `$XDG_CACHE_HOME/lockscreen/v2/`:

| Path | Written by | What |
| --- | --- | --- |
| `assets/<key>.png` and `<key>.json` | the renderer | one composed background and its report (alpha, contrast, source, credits) |
| `sets/<id>/` | the renderer | links to one asset per role and layout, the next quote, a manifest |
| `ready` | the renderer | a link to the newest complete set |
| `session/` | `lock-start.sh`, the bridge | what THIS lock shows: `primary`, `secondary`, `quote`, `layout`, `media` |
| `index.json` | the renderer | (size, mtime) to content hash, only to avoid re-hashing a big photo |
| `weather`, `quotes.json` | the two timers | the cards' data |

**The key is content, not time:** sha256 over the renderer's version, the photo's CONTENT hash, the
palette, the glass profile, the edge, the contrast targets, the layout's cards, the live size and
the focal point. Changing any of them renders anew; changing none is a cache hit (measured: 0.22 s
and 47 MB against 1.59 s and 161 MB for three fresh images).

**Atomic everywhere.** An image is written to a temp name, fsynced and renamed; a set is built in a
hidden directory and renamed whole; `ready` and the session links are swapped with `rename` over a
temp link. A reader sees the old thing or the new thing, never half. One renderer at a time, by an
`flock` on the cache; a second one leaves.

**Bounded.** After each run it keeps the 3 newest sets, plus whatever `ready` and the session point
at, deletes every asset nothing references, and sweeps temp files older than an hour. That is at
most a dozen images, around 50 MB with these photos; a total over 256 MB is logged.

**Never on the lock path, never a reason not to lock.** `lock-start.sh` only links files that
exist, carries a leading `-` in `ExecStartPre`, and falls back per image to the BUILD-TIME set: the
same renderer run once in a derivation over the packaged `nixos-artwork` images, so even an empty
cache, a full disk or a broken photo locks with real glass. Under all of that, hyprlock's `color`
paints the palette's bg if a link ever dangles, and any output nobody planned for gets the palette's
bg from a catch-all background instead of undefined pixels.

## The wallpapers

| Monitor | Pools | Fallback |
| --- | --- | --- |
| ASUS | `~/Pictures/lockscreen/wide/`: Japanese landscape prints | `nixos-artwork` catppuccin-mocha |
| LG | `~/Pictures/lockscreen/` (my portrait art, as in v1) | `nixos-artwork` waterfall, cropped |

**Two collections, on purpose (20/10/2026).** The lock is Japanese and contemplative, the desktop is
real galaxies, and until v3 the main monitor drew from the desktop's astronomy pool; now each has
its own. The lock's landscape pool started with 16 prints from The Met's Open Access collection
(Hiroshige's night rain, moon and snow views, Kyoto, Ōmi), public domain (CC0), chosen through its
v1.1 search API by `isPublicDomain` and a measured aspect of 1.3 and up; each carries a sidecar with
title, artist, date, credit line, the Met URL and the license. The desktop's wide pool
(`my.wallpaper.pools.wide`) got 13 Hubble galaxies picked from ESA/Hubble's Top 100 by the page's
own object type (M31, M51, M33, M104, M101, M82, M83, M106, NGC 1300, 1512, 1672, 7331, and NGC 5866
in the tall pool), each with object, distance, constellation, telescope, instrument, filters,
release date, credit and URL (CC BY 4.0), and the note that their colors are a filter composite.
Their originals run to 196 Mpx, which hyprpaper would hold whole in RAM, so they were reduced to
3840 px wide, and the sidecar keeps both resolutions. Downloaded once by hand, never by the lock.

**The images are STATE, not config (rule 6).** No binary enters git, no URL can rot the build, and
adding one is dropping a file in a folder; nothing is downloaded at lock time, or ever by the lock.
Each draw is random among the files that SUIT the monitor, validated by decoding the header: a wide
screen takes only landscape (aspect >= 1.2), a standing one prefers portrait and crops a landscape
only when no portrait exists, and anything that would need more than 1.5x upscaling, or that Pillow
cannot read, is never picked. A JPEG is decoded through `draft()` at the screen's size, so a
123 Mpx original (Webb's Cosmic Cliffs, tested) costs what a screen-sized one does.

**Provenance and crop.** A photo's facts live beside it as `<name>.json`, the format the desktop's
captions already use (`name`, `title`, `distance`, `constellation`, `credit`), plus an optional
`"focus": [x, y]` in 0..1 for where the crop centers. The renderer copies the sidecar into each
asset's report, so where an image came from and whose credit it carries stays next to it. To add
NASA, ESA, Hubble or Webb images, download them by hand into a pool with their sidecar; the lock
never fetches anything.

## The clock: seconds, from the system clock

The time comes from the system clock, which chrony keeps on NTS-authenticated NTP.br
([chrony](../network/network.md)); the timezone is `America/Sao_Paulo`. The lock adds no clock of its
own and claims no precision beyond the system's.

**What the timer really does** (hyprlock 0.9.5 source): a `cmd[update:N]` label re-arms its timer
when it FIRES, and the timer thread sleeps `(int)least + 1` ms, so every tick lands a little late.
Measured on 19/10/2026 in the headless harness (700 ticks per run, each command logging the instant
it ran), v1's `update:1000` ran every **1000.74 ms** on average (p5 999.7, p95 1001.4, max 1004).

**A period over one second MUST skip a second.** Fewer samples than seconds means one second has no
sample. The phase drifted 0.74 ms per tick, and when it wrapped past the boundary v1 printed
`14:15:14` and then `14:15:16`: one skipped second every 1000 / 0.74 = about 22 min. A first fix,
sleeping to the next boundary in the last 10 ms, was measured too and FAILED (it skipped
`14:15:13` instead): no command can print a second that was never sampled.

**The fix is the period.** `update:995` runs at about 995.7 ms, so every second gets at least one
sample, and every few minutes one gets two, with the same text, which changes nothing on screen.
The cost is the same single spawn per second, now a builtin `printf` in the `sh` hyprlock already
starts (2.0 ms of CPU against v1's 2.5).

| Run, 19/10/2026, headless harness | Ticks | Period | Phase wraps | Skipped seconds |
| --- | --- | --- | --- | --- |
| v1, `update:1000` and `date` | 700 | 1000.74 ms | 1 | 1 (`14:15:15`) |
| the boundary sleep, `update:1000` | 700 | 1000.72 ms | 1 | 1 (`14:15:13`) |
| v2, `update:995` and a builtin | 339 | 995.62 ms | 2 | 0 (2 repeated samples) |

What it does NOT fix is the lag: the display changes at the first sample after the boundary, so it
is 0 to 1 s behind the true second, sweeping slowly. Bounding it would take a faster timer (more
frames and wakeups) or a patched hyprlock, and neither is worth it for a lock screen.

**After a correction.** chrony slews small offsets, so the printed second simply follows the
system's. A step (a large correction, or a resume) is followed on the next tick, since every tick
reads the clock anew; when chrony is unsynchronized the lock shows the system's free-running time,
the same as every other clock on the desktop.

## Multiple monitors, hotplug and the way in

**The password buffer is global.** In hyprlock 0.9.5 the keys go to `CHyprlock::onKey`, which
appends to one `m_sPasswordState.passBuffer` and submits it to PAM on Enter, whatever output is
showing a field, or none. So losing the ASUS never strands the session: type the password blind on
the remaining screen and press Enter.

**And the screen says so.** One label on EVERY output (`monitor = ""`) reads the primary
connector's status in sysfs every 5 s: empty while it is `connected`, and "Tela principal
desconectada · digite a senha e pressione Enter" on a dark band otherwise. No second password field
anywhere, as the brief asked.

**Tested on 19/10/2026 in a headless sway 1.12** (2560x1440 plus a 1080x1920 rotated output, GL on
the B580's render node, hyprlock 0.9.5 with this config and the outputs renamed):

| Case | Result |
| --- | --- |
| the main output disabled while locked | hyprlock alive; the LG kept its cards |
| a wrong password typed with the main output GONE | PAM ran it (`Authentication failed`, attempt 1): the buffer is global |
| the main output back | a new lock surface with the clock, the date and the field |
| the standing output disabled and back | alive; its cards redrawn |
| a third output created mid-lock | a new surface, filled with the palette's bg |
| checking state | the field's hairline turned accent blue with the dots |

**What this does NOT prove.** sway is not Hyprland: Hyprland's own lock handling and its DP
reconnect on the `xe` driver were not exercised, and a CORRECT password was never typed (I do not
type mine into a test). A re-created Hyprland output keeps its connector name (DP-1), which is what
the per-monitor widgets match; a headless one in sway did not, so the "new output" row is the
catch-all, not the ASUS widgets. The real-session procedure is below.

## When the lock cannot reach the compositor

**The incident (found on 19/10/2026, in the journal).** In the boot of 18/10/2026 02:38 the boot lock
worked, and then EVERY idle lock failed: at 02:57, 03:20, 03:38, 05:23 and 06:01 hypridle asked for
the lock, `hyprlock.service` started, and hyprlock aborted in its constructor with `Couldn't connect
to a wayland compositor` (5 core dumps). The screen stayed OPEN each time, and nothing said so. The
unit takes `WAYLAND_DISPLAY` from the systemd user manager, and between 02:38 and 02:57 that value
stopped pointing at the live compositor. The root cause was NOT found: a `switch` re-executed the
user manager at 02:40, but the `switch` of 19/10 did the same and the lock kept working, so that
alone does not explain it. What it showed is the design flaw: a lock that depends on one inherited
variable, and fails in silence.

**The fix is in two parts, and neither depends on finding the cause.**

- **`lockscreen-launch` is the unit's `ExecStart`** (`modules/home/desktop/lockscreen/scripts/lock-launch.sh`). Before starting
  hyprlock it asks `hyprctl instances` for the live Hyprland instances, keeps those whose socket
  really exists, and locks the OLDEST one: the session's compositor is always older than a nested
  test one, so a stray variable pointing at a live test compositor does not win either. A wrong
  value is logged at warning priority with what was locked instead. With no Hyprland listed but a
  live `WAYLAND_DISPLAY`, it keeps that; with nothing alive, it fails the unit.
- **`OnFailure=lockscreen-lock-failed.service`** pushes an URGENT notification to the phone through
  `notify` (ntfy): a bubble on the desktop would be useless, since a failed lock means nobody is
  there. It also fires if hyprlock crashes mid-lock, which is just as worth knowing.

**Tested.** `test_lock_launch.py` (8 cases: stale, missing, a live nested compositor, a dead
instance, garbage from hyprctl, nothing alive) runs `--print` only, against fake instances and real
sockets in a scratch directory, so hyprlock never starts; a test that really launched it would find
the REAL session through `hyprctl` and lock it. Live and read-only on 19/10/2026, the built launcher
answered `wayland-1` with `WAYLAND_DISPLAY=wayland-9`, with it unset, and with it right, starting
nothing; one test push (labelled as a test, low priority) reached the phone through the same `notify`.

## Security model

- Locking is `hyprlock.service`, one unit, idempotent through `ExecCondition`, outside hypridle's
  cgroup: unchanged from v1. The new `Wants=lockscreen-media.service` cannot fail it.
- `ExecStartPre` is best effort and renders nothing; `ExecStopPost` only queues the next render
  with `--no-block`, after the unlock.
- PAM, LightDM's autologin, the boot-time lock in `autostart.lua` and Sunshine are untouched.
- Every string on screen that comes from outside (titles, artists, quotes, authors) reaches
  hyprlock as FILE CONTENT escaped for pango; none is ever spliced into a command line.
- No DPMS, no brightness, refresh rate or power-profile change: Eco stays with `power-idle-eco`.

## Power and performance

Measured on 19/10/2026 in the headless sway above (GL rendering, both outputs), 60 s windows of
`/proc/<pid>/stat` with the reaped label children counted:

| | CPU, % of one core | RSS, read soon after start |
| --- | --- | --- |
| v1 (blurred photo, padlock, 5 labels) | 0.60 | 68 MB |
| v2, Media layout, first build | 1.07 | 93 MB |
| v2, Media layout, clock inlined at 1000 ms | 0.82 | 92 MB |
| v2, Ambient layout, final config (995 ms) | 0.72 | (not comparable, see below) |
| the media bridge, between events | 0.00 | 4.5 MB (15 MB with playerctl) |
| one render of three images (cold) | 1.57 CPU-s once, after an unlock | 161 MB peak |
| the same render, cache hit | 0.22 CPU-s | 47 MB peak |
| a render from a 123 Mpx JPEG (Cosmic Cliffs) | 2.7 s wall | 159 MB peak |
| **v3**, Media layout, labels included (20/10/2026) | 0.80 | 91 MB |
| v3's observe collector, between rounds | 0.17 | 21 MB |
| v3's render of the ASUS image (4 cards, logo) | 0.9 s wall, once after an unlock | 159 MB peak |
| the GPU board, locked (v2, measured on the real desk 19/10/2026, 1 s energy samples) | 37.3 W, render idle 79.5% | |
| the GPU board, the 3 min before that lock (desktop in use) | 46.0 W, render idle 27.8% | |

Memory is approximate: the machine was 10 GB into swap during the runs, and later readings of the
idle test locks showed about half their pages swapped out (18 MB resident plus 18 MB in swap), so
only the readings taken right after a start are listed.

The difference is the LG's two extra cadences (media every 3 s, the hint every 5 s) and the two
full-screen images; every number is under 1% of ONE core. The GPU board rows were read from the
`xe` energy counter once a second during a real lock on 19/10/2026 (v2): locked, the board sat at
37 W with the render engine idle 80% of the time, which is the B580's own floor with both panels on,
not a cost of the lock. NOT measured: CPU package power while locked (its counter is root's), wall
power and the monitors (no sensor), and v3 on the real desk. The Eco hold and the profiles are
untouched.

## Testing

`nix build .#checks.x86_64-linux.lockscreen` runs 83 tests in the sandbox, against the spec JSON
the desktop really uses (`my.lockscreen.spec`), with only synthetic images:

| Suite | What it pins |
| --- | --- |
| `test_idle_gate.py` | the fullscreen-video policy |
| `test_lock_launch.py` | the lock reaches the session's compositor with a stale, missing or hostile `WAYLAND_DISPLAY` |
| Geometry | every layout fits its screen; the ASUS axis, its 32 px gaps and 800 px height; the LG grid; Ambient widens the weather and moves nothing; whole pixels; rotation and scale |
| Logo | cropped to its ink, scaled without distortion, centered; missing or broken renders without it |
| `test_observe.py` | energy units, holes and staleness, the comparable baseline; Claude resets, holes, errors, staleness; process deltas, PID reuse, app names without arguments; escaped markup |
| Selection | orientation grades, empty pools, invalid files, portrait preferred, cover and focus |
| Glass | the photo untouched outside the cards; AA over a white core; each card's baseline over a dark sky; the rim lit at the top; the shadow darkens without blurring; transmission; determinism |
| Profile | the numbers still mirror `Theme.qml` and `glass.lua` |
| Cache | the key moves with every input and only with content; atomic publish; corrupt assets; a full prepare with hits, collection, and a session kept through new sets |
| Quotes, Labels, Bridge | wrapping, escaping, authors, stale weather, dead bridge, the hint, cut-before-escape |

Every capture described in this note is a REAL hyprlock frame from the headless sway (`grim`),
not a mockup, and not a capture of the real monitors.

## The LG while locked

**One adapter, two screens.** `observe` (`modules/home/desktop/lockscreen/scripts/observe.py`,
stdlib only) reads the sources that already exist and adds none: power-log's CSV for energy,
glance-feed's SQLite (read-only) for Claude, `/proc` and `/sys` for the system and the processes.
Every snapshot carries its source, timestamp, age and status. `observe json energy` is what the
glance band's energy panel runs too, so the lock and the desktop cannot disagree.

**While locked**, `lockscreen-observe.service` (`BindsTo=hyprlock.service`, so it exists only for
the lock) writes each card as ready markup every 30 s (system, processes) and 60 s (energy,
Claude), headed by its PID and the time; the label shows a card only while that writer is alive and
the card is under 3 minutes old, and "Sem dados no momento" otherwise. No label touches the
network, walks `/proc` or reloads an image.

| Card | Shows | Rules it keeps |
| --- | --- | --- |
| Energy | measured CPU + GPU W, the split, the profile, render idle, CPU busy, 30 min graph, the Eco rest baseline | labeled "CPU + GPU medido", never the PC's power; a missing minute is a dot, never a low bar; the baseline only from comparable minutes (Eco, CPU under 10%, render idle over 70%: 53 W, where Eco alone also caught streams at 72 W) |
| Claude Code | session and week with resets, two 24 h graphs on 0 to 100% | a passed reset reads empty; values held hour to hour, never interpolated; missing is "–"; expired login and stale cache said in words |
| System | CPU % (a /proc/stat delta), RAM used and available (from MemAvailable, cache is not "used"), swap, GPU board W, clock and render idle, temperatures | the `xe` driver has no GPU utilization percentage, so none is shown; a GPU in RC6 reads "clock em repouso", not a number |
| Processes | the top 4 apps by CPU now and by memory | CPU from the tick delta of the same (pid, start time); apps grouped by systemd unit; memory as summed RSS, said so; only the unit or process name, never a command line, path or argument |
| Weather | São Carlos, temperature, condition, the day's range, rain chance, feels-like | the same freshness rule as before; a missing field drops out |
| Media | the playing track, artist, player and state | the bridge as before; no album art (it would need image reloads) |

The graphs are Unicode blocks (`▁` to `█`) in JetBrains Mono at 16 pt inside a pango label, with
absolute sizes: this pango ignores a percentage `size`. That is the reason the cards render as
TEXT and not as images: an image that changes needs `reload_time`, which is lesson 2 above.

## Known limitations

- **Unverified on the real session:** the look on the physical panels, Hyprland's handling of a
  DP unplug while locked, a correct password, GPU power. See the procedure below.
- The clock's lag (0 to 1 s, sweeping) is hyprlock's free-running timer; v2 only removes the
  skipped second.
- No live refraction or specular: the glass is a static image, its lens is baked.
- The LG's numbers move every 30 to 60 s, not live; no graph animates while locked.
- Process memory is summed RSS, so an app with many processes reads high; PSS would need a read
  of every process's smaps, which is not worth it every 30 s.
- The Met scans include the paper margin: on a wide screen some prints show their border.
- hyprlock has no focus state: the field is neutral at rest and blue only while checking.
- A media change shows within 3 s, not instantly (the SIGUSR2 path is unsafe in 0.9.5).
- The date label updates once a minute, so at midnight it may lag by up to 60 s.

## The first lock after switching, step by step

Nothing here locks the session by itself. After `! rebuild`:

1. `systemctl --user start lockscreen-prepare` and `journalctl --user -u lockscreen-prepare -n 20`:
   three `rendered` lines, or `the fallback stays` with the reason.
2. Keep a way back open BEFORE the first lock: an SSH session from another machine, or know the
   TTY path below.
3. `SUPER+L`. Check the ASUS (clock ticking, field), the LG (cards), type the password, unlock.
4. With music playing, lock again: the media card should appear and follow a track change.
5. Optional, from SSH while locked: unplug the ASUS cable, read the hint on the LG, type the
   password, press Enter.

## Troubleshooting

| Symptom | Look at |
| --- | --- |
| the NixOS art instead of my photos | `journalctl --user -u lockscreen-prepare`: "no usable photo" lists the pools; a photo too small or the wrong orientation is skipped |
| cards misplaced | `hyprctl monitors`: the renderer uses the live size; a changed mode renders anew on the next unlock |
| "Clima indisponível" | `systemctl --user status lockscreen-weather.timer`, then `glance-feed read weather` |
| "Nada tocando" with music on | `systemctl --user status lockscreen-media`; it only runs when the lock began in Media |
| an old quote every time | `systemctl --user status lockscreen-quotes`; `v2/quotes.json` |
| the lock does not appear | `systemctl --user status hyprlock` and its `ExecCondition` (a hyprlock not born from the unit) |

## Rollback

| Layer | How back |
| --- | --- |
| Configuration | `git revert` the v2 commits and `! rebuild`; or boot / `switch` to the previous generation (`sudo nixos-rebuild switch --rollback`). PAM is the same in both |
| Assets and cache | `rm -rf ~/.cache/lockscreen/v2`: the next lock uses the build-time fallback, the next unlock renders anew. It is all derived data |
| A blank or stuck lock | from a TTY (`CTRL+ALT+F2`) or SSH: `WAYLAND_DISPLAY=wayland-1 hyprlock` REATTACHES to the locked session (`allow_session_lock_restore` in `appearance.lua`) and draws the field again |
| The compositor itself | from SSH, `systemctl --user status hyprlock` and the journal first; relaunching hyprlock as above is the fix for an orphaned lock, and restarting Hyprland (which ends the session) is the last resort |

Never `pkill hyprlock` as a fix: killing the client does NOT unlock the session, it leaves the
compositor locked with nothing drawing the field, which is the lockout of 03/08/2026.
