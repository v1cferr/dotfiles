# ═══════════════════════════════════════════════════════════════════════════
# GradRadar: the app stack (Next.js plus FastAPI plus Postgres) coming up at BOOT, and the
# call-for-applications tracking chain running on a timer: collect, re-evaluate the schedule,
# notify.
#
# THE PROBLEM THIS SOLVES: Caddy already came up on its own and so did Docker, but the
# grad-radar containers did not. After every reboot https://pos.v1cferr.dev answered 502, the
# proxy up with no upstream, until somebody ran `just dev` by hand. A link that only works when
# the owner is sitting in front of the PC is no good for sending to JP and to César.
#
# WHY systemd AND NOT `restart: unless-stopped` IN THE COMPOSE: the dev compose declares
# `restart: "no"` on purpose, and the comment there explains why: containers that resurrect on
# their own after a daemon restart become orphans running with nobody asking. A oneshot with
# RemainAfterExit gives you the boot without bringing that behavior back, since what orders the
# start is the boot, not dockerd.
#
# WHY THE WORKING TREE PATH AND NOT A STORE PATH: unlike ./duo.nix, which consumes a flake
# input at a fixed commit, this one points at the repository where development happens. It is a
# conscious choice and it has a cost: what is live is the commit on disk, not one pinned in
# flake.lock. In exchange, `just dev` and the service are THE SAME stack (same project name,
# same ports, same volumes), so they do not fight over 3006/8006 and there are not two copies
# diverging. As long as the project is edited every week, that is the right trade; when it
# settles down, it becomes a flake input.
#
# IT IS A DEVELOPMENT SERVER EXPOSED TO THE WORLD. The frontend runs `next dev`, not
# `next build && next start`: it recompiles on demand, spends more memory and is much slower on
# the first hit. For three people checking a deadline, it serves. If it becomes something more,
# the step is a production compose, not touching this one.
#
# Turn it on with:  my.services.grad-radar = true;  in hosts/<host>/services.nix
# ═══════════════════════════════════════════════════════════════════════════
{
  config,
  pkgs,
  lib,
  ...
}:

let
  # The working tree, not a store path (see the header). A runtime string: Nix never reads this
  # path at evaluation time, so the impurity stays contained in the systemd unit and does not
  # contaminate the flake.
  repo = "/home/v1cferr/Projects/GitHub/v1cferr/grad-radar";
  composeFile = "${repo}/docker-compose.dev.yml";

  # The same race as ./duo.nix: `after = docker.service` is not enough when dockerd comes up
  # through socket activation and the API is not answering yet.
  dockerReady = pkgs.writeShellScript "grad-radar-wait-docker" ''
    for _ in $(seq 1 60); do ${pkgs.docker}/bin/docker info >/dev/null 2>&1 && exit 0; sleep 1; done
    echo "grad-radar: docker was not ready in time" >&2; exit 1
  '';

  # A writable DOCKER_CONFIG with the plugins linked in. Without this root does not DISCOVER
  # buildx and the build falls back to the legacy builder. The lesson from ./duo.nix.
  dockerCfgSetup = pkgs.writeShellScript "grad-radar-docker-cfg" ''
    mkdir -p /run/grad-radar/cli-plugins
    ln -sf ${pkgs.docker-buildx}/libexec/docker/cli-plugins/docker-buildx /run/grad-radar/cli-plugins/docker-buildx
    ln -sf ${pkgs.docker-compose}/libexec/docker/cli-plugins/docker-compose /run/grad-radar/cli-plugins/docker-compose
  '';

  # `-p grad-radar` matches the compose's `name:`. Without it the service would create a
  # separate project, with volumes of its own, and `just dev` would start looking at a different
  # database from the published one.
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
      # The repository belongs to the working tree, so it may not exist (a new host, a clone not
      # made yet). ConditionPathExists makes the unit be SKIPPED instead of failing, since a red
      # service caused by a missing clone trains you to ignore red services.
      ConditionPathExists = composeFile;
    };

    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      RuntimeDirectory = "grad-radar";
      # The first start builds two images and the frontend's `pnpm install` runs inside the
      # container, which takes minutes on a cold machine.
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

  # ── The call-for-applications monitor ─────────────────────────────────────
  # Up to here the collector only ran when somebody typed `just monitor`. A monitor that depends
  # on somebody remembering to run it is not a monitor, it is exactly the failure the project
  # exists to avoid, only with more steps.
  systemd.services.grad-radar-monitor = {
    description = "GradRadar: checks the official sources once";
    after = [ "grad-radar.service" ];
    requires = [ "grad-radar.service" ];
    path = [ pkgs.docker ];
    unitConfig.ConditionPathExists = composeFile;
    serviceConfig = {
      Type = "oneshot";
      # --quiet: only a change and a failure become a log. A journal with 19 lines of "the same"
      # per hour is a journal nobody reads.
      #
      # `verify` runs AFTER and without --apply: it rereads the schedules the monitor just
      # downloaded and compares the schedule verdict against what is in the database. Reporting
      # and not writing is deliberate, since a divergence can be a new schedule (which is what
      # you want to know) or the extractor failing on an unseen format, and writing silently
      # would erase the difference. A person decides, with `just verify-apply`.
      # The whole chain, in order: collect, re-evaluate the schedule, warn.
      #
      # `notify` last, and for a reason: it reads what the two before it just wrote. Running it
      # first would warn about the state of the PREVIOUS run, and an alert a day late is worse
      # than none in a project whose enemy is precisely finding out too late.
      #
      # With no channel configured, `notify` only RECORDS the events, it does not fail. That is
      # on purpose: the chain should not break for lack of a credential, and the events sit in
      # the table waiting for the channel to exist.
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
      # Twice a day. Calls for applications do not change hour by hour, and the only window that
      # matters lasts weeks; checking more would be load on UFSCar with no gain at all.
      OnCalendar = "08:00,20:00";
      # The machine is a desktop and spends nights turned off. Without this, a missed check
      # disappears forever, which is precisely the project's failure mode.
      Persistent = true;
      RandomizedDelaySec = "15m";
    };
  };
}
