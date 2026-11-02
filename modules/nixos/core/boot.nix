# BOOT: the kernel and the boot-time basics. The bootloader itself is Limine (limine.nix); why it
# replaced GRUB: docs/decisions/0015-limine-over-grub.md
{ pkgs, ... }:

{
  # The newest RELEASED mainline, because the Arc's `xe` driver LIVES in the kernel and this is the
  # only driver lever that does not cross channels. Not `_testing`: while the fan patch exists every
  # bump is an hour's local build (docs/notes/hardware/fans.md). Prefer `boot`; `switch` is safe.
  boot.kernelPackages = pkgs.linuxPackages_latest;

  boot.loader.efi.canTouchEfiVariables = true;

  # NTFS: the driver is in the kernel, but `mount` needs the userspace `mount.ntfs-3g`, which only
  # exists with this option. There is no permanent mount of the Windows disk.
  boot.supportedFilesystems.ntfs = true;

  # /tmp lives on the btrfs root, so wipe it at boot: a stale lock there silently killed flameshot.
  boot.tmp.cleanOnBoot = true;
}
