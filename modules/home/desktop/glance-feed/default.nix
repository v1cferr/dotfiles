# GLANCE-FEED: the desktop's network data (weather, INMET, CI) fetched only when it can have changed,
# into one SQLite cache the bar, the glance band and the lock screen READ. docs/notes/desktop/glance-feed.md
{
  config,
  lib,
  pkgs,
  ...
}:

let
  # Rule 19: everything this module reaches for, named once.
  inherit (pkgs)
    coreutils
    curl
    gawk
    gnugrep
    jq
    openssh
    sqlite
    systemd
    writeShellApplication
    ;

  feed = writeShellApplication {
    name = "glance-feed";
    runtimeInputs = [
      config.programs.gh.package # the CI source authenticates with gh's own login
      sqlite
      curl
      jq
      coreutils
      gnugrep
      gawk
      openssh # the network source asks the router over the LAN
      systemd # journalctl: the attacks on the exposed ports
    ];
    # The place and the source of truth are my.weather's (weather.nix), never repeated here.
    runtimeEnv = {
      GLANCE_LAT = config.my.weather.latitude;
      GLANCE_LON = config.my.weather.longitude;
      GLANCE_MODEL = config.my.weather.model;
      GLANCE_IBGE = config.my.weather.ibge;
      GLANCE_SCHEMA = ./schema.sql;
      # The CI source: the FAI GitLab (VPN only) and the pipeline hook's copy (ci-webhook.nix).
      GLANCE_GITLAB_URL = "https://git.sup.fai.ufscar.br";
      GLANCE_GITLAB_TOKEN_FILE = "/run/secrets/fai_gitlab_token";
      GLANCE_WEBHOOK_DIR = "/var/lib/ci-webhook/gitlab";
      # The network source: names and what counts as KNOWN come from the router's mirror (one owner).
      GLANCE_ROUTER_UCI = ../../../../hosts/cudy-wr3000/uci;
    };
    text = builtins.readFile ./scripts/feed.sh;
  };
in
{
  # Other modules read the cache through this (the lock screen's weather label), never a path.
  options.my.glance.feed = lib.mkOption {
    type = lib.types.package;
    readOnly = true;
    default = feed;
    description = "The glance-feed package; `glance-feed read <name>` prints a cached document.";
  };

  config.home.packages = [ feed ]; # `glance-feed read <name>` is how the UI reads

  config.systemd.user.services.glance-feed = {
    Unit.Description = "Refreshes the glance cache (weather, INMET, CI) when a source can have changed";
    Service = {
      Type = "oneshot";
      ExecStart = "${feed}/bin/glance-feed";
      Nice = 10;
    };
  };
  # Every minute it only ASKS each source whether it is due; almost every run touches no network.
  config.systemd.user.timers.glance-feed = {
    Unit.Description = "Runs glance-feed every minute; each source keeps its own cadence";
    Timer = {
      OnStartupSec = "15s"; # the first fill right after login; the UI paints from the cache meanwhile
      OnUnitActiveSec = "1min";
      AccuracySec = "10s";
    };
    Install.WantedBy = [ "timers.target" ];
  };
}
