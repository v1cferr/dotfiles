# Sunshine: screen streaming for Moonlight, captured through wlr and encoded on the Arc.
# The single access path, the DPMS trap and why packet_size is 1024: docs/notes/network/sunshine.md
{
  pkgs,
  lib,
  config,
  ...
}:

let
  # Ports DERIVED from the base with Sunshine's own offsets (read from its web assets).
  # The UDP 48002 that every blog lists does NOT exist in this version.
  basePort = 47989; # Sunshine's `port`; moving this moves all the others
  sp = n: toString (basePort + n);

  # A mark so the watchdog does not undo a hypridle toggle made by hand from the bar.
  pauseStamp = ''"''${XDG_RUNTIME_DIR:-/run/user/$(${pkgs.coreutils}/bin/id -u)}/sunshine-hypridle-paused"'';

  # The ghost reaper's first strike. It is a MARK and not a counter, because what matters is HOW
  # LONG the ghost has been standing, and a file's mtime already carries that.
  ghostStrike = ''"''${XDG_RUNTIME_DIR:-/run/user/$(${pkgs.coreutils}/bin/id -u)}/sunshine-ghost-strike"'';

  # Stream start: stops hypridle so the remote session does not LOCK mid-way through idle.
  # `|| true`: a prep-cmd that fails would cancel the stream in Sunshine.
  streamBegin = pkgs.writeShellScript "sunshine-stream-begin" ''
    ${pkgs.coreutils}/bin/touch ${pauseStamp} || true
    ${pkgs.systemd}/bin/systemctl --user stop hypridle.service || true
  '';
  # Stream end: turns hypridle back on, so it locks again after 5min of idleness.
  streamEnd = pkgs.writeShellScript "sunshine-stream-end" ''
    ${pkgs.coreutils}/bin/rm -f ${pauseStamp} || true
    ${pkgs.systemd}/bin/systemctl --user start hypridle.service || true
  '';

  # "Is there a REAL stream?", EXTRACTED because there are two consumers now (rule 11): the idle
  # guard and the ghost reaper. The signal is the SOCKETS, because Sunshine's own bookkeeping lies:
  # on 10/08/2026 `/serverinfo` still said SUNSHINE_SERVER_BUSY with the client dead for 2h30.
  # Exit 0 = there is a stream. `ss` filters itself, no pipe: pipefail plus grep -q inverts it.
  streamActive = pkgs.writeShellApplication {
    name = "sunshine-stream-active";
    runtimeInputs = [ pkgs.iproute2 ];
    text = ''
      # Video, audio and control UDP: Sunshine binds these PER SESSION and closes them at the end.
      [ -z "$(ss -uanH "sport >= :${sp 9} and sport <= :${sp 11}")" ] || exit 0
      # Or HTTPS/RTSP established with a peer that is not us. `not dst X`, never `dst != X`: the
      # second one looks natural and the parser answers `bison bellows (syntax error)`.
      [ -z "$(ss -tanH state established "( sport = :${sp (-5)} or sport = :${sp 21} ) and not dst 127.0.0.0/8 and not dst [::1]")" ] || exit 0
      exit 1
    '';
  };

  # The `undo` is not a guarantee: a client that dies with no teardown left hypridle stopped
  # for 6h. The signal is the SOCKETS, see `streamActive` above.
  hypridleGuard = pkgs.writeShellApplication {
    name = "hypridle-guard";
    # gawk is NOT optional. A systemd USER unit gets a FIXED PATH (coreutils, findutils, gnugrep,
    # gnused, systemd) and writeShellApplication only APPENDS it, so an awk that is not declared
    # here does not exist at runtime: the guard exited 127 on the /proc/uptime line every 5 min
    # from 10/08 to 19/08/2026. Running it by hand always worked, which is what hid it.
    runtimeInputs = with pkgs; [
      systemd
      coreutils
      gawk
      streamActive
    ];
    text = ''
      stamp=${pauseStamp}

      # 1) A pause that is not this guard's (the bar pill) is none of our business.
      [ -e "$stamp" ] || exit 0

      # 2) hypridle already alive: the undo ran. Just clear the mark.
      if systemctl --user is-active --quiet hypridle.service; then
        rm -f "$stamp"
        exit 0
      fi

      # 3) A 2 min grace: the window between the `do` and the video bind is the whole Steam launch.
      paused=$(systemctl --user show hypridle.service -p InactiveEnterTimestampMonotonic --value)
      now=$(awk '{printf "%d", $1 * 1000000}' /proc/uptime)
      if [ "$paused" -gt 0 ] && [ "$((now - paused))" -lt 120000000 ]; then exit 0; fi

      # 4) A real stream, by the sockets and not by Sunshine's bookkeeping.
      if sunshine-stream-active; then exit 0; fi

      echo "<4>hypridle stopped with no active stream, turning it back on (Sunshine's undo did not run)"
      rm -f "$stamp"
      systemctl --user start hypridle.service
    '';
  };

  # A real TLS handshake on 47984: an accepted TCP is not enough (the 29/07 hang).
  # No pipe on purpose: pipefail plus grep -q would read success as failure.
  sunshineHealth = pkgs.writeShellApplication {
    name = "sunshine-health";
    runtimeInputs = with pkgs; [
      openssl
      systemd
      coreutils
      findutils # `find -mmin`, which is how the strike below measures its own age
      curl
      streamActive
    ];
    text = ''
      strike=${ghostStrike}

      # 1) THE HANDLER HANG (29/07): an accepted TCP is not enough, only a COMPLETED handshake
      #    proves the HTTPS side is alive, so `-brief` printing `Protocol version:` is the test.
      handshake=""
      for attempt in 1 2 3; do
        out="$(timeout 8 openssl s_client -connect 127.0.0.1:${sp (-5)} -brief </dev/null 2>&1 || true)"
        case "$out" in
          *"Protocol version:"*)
            handshake=ok
            break
            ;;
        esac
        echo "<4>TLS handshake on ${sp (-5)} failed (attempt $attempt/3)" # <4>=warning
        [ "$attempt" = 3 ] || sleep 5
      done
      if [ -z "$handshake" ]; then
        echo "<3>HTTPS handler hung, restarting sunshine.service" >&2 # <3>=err
        rm -f "$strike"
        systemctl --user restart sunshine.service
        exit 0
      fi

      # 2) THE GHOST SESSION (10/08, again on 19/08): the handshake above PASSES while the host is
      #    unusable, because Sunshine kept a session that no longer exists. Moonlight reads
      #    `SUNSHINE_SERVER_BUSY` and refuses to open a new one, and only a restart clears it.
      #    `/serverinfo` needs no auth over loopback; the id is a dummy, only PairStatus reads it.
      info="$(timeout 5 curl -s "http://127.0.0.1:${sp 0}/serverinfo?uniqueid=0123456789ABCDEF" || true)"
      case "$info" in
        *SUNSHINE_SERVER_BUSY*) ;;
        # Free, or no answer at all: either way there is no ghost to reap.
        *)
          rm -f "$strike"
          exit 0
          ;;
      esac
      if sunshine-stream-active; then
        rm -f "$strike"
        exit 0
      fi

      # A BUSY session with no socket is a ghost, and the only thing separating it from a session
      # being BORN is time: between the app launching and the client binding video there is a
      # window that lasts the whole Steam Big Picture launch. So the condition has to HOLD, and
      # restarting a live stream is the expensive mistake here, not reaping a ghost 6 min late.
      if [ -e "$strike" ] && [ -n "$(find "$strike" -mmin +5)" ]; then
        echo "<3>session BUSY with no stream for over 5 min, restarting sunshine.service" >&2
        rm -f "$strike"
        systemctl --user restart sunshine.service
      elif [ ! -e "$strike" ]; then
        echo "<4>session BUSY with no stream, holding before calling it a ghost"
        touch "$strike"
      fi
    '';
  };
  # Session QUALITY, because the Sunshine log says CLIENT DISCONNECTED for every cause.
  # It answered the 31/07 question: the duration distribution is BIMODAL.
  statsPy = pkgs.writeText "moonlight-stats.py" ''
    import datetime, statistics, subprocess, sys

    DAYS = sys.argv[1] if len(sys.argv) > 1 else "7"

    def journal(*args):
        cmd = ["journalctl", "--no-pager", "-o", "short-iso", "--since", f"-{DAYS} days", *args]
        return subprocess.run(cmd, capture_output=True, text=True).stdout

    def stamp(line):
        try:
            return datetime.datetime.fromisoformat(line.split()[0])
        except (ValueError, IndexError):
            return None

    # CONNECTED/DISCONNECTED pairs. A session in progress is left out: no end, no duration.
    sessions, start = [], None
    for line in journal("--user", "-u", "sunshine.service").splitlines():
        t = stamp(line)
        if t is None:
            continue
        if "CLIENT CONNECTED" in line:
            start = t
        elif "CLIENT DISCONNECTED" in line and start:
            sessions.append((start, t, (t - start).total_seconds()))
            start = None

    if not sessions:
        print(f"no completed session in the last {DAYS} days.")
        sys.exit(0)

    print(f"=== Moonlight sessions, last {DAYS} days ===\n")
    print(f"{'start':<15}{'duration':>10}")
    short, long = [], []
    for a, b, d in sessions:
        (short if d < 120 else long).append(d)
        mark = "  <-- short" if d < 120 else ""
        print(f"{a.strftime('%m-%d %H:%M:%S'):<15}{d:>9.0f}s{mark}")

    print(f"\n=== summary ===")
    alld = sorted(d for _, _, d in sessions)
    print(f"sessions: {len(alld)}   median: {statistics.median(alld):.0f}s   "
          f"min: {alld[0]:.0f}s   max: {alld[-1]:.0f}s")
    print(f"short (<120s): {len(short)}/{len(alld)}   long: {len(long)}/{len(alld)}")

  '';

  # The logic lives in the build (rule 7); python3 is explicit in runtimeInputs.
  moonlightStats = pkgs.writeShellApplication {
    name = "moonlight-stats";
    runtimeInputs = with pkgs; [
      python3
      systemd
    ];
    text = ''exec python3 ${statsPy} "$@"'';
  };
