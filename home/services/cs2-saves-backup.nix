# ═══════════════════════════════════════════════════════════════════════════
# BACKUP DOS SAVES DO CITIES: SKYLINES II (Bottles) → pasta coberta pelo restic.
#
# Porquê: o restic EXCLUI ~/.local/share/bottles (prefixos Wine, ~154G re-instalável),
# mas os SAVES vivem lá dentro e são insubstituíveis (repack pirata, SEM Steam Cloud).
# Este timer ESPELHA os saves p/ ~/CS2-Saves-Backup — que fica em /home, FORA do
# exclude — e o restic diário leva pro HDD Seagate off-disk. Fecha a regra
# "estado = restic" e a nota do próprio restic.nix ("saves… faça backup à parte").
#
# rsync --delete: o espelho reflete o estado ATUAL (o histórico versionado —
# desfazer overwrite acidental — é o restic quem guarda, com keep-daily/weekly).
# Barato: rsync é incremental (no-op quando nada mudou), então rodar de hora em
# hora não pesa. Pra outro jogo depois: replicar o par src→dst num novo módulo.
# ═══════════════════════════════════════════════════════════════════════════
{ pkgs, config, osConfig, lib, ... }:

let
  home = config.home.homeDirectory;
  # origem: pasta Saves do CS2 dentro do prefixo Wine do bottle Cities-Skylines-II
  savesSrc = "${home}/.local/share/bottles/bottles/Cities-Skylines-II/drive_c/users/steamuser/AppData/LocalLow/Colossal Order/Cities Skylines II/Saves";
  # destino: pasta simples em $HOME, dentro do que o restic inclui no backup diário
  savesDst = "${home}/CS2-Saves-Backup";

  # espelha os saves (só age se já existir save → não falha antes da 1ª partida)
  mirrorSaves = pkgs.writeShellScript "cs2-saves-mirror" ''
    set -eu
    ${pkgs.coreutils}/bin/mkdir -p "${savesDst}"
    if [ -d "${savesSrc}" ]; then
      ${pkgs.rsync}/bin/rsync -a --delete "${savesSrc}/" "${savesDst}/"
    fi
  '';
in
lib.mkIf osConfig.my.services.cs2-backup {
  # serviço oneshot: dispara o espelhamento (o restic diário faz o resto)
  systemd.user.services.cs2-saves-backup = {
    Unit.Description = "Espelha os saves do CS2 (Bottles) p/ pasta coberta pelo restic";
    Service = {
      Type = "oneshot";
      ExecStart = "${mirrorSaves}";
    };
  };
  # timer: espelha 5 min após o boot e a cada 1 h (pega a sessão de jogo recém-fechada)
  systemd.user.timers.cs2-saves-backup = {
    Unit.Description = "Agenda o espelhamento dos saves do CS2";
    Timer = {
      OnBootSec = "5min";
      OnUnitActiveSec = "1h";
      Persistent = true;
    };
    Install.WantedBy = [ "timers.target" ];
  };
}
