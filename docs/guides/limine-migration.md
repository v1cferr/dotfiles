# Limine migration: GRUB to Limine on the real ESP, with GRUB kept as the way back

[ADR 0015](../decisions/0015-limine-over-grub.md) is built and drilled in a VM. What a VM cannot
prove is this machine: the ASUS firmware, the Arc B580, two monitors and Windows on the SanDisk.
This is the order to do it in, each gate with what must be true before the next one.

**Nothing here runs from a rebuild by accident**: `my.boot.loader` defaults to `"grub"` and
`my.boot.splash.enable` to `false`. Every step below is a commit you make on purpose.

## What changes on the ESP, and what does not

| Path on `/boot` | GRUB today | After the Limine install |
| --- | --- | --- |
| `EFI/NixOS-boot/grubx64.efi`, `grub/`, `kernels/` | written, signed | **left as is** (Limine's cleanup only walks `limine/`) |
| `EFI/limine/BOOTX64.EFI` | absent | written, config hash enrolled, signed by `sbctl sign` |
| `limine/limine.conf`, `limine/kernels/`, `limine/wallpapers/` | absent | written on every install |
| `EFI/BOOT/BOOTX64.EFI` (the removable fallback) | whatever is there | **untouched**: `efiInstallAsRemovable` stays false |
| NVRAM | `NixOS-boot`, `Windows Boot Manager` | plus `Limine`, created at the FRONT of BootOrder on the first install |

The Windows ESP (`sdb1`) is only read, by the firmware, when you pick Windows. Measured on
21/10/2026: the NixOS ESP holds 140 MiB of 1022 MiB under GRUB; Limine adds one copy of each
kernel and initrd per kept generation, deduplicated by store path.

## C0: before anything

1. Secure Boot is on, in user mode, and the keys are there:

   ```bash
   sudo sbctl status                  # Setup Mode: Disabled, Secure Boot: Enabled
   sudo ls /var/lib/sbctl/keys/db/    # db.key and db.pem
   ```

2. Snapshot the ESP and the NVRAM, somewhere off the NVMe:

   ```bash
   sudo tar -C /boot -cpf /mnt/backup/esp-$(date +%F).tar .
   nix shell nixpkgs#efibootmgr -c sudo efibootmgr -v | tee ~/efibootmgr-before.txt
   ```

3. Keep the GRUB generation alive. GRUB's menu stops growing once Limine is the loader, and its
   entries point into the store:

   ```bash
   sudo ln -sfn "$(readlink -f /run/current-system)" /nix/var/nix/gcroots/grub-fallback
   ```

4. BitLocker must be off: a different boot path can change what it measured. Checked on
   22/10/2026 from Linux: the C: volume (`/dev/sdb3`, with `Windows/System32`) mounts through
   `ntfs3` at `/mnt/windows`, and a BitLocker volume, even suspended, stays encrypted on disk and
   never mounts as NTFS. So it is decrypted. From Windows, `manage-bde -status C:` says the same.
5. A NixOS 26.05 USB stick that boots. It is NOT signed by this machine's db, so using it means
   turning Secure Boot off in the BIOS for that boot only ([bios-ex-b560m-v5](bios-ex-b560m-v5.md)).

## C1: the splash, still on GRUB

The splash lives in the initrd and does not touch the bootloader, so it goes first, alone.

1. In `hosts/ex-b560m-v5/default.nix`: `my.boot.splash.enable = true;`, commit.
2. `sudo nixos-rebuild boot --flake .#ex-b560m-v5`, then a COLD boot and a WARM reboot.
3. Gate: the splash on the main monitor (the LG shows it unrotated, expected), LightDM's autologin,
   the lock screen up before the desktop, Sunshine reachable, `systemctl --failed` empty,
   `journalctl -b -u plymouth-start -u plymouth-quit` clean.

**PASSED on 22/10/2026**: a warm reboot, a poweroff and a cold boot, the splash at boot and
`Shutting down` at poweroff, no black screen, `systemctl --failed` empty. Plymouth showed at 1.1 s
(in the initrd) and quit at 8.4 s, as LightDM started; the initrd grew 6.8 MiB and took 2.33 s
against 3.2 s before, inside the usual spread. The first reboot showed no splash on the way down:
it ran from the generation booted WITHOUT `splash` on the command line, so Plymouth stayed in text.

Escape on the splash shows the text console. To boot once without it from GRUB, `e` on the entry
and append `plymouth.enable=0`. Under Limine the editor is OFF (Secure Boot), so the way out there
is an older generation or a rebuild with the flag off.

## C2: Limine, one boot at a time

1. In `hosts/ex-b560m-v5/default.nix`: `my.boot.loader = "limine";`, commit.
2. `sudo nixos-rebuild boot --flake .#ex-b560m-v5`. Then check the install, which does NOT fail by
   itself when signing fails:

   ```bash
   sudo systemctl start boot-trust && cat /run/boot-trust.json   # signed: valid, integrity: enrolled
   ```

3. Put GRUB back in front and ask for Limine ONCE:

   ```bash
   sudo efibootmgr                         # note the numbers of NixOS-boot, Limine, Windows
   sudo efibootmgr -o <grub>,<limine>,<windows>
   sudo efibootmgr -n <limine>             # BootNext: the next boot only
   ```

4. Reboot. Limine comes up; whatever happens, the boot after it is GRUB again.
5. Gate, all of it on this hardware:
   - the menu: `Limine 12.5.2 (x86-64, UEFI, Secure Boot)` on top, the logo, NixOS generations,
     Windows 11; the arrows and Enter work
   - NixOS boots; `cat /run/boot-trust.json` reads `thisBoot: verified`, and the Center's BOOT
     cards are all green
   - an older generation boots
   - Windows 11 boots from the menu, and so does a warm reboot back (the Arc's `reboot=pci` path)
   - the splash at boot, at reboot and at shutdown; LightDM, the lock screen, Sunshine
   - `systemd-analyze` now shows a `loader` time (Limine reports it); record it against GRUB's
6. Promote: `sudo efibootmgr -o <limine>,<grub>,<windows>`. Later installs keep Limine's place.

## If it goes wrong

| What you see | What to do |
| --- | --- |
| The firmware refuses Limine (Secure Boot violation) | Reboot; without BootNext it is GRUB. Then `boot-trust` tells you why |
| Limine panics on a hash mismatch | Reboot into GRUB (F8 for the firmware menu), or an older generation in Limine |
| Windows does not chainload | F8 and pick Windows Boot Manager; the firmware entry was never touched |
| Nothing boots | USB stick (Secure Boot off for it), mount the root subvolume and `/boot`, `nixos-enter`, set `my.boot.loader = "grub"`, `nixos-rebuild boot`; or untar the ESP snapshot |

Going back on purpose: `my.boot.loader = "grub"`, `nixos-rebuild boot`, check GRUB boots, then
`sudo efibootmgr -b <limine> -B`. The `limine/` and `EFI/limine/` directories can go after that.

## D: the cleanup, only after C2 passed

Remove MineGRUB (the flake input and its lock entry), the GRUB branch of `modules/nixos/core/boot.nix`,
the GRUB signer in `secureboot.nix`, the selector itself, and the `grub-fallback` GC root. ADR 0007
becomes "superseded by 0015" and 0015 "accepted". Then the full gate again.
