# Desktop performance: the audit and the A/B bench

`tools/hypr-bench/` (the bench, run with `nix run .#hypr-bench`, never installed). What the
desktop costs in CPU, GPU, memory and frames, measured with the effects on and off, so an
optimization is chosen from a number and not from a guess. Started on 06/11/2026. Nothing here
changes the config: every proposal at the end waits for the owner's yes.

## The stack that was measured

MEASURED on 06/11/2026 with `hyprctl version`, `hyprctl monitors -j`, `hyprctl getoption`,
`hyprctl plugin list` and sysfs:

| Piece                                | State                                                                                                              |
| ------------------------------------ | ------------------------------------------------------------------------------------------------------------------ |
| Hyprland                             | 0.57.1 (`acc1aa0b`), Aquamarine 0.16.0, Lua config, DRM backend                                                    |
| Kernel, driver, Mesa                 | 7.3.1, `xe`, Mesa 26.1.8                                                                                           |
| DP-1, ASUS XG27ACS                   | 2560x1440 at 180 Hz, XRGB8888, VRR on                                                                              |
| DP-2, LG UltraGear                   | 1920x1080 at 143.98 Hz, rotated, XRGB8888, VRR on                                                                  |
| `misc:vrr` / `general:allow_tearing` | 1 (always) / false                                                                                                 |
| `render:direct_scanout`              | 0, the default: a fullscreen game is always composited                                                             |
| `debug:damage_tracking`              | 2 (full), the default                                                                                              |
| Effects                              | native blur on, HyprGlass 1.1.1 on (`clear-gradient`), animations `subtle`                                         |
| GPU floor                            | `min_freq` 1200 MHz of 400 to 2850 under the `performance` and `balanced` profiles ([power](../hardware/power.md)) |

## What can be measured here, and what cannot

| Metric                            | Source                                                           | Root?                                   |
| --------------------------------- | ---------------------------------------------------------------- | --------------------------------------- |
| CPU per process                   | `/proc/<pid>/stat` (utime + stime)                               | no                                      |
| CPU per logical core              | `/proc/stat`                                                     | no                                      |
| RSS of every process              | `/proc/<pid>/status`                                             | no                                      |
| PSS of Quickshell, Xwayland       | `/proc/<pid>/smaps_rollup`                                       | no                                      |
| PSS of Hyprland                   | the same file                                                    | **yes**                                 |
| GPU render engine per client      | xe `fdinfo` (`drm-cycles-rcs` over `drm-total-cycles-rcs`)       | no for Quickshell, **yes** for Hyprland |
| GPU busy, whole GT                | 1 minus the RC6 residency (`tile0/gt0/gtidle/idle_residency_ms`) | no                                      |
| GPU frequency                     | `tile0/gt0/freq0/act_freq`                                       | no                                      |
| GPU power                         | hwmon `xe`, `energy1` (card) and `energy2` (pkg)                 | no                                      |
| CPU package power                 | RAPL `energy_uj`                                                 | **yes**                                 |
| Frames composed per output        | HyprGlass's own counter, `hyprctl -j hyprglass stats`            | no                                      |
| Frame-to-frame intervals (pacing) | nothing in userspace; tracefs page-flip events                   | not done                                |
| Input-to-photon latency           | needs a camera or a photodiode on the panel                      | not done                                |

Why the root-only rows: Hyprland runs with `CAP_SYS_NICE` (to raise its own priority), which makes
the process non-dumpable, so the kernel hides its `fdinfo` and `smaps` from its own user. RAPL has
been root-only since the Platypus side channel. `perf_event_paranoid` is 2 here. `--privileged`
reads exactly those files through `sudo`, and nothing else.

Tools that do NOT work here, checked on 06/11/2026: `intel_gpu_top` only speaks i915, not `xe`
([bar](bar.md)); `pidstat`, `perf` and `drm_info` are not installed, and the bench needs none of
them.

