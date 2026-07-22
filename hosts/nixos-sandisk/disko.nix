# ═══════════════════════════════════════════════════════════════════════════
# Layout de disco DECLARATIVO — host nixos-sandisk (SanDisk SSD PLUS 1000GB, SATA).
#
# ⚠️ DESTRUTIVO: apaga o disco inteiro. NÃO roda em rebuild normal — só no
# CUTOVER, de propósito. A SanDisk hoje tem Windows (descartável no plano).
# O Arch no Kingston fica PRESERVADO como rede de segurança.
#
# Seleção por by-id (nomes sd/nvme EMBARALHAM entre boots — conferido: o Seagate
# já apareceu como sda e sdb). NUNCA usar /dev/sdX.
#
# Aplicar no dia do cutover (bootando pelo pendrive instalador):
#   sudo nix run github:nix-community/disko -- --mode destroy,format,mount \
#     --flake .#nixos-sandisk
#   sudo nixos-install --flake .#nixos-sandisk
#
# Layout: GPT · ESP 1G (vfat, /boot) · resto ext4 (/). Sem swap em disco
# (zram cobre; suspend desligado, então hibernar não é necessário).
# ═══════════════════════════════════════════════════════════════════════════
{
  disko.devices.disk.sandisk = {
    type = "disk";
    device = "/dev/disk/by-id/ata-SanDisk_SSD_PLUS_1000GB_22520C801629";
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
            type = "filesystem";
            format = "ext4";
            mountpoint = "/";
          };
        };
      };
    };
  };
}
