# boot and Secure Boot

Modules: [`system/core/boot.nix`](../../system/core/boot.nix),
[`system/core/secureboot.nix`](../../system/core/secureboot.nix)

GRUB (UEFI) with the minegrub theme, in dualboot with Windows 11, signed with our own keys
through sbctl. The two modules share one decision, so they share a page.

## Why GRUB, and not the systemd-boot that was here until aug/2026

Each system has ITS OWN ESP, on a separate disk: NixOS on the Kingston (`nvme0n1p1`, `/boot`) and
Windows 11 on the SanDisk's ESP (label SYSTEM, UUID 904C-B9D0). The `sd*` LETTER SWAPS between
boots, so identify that one by model, never by `sdX`.

systemd-boot only loads an EFI binary from its OWN ESP, so it is incapable of listing Windows:
switching OS would become F8 at POST every time. GRUB reads both.

That is also what rules out **lanzaboote**, the official Secure Boot path on NixOS, which is
systemd-boot-only. The dualboot with a menu is worth more than an end-to-end verified chain, and
the next section explains why that chain would not be complete here anyway.

## The theme's icons match by `--class`, not by the entry's title

It is the only real trap in boot.nix, and it fails SILENTLY, falling back to a generic icon with
no text:

| Class | Where it comes from |
| --- | --- |
| `nixos` | the default `entryOptions = "--class nixos --unrestricted"` |
| `windows` | the `--class windows` written by hand in `extraEntries` |
| `submenu` | old generations (`install-grub.pl` emits `--class submenu`) |

Each `customIcons` name becomes the theme's `icons/<name>.png`, and the two lines of text are
RENDERED INSIDE the PNG in the Minecraft font, so it is not GRUB text. That is why every
generation shows the same description: they share the `nixos` class. A theme limitation, not a
config error.

## Kernels on the ESP

They are copied automatically: `install-grub.pl:107` turns `copyKernels` on when `/boot` is on a
different filesystem from `/nix/store`, which avoids depending on GRUB being able to read
btrfs+zstd. The file is named by the store hash, so generations sharing a kernel occupy space
ONCE. The 10-generation limit fits comfortably in the ESP's 1 GiB: today 13 MiB of kernel plus
47 MiB of initrd per version.

## What Secure Boot here gives you, and what it does not

The firmware verifies GRUB (signed with this machine's key) and verifies Windows' `bootmgfw.efi`
(signed by Microsoft). **GRUB then loads the kernel and initrd WITHOUT verifying anything**, and
that is not an accident: it is the `--disable-shim-lock` in boot.nix, which is MANDATORY for the
machine to boot. Without it GRUB demands the shim protocol, which does not exist here, and dies
with `shim_lock protocol not found`, on NixOS as well as on Windows.

So this satisfies the firmware and Windows, and it blocks a bootloader swapped from outside. It
does NOT block somebody who already has root and swaps the kernel. The whole chain would need
shim (and then a kernel signed by Microsoft) or lanzaboote (and then no menu and no theme). There
is no third door.

## Microsoft's certificates are mandatory

`enroll-keys -m`, always. Without it, wiping the factory keys takes down Windows (whose bootloader
is signed by MS) **and** the Arc B580's option ROM, which is too.

Checked on 02/08/2026 on this machine: BIOS 2803's `db` already carries BOTH generations of CA,
the 2011 ones (Windows Production PCA / Corporation UEFI CA) and the 2023 ones (Windows UEFI CA
2023, Microsoft UEFI CA 2023, Option ROM UEFI CA 2023), and sbctl 0.18 embeds all six. That
matters NOW and not in theory: the 2011 CA expired in june/2026 and new Windows updates come
signed by the 2023 one. Enrolling only 2011 would be a Windows that boots today and stops booting
on some Patch Tuesday. (`--firmware-builtin` is no good here: this firmware's `dbDefault` is
EMPTY.)

## The runbook

Enrolling a key requires the firmware in Setup Mode, and Setup Mode is only entered through the
BIOS. None of this is automatable; what Nix automates is the signing.

0. **ON WINDOWS FIRST**: `manage-bde -status`. If any volume says "Protection On", run
   `manage-bde -off C:` and WAIT for the decryption to finish. Touching Secure Boot changes PCR 7,
   and BitLocker answers that by asking for the recovery key at boot, which nobody saved, because
   the account is local.
1. `sudo sbctl create-keys` (creates `/var/lib/sbctl/keys`)
2. `rebuild` (the hook signs GRUB)
3. BIOS (DEL): Secure Boot -> Key Management -> **Clear Secure Boot Keys**. Save and exit (F10).
   That puts the firmware in Setup Mode; the boot goes on as usual.
4. `sudo sbctl enroll-keys -m` (with Microsoft's certificates). `sbctl status` should show
   Setup Mode: Disabled.
5. BIOS: **Secure Boot -> Enabled** (OS Type: Windows UEFI mode). Reboot.
6. Check: `sbctl status` and `sbctl verify`.

**If the machine does not boot**, turn Secure Boot off in the BIOS. There is no bricking possible:
the only thing the firmware refuses is the binary, and turning SB off gives it back.

## Why the signing hook runs on every switch

`grub-install` only rewrites `grubx64.efi` when something changes (the GRUB version, the ESP, the
devices), and it is EXACTLY on that switch, the one you did not foresee, that a new unsigned
binary goes to the ESP. With Secure Boot on, that is a machine that does not turn on, discovered
on the next reboot and not on the rebuild that caused it.

The hook globs the ESP instead of using the literal path, because the default `bootloaderId` is
assembled by the module as distroName plus the ESP's mountpoint with `/` turned into `-` (giving
`NixOS-boot`), and depending on that string is depending on a nixpkgs internal. Sweeping the ESP
runs no risk of signing somebody else's binary, since the Windows ESP is ANOTHER disk.

`sbctl sign` is idempotent (`cmd/sbctl/sign.go:88` returns 0 on an already signed file), so
running it every switch is cheap and does not mask a real failure: any other error exits non-zero
and `set -e` takes the activation down, which is what you want.

## `/var/lib/sbctl` is critical state

It is not in restic (rule 6 sends state to the backup; this is state the backup does not cover).
Losing that folder means the next switch does not sign GRUB, which means the machine does not boot
with SB on. Recovery: SB off in the BIOS, redo steps 1 to 5.

It is the FIRST item to declare when impermanence lands (see
[`../open-items.md`](../open-items.md)), otherwise a reboot wipes the keys.
