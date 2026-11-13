# HOME ASSISTANT: the daily update to the newest stable image (the stack is its own repo's compose).
# Why a timer and not Watchtower, and why 05:00: docs/notes/services/home-assistant.md
{
  config,
  lib,
  pkgs,
  ...
}:

let
  # Rule 19: everything this module reaches for, named once.
  inherit (pkgs) docker docker-compose writeShellScript;

  # The working tree, not a store path: the compose and the config both live there.
  repo = "${config.users.users.v1cferr.home}/Projects/GitHub/v1cferr/home-automation";

  # `pull` only downloads when `:stable` moved; `up -d` only recreates when the image changed,
  # so a run with nothing new restarts nothing.
  update = writeShellScript "home-assistant-update" ''
    set -euo pipefail
    cd ${repo}
    ${docker-compose}/bin/docker-compose pull --quiet homeassistant
    ${docker-compose}/bin/docker-compose up -d --remove-orphans homeassistant
  '';
in
lib.mkIf config.my.services.home-assistant {
  virtualisation.docker.enable = true;

  systemd.services.home-assistant-update = {
    description = "Pulls the newest stable Home Assistant image and recreates the container";
    after = [ "docker.service" ];
    requires = [ "docker.service" ];
    path = [ docker ];
    # The pull itself is done by dockerd; this unit only talks to its Unix socket and reads the
    # compose file, so the shared sandbox (no network, home read-only) fits as is.
    serviceConfig = config.my.systemd.hardened // {
      Type = "oneshot";
      ExecStart = update;
    };
  };

  systemd.timers.home-assistant-update = {
    description = "Daily Home Assistant update";
    wantedBy = [ "timers.target" ];
    timerConfig = {
      # 05:00: after the docker prunes (04:30, 04:45), and before anyone is home and awake.
      OnCalendar = "*-*-* 05:00:00";
      Persistent = true; # the machine reboots a lot, so a missed run goes on the next boot
    };
  };
}
