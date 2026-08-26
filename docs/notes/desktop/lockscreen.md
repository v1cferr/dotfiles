# The lock screen: hyprlock plus hypridle

`home/desktop/lockscreen.nix`. Ref: <https://wiki.hypr.land/Hypr-Ecosystem/hyprlock/>

## The philosophy: no loose `.sh` scripts

The heavy logic lives where it is declarative and reproducible, in the BUILD (pure Nix) or in
SYSTEMD, and the runtime is a 1-line command with the binary at an ABSOLUTE path
(`${pkgs...}/bin/x`), not depending on the PATH. That is how this survives upgrades (rule 7,
durable into 2032+).

| Piece | Where the work happens | What the lock runs |
| --- | --- | --- |
| quote | a service plus a daily timer: ZenQuotes, DeepL, pango | `shuf -n1` |
| weather | a service plus a 10-min timer: Open-Meteo | `cat` |
| idle | hypridle, and it ONLY locks | `systemctl --user start` (the gate) |
| media | `lockscreen-idle-lock.service`: it waits while a player is Playing | `loginctl lock-session` |
| lock | `hyprlock.service`, a declared unit | `systemctl --user start` |

## The folder rule

USER apps go to `home/`. `programs.hyprlock` installs hyprlock and `services.hypridle` brings the
daemon up (`systemd --user`, like hyprsunset), which is why hypridle left `system/packages.nix`.

PAM (`system/desktop/desktop.nix`) is MANDATORY: without it hyprlock does not authenticate and
LOCKS YOU OUT. The `pt_BR` locale (`system/core/core.nix`) is for the clock's spelled-out date.

## Language: a deliberate exception

The system is en-US, and the LOCKSCREEN is full pt-BR: the spelled-out date, the weather, "Digite a
senha…", the DeepL-translated quotes. That decision is recorded in the July history, so those
strings are NOT untranslated debt, they are the product.

## Hardware lessons, durable and independent of the GPU. Do NOT touch

1. **A STATIC wallpaper, never `path = screenshot`.** screencopy/DMA segfaults hyprlock when waking
   from idle, because the DMA frame is destroyed on exit. That is a lockout.
2. **No GIF and no continuous reload.** The asynchronous gatherer races with `exit()` and corrupts
   the heap (SIGABRT on unlock).
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

## Media holds the lock back

The 5 min timeout has no business landing in the middle of a movie. The gate is
`lockscreen-idle-lock.service`: hypridle's `on-timeout` starts it, and it only calls
`loginctl lock-session` when NO MPRIS player is in `Playing`.

IT WAITS, IT DOES NOT SKIP, and that is the whole design. Each hypridle listener fires ONCE per
idle cycle, so a gate that simply returned without locking would leave the machine open until the
next keystroke: a movie ending at 3 AM would mean an unlocked desktop until morning. Waiting keeps
the lock PENDING, and it lands up to 30 s after the last player stops, which is the poll interval.

Coming back to the keyboard cancels it, through the listener's `on-resume` (`systemctl --user
stop`). The remaining race is the poll's width: the media would have to stop inside the same 30 s
window in which I come back, and the worst case there is a lock I was already getting anyway.

`PartOf = hypridle.service` because a PENDING lock belongs to the daemon that scheduled it. That is
what keeps the Sunshine guard working: `stream-begin` stops hypridle so the remote session does not
lock mid-way, and a gate left waiting in the background would fire the moment the music ended.

THE SIGNAL IS MPRIS (`playerctl --all-players status`), the same D-Bus interface behind the bar's
Spotify pill, so it covers every player the bar already sees. The consequence is deliberate: AUDIO
COUNTS, and Spotify left playing overnight keeps the machine unlocked. Narrowing it to video would
mean filtering the players, not trusting an inhibit, which is the next section.

## Why `ignore_dbus_inhibit` stays true

Because the opposite looks like the obvious fix and is not. An app's inhibit is UNBOUNDED: a
browser that leaks one disables locking forever and in silence, and nothing on screen says so. The
gate is a single decision point, re-evaluated every 30 s, and it states its reason in the journal
(`media is playing, the idle lock waits`, at notice priority).

Worth recording because it was not always so: the Arch `hypridle.conf` this module replaced carried
`ignore_dbus_inhibit = false`, and the port on 24/07/2026 flipped it to `true` with no reason
written down. It is a decision now, not a leftover.

## The quote cache

It replaced a vendored `quotes.tsv`. The timer fetches a BATCH of ~50 from `zenquotes.io
/api/quotes` (EN), filters it (non-empty, <= 120 chars, without the rate-limit placeholder) and
TRANSLATES it to pt-BR through DeepL in a SINGLE batched request, with the key from
`/run/secrets/deepl_api_key` (sops). The author stays in the original.

It escapes `&<>` for pango and writes atomically, so hyprlock never reads a half-written cache.

The fallbacks are layered: with no key or DeepL down it uses the ENGLISH batch; a length mismatch
between request and response also falls back to EN; and with no network on the first run there is
one built-in pt-BR quote, so `shuf` is never empty.

Renewed once a day: ~50 quotes leaves plenty of room in DeepL's free quota of 500k characters a
month.

## The weather cache

São Carlos/SP by COORDINATES, so there is no geocoding ambiguity. It writes atomically (`.tmp` plus
`mv`). A stable source, with no HTML scraping. Refreshed every 10 min, first fetch 1 min after
boot.

The SOURCE and the pt-BR words are the SSOT in `my.weather` (`home/desktop/weather.nix`), the same
one the bar reads, and the script's `case` arms are generated from it. It used to be wttr.in with
its own coordinates, and on 22/08/2026 the lock said 18°C while the bar said 22°C in the same
minute. The full reasoning, and every measured failure path, is in [`weather.md`](weather.md).

## The visual details worth keeping

The wallpapers are the official NixOS ones through `pkgs.nixos-artwork`, so there is no binary in
git and they bump along with nixpkgs. `blur_passes` was eased from 3 to 2 so the wallpaper shows
more while the widgets stay legible, and `brightness = 0.40` is dark enough for the clock and quote
without hiding the image.

The monitors come from the SSOT (`system/desktop/monitors.nix`, rule 11): the primary gets the
blurred desktop plus the login, the secondary (the TV) gets a static image plus a discreet padlock.
The colors come from `my.theme` and the font from `my.fonts.ui`.

The date label uses `LC_TIME=pt_BR.UTF-8` for the spelled-out form, with `sed` capitalizing the
first letter and adding the week number.
