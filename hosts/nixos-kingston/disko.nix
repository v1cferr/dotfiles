# DESTRUCTIVE disk layout for nixos-kingston (KC3000). It runs on a CUTOVER, never on a rebuild.
# Why btrfs, the zstd:1 choice and the swapfile trap: docs/notes/disko.md
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
            # Repeated per subvolume: disko has no inheritance. The why is in the note.
            subvolumes = {
              # The impermanence rollback's future target: wiped every boot once that lands.
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
              # Separate: impermanence would take the journal, which explains the bad boot.
              "@log" = {
                mountpoint = "/var/log";
                mountOptions = [
                  "compress=zstd:1"
                  "noatime"
                  "discard=async"
                ];
              };
              # btrbk's snapshots. Top-level and `nofail`: created BY HAND once, see the note.
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
