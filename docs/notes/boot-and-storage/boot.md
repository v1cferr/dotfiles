# boot and Secure Boot

Modules: [`system/core/boot.nix`](../../../system/core/boot.nix),
[`system/core/secureboot.nix`](../../../system/core/secureboot.nix)

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
[`../open-items.md`](../../open-items.md)), otherwise a reboot wipes the keys.

## The mainline kernel

`linuxPackages_latest` (7.1.x) instead of the release default (6.18.x). The reason is the VIDEO
DRIVER: the Arc B580's `xe` lives in the kernel, so a new kernel means a new driver, and it is the
only driver lever that does NOT require crossing channels, since `linuxPackages_latest` comes from
26.05 itself. See [`gpu.md`](../hardware/gpu.md) for why the rest of the graphics stack stays on stable.

It is safe here because there are zero out-of-tree modules (no zfs or virtualbox to version match)
and this machine's Secure Boot signs GRUB, not the kernel, so changing kernels does not ask for a
key re-enroll.

**PREFER `nixos-rebuild boot` plus a reboot** when changing kernel versions, but `switch` does NOT
break it: NixOS keeps `/run/booted-system/kernel-modules` with the tree of the RUNNING kernel, so
modprobe and udev keep resolving. Verified on 06/08/2026: a switch from 6.18.42 to 7.1.6 with zero
failing services. The advantage of `boot` is only not restarting a service inside a generation
whose kernel has not come up yet. Rollback is the previous generation in the GRUB menu.

## os-prober is OFF, and Windows is pinned by UUID

os-prober WORKED, finding the SanDisk's `bootmgfw.efi` on the first try, but it found TOO MUCH: the
Seagate (ST9320423AS) still has the old NixOS root. Today that disk is only the restic destination,
and the old system is still there because it cannot be formatted without losing the backups. The
result was a third entry booting a dead system.

Trading probing for a UUID solves that by CONSTRUCTION, and on top of it: the switch stops mounting
somebody else's disk, which was the slowest step and the only one with a side effect, and the menu
becomes genuinely declarative (rule 3) instead of depending on what a scan finds on that boot.

**The price, stated**: if Windows is reinstalled or moves disks, the UUID changes and the entry
breaks silently, disappearing from the menu. os-prober would adapt on its own. It is a ONE-line
edit, and it is already on the radar, since the plan is to move Windows to a new NVMe. Check with
`lsblk -o NAME,LABEL,UUID`.

## What makes GRUB boot with Secure Boot on

THREE things, each one learned by a boot dying in a different way. In none of them was the firmware
the one refusing: it ACCEPTED the signed `grubx64.efi` every single time. What refuses is GRUB,
against itself, and the three messages below are all GRUB strings, not UEFI ones.

**1. `--modules=…`.** With Secure Boot active GRUB disables `insmod`, because that is code
side-load. Since `grub-install` embeds only the minimum needed to find `/boot`, `normal` (the module
that DRAWS THE MENU) came from the disk and was blocked, so it went straight to rescue, before any
menu. Everything the boot needs has to be INSIDE the signed binary. The names were checked one by
one against grub2_efi: all 47 exist.

**2. `--disable-shim-lock`.** This is the non-obvious one, and embedding modules ALONE would not
solve it: the menu would appear and then BOTH NixOS AND Windows would fail.

In `kern/efi/sb.c`, `grub_shim_lock_verifier_setup()` only does NOT register the verifier in two
cases: Secure Boot off, or the image carrying the `OBJ_TYPE_DISABLE_SHIM_LOCK` marker, which is
what this flag embeds. Once registered, it covers `GRUB_FILE_TYPE_LINUX_KERNEL` and
`GRUB_FILE_TYPE_EFI_CHAINLOADED_IMAGE`, and its `write` calls the shim protocol, which here DOES
NOT EXIST, because we use no shim, so every boot dies in "shim_lock protocol not found".

