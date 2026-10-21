# The lock screen: Quickshell, hyprlock as the fallback, and hypridle

The lock is a Quickshell instance of its own (`modules/home/desktop/quickshell/lock.qml` and
`quickshell/lock/`), launched by `modules/home/desktop/lockscreen/default.nix`, with hyprlock kept
as a plain fallback and hypridle for the idle. Ref:
<https://quickshell.org/docs/v0.3.2/types/Quickshell.Wayland/WlSessionLock>

## v6: the lock in QML (21/10/2026)

**Why it moved.** Up to v5.3 the lock was hyprlock, which can only show static images and text. Every
"glass" card was therefore an image pre-rendered in Python (`render.py`, Pillow) and pasted behind
hyprlock's labels; the labels were shell commands reading files that a Python collector
(`observe.py`) wrote while locked. It never looked like glass, it shared nothing with the glance
band, and it took about 4,200 lines in four languages. The user's verdict on 21/10/2026: the blocks
"do not look like glass and have no integration", and too much code. Quickshell, which already
draws the bar and the band, has the same secure lock protocol hyprlock uses (`ext-session-lock`
through `WlSessionLock`) and native PAM (`Quickshell.Services.Pam`), so the lock moved there.

**What the user chose**, from real captures of the prototype (headless sway):

- **ASUS:** type straight on the print, no cards. The clock stacked on the calmer side, the field
  and a short quote centered at the foot.
- **LG:** four rows of real glass, every card the same system: a quiet label, ONE hero number, one
  chart, one line of context.
- **One accent:** the hanko's vermilion (`#c4342c`), only in the charts, the caret, a failure and
  Caps Lock.
- **Bokashi, stronger:** where the print would break AA under the type, a graded wash of the
  paper's or the indigo's tone, as strong as the measured contrast needs.
- 220 MB of memory while locked is acceptable.

The repo's language rule came out of the same conversation: Nix, Lua, QML and Shell only, so the
lock has no Python left. See [languages.md](../repo/languages.md).

## The architecture

| Piece | Where | What |
| --- | --- | --- |
| The unit | `lockscreen.service` (`default.nix`) | runs `lockscreen-launch`; one owner, idempotent |
| The launcher | `modules/home/desktop/lockscreen/scripts/lock-launch.sh` | finds the session's compositor, starts the QML lock, falls back to hyprlock |
| The lock | `quickshell/lock.qml` | `WlSessionLock`, one `Face` per output, quits after an unlock |
| Auth | `quickshell/lock/Auth.qml` | the ONE password buffer and the PAM conversation, shared by every output |
| Faces | `quickshell/lock/AsusFace.qml`, `LgFace.qml` | chosen by connector in `Face.qml`; keys from any output go to the buffer |
| The logo | `quickshell/lock/Logo.qml`, `my.lockscreen.logo` | the logo in the type's ink, beside the signature |
| The print | `quickshell/lock/Wallpaper.qml` | picks from the pools, decodes to cover the screen, crops at the sidecar's focus |
| The ink | `quickshell/lock/Ink.qml`, `InkMath.qml` | the side, the ink and the shade, measured on the shown print |
| The quote | `quickshell/lock/Quotes.qml`, `QuoteMath.qml` | the curated collection, no repeats, haiku beside prints |
| The glass | `quickshell/widgets/LiquidGlass.qml` | a live blur of the print under each card |
| The data | `quickshell/data/Energy.qml`, `System.qml`, `Weather.qml`, `dash/ClaudeUsage.qml` | the same singletons the band reads |
| The fallback | `programs.hyprlock` in `default.nix` | the palette, the time and a field on every output, nothing that can fail |
| PAM | `modules/nixos/desktop/desktop.nix` | `quickshell-lock`, and `hyprlock` for the fallback |

**A store snapshot, never the live tree.** The shell's QML is linked mutable so it hot-reloads on
save (`quickshell.nix`); the lock runs from `builtins.path` of the same tree in the store, so
editing the repo never reloads a running lock. A change to the lock's look takes a rebuild.

**Its own instance.** `qs -p <snapshot>/lock.qml` is a separate process from the bar and the band:
a bug there cannot reach the lock, and the lock's singletons (`System`, `Energy`) only sample while
it exists. `root:/` is the same tree, so it reuses `Theme`, `widgets/`, `Feed.qml` and the band's
data.

