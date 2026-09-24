# CS2 SAVES: an hourly rsync mirror out of the Bottles prefix into a plain folder in $HOME. The
# saves are irreplaceable (a repack, so no Steam cloud).
#
# It used to be HALF of a pair: the mirror put the saves where the daily restic would pick them
# up. That backup was retired on 24/09/2026 and nothing replaced it yet, so today this is a
# same-disk mirror and NOT a backup: docs/notes/boot-and-storage/restic.md
{
  pkgs,
  config,
  osConfig,
  lib,
  ...
}:

let
  # Rule 19: everything this module reaches for, named once. deadnix fails the build on an
  # entry that stops being used, so the list cannot rot into a lie (rule 16).
  inherit (pkgs)
    coreutils
    rsync
    writeShellScript
    ;

  home = config.home.homeDirectory;
  # the source: the CS2 Saves folder inside the Wine prefix of the Cities-Skylines-II bottle
  savesSrc = "${home}/.local/share/bottles/bottles/Cities-Skylines-II/drive_c/users/steamuser/AppData/LocalLow/Colossal Order/Cities Skylines II/Saves";
  # the destination: a plain folder in $HOME, outside the Bottles prefix (see the header)
  savesDst = "${home}/CS2-Saves-Backup";

  # it only acts if a save already exists, so it does not fail before the 1st game
  mirrorSaves = writeShellScript "cs2-saves-mirror" ''
    set -eu
    ${coreutils}/bin/mkdir -p "${savesDst}"
    if [ -d "${savesSrc}" ]; then
      ${rsync}/bin/rsync -a --delete "${savesSrc}/" "${savesDst}/"
    fi
  '';
in
lib.mkIf osConfig.my.services.cs2-backup {
  # a oneshot: it fires the mirroring and exits
  systemd.user.services.cs2-saves-backup = {
    Unit.Description = "Mirrors the CS2 saves out of the Bottles prefix";
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
