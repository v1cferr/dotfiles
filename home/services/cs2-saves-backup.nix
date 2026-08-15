# ═══════════════════════════════════════════════════════════════════════════
# A BACKUP OF THE CITIES: SKYLINES II SAVES (Bottles) into a folder restic covers.
#
# Why: restic EXCLUDES ~/.local/share/bottles (Wine prefixes, ~154G that is reinstallable), but
# the SAVES live in there and are irreplaceable (a pirated repack, with NO Steam Cloud). This
# timer MIRRORS the saves into ~/CS2-Saves-Backup, which sits in /home, OUTSIDE the exclude, and
# the daily restic takes it to the off-disk Seagate HDD. It closes the "state = restic" rule and
# the note in restic.nix itself ("saves… back them up separately").
#
# rsync --delete: the mirror reflects the CURRENT state (the versioned history, for undoing an
# accidental overwrite, is what restic keeps, with keep-daily/weekly).
# It is cheap: rsync is incremental (a no-op when nothing changed), so running it hourly does not
# weigh. For another game later: replicate the src->dst pair in a new module.
# ═══════════════════════════════════════════════════════════════════════════
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

  # it mirrors the saves (it only acts if a save already exists, so it does not fail before the
  # 1st game)
  mirrorSaves = pkgs.writeShellScript "cs2-saves-mirror" ''
    set -eu
    ${pkgs.coreutils}/bin/mkdir -p "${savesDst}"
    if [ -d "${savesSrc}" ]; then
      ${pkgs.rsync}/bin/rsync -a --delete "${savesSrc}/" "${savesDst}/"
    fi
  '';
in
lib.mkIf osConfig.my.services.cs2-backup {
  # a oneshot service: it fires the mirroring (the daily restic does the rest)
  systemd.user.services.cs2-saves-backup = {
    Unit.Description = "Mirrors the CS2 saves (Bottles) into a folder restic covers";
    Service = {
      Type = "oneshot";
      ExecStart = "${mirrorSaves}";
    };
  };
  # the timer: it mirrors 5 min after boot and every 1 h (it catches the game session just closed)
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
