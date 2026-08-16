# GRADRADAR: the app stack up at BOOT plus the tracking chain on a timer (collect, verify, notify).
# Why systemd, why the working-tree path and why that order: docs/notes/services/grad-radar.md
{
  config,
  pkgs,
  lib,
  ...
}:

let
  # The working tree, not a store path (see the notes). Nix never reads it at eval time.
  repo = "/home/v1cferr/Projects/GitHub/v1cferr/grad-radar";
  composeFile = "${repo}/docker-compose.dev.yml";

  # The same race as ./duo.nix: `after = docker.service` loses to socket activation.
  dockerReady = pkgs.writeShellScript "grad-radar-wait-docker" ''
    for _ in $(seq 1 60); do ${pkgs.docker}/bin/docker info >/dev/null 2>&1 && exit 0; sleep 1; done
    echo "grad-radar: docker was not ready in time" >&2; exit 1
  '';

  # A writable DOCKER_CONFIG with the plugins linked in: without it root does not find buildx.
  dockerCfgSetup = pkgs.writeShellScript "grad-radar-docker-cfg" ''
    mkdir -p /run/grad-radar/cli-plugins
    ln -sf ${pkgs.docker-buildx}/libexec/docker/cli-plugins/docker-buildx /run/grad-radar/cli-plugins/docker-buildx
    ln -sf ${pkgs.docker-compose}/libexec/docker/cli-plugins/docker-compose /run/grad-radar/cli-plugins/docker-compose
  '';

  # `-p grad-radar` matches the compose's `name:`, so `just dev` and the service share volumes.
  dc = "${pkgs.docker}/bin/docker compose -p grad-radar -f ${composeFile}";
in
lib.mkIf config.my.services.grad-radar {
  virtualisation.docker.enable = true;
  users.users.v1cferr.extraGroups = [ "docker" ];
  environment.systemPackages = [ pkgs.docker-compose ];

  systemd.services.grad-radar = {
    description = "GradRadar stack (compose: frontend + backend + db)";
    after = [
      "docker.service"
      "network-online.target"
    ];
    requires = [ "docker.service" ];
    wants = [ "network-online.target" ];
    wantedBy = [ "multi-user.target" ];
    path = [ pkgs.docker ];

    environment = {
      DOCKER_CONFIG = "/run/grad-radar";
      DOCKER_BUILDKIT = "1";
    };

    unitConfig = {
      # The clone may not exist (a new host): SKIP the unit instead of leaving a red service.
      ConditionPathExists = composeFile;
    };

    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      RuntimeDirectory = "grad-radar";
      # The first start builds two images and runs `pnpm install` inside the container.
      TimeoutStartSec = "1800";
      ExecStartPre = [
        dockerReady
        dockerCfgSetup
        "${dc} build"
      ];
      ExecStart = "${dc} up -d --remove-orphans --wait";
      ExecStop = "${dc} down";
    };
  };

  # The monitor. Up to here the collector only ran when somebody typed `just monitor`.
  systemd.services.grad-radar-monitor = {
    description = "GradRadar: checks the official sources once";
    after = [ "grad-radar.service" ];
    requires = [ "grad-radar.service" ];
    path = [ pkgs.docker ];
    unitConfig.ConditionPathExists = composeFile;
    serviceConfig = {
      Type = "oneshot";
      # The order matters: `notify` reads what the two before it wrote. `verify` reports and does
      # NOT write, since a divergence can be a new schedule or a broken extractor. See the notes.
      ExecStart = [
        "${dc} exec -T backend python -m app.monitor --quiet"
        "${dc} exec -T backend python -m app.verify"
        "${dc} exec -T backend python -m app.notify"
      ];
    };
  };

  systemd.timers.grad-radar-monitor = {
    description = "GradRadar: periodic check of the sources";
    wantedBy = [ "timers.target" ];
    timerConfig = {
      # Twice a day; the window that matters lasts weeks, and more would be load on UFSCar.
      OnCalendar = "08:00,20:00";
      # The desktop spends nights off, so a missed check has to run late, not vanish.
      Persistent = true;
      RandomizedDelaySec = "15m";
    };
  };
}
