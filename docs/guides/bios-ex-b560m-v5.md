# BIOS: ASUS EX-B560M-V5 (desired state)

The BIOS settings of this board are **not declarable** from NixOS: they live in the
firmware NVRAM, and the kernel `firmware-attributes` interface (used by
`fwupdmgr get-bios-settings`) only exists on Dell/Lenovo/HP business boards, not on
consumer ASUS. `fwupd` here answers literally `This system doesn't support firmware
settings`.

So this file is the closest thing to "declarative" available: **the intent, versioned**. It
does not apply itself, but it survives a Clear CMOS and it is reproducible by hand in
~2 min.

Machine: Intel i5-11400 + Arc B580 (Battlemage). BIOS **2803** (2025/12/26).

## Settings

Access: `Del` at POST, then `F7` (Advanced Mode).

| Setting | Value | Where | Status |
| --- | --- | --- | --- |
| Launch CSM | Disabled | Boot → CSM | confirmed (OS) |
| Above 4G Decoding | Enabled | Advanced → PCI Subsystem | confirmed (OS) |
| Re-Size BAR Support | Enabled | Advanced → PCI Subsystem | confirmed (OS) |
| Primary Display | PCIE | Advanced → System Agent / Graphics | hidden in BIOS 2803 (see below) |
| Secure Boot → OS Type | Other OS | Boot → Secure Boot | recommended |
| Fast Boot | Disabled | Boot | recommended |
| Ai Overclock Tuner (XMP) | XMP I (3200 MT/s) | Ai Tweaker | confirmed (3200 MT/s) |
| Native ASPM, PEG - ASPM, PCH ASPM | (wanted: Enabled, L1, L1) | NOT in the menus: hidden by ASUS | see below |

- **Confirmed (OS):** measured from Linux. CSM off (the Arc is UEFI-only and it booted),
  Above 4G + ReBAR active (a 16G VRAM BAR mapped above 4G, through `lspci`).
- **Recommended:** good practice for the Arc; not verified, confirm on the next visit.
- **XMP:** the TeamGroup UD4-3200 kit was running at 2400 MT/s (XMP off); with XMP on it is
  confirmed at **3200 MT/s** (`dmidecode -t 17`).

## Why CSM = Disabled is critical

Arc GPUs **have no legacy VBIOS** (they are UEFI-only). With CSM on, the motherboard tries
to bring video up in legacy mode, finds no ROM on the card and **hangs on the ASUS logo**.
That was the "CSM Forced Enablement Phenomenon" documented on the Intel forum, and it is not
a defect of the board.

