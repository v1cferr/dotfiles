# Host: nixos-seagate — HDD Seagate ST9320423AS (a instalação ATUAL).
# Só o específico desta máquina/disco; o comum vem de ../system (via flake).
{ ... }:

{
  imports = [
    ../hardware-configuration.nix # scan do HDD (gerado) — não editar
  ];

  networking.hostName = "nixos-seagate";

  # Discos extras montados SÓ-LEITURA — só fazem sentido AQUI (o HDD Seagate).
  # SEMPRE por UUID: os nomes sdX/nvmeX EMBARALHAM entre boots (já aconteceu).
  # ro + nofail + x-systemd.automount = zero escrita, não trava o boot, monta no
  # 1º acesso. uid/gid = 1000/100 → legível pelo v1cferr sem sudo (NTFS não tem
  # dono Unix). Contexto: fase de migração/backup pré-cutover.

  # Kingston (Arch) — produção. No próprio Kingston esse disco é a raiz.
  fileSystems."/mnt/kingston-arch" = {
    device = "/dev/disk/by-uuid/d98ec566-6ec2-4371-8048-d3a4f02b2cbb";
    fsType = "ext4";
    options = [ "ro" "noload" "nofail" "x-systemd.automount" ];
  };

  # SanDisk — Windows (será formatado p/ virar o backup; a UUID muda quando isso
  # acontecer → aí este bloco é atualizado pro ext4 novo).
  fileSystems."/mnt/sandisk-win" = {
    device = "/dev/disk/by-uuid/229AB7BB9AB78A35";
    fsType = "ntfs3";
    options = [ "ro" "nofail" "x-systemd.automount" "uid=1000" "gid=100" ];
  };

  # Netac — Windows (não tocar).
  fileSystems."/mnt/netac-win" = {
    device = "/dev/disk/by-uuid/CA9C7EDD9C7EC38B";
    fsType = "ntfs3";
    options = [ "ro" "nofail" "x-systemd.automount" "uid=1000" "gid=100" ];
  };

  # Fixado na 1ª instalação — NUNCA mudar depois.
  system.stateVersion = "26.05";
}
