# ═══════════════════════════════════════════════════════════════════════════
# Layout de disco DECLARATIVO — host nixos-kingston (KINGSTON KC3000, NVMe Gen4).
#
# ⚠️ DESTRUTIVO: apaga o disco inteiro. NÃO roda em rebuild normal — só no
# CUTOVER, que JÁ ACONTECEU (01/08/2026). O Arch que morava aqui foi arquivado no
# Google Drive antes disso, e o `check --read-data` provou o repo em 05/08 — como
# chegar nele está em docs/ANOTACOES.md (o módulo que criava o repo já foi apagado).
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
# IMPERMANÊNCIA (docs/ANOTACOES.md, TODO de 30/07 — raiz efêmera + lista explícita do
# que persiste, inspirado no Foundry do Misterio77). Impermanência exige /nix e
# /persist em volumes separados da raiz DESDE A INSTALAÇÃO; instalar ext4 plano
# significaria reinstalar de novo pra adotá-la. A feature NÃO está ligada ainda —
# `@persist` nasce vazio de propósito. Ligar depois vira mudança de config.
#
# KC3000 (Phison E18, TBW 800 TB): a write amplification do CoW é irrelevante nesse
# volume, e o zstd REDUZ escrita em dado compressível. Fragmentação de CoW só
# incomoda em banco de dados / imagem de VM — o `+C` desses casos é declarado em
# system/hardware/btrfs.nix.
#
# ── AS OPÇÕES DE MOUNT, e por que estas ────────────────────────────────────
# `compress=zstd:1` e não o `zstd` pelado (= nível 3): num Gen4 de ~7 GB/s o
# gargalo passa a ser o COMPRESSOR, não o disco. zstd:1 comprime várias vezes mais
# rápido por ~5-10% de razão a menos — e a DESCOMPRESSÃO tem a mesma velocidade nos
# dois níveis, então leitura não perde nada. Num disco de 953 G a 49% os GiB
# economizados pelo :3 não compram o custo em cada `nixos-rebuild`.
# ⚠️ Trocar o nível só vale pra escrita NOVA: o que já está gravado continua em
# zstd:3 (inofensivo). Reescrever exigiria `defragment -r -czstd`, que QUEBRA
# reflink/snapshot e multiplicaria o disco usado — não fazer.
#
# `discard=async` é o default do kernel desde o 6.2, mas está EXPLÍCITO de
# propósito: é ele que justifica o `services.fstrim.enable = false` no
# system/hardware/btrfs.nix. Política que depende de default implícito de kernel
# quebra calada num bump — se tirar daqui, religue o fstrim no mesmo commit.
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
            # Repetido em cada subvolume por exigência do disko (não há herança);
            # o PORQUÊ de cada opção está no cabeçalho.
            subvolumes = {
              # Alvo futuro do rollback da impermanência: é ESTE que será zerado
              # a cada boot quando a feature entrar. Por isso nada que importe
              # pode morar fora dos outros subvolumes.
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
              # /nix é imutável e enorme: noatime evita escrita a cada leitura.
              "@nix" = {
                mountpoint = "/nix";
                mountOptions = [
                  "compress=zstd:1"
                  "noatime"
                  "discard=async"
                ];
              };
              # Vazio HOJE. Vira o destino da lista explícita de persistência.
              "@persist" = {
                mountpoint = "/persist";
                mountOptions = [
                  "compress=zstd:1"
                  "noatime"
                  "discard=async"
                ];
              };
              # Separado senão a impermanência levaria o journal junto no reboot —
              # e perder log é perder justamente o que explica o boot que deu errado.
              "@log" = {
                mountpoint = "/var/log";
                mountOptions = [
                  "compress=zstd:1"
                  "noatime"
                  "discard=async"
                ];
              };
              # Casa dos snapshots do btrbk (system/services/btrbk.nix). Subvolume
              # TOP-LEVEL, não um diretório dentro de `@`, por dois motivos: (1) o
              # rollback da impermanência zeraria `@` e levaria junto exatamente o
              # histórico que existe pra salvar a pele; (2) fora de `@home`, o
              # restic nunca tropeça nele (senão faria backup de cada snapshot).
              #
              # `nofail`: subvolume NÃO nasce num rebuild — o disko só roda em
              # instalação. Num sistema já instalado ele é criado à mão, UMA vez:
              #   sudo mount -o subvolid=5 /dev/nvme0n1p2 /mnt \
              #     && sudo btrfs subvolume create /mnt/@snapshots && sudo umount /mnt
              # Com nofail, esquecer esse passo custa "o btrbk não roda" (ele exige
              # o mount via RequiresMountsFor) em vez de "boot cai no emergency shell".
              "@snapshots" = {
                mountpoint = "/.snapshots";
                mountOptions = [
                  "compress=zstd:1"
                  "noatime"
                  "discard=async"
                  "nofail"
                ];
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
