# BUILD FENCE: while a game runs, nix builds stay on a few whole cores, away from the game's.
# Why SCHED_IDLE alone still lagged, and how to check it: docs/notes/hardware/power.md
{ config, lib, ... }:

let
  cpus = config.my.gaming.buildCpus;
  enabled = cpus != null;
  systemctl = "${config.systemd.package}/bin/systemctl";
  unit = "nix-daemon-gaming-fence.service";
in
{
  options.my.gaming.buildCpus = lib.mkOption {
    type = lib.types.nullOr lib.types.str;
    default = null;
    example = "4,5,10,11";
    description = "CPUs (systemd AllowedCPUs syntax) the nix-daemon keeps while a game runs; null disables the fence.";
  };

  config = lib.mkIf enabled {
    # Root half: a cgroup property on the daemon reaches every running and future build at once.
    # `--runtime` lives in /run, so a reboot never leaves the fence up; empty values restore the defaults.
    systemd.services.nix-daemon-gaming-fence = {
      description = "Fences nix builds onto ${cpus} while a game runs";
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        # The quota is a belt for the package power budget, so the game's cores keep their turbo.
        ExecStart = "${systemctl} set-property --runtime nix-daemon.service AllowedCPUs=${cpus} CPUQuota=200%";
        ExecStop = "${systemctl} set-property --runtime nix-daemon.service AllowedCPUs= CPUQuota=";
      };
    };

    # The user may start and stop ONLY that unit, the same shape as the tor and vpn-* rules.
    security.polkit.extraConfig = ''
      polkit.addRule(function(action, subject) {
        if (action.id == "org.freedesktop.systemd1.manage-units" &&
            subject.user == "v1cferr" &&
            action.lookup("unit") == "${unit}") {
          return polkit.Result.YES;
        }
      });
    '';

    # User half: a refcount over both game triggers (GameMode and a game window); it stops once neither wants it.
    systemd.user.services.nix-build-fence = {
      description = "Keeps nix builds fenced while any game hold is active";
      unitConfig.StopWhenUnneeded = true;
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        ExecStart = "${systemctl} start ${unit}";
        ExecStop = "${systemctl} stop ${unit}";
      };
    };
    systemd.user.services.gamemode-performance.wants = [ "nix-build-fence.service" ];
    systemd.user.services.game-performance.wants = [ "nix-build-fence.service" ];
  };
}
