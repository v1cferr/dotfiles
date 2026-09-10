# CREDITRADAR: the app stack (Next.js + FastAPI + Postgres) up at BOOT plus the daily market
# collection, reachable only from home. Why boot, why the working-tree path and why the
# collection window is what it is: docs/notes/services/credit-radar.md
{
  config,
  pkgs,
  lib,
  ...
}:

let
  # Rule 19: everything this module reaches for, named once. deadnix fails the build on an
  # entry that stops being used, so the list cannot rot into a lie (rule 16).
  inherit (pkgs)
    docker
    docker-buildx
    docker-compose
    writeShellScript
    ;

  # The working tree, not a store path: the same trade as ./grad-radar.nix, since this project
  # is still edited every week. Nix never reads it at eval time.
  repo = "/home/v1cferr/Projects/GitHub/v1cferr/credit-radar";
  composeFile = "${repo}/docker-compose.yml";

  # The same race as ./duo.nix and ./grad-radar.nix: `after = docker.service` loses to socket
  # activation, so the API can still be silent when the unit starts.
  dockerReady = writeShellScript "credit-radar-wait-docker" ''
    for _ in $(seq 1 60); do ${docker}/bin/docker info >/dev/null 2>&1 && exit 0; sleep 1; done
    echo "credit-radar: docker was not ready in time" >&2; exit 1
  '';

  # A writable DOCKER_CONFIG with the plugins linked in: without it root does not find buildx
  # and the build falls back to the legacy builder without saying so.
  dockerCfgSetup = writeShellScript "credit-radar-docker-cfg" ''
    mkdir -p /run/credit-radar/cli-plugins
    ln -sf ${docker-buildx}/libexec/docker/cli-plugins/docker-buildx /run/credit-radar/cli-plugins/docker-buildx
    ln -sf ${docker-compose}/libexec/docker/cli-plugins/docker-compose /run/credit-radar/cli-plugins/docker-compose
  '';

  # `-p credit-radar` matches the compose's `name:`, so running compose by hand and this service
  # share the same containers and volumes instead of fighting over 3007/8007.
  dc = "${docker}/bin/docker compose -p credit-radar -f ${composeFile}";
in
lib.mkIf config.my.services.credit-radar {
  virtualisation.docker.enable = true;
  users.users.v1cferr.extraGroups = [ "docker" ];
  environment.systemPackages = [ docker-compose ];

  systemd.services.credit-radar = {
    description = "CreditRadar stack (compose: frontend + backend + db)";
    after = [
      "docker.service"
      "network-online.target"
    ];
    requires = [ "docker.service" ];
    wants = [ "network-online.target" ];
    wantedBy = [ "multi-user.target" ];
    path = [ docker ];

    environment = {
      DOCKER_CONFIG = "/run/credit-radar";
      DOCKER_BUILDKIT = "1";
    };

    unitConfig = {
      # The clone may not exist (a new host): SKIP the unit instead of leaving a red service.
      ConditionPathExists = composeFile;
    };

    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      RuntimeDirectory = "credit-radar";
      # The first start builds two images, and the frontend stage runs `pnpm install` plus a
      # full `next build` inside the container.
      TimeoutStartSec = "1800";
      ExecStartPre = [
        dockerReady
        dockerCfgSetup
        "${dc} build"
      ];
      # `--wait` blocks until the healthchecks pass, so a green unit means the proxy has an
      # upstream. The one-shot migration service exiting 0 does not break it.
      ExecStart = "${dc} up -d --remove-orphans --wait";
      ExecStop = "${dc} down";
    };
  };

  # THE COLLECTOR. Up to here the historical series only grew when somebody fired an HTTP
  # request by hand, which for a project whose whole asset is the history is the failure it
  # exists to avoid, only quieter.
  systemd.services.credit-radar-collect = {
    description = "CreditRadar: collects the market indicators once";
    after = [ "credit-radar.service" ];
    requires = [ "credit-radar.service" ];
    path = [ docker ];
    unitConfig.ConditionPathExists = composeFile;
    serviceConfig = {
      Type = "oneshot";
      # `--quiet` so a day when nothing moved leaves NO line in the journal. A journal with
      # seven "same as yesterday" entries per day is a journal nobody reads.
      #
      # A command and not a `curl`: a scheduled job whose interface is a URL breaks the first
      # time a route is renamed, and this one has to keep working unattended for years.
      ExecStart = "${dc} exec -T backend credit-radar collect --quiet";
    };
  };

  systemd.timers.credit-radar-collect = {
    description = "CreditRadar: daily market collection";
    wantedBy = [ "timers.target" ];
    timerConfig = {
      # Once a day is enough: the daily series move at most once per business day and the
      # monthly ones once a month. What each run buys beyond the newest point is the REVISION
      # of an already-recorded period, and revisions do not arrive hourly either.
      #
      # 09:30 because SGS publishes with a lag, so asking before the business day has produced
      # anything just spends a request to learn nothing.
      OnCalendar = "09:30";
      # The desktop spends nights and travel days off. Without this a missed day disappears
      # forever, and a hole in the series is the one thing this project cannot backfill: the
      # value can be re-read later, but WHAT WAS PUBLISHED ON WHICH DAY cannot.
      Persistent = true;
      RandomizedDelaySec = "20m";
    };
  };
}
