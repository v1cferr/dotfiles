# Host: nixos-seagate — HDD Seagate ST9320423AS (a instalação ATUAL).
# Só o específico desta máquina/disco; o comum vem de ../system (via flake).
{ ... }:

{
  imports = [
    ../hardware-configuration.nix # scan do HDD (gerado) — não editar
  ];

  networking.hostName = "nixos-seagate";

  # ═══ MAPA DE DISCOS (MOBO EX-B560M-V5) ══════════════════════════════════════
  # Os nomes sdX/nvmeX EMBARALHAM entre boots (já flagrado ao vivo) → identifique
  # SEMPRE por serial/by-id, NUNCA por sda/nvme0. Os dois NVMe se distinguem pela
  # GERAÇÃO PCIe (cat /sys/class/nvme/nvme*/device/max_link_speed):
  #
  #   Disco    | Modelo                  | by-id / serial                       | PCIe        | Papel
  #   ---------|-------------------------|--------------------------------------|-------------|------------------------
  #   Kingston | KINGSTON SKC3000S1024G  | nvme-KINGSTON_..._50026B7686B3D2F6   | Gen4 16GT/s | Arch produção (montado)
  #   Netac    | NE-1TB 2280 ("chinês")  | nvme-NE-1TB_2280_0004382002024       | Gen3  8GT/s | Windows (montado)
  #   Seagate  | ST9320423AS (HDD)       | ata-ST9320423AS_5VH4YZV8             | SATA        | ESTE sistema (/ e /boot)
  #   SanDisk  | SanDisk SSD PLUS 1000GB | ata-SanDisk_..._22520C801629         | SATA        | Windows → futuro backup
  #
  #   Regra do dedo: Kingston = Gen4 (16 GT/s) · Netac = Gen3 (8 GT/s).
  # ════════════════════════════════════════════════════════════════════════════

  # Discos extras montados SÓ-LEITURA — só fazem sentido AQUI (o HDD Seagate).
  # ro + nofail + x-systemd.automount = zero escrita, não trava o boot, monta no
  # 1º acesso. uid/gid = 1000/100 → legível pelo v1cferr sem sudo (NTFS não tem
  # dono Unix). Contexto: fase de migração/backup pré-cutover.

  # Kingston (Arch, NVMe Gen4) — produção. No próprio Kingston esse disco é a raiz.
  fileSystems."/mnt/kingston-arch" = {
    device = "/dev/disk/by-uuid/d98ec566-6ec2-4371-8048-d3a4f02b2cbb";
    fsType = "ext4";
    options = [ "ro" "noload" "nofail" "x-systemd.automount" ];
  };

  # SanDisk (SATA SSD) — Windows (será formatado p/ virar o backup; a UUID muda
  # quando isso acontecer → aí este bloco é atualizado pro ext4 novo).
  fileSystems."/mnt/sandisk-win" = {
    device = "/dev/disk/by-uuid/229AB7BB9AB78A35";
    fsType = "ntfs3";
    options = [ "ro" "nofail" "x-systemd.automount" "uid=1000" "gid=100" ];
  };

  # Netac (NVMe Gen3, "chinês") — Windows. Contém tb ResgateArch/ (home Arch de
  # Nov/2025). Não tocar até resgatar/confirmar esse conteúdo.
  fileSystems."/mnt/netac-win" = {
    device = "/dev/disk/by-uuid/CA9C7EDD9C7EC38B";
    fsType = "ntfs3";
    options = [ "ro" "nofail" "x-systemd.automount" "uid=1000" "gid=100" ];
  };

  # Fixado na 1ª instalação — NUNCA mudar depois.
  system.stateVersion = "26.05";
}