**The root of the problem on this board:** the EX-B560M-V5 had a default that
**re-enabled CSM automatically** (CSM came back by itself after a reboot or a failed POST).
That default was **turned off**, which is the real fix, at the source. With CSM off and that
auto-enable off, **you can enter the BIOS normally with the Arc installed** (video comes up
through the card's GOP, with no broken screen). The `reboot=pci` (OS side) stays as
reinforcement.

> TODO: write down here the exact name of the auto-CSM option that was turned off (its BIOS
> label), for precise reproduction after a Clear CMOS.

## The OS side (this part IS declarative)

- `boot.kernelParams = [ "reboot=pci" ]` in `modules/nixos/hardware/intel-arc-b580.nix`: it forces a
  full reset through 0xCF9 on `reboot`, the GPU reinitializes clean as in a cold boot and the
  POST does not fail, so CSM is never turned back on. **It fixes the warm-reboot hang.**
- `services.fwupd.enable = true` in `modules/nixos/hardware/hardware.nix`: it does NOT cover this board's
  BIOS (ASUS is outside LVFS); it serves SSD firmware and other components.

## The Arc's idle power: ASPM on the CPU link (18/10/2026)

The B580 drew **45 W on the board with the desktop idle** (its own `xe` sensor, read by the NixOS
Center). The usual cause on Arc is a link that never enters ASPM L1, and `lspci -vv` (as root)
showed exactly where it stops:

| Link | `LnkCap` | `LnkCtl` |
| --- | --- | --- |
| CPU root port `00:01.0` (PEG, Gen4) → the card's bridge `01:00.0` (x8) | root port: **ASPM not supported**; card: L1 | **Disabled** |
| The card's internal bridges → GPU `03:00.0` and its audio `04:00.0` | L1 | L1 Enabled |
| CPU root port `00:06.0` → the Kingston NVMe | root port: not supported | Disabled |
| PCH root port `00:1c.7` → the Realtek NIC | root port: not supported | Disabled |

The card is ready; it is the CPU's PEG port that ADVERTISES no ASPM, and Linux honors the
advertisement. So the fix is the firmware's, NOT a kernel parameter: `pcie_aspm=force` would
enable a state the port says it does not have, which is how links hang.

**The firmware has the options and hides them** (VERIFIED 18/10/2026 against BIOS 2803, the
official `EX-B560M-V5-SI-2803.zip` from `dlcdnets.asus.com/pub/ASUS/mb/BIOS/`, unpacked with
`uefiextract` and its Setup module (`899407D7-...`) read with `ifrextractor`, nothing written).
The options exist in its forms: `PCI Express Native Power Management` and `Native ASPM` (Setup),
`PEG - ASPM` with Disabled/Auto/L0s/L1/L0sL1 (SaSetup), the PCH `ASPM` (PchSetup). But in the
`Advanced` form, the links to `Platform Misc Configuration`, `System Agent (SA) Configuration`,
`PCH Configuration`, `Power & Performance`, `RC ACPI Settings` and `Thermal Configuration` all sit
under `SuppressIf 1 == 1`, a condition that is always true. What stays visible is exactly the
manual's list (CPU, PCH Storage, PCH-FW, PCI Subsystem, USB, Network Stack, NVMe, Onboard
Devices, APM, SMART), so an Expedition board simply does not offer these knobs. The SA menu
being hidden also means the `Primary Display` row above cannot be set from the menus either.

