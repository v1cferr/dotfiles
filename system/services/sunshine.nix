# Sunshine: screen streaming for Moonlight, captured through wlr and encoded on the Arc.
# The two access paths, the DPMS trap and why packet_size is 1024: docs/notes/network/sunshine.md
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

  # 47990 (the ADMIN PANEL) is out of this list ON PURPOSE: it never leaves the house.
  moonlightPorts = [
    {
      proto = "tcp";
      dport = sp (-5);
    } # 47984, HTTPS: this is how an ALREADY PAIRED host gets in
    {
      proto = "tcp";
      dport = sp 0;
    } # 47989, HTTP: /serverinfo and PIN pairing
    {
      proto = "tcp";
      dport = sp 21;
    } # 48010, RTSP: session negotiation
    {
      proto = "udp";
      dport = "${sp 9}:${sp 11}";
    } # 47998-48000: video, audio and control
  ];

  # The UFSCar blocks, mirrored BY HAND in the router's Moonlight-* redirects.
  # Never 0.0.0.0/0: /serverinfo has no auth, and this house is not behind CGNAT.
  moonlightSources = [
    "200.133.224.0/20" # UFSCar, campus. This is where the notebook goes out today, and it WORKS
    "200.136.192.0/21" # UFSCar, the FAI range. See above: the connection may not complete
  ];

  # GENERATED, because the stop list has to match the start list exactly or reload stacks
  # duplicates.
  fwMatches = lib.concatMap (
    src: map (p: "-s ${src} -p ${p.proto} --dport ${p.dport}") moonlightPorts
  ) moonlightSources;

  # A mark so the watchdog does not undo a hypridle toggle made by hand from the bar.
  pauseStamp = ''"''${XDG_RUNTIME_DIR:-/run/user/$(${pkgs.coreutils}/bin/id -u)}/sunshine-hypridle-paused"'';

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

  # The `undo` is not a guarantee: a client that dies with no teardown left hypridle stopped
  # for 6h. The signal is the SOCKETS, because Sunshine's own session bookkeeping lies.
  hypridleGuard = pkgs.writeShellApplication {
    name = "hypridle-guard";
    runtimeInputs = with pkgs; [
      systemd
      iproute2
      coreutils
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

      # 4) A real stream: video UDP bound, or control TCP established with a non-loopback peer.
      #    `ss` filters itself (no pipe: pipefail plus grep -q inverts the result).
      [ -z "$(ss -uanH "sport >= :${sp 9} and sport <= :${sp 11}")" ] || exit 0
      [ -z "$(ss -tanH state established "( sport = :${sp (-5)} or sport = :${sp 21} ) and not dst 127.0.0.0/8 and not dst [::1]")" ] || exit 0

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
    ];
    text = ''
      for attempt in 1 2 3; do
        out="$(timeout 8 openssl s_client -connect 127.0.0.1:47984 -brief </dev/null 2>&1 || true)"
        case "$out" in
          *"Protocol version:"*) exit 0 ;;
        esac
        echo "<4>TLS handshake on 47984 failed (attempt $attempt/3)" # <4>=warning
        [ "$attempt" = 3 ] || sleep 5
      done
      echo "<3>HTTPS handler hung, restarting sunshine.service" >&2 # <3>=err
      systemctl --user restart sunshine.service
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
    openFirewall = false; # closed everywhere; what opens it is the 10.10.10.0/24 rule (../net/network.nix)
    settings = {
      # The name that shows up in Moonlight. DERIVED from the hostname, never a literal: it
      # stayed "nixos-sandisk" for a month after the cutover, lying about which machine it is.
      sunshine_name = config.networking.hostName;
      # FORCES wlr: the portalgrab probe fires hyprland-share-picker, which hangs Sunshine.
      capture = "wlr";
      # Not kms: kmsgrab does not enumerate on `xe`. The monitor is pinned by NAME, because
      # the TV enumerates first and Moonlight opened on the wrong screen.
      output_name = config.my.monitors.primary; # SSOT: system/desktop/monitors.nix
      # `wan` on purpose: the firewall decides the reach, not Sunshine. It stays safe ONLY while
      # 47990 is not forwarded, which is why it is out of both port lists.
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
      # LogLevelMax cuts the 440 lines/day a 2min timer would log; real failures stay visible.
      LogLevelMax = "warning";
    };
  };

  # The idle guard's watchdog, see the `hypridleGuard` block above for the incident.
  systemd.user.services.hypridle-guard = lib.mkIf config.my.services.sunshine {
    description = "Turns hypridle back on if the Sunshine guard left it stopped with no stream";
    serviceConfig = {
      Type = "oneshot";
      ExecStart = "${hypridleGuard}/bin/hypridle-guard";
      LogLevelMax = "warning"; # same reason as the healthcheck: no Starting/Finished
    };
  };

  # The other half is the router's DNAT, so this rule alone exposes nothing. The `-s` is the
  # second lock, the one that survives somebody touching LuCI.
  networking.firewall = lib.mkIf config.my.services.sunshine {
    extraCommands = lib.concatMapStringsSep "\n" (
      m: "iptables -I nixos-fw 1 ${m} -j nixos-fw-accept"
    ) fwMatches;
    # Without this, a firewall `reload` stacks duplicates of the rules above.
    extraStopCommands = lib.concatMapStringsSep "\n" (
      m: "iptables -D nixos-fw ${m} -j nixos-fw-accept 2>/dev/null || true"
    ) fwMatches;
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
