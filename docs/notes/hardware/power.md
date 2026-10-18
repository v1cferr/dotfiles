# Power profiles: Balanced, Gaming, Eco

`modules/nixos/hardware/power.nix` (the daemon), `modules/nixos/gaming/steam.nix` (GameMode's
hold). Three operating profiles with ONE owner of the state: power-profiles-daemon (ppd).

| Profile | ppd profile | CPU (intel_pstate EPP) |
| --- | --- | --- |
| Balanced (the default) | `balanced` | `balance_performance`, the kernel's own default |
| Gaming | `performance` | `performance` |
| Eco | `power-saver` | `power` |

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
  `custom.*`/`desiredgov` lines in `steam.nix`; EPP goes back to the kernel default.
- Stuck on `performance` after a game (should not happen): `systemctl --user stop
  gamemode-performance`, or pick a profile by hand, which drops every hold.
