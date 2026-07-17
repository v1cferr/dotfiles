# Host: nixos-seagate — HDD Seagate ST9320423AS (a instalação ATUAL).
# Só o específico desta máquina/disco; o comum vem de ../system (via flake).
{ ... }:

{
  imports = [
    ../hardware-configuration.nix # scan do HDD (gerado) — não editar
  ];

  networking.hostName = "nixos-seagate";

  # Kingston (Arch) montado SÓ-LEITURA — só faz sentido AQUI (o HDD). No próprio
  # Kingston esse disco é a raiz, não um /mnt.
  fileSystems."/mnt/kingston-arch" = {
    device = "/dev/disk/by-uuid/d98ec566-6ec2-4371-8048-d3a4f02b2cbb";
    fsType = "ext4";
    options = [ "ro" "noload" "nofail" "x-systemd.automount" ];
  };

  # Fixado na 1ª instalação — NUNCA mudar depois.
  system.stateVersion = "26.05";
}
