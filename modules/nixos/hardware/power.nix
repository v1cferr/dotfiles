# POWER PROFILES: power-profiles-daemon owns the profile (Balanced/Gaming/Eco); CPU and GPU follow it.
# Why ppd, the profile map, the automatic holds and the rollback: docs/notes/hardware/power.md
{ config, pkgs, ... }:

let
  inherit (pkgs)
    coreutils
    glib
    gnugrep
    power-profiles-daemon
    writeShellApplication
    ;
  systemctl = "${config.systemd.package}/bin/systemctl";
  ppctl = "${power-profiles-daemon}/bin/powerprofilesctl";

  # The GPU half of a profile, as root: xe's own power profile and its frequency floor per GT.
  gpuApply = writeShellApplication {
    name = "power-profile-gpu";
    runtimeInputs = [
      coreutils
      gnugrep
      power-profiles-daemon
    ];
    text = ''
      shopt -s nullglob
      saved=/var/lib/power-profile-gpu
      install -d -m 0755 "$saved"
      profile="$(powerprofilesctl get)"
      for gt in /sys/class/drm/card*/device/tile*/gt*/freq0; do
        key="$(echo "$gt" | tr / _)"
        # The driver's own floor, recorded once while it is untouched, is what Balanced goes back to.
        if [ ! -f "$saved/$key" ] && grep -q '\[base\]' "$gt/power_profile"; then
          cat "$gt/min_freq" >"$saved/$key"
        fi
        if [ "$profile" = power-saver ]; then
          echo power_saving >"$gt/power_profile"
          cat "$gt/rpn_freq" >"$gt/min_freq"
        else
          echo base >"$gt/power_profile"
          [ -f "$saved/$key" ] && cat "$saved/$key" >"$gt/min_freq"
        fi
        echo "power-profile-gpu: $profile -> $gt: $(cat "$gt/power_profile" | tr -d '[]' | cut -d' ' -f1-2), min $(cat "$gt/min_freq") MHz"
      done
    '';
  };

  # Event-driven, like the user-side sync: one line per profile change or ppd (re)appearing.
  gpuWatch = writeShellApplication {
    name = "power-profile-gpu-watch";
    runtimeInputs = [ glib.bin ];
    text = ''
      gdbus monitor --system --dest org.freedesktop.UPower.PowerProfiles \
        --object-path /org/freedesktop/UPower/PowerProfiles | while IFS= read -r line; do
        case "$line" in
          *"'ActiveProfile':"* | *" is owned by "* | *" is now owned by "*) ${gpuApply}/bin/power-profile-gpu || true ;;
        esac
      done
    '';
  };

  # Never Eco over a game: any performance hold (GameMode, a game window) skips the idle hold.
  noPerformanceHold = writeShellApplication {
    name = "power-no-performance-hold";
    runtimeInputs = [
      gnugrep
      power-profiles-daemon
    ];
    # No `grep -q`: an early exit SIGPIPEs powerprofilesctl, and pipefail inverts the answer.
    text = "! powerprofilesctl list-holds | grep -E 'Profile:[[:space:]]+performance' >/dev/null";
  };
in
{
  # The one owner of intel_pstate's EPP, over D-Bus behind polkit (the active session may switch).
  services.power-profiles-daemon.enable = true;

  systemd.services.power-profile-gpu = {
    description = "Applies the power profile to the GPU (xe power_profile, frequency floor)";
    # No `after = ppd`: ppd's own unit sits After=multi-user.target, so that order is a cycle and
    # systemd drops THIS job at boot. The watcher catches ppd appearing on the bus anyway.
    wants = [ "power-profiles-daemon.service" ];
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      ExecStart = "${gpuWatch}/bin/power-profile-gpu-watch";
      Restart = "on-failure";
      RestartSec = 5;
    };
  };

  # The AUTOMATIC holds, both released by ppd on exit or on a manual switch: Eco while I am away
  # (started by hypridle), Gaming while a game window is open (started by Hyprland, rules.lua).
  systemd.user.services.power-idle-eco = {
    description = "Holds the power-saver profile while the session is idle";
    partOf = [ "hypridle.service" ]; # a stopped hypridle (the Sunshine guard) ends it too
    serviceConfig = {
      ExecCondition = "${noPerformanceHold}/bin/power-no-performance-hold";
      ExecStart = "${ppctl} launch --profile power-saver --reason Idle --appid idle ${coreutils}/bin/sleep infinity";
    };
  };
  systemd.user.services.game-performance = {
    description = "Holds the performance power profile while a game window is open";
    serviceConfig = {
      ExecStartPre = "-${systemctl} --user stop power-idle-eco.service";
      ExecStart = "${ppctl} launch --profile performance --reason Game --appid game-window ${coreutils}/bin/sleep infinity";
    };
  };
}
