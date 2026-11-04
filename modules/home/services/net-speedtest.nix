# NET SPEEDTEST: Ookla's official client, on demand from the bar's network panel and every 6 h by
# a timer, one history for both. What each number means and why bits: docs/notes/desktop/bar.md
{ pkgs, ... }:

let
  # Rule 19: everything this module reaches for, named once.
  inherit (pkgs)
    coreutils
    gawk
    iproute2
    jq
    ookla-speedtest
    util-linux
    writeShellApplication
    ;

  netSpeedtest = writeShellApplication {
    name = "net-speedtest";
    runtimeInputs = [
      coreutils
      gawk
      iproute2
      jq
      ookla-speedtest
      util-linux
    ];
    text = ''
      # --progress streams Ookla's jsonl lines (the panel's live gauge); the timer runs without it.
      progress=0
      [ "''${1:-}" = "--progress" ] && progress=1

      # The panel's button and the timer never overlap: a second run answers "busy" and leaves.
      exec 9>"''${XDG_RUNTIME_DIR:-/tmp}/net-speedtest.lock"
      if ! flock -n 9; then
        echo '{"type":"busy"}'
        exit 75
      fi
      state="''${XDG_STATE_HOME:-$HOME/.local/state}/net-speedtest"
      mkdir -p "$state"
      # The default route's interface, so the VPN or a bridge never carries the test.
      iface=$(ip route show default | awk '{ print $5; exit }')
      args=(-f jsonl -p yes --progress-update-interval=250 --accept-license --accept-gdpr)
      [ -n "$iface" ] && args+=(-I "$iface")

      exec 3< <(speedtest "''${args[@]}")
      # A cancel from the panel stops Ookla too, not only this shell. By PID, never `kill 0`: the
      # caller may share our process group.
      ookla=$!
      trap 'kill "$ookla" 2>/dev/null; exit 143' TERM INT

      result=""
      while IFS= read -r line <&3; do
        [ "$progress" = 1 ] && printf '%s\n' "$line"
        case "$line" in *'"type":"result"'*) result=$line ;; esac
      done
      if [ -z "$result" ]; then
        echo "net-speedtest: Ookla gave no result" >&2
        exit 1
      fi

      # Bandwidth stays in BYTES per second, as Ookla gives it; the panel converts to bits.
      jq -c '{
        timestamp,
        ping: .ping.latency,
        jitter: .ping.jitter,
        down: .download.bandwidth,
        up: .upload.bandwidth,
        downLoaded: .download.latency.iqm,
        upLoaded: .upload.latency.iqm,
        loss: .packetLoss,
        isp,
        server: (.server.name + " · " + .server.location),
        url: .result.url
      }' <<<"$result" >>"$state/history.jsonl"

      # 120 runs is a month at 4 a day; trimmed only past 240 so the file is rarely rewritten.
      if [ "$(wc -l <"$state/history.jsonl")" -gt 240 ]; then
        tail -n 120 "$state/history.jsonl" >"$state/history.jsonl.tmp"
        mv "$state/history.jsonl.tmp" "$state/history.jsonl"
      fi
    '';
  };
in
{
  home.packages = [ netSpeedtest ];

  systemd.user.services.net-speedtest = {
    Unit.Description = "Measures the internet link with Ookla's speed test";
    Service = {
      Type = "oneshot";
      ExecStart = "${netSpeedtest}/bin/net-speedtest";
      # The test saturates the link for ~20 s; the CPU and disk side stays out of the way.
      Nice = 10;
      IOSchedulingClass = "idle";
    };
  };

  systemd.user.timers.net-speedtest = {
    Unit.Description = "Measure the internet link every 6 h";
    Timer = {
      OnCalendar = "*-*-* 00/6:17:00";
      RandomizedDelaySec = "10m";
      Persistent = true;
    };
    Install.WantedBy = [ "timers.target" ];
  };
}