## The launcher and the fallback

`lockscreen-launch` (`modules/home/desktop/lockscreen/scripts/lock-launch.sh`):

1. **Finds the session's compositor** as before (see below), even with a stale `WAYLAND_DISPLAY`.
2. **Starts the QML lock** and waits up to 5 s for `$XDG_RUNTIME_DIR/lockscreen/secure`, which the
   lock writes once the compositor confirms every output is covered (`WlSessionLock.secure`).
3. **No mark in time means no lock:** it kills the QML process and execs hyprlock, which locks.
4. **After the lock ends,** only the word `unlocked` in that file counts as an unlock. The lock
   writes it on a PAM success, before it releases the session. An exit without it (a crash, a
   signal, even a clean exit by mistake) left the compositor locked with no client, so the launcher
   execs hyprlock, which REATTACHES to the locked session (`allow_session_lock_restore = true` in
   `hypr/lua/appearance.lua`) and draws a field.

So the screen is never left open by a broken QML lock, and never left locked with nothing to type
into. Stopping the unit (the session ending) kills the launcher too, so it never falls back then.

**The fallback is plain on purpose.** No labels running commands, no images, no cards: the
palette's background, `$TIME` and a field on EVERY output (`monitor = ""`), so it unlocks even with
a monitor gone. It is the safety net, not a second design.

## Auth, and every output typing into one field

`Auth.qml` holds one buffer. Each `Face` takes focus and sends printable keys to it: Enter submits,
Backspace erases, Ctrl+Backspace and Esc clear. The compositor gives keyboard focus to ONE lock
surface (often the LG), so a buffer per output would strand the password; one shared buffer means
typing on either screen fills the same field, as hyprlock's global buffer did.

PAM is `quickshell-lock`, the same default stack as hyprlock's (`{ }` in `desktop.nix`). The lock
answers ONE prompt per attempt; a second prompt (a module asking for more) aborts the attempt. A
failure clears the buffer, shakes the field and says "senha incorreta"; the harness has a fake PAM
(`pam_exec` with a test password) so both outcomes are tested without the real password.

**With the ASUS unplugged** the LG says "Tela principal desconectada · digite a senha e pressione
Enter" and echoes the dots, so the session is never stranded.

## The ASUS: type on the print

- **The clock:** HH over mm in Geist Light 220 px, the date under it ("quarta, 21 de outubro"),
  on the CALMER side of the print. Minute precision from `SystemClock`; the old per-second label
  and its timer workaround went with hyprlock.
- **The signature and the logo** (21/10/2026, the user's choice): under the date, as a Japanese
  print carries its artist's, my full name and `v1cferr` in the clock's ink, and beside them the
  logo, 56 px, in the same ink with no frame (`lock/Logo.qml`; the SVG's alpha masks the ink,
  since colorization keeps black black). It began as a vermilion seal, and the user dropped the
  red the same day. The name is git's `user.name` and the handle the account's (`LOCK_NAME`,
  `LOCK_USER` from the launcher); the logo is `my.lockscreen.logo`, a path to STATE (the SVG in
  Dropbox), never in git. No file, no logo; the lock locks the same. The clock's ink zone covers
  the signature, so its AA and bokashi hold.
- **The field:** no box. A hairline, the dots, a vermilion caret; "verificando…" while PAM runs;
  a failure shakes it; Caps Lock shows in vermilion under it (read from the keyboard LEDs in
  `/sys/class/leds`, polled only while locked).
- **The quote:** the text, the original smaller, `author · source · year`.

**Two inks, measured apart.** `Ink.qml` grabs the shown print at 192 px wide and `InkMath.qml`
reads two zones: the clock column (left, and its mirror on the right) and the foot. For the clock
it picks the side with less detail (a tie stays left). For each zone it picks the ink, light text
or dark sumi, with the better WCAG contrast against the zone's worst pixels (the 2nd and 98th
percentiles, with a 10% margin over the target), and the SHADE: how opaque a wash of the opposite
tone must be under the type to reach AA. The shade is solved in sRGB, because that is where an
alpha blends (solving it in linear light made it a third too weak).

