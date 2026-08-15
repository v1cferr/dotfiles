# Turning the dualboot on with Secure Boot: step by step

> **TEMPORARY FILE.** Delete it as soon as Secure Boot is on and both systems boot. What
> needs to survive is already in the header of
> [`system/core/secureboot.nix`](../../system/core/secureboot.nix); this one is only the
> sequence for the night. A completed runbook that stays in the repo turns into a lie later.

## WHERE THIS STOPPED (measured on 09/08/2026)

**Phases 0 through 3 are DONE. Only Phase 4 is left, turning Secure Boot on in the BIOS.**

| Phase | State | How it was measured |
| --- | --- | --- |
| 0, BitLocker off | done | `lsblk` shows the Windows volume as `ntfs`, not `BitLocker` |
| 1, GRUB + `create-keys` | done | `/var/lib/sbctl/keys` exists (02/08 03:07) |
| 2, Setup Mode | done (and already left) | `SetupMode = 0` |
| 3, `enroll-keys -m` | done | `PK`/`KEK`/`db` are the sbctl keys (valid 02/08/2026 to 02/08/2031) and the `db` carries both the 2011 **and** 2023 Microsoft CAs |
| 4, **turn SB on** | PENDING | `SecureBoot = 0`, the firmware is in User Mode with the right keys, only with SB off |

Measure it again without root, at any time:

```bash
cd /sys/firmware/efi/efivars
od -An -tu1 SecureBoot-8be4df61-93ca-11d2-aa0d-00e098032b8c   # 5th byte: 1 = on
od -An -tu1 SetupMode-8be4df61-93ca-11d2-aa0d-00e098032b8c    # 5th byte: 0 = keys enrolled
```

> The 02/08 history marked "Secure Boot on in both OSes" as done, and it **was not**. The
> keys went in, but SB was never actually turned on after the `grub rescue>` of that night.

Before going to Phase 4, do the preflight, which is exactly what burned on 02/08:

```bash
sudo sbctl status && sudo sbctl verify
ls -la /boot/EFI/NixOS-boot/grubx64.efi   # >= ~1.5 MB means the 47 modules are embedded
```

`verify` will complain about `/boot/EFI/BOOT/BOOTX64.EFI`: that is expected noise
(systemd-boot is already deleted and it stayed in the sbctl database, see the cleanup at the
end of this file). Do not abort because of it.

## What can go wrong, and why it is not serious

NixOS boots from the Kingston (`nvme0n1`) and Windows from the SanDisk (`sda`), separate
ESPs on separate disks. No step here writes to the other one's disk.

> **The `sd*` letters swap between boots.** On 09/08/2026 the SanDisk was `sda` and the
> old Seagate (with the dead NixOS root) was `sdb`, the opposite of what this guide used to
> say. **Always check by model, never by letter:** `lsblk -d -o NAME,MODEL`. The GRUB entry
> is immune to this (it matches by UUID), but whoever checks the wrong disk "fixes"
> `boot.nix` to the wrong UUID and breaks the menu silently.

The realistic worst case is the firmware refusing GRUB for lack of a signature, and the way
out is always the same: **turn Secure Boot off in the BIOS**. There is no brick in this
runbook; what the firmware refuses is a binary, not the disk.

---

## Phase 0, Windows: turn BitLocker off DO THIS FIRST

The `sdb3` volume is formatted with BitLocker. Touching Secure Boot **changes PCR 7**, and
BitLocker answers that by asking for the recovery key at boot, which nobody saved, because
the account is local.

Boot Windows and open an **administrator cmd**:

```text
manage-bde -status
```

If any volume says **"Protection On"**:

```text
manage-bde -off C:
```

That **decrypts the disk** and takes minutes to hours on 900 GB. Follow it with
`manage-bde -status` until `Percentage Encrypted: 0.0%` and `Protection Off`.

> Do not move to Phase 1 while the decryption has not finished. Rebooting in the middle
> corrupts nothing, but the protection stays active until the end, which is precisely the
> problem.

**While you are in Windows**, fix the clock too (otherwise the two systems fight over 3
hours on every switch, since NixOS keeps the RTC in UTC and Windows assumes local time):

```text
reg add "HKLM\SYSTEM\CurrentControlSet\Control\TimeZoneInformation" /v RealTimeIsUniversal /t REG_DWORD /d 1 /f
```

---

## Phase 1, NixOS: GRUB up, still WITHOUT Secure Boot

The goal of this phase is proving that GRUB comes up and sees Windows, **while getting it
wrong is still cheap**. Do not jump to Secure Boot before this works.

```bash
cd ~/Projects/GitHub/v1cferr/dotfiles
sudo sbctl create-keys          # creates /var/lib/sbctl/keys
rebuild
```

The `rebuild` will print `installing the GRUB 2 boot loader...`. The Windows entry is
**pinned by UUID** (`904C-B9D0`, the SanDisk ESP), it does not come from a scan, so it always
shows up in the file. What needs checking is whether the UUID still matches:

```bash
sudo grep -A5 'menuentry "Windows 11"' /boot/grub/grub.cfg
lsblk -o NAME,MODEL,LABEL,UUID       # the SanDisk ESP has to be 904C-B9D0
sbctl verify                          # grubx64.efi should show up as signed
```

If the SanDisk ESP is **not** `904C-B9D0`, fix it in
[`system/core/boot.nix`](../../system/core/boot.nix) before going on, because the entry would
exist in the menu and simply not boot.

**Reboot.** You should see the Minecraft menu with two worlds: NixOS and Windows 11. Test
**both**, including entering Windows and coming back.

---

## Phase 2, BIOS: erase the factory keys

Reboot and enter setup (**DEL** on the EX-B560M-V5). Go to `Boot → Secure Boot`.

