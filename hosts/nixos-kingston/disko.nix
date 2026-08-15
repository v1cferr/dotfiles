# ═══════════════════════════════════════════════════════════════════════════
# The DECLARATIVE disk layout, host nixos-kingston (KINGSTON KC3000, NVMe Gen4).
#
# DESTRUCTIVE: it wipes the whole disk. It does NOT run on a normal rebuild, only on the
# CUTOVER, which HAS ALREADY HAPPENED (01/08/2026). The Arch that lived here was archived to
# Google Drive before that, and `check --read-data` proved the repo on 05/08; how to reach it is
# in docs/history/ (the module that created the repo has already been deleted).
#
# Selection by by-id (sd/nvme names SHUFFLE between boots). NEVER use /dev/nvmeXnY.
#
# To apply on a cutover (booting from the installer USB stick):
#   sudo nix run github:nix-community/disko -- --mode destroy,format,mount \
#     --flake .#nixos-kingston
#   sudo nixos-install --flake .#nixos-kingston
#
# ── WHY BTRFS HERE, when the SanDisk is ext4 ───────────────────────────────
# It is not for btrfs itself, it is for the SUBVOLUME LAYOUT, which is a prerequisite for
# IMPERMANENCE (docs/history/2026/07-july.md, the 30/07 entry: an ephemeral root plus an
# explicit list of what persists, inspired by Misterio77's Foundry). Impermanence requires /nix
# and /persist on volumes separate from the root FROM THE INSTALL ONWARD; installing flat ext4
# would mean reinstalling all over again to adopt it. The feature is NOT on yet, and `@persist`
# is born empty on purpose. Turning it on later becomes a config change.
#
# KC3000 (Phison E18, 800 TB TBW): CoW's write amplification is irrelevant at that volume, and
# zstd REDUCES writes on compressible data. CoW fragmentation only bothers a database or a VM
# image, and the `+C` for those cases is declared in system/hardware/btrfs.nix.
#
# ── THE MOUNT OPTIONS, and why these ───────────────────────────────────────
# `compress=zstd:1` and not bare `zstd` (which is level 3): on a Gen4 at ~7 GB/s the bottleneck
# becomes the COMPRESSOR, not the disk. zstd:1 compresses several times faster for ~5-10% less
# ratio, and DECOMPRESSION runs at the same speed on both levels, so reads lose nothing. On a
# 953 G disk at 49%, the GiB saved by :3 do not buy the cost on every `nixos-rebuild`.
# Changing the level only affects NEW writes: what is already stored stays at zstd:3
# (harmless). Rewriting would require `defragment -r -czstd`, which BREAKS reflinks/snapshots
# and would multiply the used disk. Do not do it.
#
# `discard=async` has been the kernel default since 6.2, but it is EXPLICIT on purpose: it is
# what justifies `services.fstrim.enable = false` in system/hardware/btrfs.nix. A policy that
# depends on an implicit kernel default breaks silently on a bump, so if you take it out of
# here, turn fstrim back on in the same commit.
#
# THE SWAP TRAP: on btrfs a swapfile requires NOCOW and zero compression, otherwise the kernel
# refuses to activate it. That is why `@swap` is a subvolume OF ITS OWN and WITHOUT compress,
# and disko uses `btrfs filesystem mkswapfile`, which already applies the right attributes. The
# consequence: the /swapfile `swapDevices` left system/hardware/hardware.nix (which is shared)
# and became a host matter, declared here by disko.
# ═══════════════════════════════════════════════════════════════════════════
{
  disko.devices.disk.kingston = {
    type = "disk";
    device = "/dev/disk/by-id/nvme-KINGSTON_SKC3000S1024G_50026B7686B3D2F6";
    content = {
      type = "gpt";
      partitions = {
        ESP = {
          size = "1G";
          type = "EF00";
          content = {
            type = "filesystem";
            format = "vfat";
            mountpoint = "/boot";
            mountOptions = [ "umask=0077" ];
          };
        };
        root = {
          size = "100%";
          content = {
            type = "btrfs";
            extraArgs = [ "-f" ]; # it overwrites a previous FS signature (the Arch ext4)
            # Repeated on every subvolume because disko requires it (there is no inheritance);
            # the WHY of each option is in the header.
            subvolumes = {
              # The future target of the impermanence rollback: THIS is the one that will be
              # wiped on every boot when the feature lands. Which is why nothing that matters can
              # live outside the other subvolumes.
              "@" = {
                mountpoint = "/";
                mountOptions = [
                  "compress=zstd:1"
                  "noatime"
                  "discard=async"
                ];
              };
              "@home" = {
                mountpoint = "/home";
                mountOptions = [
                  "compress=zstd:1"
                  "noatime"
                  "discard=async"
                ];
              };
              # /nix is immutable and huge: noatime avoids a write on every read.
              "@nix" = {
                mountpoint = "/nix";
                mountOptions = [
                  "compress=zstd:1"
                  "noatime"
                  "discard=async"
                ];
              };
              # Empty TODAY. It becomes the destination of the explicit persistence list.
              "@persist" = {
                mountpoint = "/persist";
                mountOptions = [
                  "compress=zstd:1"
                  "noatime"
                  "discard=async"
                ];
              };
              # Separate, otherwise impermanence would take the journal along on reboot, and
              # losing the log is losing exactly what explains the boot that went wrong.
              "@log" = {
                mountpoint = "/var/log";
                mountOptions = [
                  "compress=zstd:1"
                  "noatime"
                  "discard=async"
                ];
              };
              # The home of the btrbk snapshots (system/services/btrbk.nix). A TOP-LEVEL
              # subvolume, not a directory inside `@`, for two reasons: (1) the impermanence
              # rollback would wipe `@` and take along exactly the history that exists to save
              # your skin; (2) outside `@home`, restic never trips over it (otherwise it would
              # back up every snapshot).
              #
              # `nofail`: the subvolume is NOT born on a rebuild, since disko only runs on an
              # install. On an already installed system it is created by hand, ONCE:
              #   sudo mount -o subvolid=5 /dev/nvme0n1p2 /mnt \
              #     && sudo btrfs subvolume create /mnt/@snapshots && sudo umount /mnt
              # With nofail, forgetting that step costs you "btrbk does not run" (it demands the
              # mount through RequiresMountsFor) instead of "the boot falls into the emergency
              # shell".
              "@snapshots" = {
                mountpoint = "/.snapshots";
                mountOptions = [
                  "compress=zstd:1"
                  "noatime"
                  "discard=async"
                  "nofail"
                ];
              };
              # NO compress and NO noatime: btrfs' mkswapfile requires pure NOCOW.
              "@swap" = {
                mountpoint = "/swap";
                swap.swapfile.size = "16G"; # = the RAM, the same criterion as the old host
              };
            };
          };
        };
      };
    };
  };
}
