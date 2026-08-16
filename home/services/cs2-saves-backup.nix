# CS2 SAVES: an hourly rsync mirror out of the Bottles prefix, which restic EXCLUDES, into a
# folder it covers. The saves are irreplaceable (no Steam Cloud): docs/notes/restic.md
{
  pkgs,
  config,
  osConfig,
  lib,
  ...
}:

let
  home = config.home.homeDirectory;
  # the source: the CS2 Saves folder inside the Wine prefix of the Cities-Skylines-II bottle
  savesSrc = "${home}/.local/share/bottles/bottles/Cities-Skylines-II/drive_c/users/steamuser/AppData/LocalLow/Colossal Order/Cities Skylines II/Saves";
  # the destination: a plain folder in $HOME, inside what restic includes in the daily backup
  savesDst = "${home}/CS2-Saves-Backup";

  # it only acts if a save already exists, so it does not fail before the 1st game
  mirrorSaves = pkgs.writeShellScript "cs2-saves-mirror" ''
    set -eu
    ${pkgs.coreutils}/bin/mkdir -p "${savesDst}"
    if [ -d "${savesSrc}" ]; then
      ${pkgs.rsync}/bin/rsync -a --delete "${savesSrc}/" "${savesDst}/"
    fi
  '';
in
lib.mkIf osConfig.my.services.cs2-backup {
  # a oneshot: it fires the mirroring, and the daily restic does the rest
  systemd.user.services.cs2-saves-backup = {
    Unit.Description = "Mirrors the CS2 saves (Bottles) into a folder restic covers";
    Service = {
      Type = "oneshot";
      ExecStart = "${mirrorSaves}";
    };
  };
  # 5 min after boot and hourly, which catches a game session that just closed
  systemd.user.timers.cs2-saves-backup = {
    Unit.Description = "Schedules the mirroring of the CS2 saves";
    Timer = {
      OnBootSec = "5min";
      OnUnitActiveSec = "1h";
      Persistent = true;
    };
    Install.WantedBy = [ "timers.target" ];
  };
}
