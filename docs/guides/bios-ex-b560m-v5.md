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
| Primary Display | PCIE | Advanced → System Agent / Graphics | recommended |
| Secure Boot → OS Type | Other OS | Boot → Secure Boot | recommended |
| Fast Boot | Disabled | Boot | recommended |
| Ai Overclock Tuner (XMP) | XMP I (3200 MT/s) | Ai Tweaker | confirmed (3200 MT/s) |

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

- `boot.kernelParams = [ "reboot=pci" ]` in `system/gpu.nix` (the intel profile): it forces a
  full reset through 0xCF9 on `reboot`, the GPU reinitializes clean as in a cold boot and the
  POST does not fail, so CSM is never turned back on. **It fixes the warm-reboot hang.**
- `services.fwupd.enable = true` in `system/hardware.nix`: it does NOT cover this board's
  BIOS (ASUS is outside LVFS); it serves SSD firmware and other components.

## Backup and restore

- **Profile in the BIOS (native):** Tool → ASUS User Profile (or Save & Exit → Save Profile),
  which saves into a slot (1-8) in NVRAM. After a Clear CMOS it is just Load Profile.
- **Recovering from a hang:** hold the power button ~8s, and a cold boot always recovers the
  Arc. As a last resort, a Clear CMOS (the CLRTC jumper, or pulling the battery for ~1 min)
  goes back to defaults.

## Do NOT do

- **Do NOT flash a modified BIOS** (a mod for hidden menus): this board has **no USB BIOS
  FlashBack**, so a brick becomes a job for an external SPI programmer (CH341A + clip).
- **Do NOT edit the raw variables** (`AMITSESetup`, `CpuSetup` and friends, through
  `setup_var`/`efivarfs` by offset): the offsets are undocumented and change per BIOS
  version, so the risk is corrupting or bricking it. The options that matter are already in
  F7 Advanced Mode.

## Updating the BIOS (reference)

1. Download the version's `.CAP` from <https://www.asus.com/motherboards-components/motherboards/expedition/ex-b560m-v5/helpdesk_bios/>
   and check the official SHA-256.
2. A **FAT32** flash drive, with the `.CAP` at the root.
3. `Del` → `F7` → Tool → **ASUS EZ Flash 3 Utility** → pick the file.
4. The flash **resets the settings to defaults**, so reapply the table above afterwards.
