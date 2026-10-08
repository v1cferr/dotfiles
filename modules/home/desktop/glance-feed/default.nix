# GLANCE-FEED: the desktop's network data (weather, INMET, CI) fetched only when it can have changed,
# into one SQLite cache the bar, the glance band and the lock screen READ. docs/notes/desktop/glance-feed.md
{ config, pkgs, ... }:

let
  # Rule 19: everything this module reaches for, named once.
  inherit (pkgs)
    coreutils
    curl
    gnugrep
    jq
    sqlite
    writeShellApplication
    ;

  feed = writeShellApplication {
    name = "glance-feed";
    runtimeInputs = [
      sqlite
      curl
      jq
      coreutils
      gnugrep
    ];
    # The place and the source of truth are my.weather's (weather.nix), never repeated here.
    runtimeEnv = {
      GLANCE_LAT = config.my.weather.latitude;
      GLANCE_LON = config.my.weather.longitude;
      GLANCE_MODEL = config.my.weather.model;
      GLANCE_IBGE = config.my.weather.ibge;
      GLANCE_SCHEMA = ./schema.sql;
    };
    text = builtins.readFile ./scripts/feed.sh;
  };
in
{
  home.packages = [ feed ]; # `glance-feed read <name>` is how the UI reads

  systemd.user.services.glance-feed = {
    Unit.Description = "Refreshes the glance cache (weather, INMET, CI) when a source can have changed";
    Service = {
      Type = "oneshot";
      ExecStart = "${feed}/bin/glance-feed";
      Nice = 10;
    };
  };
  # Every minute it only ASKS each source whether it is due; almost every run touches no network.
  systemd.user.timers.glance-feed = {
    Unit.Description = "Runs glance-feed every minute; each source keeps its own cadence";
    Timer = {
      OnStartupSec = "15s"; # the first fill right after login; the UI paints from the cache meanwhile
      OnUnitActiveSec = "1min";
      AccuracySec = "10s";
    };
    Install.WantedBy = [ "timers.target" ];
  };
}