The live values agree (read from efivarfs, 4-byte attribute header first; `Setup` is 2698 bytes
= the IFR's 0xA86 plus 4, so the offsets match this BIOS):

| Option | Variable + offset (BIOS 2803 only) | Value now | Wanted |
| --- | --- | --- | --- |
| PCI Express Native Power Management | `Setup` 0x51 | 0 (Disabled) | 1 |
| Native ASPM | `Setup` 0x52 | 0 (Disabled) | 1 (Enabled) |
| CPU PCIe Root Port 1 ASPM (the x16 slot, `00:01.0`) | `SaSetup` 0x35D | 0 (Disabled) | 2 (L1) |
| PCH ASPM (left alone: the Realtek NIC lives there) | `PchSetup` 0x113 | 0 (Disabled) | unchanged |

There are TWO `PEG - ASPM` questions. The form picks one by the CPU: `SaSetup` 0x52 is suppressed
when `CpuSetupVolatileData` reads `0x670` (CPUID `A0671` masked, Rocket Lake), and `SaSetup`
0x35D, the "PCI Express Root Port 1" page, is the one shown for this CPU. L1 Substates (0x361)
stay off: a Battlemage card has been reported failing to boot with L1.1 enabled.

### The exception: `bios-aspm` (decided 18/10/2026, review 18/01/2027)

The "Do NOT do" rule against raw variables gets ONE exception, these three bytes, by decision on
18/10/2026: the menus cannot reach them, the gain is the largest idle draw on the machine, and
the risk is bounded by the checks below and a Clear CMOS. `hosts/ex-b560m-v5/bios-aspm.nix`
installs `bios-aspm`:

- `bios-aspm status` (no root): the three values, whether the kernel still logs the FADT line,
  and as root the `00:01.0`/`01:00.0` link state.
- `sudo bios-aspm apply`: refuses on any other board, any BIOS but 2803, a variable of another
  size, attributes other than `07000000`, or a current value outside the option's valid set.
  Then it backs both variables up to `/var/backup/bios-aspm/<date>/` with `SHA256SUMS` (inside
  restic's paths), asks for `yes`, writes each variable in ONE write as efivarfs requires,
  reads it back, and puts the backup back on any mismatch.
- `sudo bios-aspm restore <dir>`: writes a verified backup back.

TESTED before any write, 18/10/2026: the patch applied to copies of the live variables changed
exactly positions 86 and 87 of `Setup` and 866 of `SaSetup` (0x51, 0x52 and 0x35D plus the
4-byte header), sizes intact. Two traps it already avoids: `cp` cannot read efivarfs (`Illegal
seek`), so it copies with `cat`; and `grep -q` after `journalctl` under `pipefail` reads a match
as a miss.

On the review date: if ASPM held with no `xe` resets or link errors, the exception stays and
this paragraph gets the measured watts; if anything regressed, `restore` and drop the module.
A BIOS update changes the offsets: `bios-aspm` then refuses, and the IFR has to be read again.

The kernel log names the same cause before any `lspci`. On the boot of 18/10/2026:
`ACPI FADT declares the system doesn't support PCIe ASPM, so disable it`, `FADT indicates ASPM is
unsupported, using BIOS configuration`, and `r8169 ... can't disable ASPM; OS doesn't have ASPM
control`. That FADT flag is what Native ASPM = Disabled publishes, so its absence is the first sign
the BIOS change took.

Checking it, after the BIOS change and a reboot (read only):

```sh
journalctl -k -b | grep -iE 'FADT.*ASPM|OS now controls'      # wanted: no FADT line
P=$(nix build --no-link --print-out-paths nixpkgs#pciutils.out)
sudo $P/bin/lspci -vv -s 00:01.0 | grep -E 'LnkCap|LnkCtl'   # wanted: ASPM L1 in both
sudo $P/bin/lspci -vv -s 01:00.0 | grep LnkCtl               # wanted: ASPM L1 Enabled
```

Then read the board's idle watts again (the NixOS Center's GPU BOARD card, desktop idle, both
monitors on), and watch a day of normal use and one game session for stutter, a black screen or
an `xe` reset in `journalctl -k`. If anything regresses, set PEG - ASPM back to Disabled: that
is the whole rollback. Two lit monitors at 180 Hz and 144 Hz keep the display engine busy, so
even a working L1 will not bring the card down to single-monitor figures.

## Backup and restore

- **Profile in the BIOS (native):** Tool → ASUS User Profile (or Save & Exit → Save Profile),
  which saves into a slot (1-8) in NVRAM. After a Clear CMOS it is just Load Profile.
- **Recovering from a hang:** hold the power button ~8s, and a cold boot always recovers the
  Arc. As a last resort, a Clear CMOS (the CLRTC jumper, or pulling the battery for ~1 min)
  goes back to defaults.

## Do NOT do

- **Do NOT flash a modified BIOS** (a mod for hidden menus): this board has **no USB BIOS
  FlashBack**, so a brick becomes a job for an external SPI programmer (CH341A + clip).
- **Do NOT edit the raw variables** (except the three bytes of `bios-aspm` above) (`AMITSESetup`, `CpuSetup` and friends, through
  `setup_var`/`efivarfs` by offset): the offsets are undocumented and change per BIOS
  version, so the risk is corrupting or bricking it. The options that matter are already in
  F7 Advanced Mode.

## Updating the BIOS (reference)

1. Download the version's `.CAP` from <https://www.asus.com/motherboards-components/motherboards/expedition/ex-b560m-v5/helpdesk_bios/>
   and check the official SHA-256.
2. A **FAT32** flash drive, with the `.CAP` at the root.
3. `Del` → `F7` → Tool → **ASUS EZ Flash 3 Utility** → pick the file.
4. The flash **resets the settings to defaults**, so reapply the table above afterwards.