1. **`Secure Boot Mode` → `Custom`** **This is the step that unlocks everything.** In
   `Standard`, ASUS does not even SHOW the `Key Management` submenu, since the firmware uses
   the factory keys and does not let you touch them. If you cannot find "Clear Secure Boot
   Keys", it is because you are still in Standard.
2. `Key Management` → **`Clear Secure Boot Keys`** → the state becomes **`Setup`**.
3. Save and exit (**F10**).

> **Do not touch `Install Default Secure Boot Keys`.** It restores the factory keys and
> undoes the Phase 3 enroll. It is in the same menu, one line over.

That puts the firmware in **Setup Mode**. Booting stays normal, because in Setup Mode Secure
Boot is inactive, so GRUB and Windows keep coming up.

> Note: `OS Type` (`Windows UEFI mode` / `Other OS`) is a DIFFERENT thing, it is the Secure
> Boot on/off switch, and it belongs to Phase 4. `Secure Boot Mode` is what controls whether
> the keys are the factory ones or yours. The two names look alike and sit on the same
> screen.

---

## Phase 3, NixOS: enroll the keys

> **If you are resuming after the `grub rescue>` of 02/08:** the firmware is in Setup
> Mode and the keys were cleared again, so start over with a `rebuild`, which reinstalls GRUB
> **with the embedded modules** (`extraGrubInstallArgs`) and re-signs it. Without that
> `rebuild` the binary on the ESP is still the old one, and the rescue mode comes back.

```bash
rebuild                  # reinstalls GRUB with the embedded modules + signs it
sudo sbctl enroll-keys -m
sbctl status
```

`status` should show **Setup Mode: Disabled** (the keys went in).

> **The `-m` is not optional.** It is what reinstalls the Microsoft certificates along
> with yours. Without it you take down Windows **and** the Arc B580's option ROM, since both
> are signed by Microsoft. It has already been checked on this machine: sbctl 0.18 carries
> both CA generations (2011 and 2023), so Windows keeps booting even after the 2011
> certificate expired, in june/2026.

---

## Phase 4, BIOS: turn Secure Boot on

1. `Boot → Secure Boot → OS Type` → **`Windows UEFI mode`** (this is the on/off switch; in
   `Other OS` Secure Boot stays inactive).
2. Confirm that `Secure Boot State` became **Enabled**.
3. Save and exit (**F10**).

> `Secure Boot Mode` **stays in `Custom`**, and that is how it has to stay, because it is
> what says "use the enrolled keys, not the factory ones". Going back to `Standard` would
> undo everything.

---

## Phase 5, check

On NixOS:

```bash
sbctl status                    # Secure Boot: ✓ Enabled
sbctl verify                    # grubx64.efi signed
bootctl status | head -5        # Secure Boot: enabled
```

On Windows, `msinfo32` → **Secure Boot State: On**.

---

## If it goes wrong

| Symptom | What it is |
| --- | --- |
| The firmware boots nothing / "Invalid signature" | GRUB was rewritten without a signature. **BIOS → Secure Boot: Disabled**, boot, `sudo sbctl sign -s /boot/EFI/*/grubx64.efi`, turn SB back on |
| `prohibited by secure boot policy` + `grub rescue>` | **This happened on 02/08.** The signature was RIGHT (the firmware executed GRUB), what was missing were the embedded modules. Solved by `extraGrubInstallArgs` in [`system/core/boot.nix`](../../system/core/boot.nix); check that the `rebuild` reinstalled GRUB |
| `shim_lock protocol not found` | `--disable-shim-lock` is missing from `extraGrubInstallArgs`. Without it GRUB demands a shim that does not exist here, and neither NixOS nor Windows boots |
| Windows in the menu, but it does not boot | The UUID changed. `lsblk -o NAME,MODEL,LABEL,UUID` (by MODEL, the letter swaps) and fix the `search --fs-uuid` in [`system/core/boot.nix`](../../system/core/boot.nix) |
| Windows asks for the recovery key | BitLocker was not turned off (Phase 0). Without the key, `sbctl reset` + SB off gives the previous PCR 7 back |
| Arc B580 with no video at POST | `enroll-keys` without the `-m`. `sudo sbctl reset` with the BIOS in Setup Mode and redo Phase 3 **with** the `-m` |
| I cannot find "Clear Secure Boot Keys" in the BIOS | `Secure Boot Mode` is still in `Standard`. In Standard, ASUS hides the whole `Key Management` |
| It asks for the Microsoft key again / Windows does not boot | Somebody put `Secure Boot Mode` back to `Standard`, or used `Install Default Secure Boot Keys` |
| The GRUB menu looks ugly or stretched | `gfxmodeEfi` did not take 1080p. Adjust it in [`system/core/boot.nix`](../../system/core/boot.nix) |
| A generic icon with no text on some entry | The `--class` of that entry matches no `customIcons.name`. See `grep menuentry /boot/grub/grub.cfg` |

**Last-resort recovery:** turning Secure Boot off in the BIOS gives booting back in every
scenario above. NixOS does not depend on the SanDisk for anything, and Windows does not
depend on the Kingston.

---

## Once everything is up

0. `sudo sbctl remove-file /boot/EFI/BOOT/BOOTX64.EFI`, because that file was systemd-boot
   and it was deleted in the ESP cleanup, but the hook did sign it beforehand, so it stayed
   in the sbctl database and `verify` complains about a file that does not exist.
1. `git rm docs/guides/secure-boot.md`, because this file will have served its purpose.
2. Check whether Moonlight still pairs (the `sunshine_name` changed from `nixos-sandisk` to
   `nixos-kingston`, which is only a display name, since pairing is by certificate).