**The frame counter is trusted because it matches the physics.** In a test compositor at 60 Hz,
one animated workspace switch added 21 frames: 350 ms, against the `settle` spring's 306 ms to rest
plus its first and last frame ([motion](motion.md)). With HyprGlass disabled at runtime the counter
keeps counting (two unanimated switches, two frames), so it measures every scenario, including
the ones with the glass off. FPS is a load measure here, never a latency measure: with VRR on, an
idle output that composes 0 frames is the IDEAL, not a stall.

## What the audit already shows (no bench yet)

MEASURED on 06/11/2026 during normal use, not idle, so these are context, not results:

- **Quickshell averaged 13% of one core over 11 h** (`ps` lifetime CPU) and 7% in a 5 s sample,
  with 227 MiB RSS, about 100 MiB of VRAM and 4% of the render engine's cycles over its lifetime.
  Hyprland averaged 5.7% of a core over the same 11 h.
- **Over those 11 h, DP-2 composed 2 246 720 frames and DP-1 1 818 814** (HyprGlass's counters
  since the session began): 55.6 and 45 frames per second on average. DP-2 is the LG, whose screen
  is mostly the glance band. A Twitch stream on DP-1 explains DP-1's share; the LG's 55.6 average
  is the number the bench has to explain.
- Static reading of the shell (06/11/2026) lists what can keep the LG composing while nobody
  touches it: the 1 Hz clock with seconds on the band (`dash/ClockWeather.qml`, fed by
  `bar/Bar.qml`'s `SystemClock`), the 1 Hz ping that redraws the bar's net pill
  (`widgets/PingProbe.qml`), the page dots that grow 1 px every 682 ms and 455 ms
  (`dash/PageDots.qml`, `dash/ServiceStrip.qml`), the infinite pulses of a degraded service or a
  tile in alert, and a fork every 2, 3 and 5 s. Each of those repaints a layer that HyprGlass and
  the blur then re-render. These are HYPOTHESES until the idle workload measures them.

## The bench

### Scenarios

Each one is applied with `hyprctl eval` on top of a fresh `hyprctl reload config-only`, so a block
never inherits the one before:

| Scenario            | Animations | Native blur                                                                   | HyprGlass |
| ------------------- | ---------- | ----------------------------------------------------------------------------- | --------- |
| A, baseline         | on         | on                                                                            | on        |
| B, no animation     | off        | on                                                                            | on        |
| C, no blur          | on         | off                                                                           | off       |
| D, minimal          | off        | off                                                                           | off       |
| E, native blur only | on         | on, plus the shell-layer rule `appearance.lua` adds when the plugin is absent | off       |

E answers whether HyprGlass costs more than the blur it replaced. `--shell-off` adds
`qs ipc call bar hide` to every scenario, which stops the bar and the band from drawing while
their timers and forks go on, so it splits Quickshell's render cost from its polling cost.

### Workloads

The bench opens three named workspaces with static terminals of class `hypr-bench` (two on
`bench-a` and one on `bench-b`, on the primary; one on `bench-c`, on the secondary) BEFORE any
measurement, so no app start-up lands inside a block, and both screens show the same content in
every scenario.

| Workload   | What happens                                                                       | Default length |
| ---------- | ---------------------------------------------------------------------------------- | -------------- |
| idle       | nothing                                                                            | 45 s           |
| workspace  | `bench-a` and `bench-b` alternate every 0.5 s                                      | 20 s           |
| window     | a terminal moves between `bench-a` and `bench-b` every 0.5 s, without following it | 20 s           |
| panel      | the weather panel opens and closes once a second (`qs ipc call bar panel weather`) | 20 s           |
| fullscreen | `vkcube` fullscreen, FIFO, on the primary                                          | 20 s           |

Every block waits 5 s after the scenario changes. Three rounds by default, the order of the
scenarios rotated each round so a slow drift (heat, a timer) spreads over all of them. The
aggregate is the mean over rounds with its standard deviation. A full run takes about 35 minutes;
`--quick` (one round, short blocks) about 5.

### The safety of the desk

- **Refuses to start** with the session locked, a window of yours fullscreen, a Sunshine stream
  live (UDP 47998 to 48000), or the GPU already more than 50% busy (a game or a video would swamp
  the deltas). A block that saw the lock, a fullscreen window, a stream, a change of power profile
  or a cursor move is kept in `rows.csv` and marked invalid, never averaged.
- **Holds a logind idle inhibitor** for the run (`systemd-inhibit --what=idle`): without it,
  hypridle locks the screen AND starts `power-idle-eco` at 300 s, which drops the GPU floor and
  changes what is being measured. The inhibitor dies with the process, even on SIGKILL.
- **Never touches** a monitor, a mode, VRR, tearing, direct scanout, a driver or a service.
- **Restores in three layers.** The `finally` of the run (also reached by Ctrl+C and SIGTERM)
  reloads the config without a modeset, closes the panel, unhides the bar, kills only its own
  terminals and `vkcube`, and focuses each monitor's workspace back; a `systemd-run --user` timer
  armed at the start does the same if the process dies without its `finally`; and the restore
  compares `getoption` for every key it touched against the start, exiting non-zero if one differs.
  `hypr-bench restore` runs the same path by hand.

### Running it

1. Close games and videos, leave the desk alone (a cursor move invalidates the block).
2. `nix run .#hypr-bench -- run --quick` to check the mechanism, then
   `nix run .#hypr-bench -- run` for the real thing. Add `--privileged` for Hyprland's own GPU and
   PSS and the CPU package power (it asks for the sudo password once, at the start).
3. Results land in `~/.local/state/hypr-bench/<date>/`: `raw.json` (every block and the
   environment), `rows.csv`, `summary.json` and `report.md`. `hypr-bench report <dir>` rebuilds the
   last three from `raw.json`.

`hypr-bench probe` prints two seconds of every metric and changes nothing: the first thing to run
when a number looks wrong.

## Results

None yet: the bench was written on 06/11/2026 while the desk was in use (a game on DP-1, which the
load guard refused, as designed). This section gets the tables and their date from the first full
run.

## Proposals, waiting for the bench

Hypotheses only, ranked by what they would save if the bench confirms them; none is applied.

| Proposal                                                                                                                          | Evidence so far                                                    | Risk                                                                                 | Effort                                  |
| --------------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------ | ------------------------------------------------------------------------------------ | --------------------------------------- |
| Stop the band from repainting every second when nothing changed (no seconds on the clock, page dots that step instead of growing) | the LG composed 55.6 fps on average over 11 h                      | low: visual only                                                                     | low: QML                                |
| Try `render:direct_scanout = 2` (games only)                                                                                      | it is off, so every fullscreen game frame is composited            | medium: flicker or capture issues upstream warns about, Sunshine captures the output | low: one option, but needs its own test |
| Lower the GPU floor at idle                                                                                                       | 1200 MHz is held under `balanced`, the driver's own minimum is 400 | medium: the floor exists for a reason in [power](../hardware/power.md)               | low                                     |

## Rejected

- **A nested Hyprland as the test bed.** On 06/11/2026 the API check ran in a Hyprland nested in a
  headless output of the live one, as the HyprGlass tests did in October. On exit, Hyprland 0.57.1
  runs `systemctl --user stop graphical-session.target` and unsets `DISPLAY`,
  `HYPRLAND_INSTANCE_SIGNATURE` and others in the user manager (both strings are in the binary), so
  the nested one took the LIVE session's units down: Sunshine, hypridle, the portals, and the apps
  scoped to the session. `hypr-session-ensure` brought the target back, but with the dead nested
  instance's signature, because it picks the newest directory in `$XDG_RUNTIME_DIR/hypr`. Repaired
  by hand the same night. The bench needs no nested compositor: `hyprctl eval` and
  `reload config-only` were checked there before it went wrong, and their effect is checked again
  by `getoption` at every restore.
- **`hyprctl keyword`** for the toggles: dead under the Lua config (`keyword can't work with
  non-legacy parsers`).
- **Killing Quickshell to isolate it**: the bar, the band and the notifications would vanish, and
  its own counters already isolate its CPU and GPU. `--shell-off` hides it through its IPC instead.
- **`intel_gpu_top`** for the engines: i915 only.