in
{
  services.sunshine = {
    enable = config.my.services.sunshine;
    # NO capSysAdmin: the capture is wlr (wlr-screencopy), which does NOT need CAP_SYS_ADMIN.
    # Only a KMS grab would, and KMS does not even work on the xe driver. Less privilege.
    autoStart = true; # comes up with the graphical session (a --user service, WantedBy graphical-session)
    # Closed everywhere, and now there is exactly ONE door: the `10.10.10.0/24` rule in
    # ../net/network.nix, which is the router's WireGuard. The UFSCar direct path (8 rules here plus
    # 8 redirects on the router) was RETIRED on 19/08/2026, and the why is in the notes.
    openFirewall = false;
    settings = {
      # The name that shows up in Moonlight. DERIVED from the hostname, never a literal: it
      # stayed "nixos-sandisk" for a month after the cutover, lying about which machine it is.
      sunshine_name = config.networking.hostName;
      # FORCES wlr: the portalgrab probe fires hyprland-share-picker, which hangs Sunshine.
      capture = "wlr";
      # Not kms: kmsgrab does not enumerate on `xe`. The monitor is pinned by NAME, because
      # the TV enumerates first and Moonlight opened on the wrong screen.
      output_name = config.my.monitors.primary; # SSOT: system/desktop/monitors.nix
      # `wan` on purpose: the firewall decides the reach, not Sunshine. Since the direct path was
      # retired (19/08/2026) NOTHING is forwarded, so the panel only answers from the LAN and from
      # the tunnel. Do not read this value as "exposed": read the firewall.
      origin_web_ui_allowed = "wan";
      # The CSRF origin is a SNAPSHOT of the LAN IP: an IP cannot be derived at build time.
      # It was silently wrong once, because only the web UI breaks, never the stream.
      csrf_allowed_origins = "https://192.168.1.10:47990";
      # 1024 and LOCKED: the default 1392 overflows a tunnel and WireGuard drops it silently.
      # The value is global and the ceiling is the SMALLER path's, always.
      packet_size = 1024;
      # A host-side bitrate ceiling, so it holds for ANY client that pairs. 20000 is the de facto
      # rate made explicit, not an experiment. On the codec: docs/notes/network/sunshine.md
      max_bitrate = 20000; # Kbps
      # More FEC: the path to FAI loses packets (1.67%, RTT spiking 20 to 312 ms).
      # It costs bandwidth, which is why it travels with the ceiling above.
      fec_percentage = 30;
      # Tolerates a transient hole. It only helps when the HOST gives up, and it is not free:
      # a dead client's session holds hypridle paused for longer.
      ping_timeout = 20000; # ms
      # Idle guard: do/undo wake the screen and pause hypridle during the stream (see the
      # header). JSON in sunshine.conf; it holds for ALL apps (including the remote "Desktop").
      global_prep_cmd = builtins.toJSON [
        {
          do = "${streamBegin}";
          undo = "${streamEnd}";
        }
      ];
    };

    # Apps DECLARED (rule 3). A factory app dropped every stream with an xrandr prep-cmd, and
    # declaring these makes the web UI's Applications tab read-only: docs/notes/network/sunshine.md
    applications = {
      apps = [
        # Remote desktop: Sunshine's "special" app (with no cmd it streams the session).
        { name = "Desktop"; }
        # `detached` so the session does not die with Steam. `steam` stays a NAME: the FHS wrapper
        # on the session PATH is what resolves it.
        {
          name = "Steam Big Picture";
          detached = [ "${pkgs.util-linux}/bin/setsid steam steam://open/bigpicture" ];
          prep-cmd = [
            {
              do = "";
              undo = "${pkgs.util-linux}/bin/setsid steam steam://close/bigpicture";
            }
          ];
        }
      ];
    };
  };

  # An ACTIVE probe: on 29/07 the HTTPS handler hung with the unit still active, exit 0 and
  # not one log line. Attempting the handshake is the only way to see it.
  systemd.user.services.sunshine-healthcheck = lib.mkIf config.my.services.sunshine {
    description = "Restarts Sunshine if the HTTPS handler (47984) is hung";
    serviceConfig = {
      Type = "oneshot";
      ExecStart = "${sunshineHealth}/bin/sunshine-health";
      # LogLevelMax cuts the 440 lines/day a 2min timer would log. SyslogLevel is what makes the
      # second half of that sentence true: systemd logs a script's stdout AND stderr at INFO, so
      # the filter alone also ate every shell error, and 7 straight failures of the guard logged
      # not one reason (19/08/2026). A `<3>`/`<4>` prefix keeps its own level either way.
      LogLevelMax = "warning";
      SyslogLevel = "warning";
    };
  };

  # The idle guard's watchdog, see the `hypridleGuard` block above for the incident.
  systemd.user.services.hypridle-guard = lib.mkIf config.my.services.sunshine {
    description = "Turns hypridle back on if the Sunshine guard left it stopped with no stream";
    serviceConfig = {
      Type = "oneshot";
      ExecStart = "${hypridleGuard}/bin/hypridle-guard";
      # The same pair as the healthcheck, for the same two reasons.
      LogLevelMax = "warning";
      SyslogLevel = "warning";
    };
  };

  # Diagnostics live in system/ next to what they diagnose (the healthcheck above lives here
  # for the same reason): system/ is rescue, base and DIAGNOSTICS.
  environment.systemPackages = lib.mkIf config.my.services.sunshine [ moonlightStats ];

  systemd.user.timers.sunshine-healthcheck = lib.mkIf config.my.services.sunshine {
    description = "Periodic probe of the Sunshine HTTPS handler";
    timerConfig = {
      OnActiveSec = "2min"; # gives the service time to come up before the 1st probe
      OnUnitActiveSec = "2min";
    };
    partOf = [ "graphical-session.target" ]; # with no session there is no Sunshine to check
    wantedBy = [ "graphical-session.target" ];
  };

  # 5min and not 2: idle locks after 5min anyway, so finer resolution buys nothing, and the
  # cost of turning it back on late is tiny next to turning it back on too early.
  systemd.user.timers.hypridle-guard = lib.mkIf config.my.services.sunshine {
    description = "Periodic check of the Sunshine idle guard";
    timerConfig = {
      OnActiveSec = "5min";
      OnUnitActiveSec = "5min";
    };
    partOf = [ "graphical-session.target" ];
    wantedBy = [ "graphical-session.target" ];
  };
}
