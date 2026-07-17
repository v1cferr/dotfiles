# ═══════════════════════════════════════════════════════════════════════════
# Layout de disco DECLARATIVO — host ex-b560m-v5 (SSD Kingston SKC3000S1024G).
#
# ⚠️ DESTRUTIVO: apaga o disco inteiro. NÃO roda em rebuild normal — só no
# CUTOVER, de propósito, quando você já tiver feito o backup dos dados do Arch.
#
# Seleção por by-id (nomes nvme/sd EMBARALHAM entre boots — conferido: o Seagate
# já apareceu como sda e sdb em checagens diferentes). NUNCA usar /dev/nvme1n1.
#
# Aplicar no dia do cutover (bootando pelo pendrive instalador):
#   sudo nix run github:nix-community/disko -- --mode destroy,format,mount \
#     --flake .#ex-b560m-v5
#   sudo nixos-install --flake .#ex-b560m-v5
#
# Layout: GPT · ESP 1G (vfat, /boot) · resto ext4 (/). Sem swap em disco
# (zram cobre; suspend está desligado, então hibernar não é necessário).
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
            type = "filesystem";
            format = "ext4";
            mountpoint = "/";
          };
        };
      };
    };
  };
}
