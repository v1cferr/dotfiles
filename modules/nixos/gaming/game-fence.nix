# GAME FENCE: while a game runs, everything else gets idle priority and only the CPUs the game leaves free.
# Why SCHED_IDLE on the nix-daemon alone still lagged, and how to check it: docs/notes/hardware/power.md
{
  config,
  lib,
  pkgs,
  ...
}:

let
  inherit (pkgs)
    coreutils
    gnugrep
    jq
    writeShellApplication
    ;
  cpus = config.my.gaming.buildCpus;
  enabled = cpus != null;
  systemctl = "${config.systemd.package}/bin/systemctl";
  rootUnit = "game-fence-system.service";

  # User half: every app SCOPE (VS Code, browsers, terminals, Discord) except the game's own.
  # Daemons stay out on purpose: Sunshine, the portals and audio must not starve under a game.
  fenceApps = writeShellApplication {
    name = "game-fence";
    runtimeInputs = [
      config.systemd.package
      coreutils
      gnugrep
      jq
    ];
    text = ''
      shopt -s nullglob
      base="/sys/fs/cgroup/user.slice/user-$(id -u).slice/user@$(id -u).service"
      state="$XDG_RUNTIME_DIR/game-fence.units"
      threads="$(nproc)"
      headroom=2 # threads always kept free above what the game is using, for its spikes
      floor=2 # the rest never drops below this many CPUs
      : >"$state"

      # The game's cgroups, from GameMode's clients and the game windows Hyprland records (rules.lua).
      game_cgroups() {
        {
          busctl --user --json=short call com.feralinteractive.GameMode /com/feralinteractive/GameMode \
            com.feralinteractive.GameMode ListGames 2>/dev/null | jq -r '.data[0][][0]' || true
          cat "$XDG_RUNTIME_DIR/game-pids" 2>/dev/null || true
        } | while read -r pid; do
          [ -n "$pid" ] && cut -d: -f3 "/proc/$pid/cgroup" 2>/dev/null
        done | sort -u
      }

      # Total CPU time of the game's cgroups, in microseconds.
      game_usec() {
        local total=0 cg usec
        while read -r cg; do
          [ -n "$cg" ] || continue
          usec="$(grep -m1 '^usage_usec' "/sys/fs/cgroup$cg/cpu.stat" 2>/dev/null | cut -d' ' -f2)" || continue
          total=$((total + ''${usec:-0}))
        done <<<"$1"
        echo "$total"
      }

      unfence() { systemctl --user set-property --runtime "$1" CPUQuota= CPUWeight= 2>/dev/null || true; }
      release() {
        while read -r unit; do unfence "$unit"; done <"$state"
        rm -f "$state"
        exit 0
      }
      trap release TERM INT

      quota="" last_usec="" last_t=""
      while true; do
        cgs="$(game_cgroups)"
        games="$(while read -r cg; do [ -n "$cg" ] && basename "$cg"; done <<<"$cgs")"

        # ADAPTIVE: the rest gets every thread the game is not using, minus the headroom.
        usec="$(game_usec "$cgs")" t="$(date +%s%N)"
        new="$quota"
        if [ -n "$last_usec" ] && [ "$t" -gt "$last_t" ]; then
          used=$(((usec - last_usec) * 1000 * 100 / (t - last_t))) # in percent of one CPU
          game_threads=$(((used + 99) / 100))
          free=$((threads - game_threads - headroom))
          [ "$free" -lt "$floor" ] && free=$floor
          new="$((free * 100))%"
        fi
        last_usec="$usec" last_t="$t"
        [ -n "$new" ] || new="$((floor * 100))%" # the first round, before any measurement

        for dir in "$base"/app.slice/*.scope "$base"/background.slice/*.scope; do
          unit="$(basename "$dir")"
          if grep -qxF "$unit" <<<"$games"; then
            # A scope that became (or holds) a game is let go.
            if grep -qxF "$unit" "$state"; then
              unfence "$unit"
              grep -vxF "$unit" "$state" >"$state.new" || true
              mv "$state.new" "$state"
            fi
          elif ! grep -qxF "$unit" "$state"; then
            systemctl --user set-property --runtime "$unit" CPUQuota="$new" CPUWeight=idle && echo "$unit" >>"$state"
          elif [ "$new" != "$quota" ]; then
            systemctl --user set-property --runtime "$unit" CPUQuota="$new" || true
          fi
        done
        quota="$new"
        sleep 2 &
        wait $!
      done
    '';
  };
in
{
  options.my.gaming.buildCpus = lib.mkOption {
    type = lib.types.nullOr lib.types.str;
    default = null;
    example = "4,5,10,11";
    description = "CPUs (systemd AllowedCPUs syntax) the nix-daemon keeps while a game runs; null disables the whole fence.";
  };

  config = lib.mkIf enabled {
    # Root half: system services at idle weight (they take only what the game leaves), and nix
    # builds off the game's cores and their SMT siblings. `--runtime` lives in /run, so a reboot
    # never leaves the fence up; empty values restore the defaults.
    systemd.services.game-fence-system = {
      description = "Fences system services while a game runs";
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        ExecStart = [
          "${systemctl} set-property --runtime system.slice CPUWeight=idle"
          "${systemctl} set-property --runtime nix-daemon.service AllowedCPUs=${cpus}"
        ];
        ExecStop = [
          "${systemctl} set-property --runtime system.slice CPUWeight="
          "${systemctl} set-property --runtime nix-daemon.service AllowedCPUs="
        ];
      };
    };

    # The user may start and stop ONLY that unit, the same shape as the tor and vpn-* rules.
    security.polkit.extraConfig = ''
      polkit.addRule(function(action, subject) {
        if (action.id == "org.freedesktop.systemd1.manage-units" &&
            subject.user == "v1cferr" &&
            action.lookup("unit") == "${rootUnit}") {
          return polkit.Result.YES;
        }
      });
    '';

    # Refcounted over both game triggers (GameMode and a game window): it stops once neither wants it.
    systemd.user.services.game-fence = {
      description = "Gives every non-game app only the CPUs the game leaves free";
      unitConfig.StopWhenUnneeded = true;
      serviceConfig = {
        ExecStartPre = "${systemctl} start ${rootUnit}";
        ExecStart = "${fenceApps}/bin/game-fence";
        ExecStopPost = "${systemctl} stop ${rootUnit}";
      };
    };
    systemd.user.services.gamemode-performance.wants = [ "game-fence.service" ];
    systemd.user.services.game-performance.wants = [ "game-fence.service" ];
  };
}
