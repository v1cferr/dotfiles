# Power profiles: Balanced, Gaming, Eco

`modules/nixos/hardware/power.nix` (the daemon), `modules/nixos/gaming/steam.nix` (GameMode's
hold), `modules/home/services/power-profile.nix` (the user-side effects). Three operating profiles
with ONE owner of the state: power-profiles-daemon (ppd). Everything else FOLLOWS it.

| Profile | ppd profile | CPU (intel_pstate EPP) | SignalSift | Ollama |
| --- | --- | --- | --- | --- |
| Balanced (the default) | `balanced` | `balance_performance`, the kernel default | `balanced` | its own 5 min keep-alive |
| Gaming | `performance` | `performance` | `gaming` | idle models unloaded once |
| Eco | `power-saver` | `power` | `eco` | idle models unloaded once |

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
- Stuck on `performance` after a game (should not happen): `systemctl --user stop
  gamemode-performance`, or pick a profile by hand, which drops every hold.
