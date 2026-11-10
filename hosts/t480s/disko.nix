# DESTRUCTIVE disk layout for t480s (its KIOXIA BG4). It runs on an INSTALL, never on a rebuild.
# The desk's btrfs layout inside LUKS; the subvolumes' reasons: docs/notes/boot-and-storage/disko.md
let
  # ONE definition (rule 11); only the FIRST mounted subvolume's options take effect anyway.
  btrfsOptions = [
    "compress=zstd:1"
    "noatime"
    "discard=async"
  ];
in
{
  disko.devices.disk.kioxia = {
    type = "disk";
    device = "/dev/disk/by-id/nvme-KBG40ZNS512G_NVMe_KIOXIA_512GB_Z0KPG2DQQUN1";
    content = {
      type = "gpt";
      partitions = {
        # Outside LUKS: Limine reads the kernel and the initrd from here.
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
        luks = {
          size = "100%";
          content = {
            type = "luks";
            name = "cryptroot";
            # Read ONCE, at format time: the install uploads it (`--disk-encryption-keys`).
            passwordFile = "/tmp/luks-passphrase";
            settings.allowDiscards = true; # TRIM through dm-crypt, or discard=async does nothing
            content = {
              type = "btrfs";
              extraArgs = [ "-f" ]; # it overwrites a previous FS signature
              subvolumes = {
                "@" = {
                  mountpoint = "/";
                  mountOptions = btrfsOptions;
                };
                "@home" = {
                  mountpoint = "/home";
                  mountOptions = btrfsOptions;
                };
                "@nix" = {
                  mountpoint = "/nix";
                  mountOptions = btrfsOptions;
                };
                "@persist" = {
                  mountpoint = "/persist";
                  mountOptions = btrfsOptions;
                };
                "@log" = {
                  mountpoint = "/var/log";
                  mountOptions = btrfsOptions;
                };
                "@snapshots" = {
                  mountpoint = "/.snapshots";
                  mountOptions = btrfsOptions ++ [ "nofail" ];
                };
                # NO compress and NO noatime: btrfs' mkswapfile requires pure NOCOW.
                "@swap" = {
                  mountpoint = "/swap";
                  swap.swapfile.size = "12G"; # = the RAM, the same criterion as the desk
                };
              };
            };
          };
        };
      };
    };
  };
}
