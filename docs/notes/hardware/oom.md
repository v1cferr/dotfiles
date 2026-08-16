# earlyoom, and the three traps in its regex

`system/hardware/oom.nix`. It avoids the FREEZE caused by running out of RAM (Chrome/Electron
eating everything).

## Why two layers

A companion to zram (`system/hardware/hardware.nix`): when RAM gets tight, zram compresses; when
not even that holds, somebody has to die BEFORE the kernel freezes the machine.

`systemd-oomd` (on by default in NixOS) is PSI/cgroup based and reacts slowly, and under Hyprland
the apps do not sit in monitored cgroups, so it lets things through. `earlyoom` is %-based and
KILLS THE BIGGEST PROCESS early, which is what prevents the 30-60 s freeze. The two coexist:
earlyoom is the fast guard, oomd the cgroup backstop.

## The thresholds

earlyoom's tested defaults, 10%/10%: a SIGTERM when free RAM < 10% AND free swap < 10%, a SIGKILL
at half that (5%/5%). Acting EARLY prevents the freeze better than waiting for 5%. Since the swap
here is 100% zram, which lives in RAM, the swap metric is not very reliable, so the RAM threshold
is what carries the decision. If it still freezes, raise that one.

`enableNotifications` says on the desktop which process was killed and why.

## The prefer/avoid lists

`--prefer` are the disposable gluttons, easy to reopen: chrome, chromium, firefox, librewolf, zen,
electron, spotify, Discord. Editors (code, obsidian) are deliberately OUT, since losing unsaved
work hurts more than a browser does.

`--avoid` is the compositor and the shell (a frozen screen), audio, the session and SSH (no
rescue). quickshell takes waybar's place there, since today it is the bar, the OSD AND the
notification daemon.

## The three traps, all measured on 05/08/2026

earlyoom matches `comm`, the KERNEL's field, truncated at 15 chars, through an extended regex.

1. **The nixpkgs wrapper changes the name.** `wrapProgram` leaves the script with the original name
   and the real ELF as `.X-wrapped`; what RUNS is the ELF, so the comm is `.Hyprland-wrapp` and
   `.quickshell-wra` (cut at the 15th char), NEVER `Hyprland`. Hence the `[.]?` and the end
   WITHOUT a `$`: it matches wrapped and raw, and it survives the day a package starts or stops
   being wrapped.
2. **The `$` anchor plus an exact name is a false sense of protection.** The old list was
   `^(Hyprland|waybar|…|mako)$` and it matched 5 out of 10 against the live processes: the
   COMPOSITOR was left out for reason 1, and `waybar`/`mako` were ghosts that left in the
   migration to Quickshell. The comment promised "the compositor never dies" and the effect was
   the opposite of what was written.
3. **`[.]` and NOT `\.`, because the backslash DOES NOT ARRIVE.** The nixpkgs module delivers the
   args through `Environment=EARLYOOM_ARGS=…`, and systemd discards `\.` as an invalid escape.
   Written as `"^\\.?"`, earlyoom logged `regex '^.?(Hyprland|…)'`, without the backslash. It
   still worked (`.?` is one optional character, and over-matching in `--avoid` errs on the safe
   side), but the comment became a lie. A character class has no backslash to lose.

ALWAYS check what the daemon PARSED, never the `.nix`:

```sh
journalctl -u earlyoom | grep 'avoid killing'
```
