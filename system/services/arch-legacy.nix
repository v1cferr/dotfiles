# ═══════════════════════════════════════════════════════════════════════════
# ACERVO DO ARCH ANTIGO — lado SISTEMA: o ponto de montagem e a SSOT do caminho.
#
# Quem MONTA é o usuário (home/services/arch-legacy-mount.nix): mount FUSE é privado de
# quem montou, então `sudo restic mount` produz pasta que o Dolphin não abre. Root só
# entra aqui pra CRIAR o diretório, porque /mnt é dele e o usuário não escreve lá.
#
# A opção nasce neste lado e não no módulo do home por causa da regra 11: o tmpfiles
# abaixo é módulo de SISTEMA e consome o caminho, e módulo de sistema não lê opção do
# home-manager. Os consumidores do home (a unit e o bookmark do Dolphin) leem via
# `osConfig.my.archAntigo.*`.
#
# O diretório era criado dentro do restic.nix até 11/08/2026, junto do /mnt/backup. Saiu
# porque lá ele ficava atado ao toggle `restic`: desligar o backup passaria a derrubar um
# mount que agora é PERMANENTE, e a falha apareceria longe da causa (mount sem
# mountpoint). O /mnt/backup fica lá porque continua sendo consulta sob demanda do
# `backup-browse`, que é do domínio do restic.
#
# O repo é ESTÁTICO: nada escreve nele desde 01/08/2026, quando o Kingston foi formatado
# (ver docs/arch-legacy.md). Isso não é curiosidade — é a premissa que autoriza o
# `--no-lock` do lado do home.
# ═══════════════════════════════════════════════════════════════════════════
{ config, lib, ... }:

{
  options.my.archAntigo = {
    local = lib.mkOption {
      type = lib.types.str;
      default = "/mnt/arch-antigo";
      description = "Ponto de montagem. SSOT lida pela unit do mount e pelo bookmark do Dolphin (regra 11).";
    };

    repo = lib.mkOption {
      type = lib.types.str;
      default = "rclone:gdrive:BACKUPS_EX-B560M-V5/ARCH-KINGSTON";
      description = ''
        Repo restic do acervo. `rclone:<remote>:<caminho>` — o restic sobe um
        `rclone serve restic --stdio` e fala com ele. A pasta no Drive se chamava
        `KINGSTON` e virou `ARCH-KINGSTON` em 05/08/2026 (o nome antigo não dizia
        que era o Arch).
      '';
    };
  };

  # FORA do /home de propósito: mountpoint dentro de /home/v1cferr entraria no `paths` do
  # backup e cairia na armadilha do ~/Drive e do ~/FAI-workstation — root não dá lstat em
  # FUSE do usuário, o restic sai 3 e o `forget --prune` deixa de rodar (o estrago está
  # documentado em system/services/restic.nix). Em /mnt o problema nem existe.
  config = lib.mkIf config.my.services.arch-antigo-mount {
    systemd.tmpfiles.rules = [
      "d ${config.my.archAntigo.local} 0755 v1cferr users -" # dono = usuário: é ele que monta
    ];
  };
}
