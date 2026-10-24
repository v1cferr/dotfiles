# earlyoom, and the three traps in its regex

`modules/nixos/hardware/oom.nix`. It avoids the FREEZE caused by running out of RAM (Chrome/Electron
eating everything).

## Why two layers

A companion to the swap: zram first (`modules/nixos/hardware/hardware.nix`, priority 5), then the
16 GiB NVMe swapfile (the host's `disko.nix`, priority -1) as the fallback. When RAM gets tight,
zram compresses; when not even the swapfile holds, somebody has to die BEFORE the kernel freezes
the machine.

`systemd-oomd` is on (the NixOS default) but, MEASURED 18/10/2026 with `oomctl`, it monitors NO
cgroup: `Swap Monitored CGroups` and `Memory Pressure Monitored CGroups` are both empty. Its
`enableUserSlices` would fix that by putting `ManagedOOMMemoryPressure=kill` on `user-1000.slice`,
and that slice holds `session-2.scope`, which is Hyprland itself: oomd kills a whole cgroup, so
the "biggest pressure" candidate can be the session. Not turned on until the session can be
excluded. So earlyoom is the only guard that acts today.

## The thresholds

earlyoom's defaults, 10%/10%: a SIGTERM when available RAM < 10% AND free swap < 10%, a SIGKILL at
half that (5%/5%).

**The swap condition is the one that decides** (corrected 18/10/2026; this page used to say the
opposite, from the days when swap was 100% zram). Swap is now zram plus the NVMe file, 24 GiB in
total, and the kernel keeps `MemAvailable` above 10% by swapping for as long as swap lasts. So the
SIGTERM comes when free swap falls under 2.4 GiB: about 21.8 GiB swapped, 14 of them on the NVMe.
Before that point the cost is swap-in latency on the NVMe (stutter when going back to an old tab),
not a hard freeze, and in 30 days of logs earlyoom killed nothing and the kernel OOM never fired.

**Kept as is**, because no freeze has been measured. The candidate if one shows up is
`freeSwapThreshold = 50`: a kill once ~12 GiB are swapped (zram full plus ~4 GiB on disk) and RAM is
under 10%. The test before changing it, in a session with nothing unsaved:

```sh
journalctl -u earlyoom -f &                       # its hourly line shows mem and swap %
cat /proc/pressure/memory                         # watch full avg10 climb
nix shell nixpkgs#stress-ng -c \
  stress-ng --vm 1 --vm-bytes 90% --vm-keep -t 120s   # NOT under a game, NOT with unsaved work
```

The verdict is how long `full avg10` stays above ~20 before earlyoom acts, and whether the desktop
stays usable meanwhile.

`enableNotifications` says on the desktop which process was killed and why.

## The prefer/avoid lists

`--prefer` are the disposable gluttons, easy to reopen: chrome, chromium, firefox, librewolf, zen,
electron, Discord. Editors (code, obsidian) are deliberately OUT, since losing unsaved
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
