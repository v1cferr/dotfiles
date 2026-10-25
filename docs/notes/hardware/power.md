# Power profiles: Balanced, Gaming, Eco

`modules/nixos/hardware/power.nix` (the daemon, the GPU half, the automatic holds),
`modules/nixos/gaming/steam.nix` (GameMode's hold), `modules/home/services/power-profile.nix`
(the user-side effects), `modules/home/desktop/hypr/lua/rules.lua` (the game-window trigger). Three operating profiles
with ONE owner of the state: power-profiles-daemon (ppd). Everything else FOLLOWS it.

| Profile | ppd profile | CPU (intel_pstate EPP) | GPU (xe, both GTs) | SignalSift | Ollama |
| --- | --- | --- | --- | --- | --- |
| Balanced (the default) | `balanced` | `balance_performance`, the kernel default | `base`, the driver's floor | `balanced` | its own 5 min keep-alive |
| Gaming | `performance` | `performance` | `base`, the driver's floor | `gaming` | idle models unloaded once |
| Eco | `power-saver` | `power` | `power_saving`, floor at RPn (400 MHz) | `eco` (`balanced` when automatic) | idle models unloaded once (manual Eco; the automatic one leaves its 5 min keep-alive) |

**Automatic by default** (19/10/2026). I never pick a profile: Balanced is the base, and two
HOLDS move it, both released by ppd when their unit stops, when it crashes, or when I pick a
profile by hand (a manual pick always wins).

- **Away → Eco.** hypridle's 5 min listener starts the user unit `power-idle-eco`
  (`powerprofilesctl launch --profile power-saver --reason Idle --appid idle`), and coming back
  stops it. It is `PartOf=hypridle.service`, so the Sunshine guard, which stops hypridle while
  streaming, ends it too. SignalSift stays on `balanced` under THIS Eco: the free PC is when its
  heavy jobs should run. A manual Eco still pauses it.
- **A game → Gaming**, by two independent triggers: GameMode (`gamemoderun`, or a Bottles
  bottle with GameMode on) starts `gamemode-performance`; and Hyprland itself starts
  `game-performance` while any game WINDOW is mapped (`rules.lua`: `*.exe`, `steam_app_N`,
  `gamescope`, the confine rule's set, minus `battle.net.exe`, a launcher left open for hours). So a Steam game without the launch option still gets Gaming.
- **Never Eco over a game.** ppd lets a power-saver hold win over a performance one, so both
  game units stop `power-idle-eco` before holding, and `power-idle-eco` has an `ExecCondition`
  that skips it while any performance hold exists (a controller game with no keyboard input
  goes idle in hypridle's eyes).

TESTED live 19/10/2026 by starting the units by hand: `power-idle-eco` gave `power-saver`, both
GTs `power_saving` at 400 MHz and SignalSift still `balanced`; `game-performance` on top stopped
it, raised `performance`, put the GPU back on `base` at 1200 MHz and SignalSift on `gaming`; a
second `power-idle-eco` under the game was skipped by its `ExecCondition`; stopping the game hold
returned to `balanced` with no hold left. The real triggers (5 min away, a game window) are the
same units started by hypridle and Hyprland.

The GPU half runs as root (`power-profile-gpu`, the same `gdbus monitor` pattern as the user
sync): `/sys/class/drm/card0/device/tile0/gt{0,1}/freq0/power_profile` and `min_freq`. MEASURED
18/10/2026, both GTs ship `power_profile` `base` with a floor of 1200 MHz while RPn is 400; the
driver's floor is recorded once in `/var/lib/power-profile-gpu/` and restored outside Eco. The
board's `power1_cap` (210 W) is not touched: a cap only bites under load, and Eco is for light
use. The monitors are not touched either (see the LG experiment below).

The watcher is NOT ordered after ppd. ppd's upstream unit carries `After=multi-user.target`, so
`after = power-profiles-daemon.service` on a unit wanted by `multi-user.target` closes a cycle,
and systemd broke it by deleting this job: the GPU half silently never ran at boot (seen 25/10/2026).
`gdbus monitor` already reacts to ppd taking its bus name, so the ordering bought nothing.

Kept in EVERY profile: the network, the tunnel, Caddy and every published service, Syncthing,
Dropbox, the backups and their timers, Sunshine, audio. No profile suspends the machine, stops a
service, or touches the monitors' power state.

## What the CPU offers (MEASURED 18/10/2026)

The i5-11400 runs `intel_pstate` in `active` mode with HWP: governors `performance` and
`powersave`, governor `powersave`, EPP `balance_performance`, the five EPP values available
(`default performance balance_performance balance_power power`), turbo on, `cpuidle` on
`intel_idle` with C1/C2/C3 (ACPI). No `/sys/firmware/acpi/platform_profile`, so ppd drives
`intel_pstate` only. ASPM is at the kernel's `default` policy and stays there (see below).

With HWP the governor is not the lever: `powersave` already lets the hardware boost to the top,
and EPP is the hint that decides how eagerly it does. That is exactly what ppd writes.

## Why power-profiles-daemon

- It is the upstream, maintained owner of this exact knob, with a D-Bus API and polkit rules that
  let the ACTIVE session switch profiles without root (`switch-profile` and `hold-profile` are
  `allow_active yes` in 0.30), so neither Quickshell nor a script needs privileges.
- **Holds**: a client can hold a profile while it runs. ppd drops the hold when the holder exits,
  when it crashes, or when the user switches profile by hand, and then returns to the profile the
  user had picked. That is the whole "leave the game and go back to Eco, not to Balanced" rule,
  without a state file of our own.
- Quickshell 0.3.2 binds it natively (`Quickshell.Services.UPower`, `PowerProfiles`).
- The NixOS module asserts against TLP and auto-cpufreq; neither is on, and no other module here
  touches EPP or the governor (`powerManagement.cpuFreqGovernor` is null).

The profile survives reboots: ppd keeps it in `/var/lib/power-profiles-daemon/state.ini`.

## GameMode: a hold, not the governor

MEASURED 18/10/2026: GameMode had never boosted anything. Every game start logged `Requesting
update of governor policy to performance`, then `pkexec ... cpugovctl set performance: Not
authorized` and `ERROR: Failed to update cpu governor policy`, and the split-lock helper failed
the same way. The gamemode polkit rule only authorizes members of the `gamemode` group, and the
user was not in it.

The fix is two parts:

1. **The user joins `gamemode`**, which is what the NixOS module creates the group for. The
   helpers stop failing; split-lock mitigation goes off during a game, GameMode's default.
2. **The governor stays `powersave`** (`general.desiredgov`). The `performance` governor would pin
   HWP and make EPP unwritable, a second owner fighting ppd. Instead GameMode's `custom.start`
   starts the user unit `gamemode-performance`, which runs `powerprofilesctl launch --profile
   performance` around a `sleep infinity`, and `custom.end` stops it.

Why this shape: GameMode runs `start` once for the first game and `end` once after the last, so
concurrent games share one hold. The unit `BindsTo=gamemoded.service`, so a crashed GameMode
ends the hold instead of leaving the CPU on `performance`. A manual pick during a game wins:
ppd releases every hold when the user switches.

## The user-side effects: `power-profile-sync`

A user unit (`default.target`, so it works over SSH too) runs `gdbus monitor` on ppd's object and
calls `power-profile-apply` on every `ActiveProfile` change and every time ppd (re)appears on the
bus, which covers its own start. Event-driven, no polling. The apply, serialized by `flock`:

- **SignalSift**: `signalsift profile set balanced|gaming|eco`, the app's own interface. `gaming`
  keeps the API and light collection and stops transcription and inference; `eco` stops all
  background work. The app kills a running heavy job with its process group and keeps what it
  already transcribed (its `docs/benchmarks/whisper-arc-b580.md`), so nothing is lost. The
  profile lives only until the daemon restarts, so `signalsift.service` gets an
  `ExecStartPost=-power-profile-apply --signalsift-only` that re-applies it, retrying for 10 s
  while the daemon comes up.
- **Ollama**: in Gaming and Eco, every model in `/api/ps` gets `keep_alive: 0`, which frees its
  VRAM as soon as any request in flight ends. It never blocks the API: Duo's next run simply
  loads the model again. Its VRAM no longer competes with a game.

The outcome of each apply lands in `$XDG_RUNTIME_DIR/power-profile.json` (profile, SignalSift
result, Ollama result, time), which the NixOS Center reads, and in the journal:

```sh
journalctl --user -u power-profile-sync -b
cat "$XDG_RUNTIME_DIR/power-profile.json"
power-profile-apply                          # re-apply by hand, idempotent
```

TESTED on 18/10/2026 before any switch, with `powerprofilesctl` and `signalsift` stubbed and the
real Ollama API: `power-saver` gave `eco (ok)` and `unloaded 0`; a refusing SignalSift was retried
10 times and recorded as `failed: error: connection refused`; `--signalsift-only` kept the previous
Ollama result.

TESTED live after the switch, the same evening: `powerprofilesctl set power-saver` moved EPP to
`power` and the sync recorded `eco (ok)`; starting `gamemode-performance` from the user manager
was allowed by polkit, showed the hold (`performance`, `GameMode`) and EPP `performance` with
SignalSift on `gaming`; stopping it returned to `power-saver`, NOT to balanced, with EPP `power`
and SignalSift back on `eco`.

**A switch does NOT reload a running gamemoded.** It reads `/etc/gamemode.ini` at its own start,
and NixOS restarts no user unit on activation. MEASURED on 18/10/2026: the instance from before the
switch still had the old config, so `gamemoderun` raised the GOVERNOR to `performance` (EPP
`performance` with ppd still reporting `balanced` and no hold), the exact second owner this setup
removes. And it was allowed: polkit reads the group from `/etc/group`, so the new `gamemode`
membership counts for the helpers before any re-login. After `systemctl --user restart
gamemoded` (no game running), `gamemoderun sleep 8` gave the hold (`performance`, `GameMode`),
governor still `powersave`, SignalSift `gaming`, and on exit `balanced` again, with no polkit
error. So after a switch that touches `programs.gamemode`: restart gamemoded with no game open,
or log in again.

## The LG at 60 Hz in Eco: an experiment, not wired

The LG offers 1920x1080 at 60 Hz (`hyprctl monitors`), and a lower refresh lowers the GPU's work
for that output. It is NOT automated, because the repo's history with this panel is DisplayPort
link loss, a panel DDC cannot wake, and black screens under Sunshine (see
[monitors](monitors.md) and [away](../desktop/away.md)), and because Hyprland 0.55 killed `hyprctl
keyword`, so a runtime mode change needs `hyprctl eval` on `hl.monitor`, untested here. The
experiment, by hand, with nothing streaming:

1. Read the board power for 60 s at 143.98 Hz (the command in
   [the baseline](power-and-memory-baseline.md#pending)).
2. Switch the LG to 60 Hz through the Lua API, keeping `transform=1` and its position, and read
   the board power again for 60 s.
3. Switch back and check `hyprctl monitors` shows 143.98 Hz, the same position and transform.

Only a measured saving with a clean way back earns it a place in the Eco apply.

## The power log: what is measured, and what is not (19/10/2026)

`modules/nixos/hardware/power-log.nix`. A root timer every minute appends one line to
`/var/lib/power-log/YYYY-MM.csv`. It reads CUMULATIVE energy counters, so each line is the exact
average over its interval and no burst between samples is lost. A first sample, a new boot or a
gap over 10 min writes nothing (there is no interval to report).

| Column | Source | Kind |
| --- | --- | --- |
| `cpu_package_w`, `cpu_cores_w` | RAPL `package-0` and `core` (root-only, which is why it runs as root) | measured |
| `gpu_board_w` | `xe` hwmon `energy1` (`card`): the WHOLE B580 board | measured |
| `gpu_chip_w` | `xe` hwmon `energy2` (`pkg`): the GPU package only | measured |
| `measured_w` | CPU package + GPU board | a measured FLOOR, never the PC |
| `wall_w` | empty: there is no meter | see below |
| `gpu_render_idle_pct`, `gpu_media_idle_pct` | GT0/GT1 `idle_residency_ms`: the time in RC6 | context |
| `cpu_busy_pct`, `profile`, `cpu_c`, `gpu_c`, `nvme_c` | `/proc/stat`, ppd, coretemp, `xe` pkg, NVMe | context |

Checked on 19/10/2026 that this board has no other source: no PSU telemetry on USB, no UPS, no
`/sys/class/power_supply`. The board, RAM, SSD, fans, the PSU's own loss and the monitors have no
sensor. So the macro view needs ONE outlet meter with a local API (a smart plug with energy
metering, read over the LAN); its reading becomes `wall_w`, and the unmeasured remainder is
`wall_w - measured_w`. Until then the log is the micro view and a floor, and says so.

```sh
power-report        # the last 24 h: averages, kWh, by profile, by hour of the day
power-report 168    # the last week
```

First readings, 19/10/2026 around noon, the desktop IN USE (Zen, VS Code, Discord, Spotify and an
agent's terminal): CPU package 38 to 48 W at only 4 to 10% busy, the cores alone 25 to 33 W, the
GPU board 43 to 48 W. The cores sat at 4.2 GHz and spent 57% of their idle time in C1, against
18% each in the two deep states, under ~20 800 interrupts/s (14 000 of them local timers, ~1 200
per core): apps waking the CPU, not a BIOS limit, since `CPU C-states` and `Package C State
Limit` both read Auto (255) in `CpuSetup` and the deep states are in use. An A/B on the same use:
three minutes of Eco gave a CPU package of 33 to 35 W (cores 19 to 21 W) at 7.7 to 8.3% busy,
against 43 W (cores 29 W) for Balanced at 7%, so about 8 to 9 W or ~20% off the CPU, and nothing
off the GPU, as expected from a profile that only moves EPP. The load drifted between minutes, so
it is an indication, not a benchmark. The `profile` column is read at the END of each interval.

A trap for anyone measuring by hand: Claude Code's spinner and streaming output repaint the
terminal, which wakes the GPU at the monitor's refresh rate. MEASURED 19/10/2026: render idle 0%
and 50 W on the board while an agent ran its commands, 50% and 43 W a few minutes later. Idle
readings belong to this log, taken while nobody is at the keyboard.

## RGB

Not part of any profile. The LEDs are already driven by OpenRGB profiles and the away mode, and
the gain is too small to justify a second writer of their state.

## Rejected

- **TLP, auto-cpufreq, tuned**: a laptop's battery policy, or a second owner of the same EPP.
- **Fixing GameMode's governor change alone**: it would work, then fight ppd's EPP writes.
- **A profile daemon of our own**: ppd already owns the state, the D-Bus API, the polkit gate
  and the hold semantics.
- **ASPM overrides (`pcie_aspm=force`, `pcie_aspm.policy=powersupersave`)**: the B580 is known
  to idle high without ASPM L1 on some boards, but forcing it globally risks link instability
  on every PCIe device, and nothing here can read the link state without root (`lspci -vv` is
  not installed). Measure first, see [the baseline](power-and-memory-baseline.md).

## Checking it

```sh
powerprofilesctl                     # the active profile and every hold, with its reason
powerprofilesctl list-holds          # during a game: performance, reason GameMode
cat /sys/devices/system/cpu/cpufreq/policy0/energy_performance_preference
journalctl --user -u gamemoded -b | grep -iE 'govern|Not authorized'   # must be quiet
systemctl --user status gamemode-performance
```

## Rollback

- Everything: delete `./power.nix` from `modules/nixos/hardware/default.nix` and the
  `custom.*`/`desiredgov` lines in `steam.nix`; EPP goes back to the kernel default, and
  `power-profile.nix` turns itself off (it is gated on ppd).
- Only the side effects: delete `./power-profile.nix` from `modules/home/services/default.nix`.
  SignalSift then stays on its config's profile and Ollama on its own keep-alive.
- Only the automatic mode: delete the `power-idle-eco` listener in `lockscreen.nix` and the
  game-window block in `rules.lua`; GameMode's hold stays.
- Only the GPU half: delete `systemd.services.power-profile-gpu` in `power.nix`, then
  `echo base | sudo tee /sys/class/drm/card0/device/tile0/gt*/freq0/power_profile` and write the
  floors saved in `/var/lib/power-profile-gpu/` back to `min_freq` (or reboot).
- Stuck on `performance` or `power-saver` (should not happen): `powerprofilesctl list-holds`
  names the unit; `systemctl --user stop gamemode-performance game-performance power-idle-eco`,
  or pick a profile by hand, which drops every hold.
