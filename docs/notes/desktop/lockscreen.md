# The lock screen: hyprlock plus hypridle

`modules/home/desktop/lockscreen/default.nix`, with its renderer and scripts in
`modules/home/desktop/lockscreen/scripts/`. Ref: <https://wiki.hypr.land/Hypr-Ecosystem/hyprlock/>

## Lockscreen v5.1: an editorial ASUS, Bento cards on the LG, a modern type system (20/10/2026)

v3 had the right content in the wrong shape: four ASUS cards of four widths stacked into a ragged
silhouette that hid the print, and six LG cards of three heights that filled only the top 60% of
the screen, each with an empty lower half, all in one font, one weight and nearly one size. v4 keeps
the v2 architecture below and every guarantee (AA measured on the composited pixels, no fabricated
number, no command line, lock-scoped services, art and logo as state) and changes the composition;
v5 brought the type system and v5.1 (below) the Bento LG, the avatar and the one-size clock:

| Monitor | What it shows | What it never shows |
| --- | --- | --- |
| ASUS (`my.monitors.primary`) | the time with seconds and the date; my logo in an avatar, name and handle, with the password field; the quote of this lock | energy, Claude, the system, weather |
| LG (`my.monitors.secondary`) | six glass cards: energy, Claude Code, the system, processes, weather, and media in a Media lock | the time, the quote, my name, a password field |

**One type system, and everything stays TEXT.** v5 replaced v4's all-JetBrains-Mono look with four
families, picked from a bake-off rendered by the same pango 1.57 hyprlock uses. Lesson 2 (no image
reloads while locked) still holds: icons and charts are fonts, not pictures.

| Role | Family | Why |
| --- | --- | --- |
| clock, numbers, body | Geist (Vercel, OFL; the face Nothing OS adopted) | a modern grotesque from Thin to Black; `font_features="tnum"` keeps the clock's digits from dancing |
| labels and data | Geist Mono | the same design, aligned columns; caps tracked by 2 to 4 pt |
| icons | Material Symbols Rounded (Google, Apache 2.0) | ligatures (`bolt`, `memory`) on a variable weight axis: `@wght=300` keeps an icon as thin as the number beside it; `clock_loader_*` are the Claude rings |
| charts | Sparks (After the Flood, OFL, `pkgs/sparks-font`): Dot-line Thick for energy, Bar Medium for Claude's week | its `calt` turns `{30,60,90}` into a chart drawn by the font; one point is 0.35 em (line) or 0.30 em (bars), measured |

The families live in ONE `type` attrset in `default.nix`, which the labels read and `observe`
receives as a JSON file (`--type`). They are installed system-wide by `fonts.nix` but never become
a fontconfig default: the desktop's UI stays JetBrains Mono. Two pango details matter: a family
whose name ends in a weight word needs a trailing comma (`Sparks Dot-line Thick,`), or pango reads
"Thick" as a weight and falls back; and the icon axes go in the font description
(`Material Symbols Rounded 16 @wght=300,FILL=1`).

**The clock** (v5.1) is HH:MM:SS at ONE size, Geist Thin 144 pt with tabular digits, the `:SS` in
the accent at 85%: one string, centered as a whole, whose width never changes as the digits tick.
v5's small raised seconds were the iOS hierarchy; the one-size clock reads as one instrument.

Hierarchy comes from weight and size, not from boxes: a Thin hero, ExtraLight numbers (36 to
44 pt), SemiBold caps labels at 11 to 13 pt, a 14 pt body and a 12 pt meta line. Color carries the
section (energy orange, Claude violet, system blue, weather sky, media green) and appears only on
its caption, its icon and its marks; text is `text` or `subtext`, never `dim`, which fails AA.

