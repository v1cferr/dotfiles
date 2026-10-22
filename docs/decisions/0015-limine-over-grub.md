# 0015. Limine replaces GRUB, so the initrd is verified too

The bootloader moves from GRUB to Limine, keeping the sbctl keys, the dualboot and ten generations,
because Limine's enrolled config verifies the kernel, the initrd and the command line.

- **Status**: proposed: built and drilled in a VM, waiting for the hardware gates of
  [the migration guide](../guides/limine-migration.md); supersedes 0007 only once those pass
- **Date**: 22/10/2026

## Context

[0007](0007-grub-over-lanzaboote.md) kept GRUB for its menu and theme and accepted the price: the
firmware verifies GRUB and the kernel (through `LoadImage`), and nothing verifies the initrd. Two
facts changed the weighing:

- nixpkgs 26.05 ships `boot.loader.limine` with `secureBoot.enable`, which signs Limine with the
  EXISTING sbctl keys and enrolls a BLAKE2b hash of `limine.conf` into the signed binary. That
  config carries a hash of every kernel AND initrd, and the command line, and Limine panics on a
  mismatch. Read in the pinned source (`limine-install.py`, Limine 12.5.2) on 21/10/2026.
- Limine chainloads an EFI binary on another disk by GPT PARTUUID (`guid(...)`), which is what
  Windows on the SanDisk needs. That was the gap that kept systemd-boot and lanzaboote out.

What lost, and why:

- **lanzaboote**: verifies the same things, but reaching Windows on another ESP still needs the
  EDK2 shell signed and accepted under Secure Boot (0007's open experiment). Limine does it natively.
- **GRUB plus signing the initrd**: GRUB under lockdown has no path to verify an initrd; the `tpm`
  module only measures it.
- **Keeping MineGRUB's look**: it is a theme, and the brief ranks a theme below verification.

## Decision

Limine with `secureBoot.enable`, the existing keys (no key generation, no enrollment), ten
generations, the editor off, and Windows chainloaded by PARTUUID. GRUB stays installed and in the
firmware's BootOrder until the hardware gates pass, as the recovery path.

## Consequences

- The initrd and the command line join what the firmware chain verifies. It still stops a boot
  chain tampered with from outside, not somebody with root: the db key sits unencrypted in
  `/var/lib/sbctl` on a disk without LUKS ([0006](0006-no-disk-encryption.md)).
- The menu is Limine's own text menu over a palette wallpaper. The older generations come EXPANDED
  under one directory: the module writes that tree itself, and folding it would mean patching the
  installer.
- `limine-install.py` does not fail when `sbctl sign` fails. `boot-trust` re-checks the signature
  after every install and raises `my.alert`, so the failure is loud before the next boot.
- MineGRUB, its flake input and the GRUB signer leave in a cleanup commit, only after the gates.
