# DESTRUCTIVE disk layout for nixos-kingston (KC3000). It runs on a CUTOVER, never on a rebuild.
# Why btrfs, the zstd:1 choice and the swapfile trap: docs/notes/boot-and-storage/disko.md
let
  # ONE definition (rule 11), and not only to avoid 6 copies: upstream says most btrfs options apply
  # to the WHOLE filesystem and only the FIRST mounted subvolume's take effect. The note has it.
  btrfsOptions = [
    "compress=zstd:1"
    "noatime"
    "discard=async"
  ];
in
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
                mountOptions = btrfsOptions;
              };
              "@home" = {
                mountpoint = "/home";
                mountOptions = btrfsOptions;
              };
              # /nix is immutable and huge: noatime avoids a write on every read.
              "@nix" = {
                mountpoint = "/nix";
                mountOptions = btrfsOptions;
              };
              # Empty TODAY. It becomes the destination of the explicit persistence list.
              "@persist" = {
                mountpoint = "/persist";
                mountOptions = btrfsOptions;
              };
              # Separate: impermanence would take the journal, which explains the bad boot.
              "@log" = {
                mountpoint = "/var/log";
                mountOptions = btrfsOptions;
              };
              # btrbk's snapshots. Top-level and `nofail`: created BY HAND once, see the note.
              "@snapshots" = {
                mountpoint = "/.snapshots";
                mountOptions = btrfsOptions ++ [ "nofail" ];
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