**3. `tpm` in the module list.** Flags 1 and 2 drew the menu and then killed BOTH entries with
`error: verification requested but nobody cares`, measured on 30/08/2026. The chain of causes is
worth reading in order, because the message names no file that is wrong:

- `kern/efi/init.c:123` calls `grub_lockdown()` UNCONDITIONALLY when Secure Boot is on, and only
  afterwards `grub_shim_lock_verifier_setup()`. Flag 2 skips the second one, never the first.
- `kern/lockdown.c:55` registers a verifier that answers `GRUB_VERIFY_FLAGS_DEFER_AUTH` for
  `LINUX_KERNEL`, `EFI_CHAINLOADED_IMAGE`, `GRUB_MODULE` and 14 other types. DEFER does not mean
  "denied", it means "I do not verify this, somebody else has to".
- `kern/verifiers.c:100` walks the registered verifiers. If one deferred and NOBODY else claimed the
  file, line 118 fails with the message above. So the error is not a bad signature: it is a file
  that needed an owner and had none.
- `commands/tpm.c:33` is the owner. Its `init` returns `SINGLE_CHUNK`, neither SKIP nor DEFER, so
  the loop STOPS there and the file goes through, hashed into PCR 9 along the way.

Order helps instead of hurting: verifiers are pushed onto a list, and `tpm` loads with the modules,
after `grub_efi_init`, so it sits in FRONT of the lockdown one and answers first.

It has to be EMBEDDED, never loaded off `/boot`: lockdown defers on `GRUB_FILE_TYPE_GRUB_MODULE`
too, so a `tpm.mod` on disk would need a verifier in order to load the verifier. And it only works
because this machine has a TPM 2.0 (`MSFT0101`) whose TCG2 protocol the firmware publishes, which is
exactly what `grub_tpm_present()` looks for. Turning the TPM off in the BIOS brings the error back.

**4. The kernel signed, because GRUB does not load it.** Getting past the verifier only gets the
file OPEN. On `x86_64-efi` the `linux` module is `loader/efi/linux.c` (Makefile.core.def), and line
211 hands the buffer to the FIRMWARE's `LoadImage`, with `start_image` right after. Under Secure
Boot that call validates the PE against `db` like any other image, and an unsigned kernel comes back
as `error: cannot load image`. So `secureboot.nix` signs `/boot/kernels/*bzImage` on every switch,
with no `-s`: the name carries the store hash, the GC deletes it, and recording it in sbctl's
database would only pile up entries for files that no longer exist.

**What the chain is worth, stated.** Better than the earlier note in this file claimed, and for a
reason that is not GRUB's doing. `tpm` MEASURES and does not verify, and flag 2 is literally "do not
verify anything after me", so GRUB itself checks nothing. But the kernel goes out through
`LoadImage`, which puts the FIRMWARE back in the loop: swapping it for an unsigned one does not
boot, and signing one demands the key in `db`. What stays unprotected is the INITRD, which GRUB
hands over through its own protocol, without ever going near `LoadImage`, and which `sb.c:149` files
under "does not affect secureboot state" even on the shim road. Whoever has root swaps the initrd,
not the kernel. Closing that means a UKI (kernel plus initrd plus cmdline in ONE signed PE), which
is lanzaboote, and then there is no menu and no theme.

## Two smaller boot details

**`gfxmode` is a list with a fallback**, not `"auto"`. `auto` lets GRUB choose by EDID, and here
there is a TV on HDMI besides the monitor, so the wrong mode means a stretched theme or a menu on
the powered-off screen. GRUB tries the list in order and only falls back to `auto` if the GOP does
not offer 1080p.

**NTFS support**: the `ntfs3` driver already ships in the kernel, but what `mount` looks for is the
userspace helper `mount.ntfs-3g`, which only exists with `boot.supportedFilesystems`. Kept after the
dualboot was done so the Windows disk can be read on demand. There is no permanent mount of it.

The "old generations" submenu title is in en-US like the rest of the system UI (the pt-BR exception
is only the lockscreen), and it overrides the theme's default text, which is a "Select To Enter"
that does not say what is in there.