**Bokashi, not a scrim.** The shade becomes a graded band, the printmaker's own wash: across the
foot (half the screen's height, fading upward) and along the clock's side, in the paper's tone
behind dark ink or the indigo's behind light ink. Zero when the print already reads; never a box,
never a dark scrim over the whole screen (the user rejected that in v5.2). A tight glyph halo of
the same tone sits on the type itself.

## The LG: one hero number per glass card

| Card | Hero | Chart | Context |
| --- | --- | --- | --- |
| Energia | measured CPU + GPU watts | the last 30 min, a line | CPU, GPU, the peak |
| Claude Code | session % and week % | the week, 4 h bars | when each resets |
| Sistema | CPU % now | its last two minutes | RAM used, GPU temperature |
| Processos | the top three apps by CPU now | none | "% de um núcleo" |
| Clima, or Tocando | the temperature and the sky | none | max, min, rain, feels-like |

Tocando replaces Clima while a player PLAYS (`Quickshell.Services.Mpris`, live), with the title,
the artist and a vermilion progress line. The old bridge script and the once-per-lock layout choice
are gone: the card follows the player while locked.

**Real glass.** `LiquidGlass.qml` samples the print under the card (`ShaderEffectSource` on the
region it covers), blurs it and carries its color through (`MultiEffect`: blur 1.0 of 64, saturation
0.35, brightness -0.08), then a tint of the palette's bg, a top sheen, a hairline rim and a soft
`RectangularShadow`. The tint is measured, not guessed: an `Ink` over the cards' area finds how much
dark tint keeps light text AA on THIS print (at least 0.32). The region is re-read after layout,
because a binding cannot see an ancestor (the Column) move its children. It samples an Item, not
the compositor, so it works over the lock's own print, not over windows.

**The numbers are honest.** Energy is the MEASURED CPU package plus GPU board, never "the PC's
power"; a minute with no sample is a gap in the line, never a zero; RAM is used from
`MemAvailable` (cache is not used); the GPU shows temperature, not a utilization the `xe` driver
does not report; processes are app names from their systemd unit, never a command line.

## The data, shared with the band

| Singleton | Reads | Cadence |
| --- | --- | --- |
| `data/Energy.qml` (+ `EnergyMath.qml`) | power-log's last two monthly CSVs, through `tail` | 1 min |
| `data/System.qml` (+ `SystemMath.qml`) | `/proc/stat`, `/proc/meminfo`, the xe sysfs (rc6, frequency, the `pkg` temperature), every `/proc/*/stat` and cgroup | 2 s, processes 5 s |
| `data/Weather.qml` | glance-feed's cache (`glance-feed read weather`) and `my.weather`'s pt-BR conditions | on change, and every 5 min |
| `dash/ClaudeUsage.qml` | glance-feed's `claude_usage` document | on change |

The band's energy panel reads `data/Energy.qml` too, so the lock and the desktop cannot disagree.
Nothing here touches the network: glance-feed owns every fetch
([glance-feed.md](glance-feed.md)).

## The quote, one per lock

The quotes are a CURATED collection in the repo, `modules/home/desktop/lockscreen/quotes.json`.
Four kinds, mixed:

| Kind | What | Shown as |
| --- | --- | --- |
| `stoic` | Marcus Aurelius, Seneca, Epictetus | a free pt-BR translation, the Greek or Latin under it |
| `literature` | Machado de Assis, Fernando Pessoa and his heteronyms | the original Portuguese, once |
| `haiku` | Bashō, Buson, Issa | a pt-BR translation in its 3 lines, the Japanese under it |
| `computing` | Kay, Dijkstra, Knuth, Hopper, Brooks, Perlis… | a pt-BR translation, the English under it |

**The sources policy.** An entry goes in only with a precise source (a work and its section, an
EWD number, a paper or talk with its year), checked against a primary text (Perseus, Wikisource,
Gutenberg, Arquivo Pessoa, the E.W. Dijkstra Archive) or Quote Investigator. A famous line whose
earliest source is doubtful is left out on purpose. The translations are free translations made for
this collection. Each entry:

```json
{"id": "…", "kind": "stoic", "text": "pt-BR…", "original": "…", "lang": "grc",
 "author": "Marco Aurélio", "source": "Meditações, IV.3", "year": "c. 170"}
```

**Choosing** (`QuoteMath.qml`, ported rule for rule from the old renderer): the lock picks one not
shown yet; the ids go to `~/.local/state/lockscreen/quotes-seen.json` (state, not cache), and the
history resets only when everything was seen, never repeating the last one. **Haiku sit beside the
prints**: they are eligible only when the ASUS print has a sidecar with an `artist`, and then about
one draw in three is a haiku. An entry that does not fit the measure (64 columns, 3 lines; the
original 90 columns, 2 lines) is skipped; the credit drops the year, then the source, before it
would overflow. With no usable collection it is the built-in Alan Kay quote. Polytonic Greek is set
in Noto Sans, which has it (Geist does not).

**Adding a quote** is editing `quotes.json` and `! rebuild`.

## The wallpapers

| Monitor | Pool (`LOCK_POOL_*` in `default.nix`) | No usable file |
| --- | --- | --- |
| ASUS | `~/Pictures/lockscreen/wide/`: Japanese landscape prints | the palette's gradient |
| LG | `~/Pictures/lockscreen/` (one level deep: my portrait art) | the palette's gradient |

**Two collections, on purpose (20/10/2026).** The lock is Japanese and contemplative, the desktop
is real galaxies. The lock's landscape pool started with 16 prints from The Met's Open Access
collection (Hiroshige's night rain, moon and snow views, Kyoto, Ōmi), public domain (CC0); each
carries a sidecar with title, artist, date, credit line, the Met URL and the license.

**The images are STATE, not config (rule 6).** No binary enters git, and nothing is downloaded at
lock time, or ever by the lock. Each lock draws a random file from its pool (symlinks followed),
skipping the last five shown on that monitor (`seen-primary.json`, `seen-secondary.json` in
`~/.local/state/lockscreen`). The image is decoded straight to cover the screen (`sourceSize`), so a
100 Mpx print never lands in memory at full size, and cropped around the sidecar's optional
`"focus": [x, y]`.

## Locking cannot depend on hypridle

Until 10/08/2026 the only path to locking was `loginctl lock-session`, which does NOT lock anything
on its own: it only sets `LockedHint` and emits the `Lock` signal on D-Bus. What listened was
hypridle, through `lock_cmd`. With hypridle stopped (6 h on 10/08/2026, the Sunshine guard holding
it after a client died with no teardown) the bar's "Lock" did nothing, with no error.

Locking is a SECURITY FUNCTION and cannot be hostage to an IDLE daemon that anything can stop. The
lock is a unit of its own, `lockscreen.service` (it was `hyprlock.service` until v6), and whoever
wants to lock runs `systemctl --user start lockscreen.service`: hypridle's `lock_cmd`, the boot's
line in `autostart.lua`, the bar's Lock action.

**Why a real unit and not a transient `systemd-run`:**

- It stays OUTSIDE the `hypridle.service` cgroup, which prevents the REMOTE LOCKOUT of 03/08/2026:
  the Sunshine guard's `systemctl --user stop hypridle` killed the whole cgroup and took the lock
  client with it, leaving the compositor LOCKED WITH NO CLIENT.
- Idempotence for free: `start` on an active unit is a no-op. Two session-lock clients confuse the
  keyboard grab; systemd guarantees one.
- The name is not left occupied after the unlock.

`ExecCondition` (not `ExecStartPre`) skips the start silently while a hyprlock started by hand runs
(the TTY rescue). There is no `Restart`: a lock that exits is an unlock. **No `Install`** on
purpose. Zen's close-after-lock guard binds to this unit ([zen.md](../apps/zen.md)).

## Media and the idle lock

The 5 min timeout has no business landing in the middle of a movie, and music has no business
keeping the machine open. The gate is `lockscreen-idle-lock.service`: hypridle's `on-timeout`
starts it, and it calls `loginctl lock-session` unless FULLSCREEN VIDEO is playing.

**The policy, since 19/10/2026.** The lock is held back only while ONE process is both a window in
true fullscreen (Hyprland's state 2; maximized does not count) and the owner of an MPRIS name whose
`PlaybackStatus` is `Playing`. The PID of the MPRIS name comes from the BUS
(`GetConnectionUnixProcessID`), not from the player's own metadata, so a Spotify playing behind a
fullscreen game is two processes and does not hold. The hold is capped at 3 h, then it locks anyway.

| Situation | Before 19/10/2026 | Now |
| --- | --- | --- |
| Spotify playing, nobody at the desk | never locked, all night | locks at 5 min |
| Anything paused | locked | locked |
| A film fullscreen in Zen or mpv | held until it stopped | held until it stops, at most 3 h |
| The same film in a window | held | locks at 5 min |
| A game fullscreen with music playing | held | locks at 5 min (the Sunshine guard covers streams) |
| Manual lock (`SUPER+L`, the bar) | always | always: the gate is only on the idle path |

IT WAITS, IT DOES NOT SKIP. Each hypridle listener fires ONCE per idle cycle, so a gate that
returned without locking would leave the machine open until the next keystroke. Waiting keeps the
lock PENDING; it lands up to 30 s (the poll) after the video stops. Coming back to the keyboard
cancels it through the listener's `on-resume`. `PartOf = hypridle.service`, because a pending lock
belongs to the daemon that scheduled it: the Sunshine guard stops hypridle so a stream never locks.

## Why `ignore_dbus_inhibit` stays true

An app's inhibit is UNBOUNDED: a browser that leaks one disables locking forever and in silence.
The gate is a single decision point, re-evaluated every 30 s, and it states its reason in the
journal (`fullscreen video is playing, the idle lock waits`, at notice priority). The Arch config
this replaced had `false`; the port flipped it on 24/07/2026, and it is a decision now.

## When the lock cannot reach the compositor

**The incident (18/10/2026, found in the journal).** After the boot lock worked, EVERY idle lock
failed: the lock aborted with `Couldn't connect to a wayland compositor`, and the screen stayed
OPEN each time, in silence. The unit takes `WAYLAND_DISPLAY` from the systemd user manager, and
that value stopped pointing at the live compositor. The root cause was not found; the design flaw
was a lock depending on one inherited variable.

**The fix, independent of the cause:**

- **The launcher asks `hyprctl instances`**, keeps those whose socket really exists, and locks the
  OLDEST one: the session's compositor is always older than a nested test one. A wrong value is
  logged at warning priority; with no Hyprland but a live `WAYLAND_DISPLAY` it keeps that; with
  nothing alive it fails the unit.
- **`OnFailure=lockscreen-lock-failed.service`** pushes an URGENT notification to the phone through
  `notify` (ntfy): a desktop bubble is useless when nobody is there.

## Security model

- One unit, idempotent, outside hypridle's cgroup; the launcher never leaves the screen open (no
  `secure` in 5 s is hyprlock) nor locked with no client (no `unlocked` is hyprlock).
- The lock runs from the store, never from the mutable tree.
- The password lives in one QML string while typed and goes only to PAM; it is never logged, never
  on a command line. A QML `Process` here only reads (`find`, `cat`, `tail`, `glance-feed read`).
- Strings from outside (titles, artists, quotes) are plain `Text`, never markup that runs anything.
- PAM, LightDM's autologin, the boot-time lock and Sunshine are untouched.
- No DPMS, brightness, refresh rate or power-profile change: Eco stays with `power-idle-eco`.

## Hardware lessons, durable and independent of the GPU. Do NOT touch

1. **A static print, never a screenshot of the desktop under the lock.** hyprlock's
   `path = screenshot` segfaulted on wake (the DMA frame destroyed on exit), a lockout. The QML
   lock draws only its own print.
2. **dpms-off REMOVED (jul/2026).** Turning the screen off on idle broke Sunshine (wlr capture on
   `xe` got a BLACK SCREEN) and toggling dpms under capture caused a GPU ENGINE RESET. Idle ONLY
   locks. See [`sunshine.md`](../network/sunshine.md).

## Language: a deliberate exception

The system is en-US and the lock screen is pt-BR: the date, the field, the cards, the quotes (with
the original under them). Those strings are the product, not untranslated debt.

## Power and performance

Measured on 21/10/2026 in the headless sway (GL on the B580's render node, both outputs, 30 s of
`/proc/<pid>/stat`):

| | CPU, % of one core | RSS |
| --- | --- | --- |
| **v6**, the QML lock, both faces, data sampling | 1.93 | 220 MB |
| v5.1, hyprlock plus its label children (the last measured hyprlock) | 2.12 | 93 MB |

The memory is Qt's and the two decoded prints, and only exists while locked: the process exits on
unlock. NOT measured: GPU power while locked on the real desk (v2's lock sat at 37 W on the board
with render idle 80%, the B580's floor with both panels on).

## Testing

| Check | What it pins |
| --- | --- |
| `nix build .#checks.x86_64-linux.lockscreen` | `modules/home/desktop/lockscreen/scripts/test.sh`, bash: the launcher reaches the session's compositor with a stale, missing or hostile `WAYLAND_DISPLAY`; five fallback cases (unlock, death while locked, a clean exit without an unlock, never locking, failing to start); the idle gate's video policy |
| `nix build .#checks.x86_64-linux.quickshell-logic` | `quickshell/tests/`, Qt's `qmltestrunner`, headless: quotes (wrap, schema, no repeat, haiku pairing), ink (contrast, the side, the shade), energy (holes, staleness, the Eco baseline), system (CPU, memory, app names) |

**The harness** (`~/.cache/lockscreen-dev/harness`, outside the repo) runs a headless sway with two
outputs and a guard that refuses unless the socket belongs to that sway; the BUILT launcher is run
there with the instance list pinned to the test sway, because a bare `hyprctl instances` would find
the live session and lock it. Checked there on 21/10/2026: a wrong password refused, the right one
(fake PAM) unlocking with exit 0 and no fallback, SIGKILL on the locked QML handing over to the
fallback, a QML file that does not load replaced in 5 s. `wtype` loses the first key of each run
(a keymap race in the harness only), so every run starts with a throwaway key.

## Known limitations

- **Unverified on the real desk:** the look on the physical panels, Hyprland's own lock handling
  (the harness is sway), the real password, a DP unplug while locked, and Caps Lock on a real
  keyboard. See the procedure below.
- A pool's file is not checked for orientation or size any more: a landscape file in the LG's pool
  is cropped to portrait.
- The glass blurs the lock's own print only; it cannot show windows (the lock hides them anyway).
- A very busy print still shows through the bokashi: the shade is measured on a reduced grab, so
  its worst pixel is not the single worst pixel (the foot's wash takes 1.3x the measured shade).
- Process memory is summed RSS, so an app with many processes reads high.

## The first lock after switching, step by step

Nothing here locks the session by itself. After `! rebuild`:

1. Keep a way back open BEFORE the first lock: an SSH session from another machine.
2. `SUPER+L`. Check the ASUS (the clock on the calmer side, the field, the quote) and the LG (four
   rows of glass). Type a WRONG password first (the shake and "senha incorreta"), toggle Caps Lock,
   then the right one, and unlock.
3. Lock again and, from SSH, `kill` the `qs` PID that `systemctl --user status lockscreen` lists.
   hyprlock must take over within a second and unlock with the password.
4. The old cache is dead data now: `rm -rf ~/.cache/lockscreen`.

## Troubleshooting

| Symptom | Look at |
| --- | --- |
| the palette's gradient instead of a print | the pool is empty or unreadable: `ls ~/Pictures/lockscreen/wide` |
| the plain hyprlock instead of the QML lock | `journalctl --user -u lockscreen`: "did not lock within 5 s" or "exited without an unlock", then the QML's own log under `/run/user/1000/quickshell/by-id/` |
| a card says "sem dados" | its source: `tail /var/lib/power-log/*.csv`, `glance-feed read claude_usage`, `glance-feed read weather` |
| the same quotes coming back | `~/.local/state/lockscreen/quotes-seen.json`: it resets only after the whole collection |
| the lock does not appear | `systemctl --user status lockscreen` and its `ExecCondition` (a hyprlock started by hand) |

## Rollback

| Layer | How back |
| --- | --- |
| Configuration | `git revert` the v6 commits and `! rebuild`, or boot the previous generation (`sudo nixos-rebuild switch --rollback`) |
| State | `~/.local/state/lockscreen` holds only the seen-lists; deleting it only resets them |
| A blank or stuck lock | from a TTY (`CTRL+ALT+F2`) or SSH: `WAYLAND_DISPLAY=wayland-1 hyprlock` REATTACHES to the locked session and draws a field |
| The compositor itself | from SSH, the journal first; relaunching hyprlock as above is the fix for an orphaned lock, and restarting Hyprland (which ends the session) is the last resort |

Killing the QML lock is now SAFE (the launcher hands over to hyprlock), but killing hyprlock
itself is not: with no launcher behind it, it leaves the compositor locked with nothing drawing
the field, which is the lockout of 03/08/2026.