**The ASUS is an editorial page on one axis** (`geometry.nix`). At the top, the clock and the date.
Then who is unlocking, as ONE group: the logo in a 112 px glass circle (the SVG cropped to its ink
and fitted into 72 px, recolored in `text`), 50 px above "Victor Ferreira" (Geist 20 pt) and
"v1cferr", and under them the field, 480x70 on its own glass with the same 16 px corner hyprlock
draws its hairline at (border at 85%, blue checking, red failed, yellow with Caps Lock) and a
legible placeholder. At the foot, the quote on a quiet glass reading surface (1200x280, baseline
0.40) at 21 pt, the original at 14 and the credit at 13. Legibility of the type over the art comes
from a **scrim**: a feathered shade of the palette's `bg` behind the column, measured only on the
text LINES (the geometry names them as zones), from 0.20 up to 0.94; every line there is `text`, so
it needs AA for one color only and stays at 0.70 to 0.76 over the cream paper of the Met prints.
Glass may sit on a scrim (it is a shade on the photo); two surfaces may not overlap. No text shadow
on the ASUS. The logo is STATE (`my.lockscreen.logo`, my SVG outside git); a missing or broken file
renders an empty avatar circle, and the lock never depends on it.

**The LG is six independent glass cards** on one grid: 72 px margins, 24 px gaps, rows from 184 px
down, every edge on the 8 px grid, the lower ~460 px left to the print. Energy and Claude Code are
full width (936x328), the system and the processes side by side (456x304), the weather and the
media under them (456x240). Ambient has no media card: the weather takes the whole row (936x240)
and splits into now and the day's context, instead of leaving an empty surface. Every card has the
same header policy (a 16 pt Material icon at weight 300, two spaces, tracked 12 pt caps, in the
card's color, 40 px from its top) and a 32 px inset.

| Section | Hero | Then |
| --- | --- | --- |
| Energy | the measured watts, Geist 56 pt, "CPU + GPU medidos" beside it | the 30 min line chart across the card, on a round range around the data that the meta line prints ("75 a 125 W"; a line shows a trend, so its scale hugs the data), "CPU package" and "GPU board" as meters, the Eco rest baseline and the profile |
| Claude Code | the 5 h session and the weekly limit side by side, each a progress ring (`clock_loader_10` to `_90`; an empty circle for nothing read, a filled one at 100%), the share and its reset | ONE chart: the week's last 7 days as held 4 h bars on a true 0 to 100% scale, with "há 7 dias … agora" under it (or "coletando desde …" while the feed holds less), and the last reset, observed or inferred |
| System | CPU %, RAM used, GPU render active %: a number in one mono column and a meter each | short caps names with their details in meta (temperatures, free RAM, GPU clock); never the GPU watts, which are the energy card's |
| Processes | the three apps using the most CPU now and the three holding the most memory | grouped by app, names only |
| Weather | the sky's glyph and the temperature | the condition, the day's range, rain, feels-like and "previsão das HH:MM" |
| Media | the title, Light 20 pt | the artist, the state and the player |

**The material** of every LG card is Adaptive Glass+: a frosted core (blur sigma 22, so the print's
shapes still read through,
the profile's tint, 6% of the accent, the bg-to-surface ease, ±1 dither), an optical rim (the
hairline plus text-colored light at 28% that fades by mid-height, and a 1.2% lens in a 6 px band
that never touches text), a soft highlight, and an ELEVATION shadow (35%, sigma 36, 14 px down).
Each card's baseline is 0.72 and it rises only as far as its text needs; the LG's text keeps one
light shadow pass.

**Claude's week, end to end.** glance-feed's `claude_usage` table keeps one row per change for 8 days;
its document carries the last 7 days plus the row before them, ONLY as the value the week opens
with (docs/notes/desktop/glance-feed.md). `observe` folds that into 42 buckets of 4 h, each the last
value known at its end (a step chart: a reset reads as the drop it was), None before the first
sample (drawn as an invisible point of the same width, never a zero), clamped to 0 to 100%. A drop
is a reset: "observed" when it spans the documented boundary (the next reset minus 7 days),
"inferred" otherwise. The Quickshell CLAUDE page reads the same document through
`ClaudeUsage.series("w", 7 days, 1 h)`, so the two screens cannot disagree.

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

**Adaptive opacity.** The profile gives a RANGE, not a number (the ASUS scrim follows the same rule
with its own range, 0.20 to 0.94). For each card the renderer tries
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
| the six LG data cards | 5 s each | `lockscreen-label obs <card>`: the observe service starts WITH the lock and writes about 1 s in, after the labels' first read, so a slower re-read left them "Sem dados" for a whole 30 to 60 s round (found on the desk, 20/10/2026) | |
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
senha…", "Nada tocando", the quotes in pt-BR (with the original under them). That decision is recorded in the July history,
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

The quotes are a CURATED collection in the repo,
`modules/home/desktop/lockscreen/quotes.json`, replacing the daily ZenQuotes batch that DeepL
translated (generic self-help, weak attribution, no context, and a free tier that asks for a credit
link). Four kinds, mixed:

| Kind | What | Shown as |
| --- | --- | --- |
| `stoic` | Marcus Aurelius, Seneca, Epictetus | a free pt-BR translation, the Greek or Latin under it |
| `literature` | Machado de Assis, Fernando Pessoa and his heteronyms | the original Portuguese, once |
| `haiku` | Bashō, Buson, Issa | a pt-BR translation in its 3 lines, the Japanese under it |
| `computing` | Kay, Dijkstra, Knuth, Hopper, Brooks, Perlis… | a pt-BR translation, the English under it |

**The sources policy.** An entry goes in only with a precise source (a work and its section, an
EWD number, a paper or talk with its year), checked against a primary text (Perseus, Wikisource,
Gutenberg, Arquivo Pessoa, the E.W. Dijkstra Archive) or Quote Investigator. A famous line whose
earliest source is doubtful is left out on purpose: fewer real quotes beat many doubtful ones. The
translations are free translations made for this collection, never a copied modern one. Each entry:

```json
{"id": "…", "kind": "stoic", "text": "pt-BR…", "original": "…", "lang": "grc",
 "author": "Marco Aurélio", "source": "Meditações, IV.3", "year": "c. 170"}
```

**Choosing.** The renderer picks the next lock's quote at `prepare`, from what was not shown yet:
the ids go to `~/.local/state/lockscreen/quotes-seen.json` (state, not cache), and the history
resets only when everything was seen, never repeating the last one. A quote drawn by the 6 h timer
for a set that is never shown still counts as seen. **Haiku sit beside the prints**: they are
eligible only when the ASUS image has a sidecar with an `artist`, and then about one draw in three
is a haiku (`haikuShare`). The quote is chosen ONCE for the lock and copied into the session at
lock time, so it never changes while locked; with no usable collection it is the built-in Alan Kay
quote, so the band is never empty.

**The band** shows the text in italics at a 72-column measure (a haiku keeps its own lines, without
quotation marks), the original smaller in `subtext`, and `author · source · year`, dropping the
year and then the source before the credit would overflow. An entry that does not fit is skipped,
and `test_render.py` fails if any entry in the collection does not fit or breaks the schema.

**Adding a quote** is editing `quotes.json` and `! rebuild`; the test says if it breaks a rule.
The DeepL key's declaration went with the old pipeline; the key itself is still in Bitwarden, to
delete there if it has no other use.

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
| `weather` | the weather timer | the weather card's data |

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
| v4, Media layout, 20 labels, music paused (20/10/2026): hyprlock ITSELF only | 0.38 | 94 MB |
| v5, Media layout, 20 labels: hyprlock itself + its label children | 0.38 + 0.62 = 1.00 | 93 MB |
| v5.1, Media layout, 25 labels (Bento, split weather): itself + children | 0.50 + 0.88 = 1.38 | 93 MB |
| **v5.1**, the cards re-read every 5 s (so they show seconds after the lock, not a round later) | 0.75 + 1.37 = 2.12 | 93 MB |
| v5.1 render, ASUS (scrim, avatar with logo, field, quote) | 2.8 s wall, once after an unlock | 190 MB peak |
| v5.1 render, LG Media (six cards) | 1.5 s wall | 149 MB peak |
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

`nix build .#checks.x86_64-linux.lockscreen` runs 100 tests in the sandbox, against the spec JSON
the desktop really uses (`my.lockscreen.spec`), with only synthetic images:

| Suite | What it pins |
| --- | --- |
| `test_idle_gate.py` | the fullscreen-video policy |
| `test_lock_launch.py` | the lock reaches the session's compositor with a stale, missing or hostile `WAYLAND_DISPLAY` |
| Geometry | every layout fits its screen; glass may sit on a scrim, two surfaces never overlap; the ASUS on one axis, the avatar a true circle above the field, both inside the column; the LG's six cards at their exact rects on the 8 px grid, Ambient widening only the weather; whole pixels; rotation and scale |
| Logo | cropped to its ink, scaled without distortion, centered; missing or broken renders without it |
| `test_observe.py` | energy units, holes and staleness, the comparable baseline; Claude resets, holes, errors, staleness; process deltas, PID reuse, app names without arguments; escaped markup; the ring's steps; rows that fit their columns; the sparkline's scale, floor, clamping, holes as gaps and its width |
| Selection | orientation grades, empty pools, invalid files, portrait preferred, cover and focus |
| Editorial | the scrim reaches AA over a bright photo, darkens without blurring and fades to an untouched photo |
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
the lock) writes each piece of a section as ready markup every 30 s (the system's three columns and
its apps) and 60 s (energy, Claude's two halves), headed by its PID and the time; the label shows a
piece only while that writer is alive and it is under 3 minutes old, and "Sem dados no momento" otherwise. No label touches the
network, walks `/proc` or reloads an image.

| Section | Shows | Rules it keeps |
| --- | --- | --- |
| Energy | measured CPU + GPU W, the split, the profile, 30 min graph and its scale, the peak, the Eco rest baseline | labeled "CPU + GPU medido", never the PC's power; a missing minute is a dot, never a low bar; the baseline only from comparable minutes (Eco, CPU under 10%, render idle over 70%: 53 W, where Eco alone also caught streams at 72 W) |
| Claude Code | session and week with resets, two 24 h graphs on 0 to 100% | a passed reset reads empty; values held hour to hour, never interpolated; missing is "–"; expired login and stale cache said in words |
| System | CPU % (a /proc/stat delta), RAM used and available (from MemAvailable, cache is not "used"), GPU board W and render active, temperatures | the `xe` driver has no GPU utilization percentage, so the GPU meter is render ACTIVE time and says so |
| Apps | the top 3 apps by CPU now | CPU from the tick delta of the same (pid, start time); apps grouped by systemd unit; memory as summed RSS, said so; only the unit or process name, never a command line, path or argument |
| Weather | São Carlos, temperature, condition, the day's range, rain chance, feels-like | the same freshness rule as before; a missing field drops out |
| Media | the playing track, artist, player and state | the bridge as before; no album art (it would need image reloads) |

The charts are the Sparks font inside a pango label, sized so the points span their width (one
data point is 0.35 em, measured): the energy chart across the panel, the 24 h strips across a half.
Sizes are absolute: this pango ignores a percentage `size`. That is the reason the charts render as
TEXT and not as images: an image that changes needs `reload_time`, which is lesson 2 above.

## Known limitations

- **Unverified on the real session:** the look on the physical panels, Hyprland's handling of a
  DP unplug while locked, a correct password, GPU power. See the procedure below. v5.1's field
  states past typing (checking, a wrong password, Caps Lock) are unverified too: in the headless
  sway, `wtype` types into hyprlock (the dots appear) but its Enter arrives as a stray key event
  that hyprlock refuses, so no password is ever submitted there.
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
3. `SUPER+L`. Check the ASUS (clock ticking, avatar, field), the LG (the six cards), type a WRONG
   password first (the red hairline and the PAM message), then the right one, and unlock.
4. With music playing, lock again: the media half should appear and follow a track change.
5. Optional, from SSH while locked: unplug the ASUS cable, read the hint on the LG, type the
   password, press Enter.

## Troubleshooting

| Symptom | Look at |
| --- | --- |
| the NixOS art instead of my photos | `journalctl --user -u lockscreen-prepare`: "no usable photo" lists the pools; a photo too small or the wrong orientation is skipped |
| cards misplaced | `hyprctl monitors`: the renderer uses the live size; a changed mode renders anew on the next unlock |
| "Clima indisponível" | `systemctl --user status lockscreen-weather.timer`, then `glance-feed read weather` |
| "Nada tocando" with music on | `systemctl --user status lockscreen-media`; it only runs when the lock began in Media |
| the same quotes coming back | `~/.local/state/lockscreen/quotes-seen.json`: it resets only after the whole collection was shown |
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
