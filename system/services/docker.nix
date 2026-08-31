# DOCKER: the automatic PRUNE policy only; the ENGINE is turned on by the stacks that need it.
# The 11 GB that had no ceiling, and the 2 options that: docs/notes/services/docker-prune.md
{ config, lib, ... }:

let
  docker = config.virtualisation.docker.package;
in
lib.mkIf config.virtualisation.docker.enable {
  virtualisation.docker.autoPrune = {
    enable = true;

    # NOT systemd's `weekly` (Mon 00:00), which is nix-gc's slot. 04:30 queues after restic and
    # nix-optimise instead of fighting them on the same NVMe. `persistent` is already true.
    #
    # DAILY and no longer Mon-only. MEASURED on 30/08, six days after the last run: the build
    # cache was back to 10.45 GB with 7.6 reclaimable. grad-radar runs `compose build` in its
    # ExecStartPre, which is to say on every boot, so a weekly ceiling is a week of refilling.
    dates = "*-*-* 04:30:00";
  };

  # THE GAP autoPrune cannot cover. `docker system prune` never touches volumes at all, and the
  # module's only knob for that is `allVolumes`, which passes `--volumes` and takes NAMED volumes
  # with it. That refusal still stands and the risk is not hypothetical: MEASURED on 30/08, with
  # the stack merely stopped, `grad-radar_caddy_config` and `grad-radar_caddy_data` were already
  # sitting there unreferenced, which is exactly the state in which `--volumes` deletes them.
  #
  # `docker volume prune` WITHOUT `-a` is the middle ground the option does not expose: anonymous
  # volumes only, by construction, so a named volume cannot be reached even when its stack is down.
  #
  # Anonymous is also the only kind that is safe to lose here. grad-radar declares one on purpose
  # (`/app/.venv`, to keep the container's Linux venv from being shadowed by the host bind-mount),
  # and docker repopulates a fresh anonymous volume FROM THE IMAGE on first use. So pruning costs a
  # copy at container start, not data. That is what had been piling up: 36 orphans of ~127 MB
  # each, 4.5 GB, one per container recreation, with nothing to ever collect them.
  systemd.services.docker-volume-prune = {
    description = "Prunes ANONYMOUS unused docker volumes (never named ones)";
    after = [ "docker.service" ];
    requires = [ "docker.service" ];
    serviceConfig = {
      Type = "oneshot";
      ExecStart = "${docker}/bin/docker volume prune -f";
    };
  };

  systemd.timers.docker-volume-prune = {
    description = "Daily prune of the anonymous docker volumes";
    wantedBy = [ "timers.target" ];
    timerConfig = {
      # 04:45: after the 04:30 system prune, so the two never overlap on the same NVMe.
      OnCalendar = "*-*-* 04:45:00";
      Persistent = true; # the machine reboots a lot, so a missed run goes on the next boot
    };
  };
}
