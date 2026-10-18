# Memory, energy and workload: the baseline

The audit of 18/10/2026 that the memory, Docker and power changes stand on. Every number says how
it was obtained: **MEASURED** (read on this machine, with the command), **DERIVED** (computed from
measured values) or **PENDING** (not measurable that day, with the reason). Kernel 7.2.10,
NixOS 26.05, 5 h of uptime, Zen, VS Code, Discord, Obsidian and Hearthstone (Bottles, under
GameMode) open. That is a LOADED desktop, not an idle one: see Pending.

## Memory (MEASURED, `free`, `swapon`, `zramctl`, `/proc/pressure/memory`)

| What | Value |
| --- | --- |
| RAM | 15.4 GiB total, 4.3 to 6.0 GiB available across the session |
| zram0 | zstd, 7.7 GiB logical (the NixOS default, 50% of RAM), priority 5 |
| zram use | 5.0 GiB of data in 1.4 GiB of RAM: a 3.6x ratio |
| NVMe swapfile | 16 GiB, priority -1 (the fallback), 2.4 GiB in use |
| Swap total in use | 7.9 GiB now; earlyoom's hourly line read 62% (15 GiB) at 18:12 |
| PSI memory | `some avg300=0.03`, `full avg300=0.03`: no sustained stall |
| `vm.swappiness` | 60 (the kernel default) |
| `vm.page-cluster` | 3 (the kernel default) |
| MGLRU | `/sys/kernel/mm/lru_gen/enabled` = `0x0007`: on, all features |
| zswap | `N`: off, correctly so next to zram |
| OOM kills | none: no earlyoom kill in 30 days, no kernel OOM in 14 (`journalctl`) |

Where the memory goes (MEASURED, `memory.current` and `memory.swap.current` per cgroup, MiB):

| cgroup | RAM | swap |
| --- | --- | --- |
| Zen | 3888 | 1705 |
| Bottles (Hearthstone) | 2138 | 30 |
| VS Code (two scopes) | 2074 | 1773 |
| Chromium, Discord, Obsidian | ~1080 | ~830 |
| ALL of `system.slice` | ~1100 | small |
| Docker containers (11) | 3 to 20 each | up to 263 |
| Ollama with no model loaded | 12 | 20 |

**Conclusion**: the pressure is the interactive apps, not the services. Every background service
together is about 1.1 GiB of RAM, and the eleven containers are mostly swapped out already. Making
a stack on-demand would buy tens of MiB, which does not pay for the added failure modes (backups
that need the database, timers that `docker exec` into it). zram is doing its job at 3.6x.

## What was NOT changed, and why

- **zram size, swappiness, page-cluster**: kept. PSI shows no stall, and nothing has been killed in
  a month. `page-cluster = 0` is the usual zram advice, but since 5.x the kernel already bypasses
  swap readahead for a synchronous device like zram on a singly mapped page, while the NVMe
  swapfile does gain from readahead; the expected gain is not measurable here.
- **zswap**: stays off. zswap in front of zram compresses twice.
- **systemd-oomd user slices**: `oomctl` shows it monitors no cgroup at all. `enableUserSlices`
  would put `session-2.scope`, which holds Hyprland, among the kill candidates; see
  [oom](oom.md).
- **Ollama**: already lean. MEASURED: `OLLAMA_NUM_PARALLEL:1`, `OLLAMA_KEEP_ALIVE:5m0s`,
  no model resident at idle (`/api/ps` empty). The profiles unload models on top of that.
- **CreditRadar, Basic Memory FAI, the FUSE mounts on demand**: the measured RSS (3 to 50 MiB
  each) does not justify the risk to backups, clients and pending uploads.

## Boot and Docker (MEASURED, `systemd-analyze`, `journalctl -b -N`)

| Boot | Userspace to `graphical.target` | Stack builds |
| --- | --- | --- |
| 18/10 14:12 (after the 04:30 prune) | 2 min 30 s | full rebuild |
| 18/10 02:38 | 27.7 s | 28 `CACHED` |
| 17/10 22:46 | 29.9 s | 28 `CACHED` |
| 17/10 16:03 | 27.2 s | 28 `CACHED` |
| 17/10 13:29 (after the 11:20 catch-up prune) | 1 min 53 s | full rebuild |

`multi-user.target` waits for the three oneshot stacks, so a rebuild holds the whole boot. Fixed
by keeping the build cache a week: [docker-prune](../services/docker-prune.md).

## CPU and GPU (MEASURED)

- **CPU**: `intel_pstate` active, HWP, governor `powersave`, EPP `balance_performance`; no
  power manager, and GameMode's governor change was failing on polkit. See [power](power.md).
- **GPU**: the Arc B580 on `xe`, runtime PM `active` (a display is driving it). Its own hwmon
  publishes `energy1` (`card`, the whole board) and `energy2` (`pkg`, the GPU package), readable
  without root. During Hearthstone: 86 W board, 60 W package, GT0 at 2850 MHz, 54 to 58 °C.
  The GT0 `min_freq` reads 1200 MHz with `power_profile` = `base`; not touched.
- **PCIe ASPM**: kernel policy `default`; the per-link state is in the next item.
- **GPU at idle** (MEASURED 18/10/2026 20:10, from the NixOS Center's card, game closed, two
  monitors lit): **45 W on the board**. That is high for an idle card and is the usual signature
  of a B580 whose link never reaches ASPM L1. It is the largest single idle draw found, and the
  first thing to investigate. MEASURED the same evening with `lspci -vv` as root: the card and
  its internal bridges have L1 enabled, but the CPU's PEG root port advertises `ASPM not
  supported`, so the external link stays `ASPM Disabled`. A BIOS setting, not a kernel one:
  [the BIOS guide](../../guides/bios-ex-b560m-v5.md#the-arcs-idle-power-aspm-on-the-cpu-link-18102026).
- **Monitors**: ASUS XG27ACS 2560x1440 at 180 Hz, LG UltraGear 1920x1080 at 143.98 Hz rotated
  (`transform=1`), both VRR on. The LG offers 60 Hz at 1080p (`hyprctl monitors`).

## What the sensors can and cannot say

- `xe` energy counters are the GPU board, measured by the card itself. They are NOT the PC.
- RAPL (`/sys/class/powercap/intel-rapl:0/energy_uj`) is root-only (mode `0400`), so the shell
  cannot show CPU package watts, and does not pretend to.
- Neither is wall power. The PC's real draw needs a meter at the outlet.

## PENDING

- **An idle baseline.** A game was running all through the audit. To take one: close the apps,
  wait 10 min, then `free -m; zramctl; cat /proc/pressure/memory` and, for the GPU board,
  `e=$(cat /sys/class/hwmon/hwmon*/energy1_input | head -1); sleep 60; echo $(( ($(cat
  /sys/class/hwmon/hwmon*/energy1_input | head -1) - e) / 60000000 )) W` (pick the `xe` hwmon).
- **Wall power per profile**, with a plug meter: read it after 5 min idle in each profile, and
  again after 5 min in a game. Only that number answers "how much did Eco save".
- **CPU package power**: `sudo turbostat --quiet --show PkgWatt,CorWatt --interval 5`
  (`linuxPackages.turbostat`, not installed) or two root reads of `energy_uj`.
- **ASPM**: the BIOS change and the idle reading after it ([the BIOS guide](../../guides/bios-ex-b560m-v5.md)).
