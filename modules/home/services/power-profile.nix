# POWER PROFILE SYNC: on every ppd profile change, the user-side effects (SignalSift, idle Ollama models).
# The profile map, the state file and the rollback: docs/notes/hardware/power.md
{
  config,
  lib,
  osConfig,
  pkgs,
  ...
}:

let
  inherit (pkgs)
    coreutils
    curl
    glib
    jq
    power-profiles-daemon
    util-linux
    writeShellApplication
    ;

  signalsift = config.services.signalsift.enable;
  ollama = osConfig.my.services.ollama;

  # ONE apply for every trigger, serialized by flock; its outcome lands in a state file the shell reads.
  apply = writeShellApplication {
    name = "power-profile-apply";
    runtimeInputs = [
      coreutils
      curl
      jq
      power-profiles-daemon
      util-linux
    ]
    ++ lib.optional signalsift config.services.signalsift.package;
    text = ''
      state="''${XDG_RUNTIME_DIR:?}/power-profile.json"
      exec 9>"$state.lock"
      flock 9

      profile="$(powerprofilesctl get)"
      case "$profile" in
        performance) ss=gaming ;;
        power-saver) ss=eco ;;
        *) ss=balanced ;;
      esac

      ss_res=off
      ${lib.optionalString signalsift ''
        # Retried: right after its own start the daemon may not listen yet (the ExecStartPost case).
        ss_res="failed: the daemon did not answer"
        for _ in 1 2 3 4 5 6 7 8 9 10; do
          if out="$(signalsift profile set "$ss" 2>&1)"; then ss_res=ok; break; fi
          ss_res="failed: ''${out##*$'\n'}"
          sleep 1
        done
      ''}

      # A SignalSift-only run keeps the last Ollama outcome instead of overwriting it.
      ol_res="$(jq -r '.ollama // "kept"' "$state" 2>/dev/null || echo kept)"
      [ "''${1:-}" = --signalsift-only ] || ol_res=kept
      # Only an UNLOAD, never a block: the next request (Duo's 08:00 run) loads the model again.
      ${lib.optionalString ollama ''
        if [ "$ss" != balanced ] && [ "''${1:-}" != --signalsift-only ]; then
          if models="$(curl -fsS --max-time 3 http://127.0.0.1:11434/api/ps | jq -r '.models[].name')"; then
            n=0
            for m in $models; do
              jq -nc --arg m "$m" '{model: $m, keep_alive: 0}' \
                | curl -fsS --max-time 30 -d @- http://127.0.0.1:11434/api/generate >/dev/null && n=$((n + 1))
            done
            ol_res="unloaded $n"
          else
            ol_res="failed: the API did not answer"
          fi
        fi
      ''}

      jq -nc --arg p "$profile" --arg ss "$ss" --arg ssr "$ss_res" --arg ol "$ol_res" \
        --arg at "$(date -Is)" '{profile: $p, signalsift: $ss, signalsiftResult: $ssr, ollama: $ol, at: $at}' \
        >"$state.tmp"
      mv "$state.tmp" "$state"
      echo "power-profile: $profile -> signalsift $ss ($ss_res), ollama ($ol_res)"
    '';
  };

  # Event-driven: gdbus prints a line per PropertiesChanged and per owner change, so no polling.
  watch = writeShellApplication {
    name = "power-profile-watch";
    runtimeInputs = [ glib.bin ];
    text = ''
      gdbus monitor --system --dest org.freedesktop.UPower.PowerProfiles \
        --object-path /org/freedesktop/UPower/PowerProfiles | while IFS= read -r line; do
        case "$line" in
          # The profile itself, or ppd (re)appearing: the latter also covers this unit's own start.
          *"'ActiveProfile':"* | *" is owned by "* | *" is now owned by "*) ${lib.getExe apply} || true ;;
        esac
      done
    '';
  };
in
lib.mkIf osConfig.services.power-profiles-daemon.enable {
  home.packages = [ apply ];

  systemd.user.services.power-profile-sync = {
    # default.target and not the graphical session: none of its effects needs a screen.
    Unit.Description = "Applies the power profile's side effects (SignalSift, idle Ollama models)";
    Service = {
      ExecStart = lib.getExe watch;
      Restart = "on-failure";
      RestartSec = 5;
    };
    Install.WantedBy = [ "default.target" ];
  };

  # SignalSift forgets its profile on restart ("until restart"), so its own start re-applies it.
  systemd.user.services.signalsift.Service.ExecStartPost = lib.mkIf signalsift [
    "-${lib.getExe apply} --signalsift-only"
  ];
}
