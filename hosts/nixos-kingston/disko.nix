# ═══════════════════════════════════════════════════════════════════════════
# Layout de disco DECLARATIVO — host nixos-kingston (KINGSTON KC3000, NVMe Gen4).
#
# ⚠️ DESTRUTIVO: apaga o disco inteiro. NÃO roda em rebuild normal — só no
# CUTOVER, de propósito. O Kingston hoje tem o Arch antigo, já ARQUIVADO no
# Google Drive (system/services/restic-arch-kingston.nix) e verificado antes disto.
#
# Seleção por by-id (nomes sd/nvme EMBARALHAM entre boots). NUNCA usar /dev/nvmeXnY.
#
# Aplicar no cutover (bootando pelo pendrive instalador):
#   sudo nix run github:nix-community/disko -- --mode destroy,format,mount \
#     --flake .#nixos-kingston
#   sudo nixos-install --flake .#nixos-kingston
#
# ── POR QUE BTRFS AQUI, se o SanDisk é ext4 ────────────────────────────────
# Não é pelo btrfs em si: é pelo LAYOUT DE SUBVOLUMES, que é pré-requisito da
# IMPERMANÊNCIA (ANOTACOES.md, TODO de 30/07 — raiz efêmera + lista explícita do
# que persiste, inspirado no Foundry do Misterio77). Impermanência exige /nix e
# /persist em volumes separados da raiz DESDE A INSTALAÇÃO; instalar ext4 plano
# significaria reinstalar de novo pra adotá-la. A feature NÃO está ligada ainda —
# `@persist` nasce vazio de propósito. Ligar depois vira mudança de config.
#
# KC3000 (Phison E18, TBW 800 TB): a write amplification do CoW é irrelevante nesse
# volume, e o zstd REDUZ escrita em dado compressível. Fragmentação de CoW só
# incomoda em banco de dados / imagem de VM — resolve com `chattr +C` pontual.
#
# PEGADINHA DO SWAP: em btrfs, swapfile exige NOCOW e zero compressão, senão o
# kernel recusa ativar. Por isso `@swap` é subvolume PRÓPRIO e SEM compress — e o
# disko usa `btrfs filesystem mkswapfile`, que já aplica os atributos corretos.
# Consequência: o `swapDevices` de /swapfile saiu do system/hardware/hardware.nix
# (que é compartilhado) e virou coisa de host — aqui quem declara é o disko.
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
            extraArgs = [ "-f" ]; # sobrescreve assinatura de FS anterior (o ext4 do Arch)
            subvolumes = {
              # Alvo futuro do rollback da impermanência: é ESTE que será zerado
              # a cada boot quando a feature entrar. Por isso nada que importe
              # pode morar fora dos outros subvolumes.
              "@" = {
                mountpoint = "/";
                mountOptions = [ "compress=zstd" "noatime" ];
              };
              "@home" = {
                mountpoint = "/home";
                mountOptions = [ "compress=zstd" "noatime" ];
              };
              # /nix é imutável e enorme: noatime evita escrita a cada leitura.
              "@nix" = {
                mountpoint = "/nix";
                mountOptions = [ "compress=zstd" "noatime" ];
              };
              # Vazio HOJE. Vira o destino da lista explícita de persistência.
              "@persist" = {
                mountpoint = "/persist";
                mountOptions = [ "compress=zstd" "noatime" ];
              };
              # Separado senão a impermanência levaria o journal junto no reboot —
              # e perder log é perder justamente o que explica o boot que deu errado.
              "@log" = {
                mountpoint = "/var/log";
                mountOptions = [ "compress=zstd" "noatime" ];
              };
              # SEM compress e SEM noatime: o mkswapfile do btrfs exige NOCOW puro.
              "@swap" = {
                mountpoint = "/swap";
                swap.swapfile.size = "16G"; # = RAM, mesmo critério do host antigo
              };
            };
          };
        };
      };
    };
  };
}
