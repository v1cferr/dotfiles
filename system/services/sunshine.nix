# Sunshine: a screen/remote desktop streaming server (the client is Moonlight). It is the
# recommended way to do remote access on Hyprland/Wayland: it captures through
# wlr-screencopy (`wlr`, auto-selected) and encodes on the GPU. The Arc B580 has an AV1/HEVC
# encoder (VA-API), so the stream is smooth and low latency. It was Tailscale until
# 08/08/2026, and the swap is recorded in docs/history/2026/08-august.md.
#
# HOW YOU GET HERE: TWO paths since 10/08/2026, and `openFirewall = false` still holds for
# both (neither one opens a port on every interface):
#   1. The router's WireGuard, through the 10.10.10.0/24 source rule in ../net/network.nix.
#   2. The INTERNET, directly, restricted to the UFSCar blocks: the rules at the end of this
#      file, plus the `Moonlight-*` redirects on the router (router/uci/firewall.conf).
# Path 2 exists because the FAI notebook already runs nxBender + openconnect, and adding a
# third VPN client there is a routing conflict waiting to happen.
#
# Path 2 is NOT "more direct" than path 1, and that was the premise that motivated it: the
# WireGuard endpoint is the home router ITSELF, so both travel UFSCar to internet to
# 177.52.84.188. There is no relay (that was a Tailscale risk, and Tailscale is gone). What
# path 2 actually gains is MTU, 1492 from PPPoE against 1420 through the tunnel, and what it
# gains in latency is noise. Do not rewrite this as a routing gain.
#
# ENCRYPTION, and why it is not a downgrade: Sunshine classifies the client by IP. Through
# the tunnel it arrives as 10.10.10.x = LAN, so `lan_encryption_mode = 0` (the tunnel already
# encrypts). Over the internet it arrives public = WAN, so `wan_encryption_mode = 1`, which
# is the default and stays ON. Do not touch those two: they are what keeps path 2 from
# streaming in the clear.
#
# LESSON LEARNED (jul/2026, a long debug): "black screen in Moonlight" was wlr capturing the
# monitor while DPMS-OFF, and NOT a version or encoder regression. Capture works as long as
# the monitor is ON during the stream, which is why the streamBegin guard exists. `capture=kms`
# would be an alternative, but kmsgrab does NOT enumerate on the `xe` driver. CAREFUL:
# toggling dpms WITH capture and encoding active caused a GPU engine reset (xe RCS), which is
# why the guard wakes the screen BEFORE the stream (in the prep-cmd), never in the middle.
#
# Interactive setup (once, from the browser of any WireGuard peer):
#   https://192.168.1.10:47990  then create the admin user/password and pair Moonlight (PIN).
# The state (paired clients) lives in ~/.config/sunshine (not declarable, so it is STATE).
#
# IDLE GUARD (a conflict with hypridle): the capture is of the PHYSICAL monitor through wlr,
# which works as long as the monitor is on. Idle no longer turns the screen off (dpms-off was
# removed because it broke this: a black screen plus a GPU engine reset on xe, see
# home/desktop/lockscreen.nix). What is left is the LOCK after 5min, which in the middle of a
# stream would lock the remote session. So the guard only PAUSES hypridle while the stream
# runs (the global_prep_cmd do/undo) and turns it back ON at disconnect. No dpms or settle:
# the monitor is always on now. The `undo` is NOT reliable (a client that dies with no
# teardown never fires it), hence the `hypridle-guard` watchdog in this file, which closes
# that gap.
{
  pkgs,
  lib,
  config,
  ...
}:

let
  # ── Ports, and where we accept them from ───────────────────────────────────
  # DERIVED from the base with the SAME offsets Sunshine itself uses to build the web UI's
  # port table. Read from the build in use (2026.516.143833), in
  # `assets/web/assets/config-*.js`: tcp `port-5`, `port`, `port+1`, `port+21` and udp
  # `port+9` through `port+11`. Writing the numbers by hand would be copying from a blog, and
  # blogs get it wrong: almost every list on the internet includes a UDP 48002 ("mic") that
  # DOES NOT EXIST in this version. There are three UDP ports, not four. Check the js in the
  # store when updating.
  basePort = 47989; # Sunshine's `port`; moving this moves all the others
  sp = n: toString (basePort + n);

  # What Moonlight needs to reach, and what it does NOT. `port+1` (47990) is the ADMIN PANEL
  # and it is out of this list ON PURPOSE: it never leaves the house. Whoever adds it here
  # publishes the screen that creates users and pairs clients on the internet.
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

  # WHERE we accept it from. Public UFSCar blocks, confirmed on registro.br on 10/08/2026
  # (both registered under CNPJ 45.358.058/0001-40).
  #
  # Do NOT swap this for `0.0.0.0/0` "so it works from anywhere". The house is NOT behind
  # CGNAT (measured on 10/08/2026, port 2222 answers from Austria, Canada and Iran), so
  # `0.0.0.0/0` here literally means the planet. What these ports hand to whoever reaches them
  # is `/serverinfo` with NO authentication at all: hostname, GPU, app list and whether there
  # is an active session. Pairing still requires the PIN typed on the host; inventorying the
  # machine requires nothing.
  #
  # A literal, and not an option in ../net/subnets.nix, because rule 11 asks for 2+ consumers
  # and here there is ONE. But there is a mirror to keep in sync by hand: the `src_ip` of the
  # `Moonlight-*` redirects in router/uci/firewall.conf. If the two lists diverge, the router
  # forwards and the host drops, and the symptom is "Moonlight does not connect", which is
  # indistinguishable from everything else.
  #
  # THE TWO BLOCKS ARE NOT WORTH THE SAME, and that is measured
  # (docs/history/2026/08-august.md, the CGNAT false alarm entry): the FAI network DROPS THE
  # SYN-ACK on the way back. The SYN leaves there, arrives here, the host answers, the
  # router's conntrack sits in `SYN_RECV` and the final ACK never comes back. Which means the
  # connection from the /21 may simply not complete, and there is nothing on this side that
  # fixes it. The /20 (campus) DOES get through, proven by the SSH session of 10/08/2026,
  # coming from 200.133.233.101. The /21 stays on the list anyway: it costs one rule, and the
  # block is THEIR firewall's, which can change without notice.
  moonlightSources = [
    "200.133.224.0/20" # UFSCar, campus. This is where the notebook goes out today, and it WORKS
    "200.136.192.0/21" # UFSCar, the FAI range. See above: the connection may not complete
  ];

  # Source times port = 8 rules. GENERATED and not written by hand because the stop list has
  # to match the start list EXACTLY: a rule that does not match is not removed on reload and
  # stacks a duplicate on every rebuild. Writing 16 mirrored lines by hand is precisely how
  # you leave one behind.
  fwMatches = lib.concatMap (
    src: map (p: "-s ${src} -p ${p.proto} --dport ${p.dport}") moonlightPorts
  ) moonlightSources;

  # A mark saying the hypridle pause belongs to THIS guard and not to me. The bar's pill
  # (quickshell, Bar.qml) also stops hypridle, on purpose, and without this mark the watchdog
  # below would undo that manual toggle within 5 min. It lives in XDG_RUNTIME_DIR: it
  # disappears on reboot, which is exactly when hypridle comes back on its own anyway.
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

  # ── The guard's watchdog: the `undo` above is NOT a guarantee ────────────────
  # Measured on 10/08/2026: a client disappeared with no clean teardown at ~14:57, Sunshine
  # never closed the session, the `undo` never ran, and hypridle stayed stopped for 6h. The
  # `ping_timeout` does not cover this: it drops the STREAM, not Sunshine's session
  # bookkeeping. And while hypridle is stopped the machine never locks by itself.
  #
  # THE SIGNAL HAS TO BE REALITY, NOT SUNSHINE'S BOOKKEEPING. The obvious path would be
  # `/serverinfo` (no auth on 47989, which is what the header cites), but that is precisely
  # what lies: at 17:30 that day it still said SUNSHINE_SERVER_BUSY with the client dead for
  # 2h30. A watchdog keyed on it would never fire.
  #
  # What did NOT lie in the same measurement: the sockets. With the ghost session "active",
  # Sunshine had ZERO UDP sockets on the video ports; it creates them per session and closes
  # them at the end. So `bound` means a real stream.
  # I measured the NEGATIVE side (no stream implies no socket); the positive one is a strong
  # inference (that is where the client sends video/audio/control, the same ports as
  # `moonlightPorts`) but not observed. Check on the next stream with `ss -uan | grep 4799`
  # before treating it as fact.
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

      # 3) A 2 min GRACE. Between the `do` (which stops hypridle) and the bind of the video
      #    ports there is a window; in "Steam Big Picture" it lasts the whole Steam launch.
      #    Turning it back on inside that window is the 03/08 remote lockout all over again.
      paused=$(systemctl --user show hypridle.service -p InactiveEnterTimestampMonotonic --value)
      now=$(awk '{printf "%d", $1 * 1000000}' /proc/uptime)
      if [ "$paused" -gt 0 ] && [ "$((now - paused))" -lt 120000000 ]; then exit 0; fi

      # 4) A real stream? Video UDP bound, or control TCP ESTABLISHED with a non-loopback
      #    peer (which covers the setup window, before video comes up; loopback is excluded
      #    because sunshine-healthcheck opens one on 47984 every 2 min).
      #    ss does the filtering itself, with NO PIPE into grep: `set -o pipefail` plus a
      #    `grep -q` that exits on the 1st match gives SIGPIPE and inverts the result, which
      #    is the sunshineHealth lesson.
      #    `not dst X` and NOT `dst != X`: the second looks natural and the ss parser rejects
      #    it with "bison bellows (syntax error)". Tested on 10/08/2026.
      [ -z "$(ss -uanH "sport >= :${sp 9} and sport <= :${sp 11}")" ] || exit 0
      [ -z "$(ss -tanH state established "( sport = :${sp (-5)} or sport = :${sp 21} ) and not dst 127.0.0.0/8 and not dst [::1]")" ] || exit 0

      echo "<4>hypridle stopped with no active stream, turning it back on (Sunshine's undo did not run)"
      rm -f "$stamp"
      systemctl --user start hypridle.service
    '';
  };

  # sunshine-health: a real TLS handshake on 47984. `-brief` prints "Protocol version:" only
  # when the handshake COMPLETES, and that is the signal; an accepted TCP is not enough, which
  # was exactly the hung state of 29/07. The probe targets 127.0.0.1, so it does not depend on
  # the VPN.
  #
  # NO PIPE on purpose: writeShellApplication turns `set -o pipefail` on, and with `| grep -q`
  # the grep exits on the 1st match, openssl dies of SIGPIPE and the pipeline returns an ERROR
  # despite having matched. That inverted the result: a successful handshake was read as a
  # failure, and the timer would restart Sunshine every 2 min forever. Capturing into a
  # variable plus a `case` avoids the pipe entirely.
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
  # moonlight-stats: a report on session QUALITY, because "it drops all the time" is not
  # measurable and the Sunshine log only says "CLIENT DISCONNECTED", the same line for a
  # client that closed, a client that gave up and a host that dropped it.
  #
  # What it answers, and what closed the 31/07 diagnosis: the distribution is BIMODAL, so
  # either the session lasts hours or it dies in 3 to 60 s. That alone separates "bad network"
  # from "something drops it", which was the question.
  #
  # It SHRANK on 08/08/2026, when Tailscale left. It used to cross-reference each session with
  # the tailscaled events (IPv4/IPv6 path swap, link change) and with the sunshine-path-probe
  # samples, to answer "was this session direct or did it fall into DERP?". With WireGuard
  # there is no relay: the question lost its object, and the sections answering it were removed
  # instead of adapted. What stayed is what is still true, the session durations and the
  # short/long split.
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

    # Sessions: CONNECTED to DISCONNECTED pairs. A session in progress (with no pair) is left
    # out, because with no end there is no duration, and counting it as "short" would lie
    # about precisely the session happening right now.
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

  # Wrapper: the logic lives in the build (rule 7) and the runtime is one line. `python3` is
  # explicit in runtimeInputs, because the script is a store artifact and not a loose .sh in
  # the repo.
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
      # FORCES the wlr backend (wlr-screencopy). Without this, Sunshine PROBES the
      # `portalgrab` backend (the ScreenCast/RemoteDesktop portal) at startup, and on Hyprland
      # that probe fires `hyprland-share-picker`, which does not render (a missing Qt plugin)
      # and HANGS Sunshine, so it never opens the ports (Moonlight would not connect after a
      # VPN change or a boot). wlr is the correct backend for wlroots, and forcing it skips
      # the portal probe. (Video = wlr, input = uinput through the /dev/uinput uaccess ACL,
      # both with no portal.)
      capture = "wlr";
      # Do NOT force capture=kms: kmsgrab does NOT enumerate on the `xe` driver (Battlemage),
      # giving "Unable to find display" and the service does not even stream. Leaving it auto
      # means `wlr` (which works AS LONG AS the monitor is on, see the streamBegin guard
      # below).
      # WHICH monitor to capture. Without this, wlgrab takes the FIRST in the enumeration, and
      # the TV enumerates before the LG, so Moonlight opened on the SECONDARY monitor
      # (measured in the log: "Monitor 0 is HDMI-A-3 / Monitor 1 is DP-2" then "Selected
      # monitor [... LG TV]"). It is not the client's choice: Moonlight gets what the host
      # sends. It matches by connector NAME (the same one in the log's monitor list), not by
      # index, because the index depends on enumeration order, which is exactly what went
      # wrong here.
      output_name = config.my.monitors.primary; # SSOT: system/desktop/monitors.nix
      # "wan" and not "lan": kept at the more permissive value ON PURPOSE, because what
      # decides the reach here is the firewall, not Sunshine. Tightening this would gain
      # nothing and risks breaking the web UI silently (the stream does not use CSRF, so the
      # symptom only shows up when opening the panel).
      #
      # THIS ONLY STAYS SAFE WHILE 47990 IS NOT FORWARDED. Until 10/08/2026 the sentence here
      # was "only the WireGuard range reaches this port", and it stopped being true the day
      # direct access landed: now UFSCar reaches it too, on the STREAM ports. 47990 was left
      # out of both lists (`moonlightPorts` at the top and the router redirects) precisely
      # because this value is "wan"; forwarding it would publish the admin panel with no gate
      # at all.
      origin_web_ui_allowed = "wan";
      # CSRF: allows the origin the panel is opened through. Without this, creating the user
      # or saving through the web UI is blocked when the host is not localhost.
      #
      # IT WAS ALREADY WRONG ONCE, between the cutover (01/08) and 02/08/2026, and nobody
      # noticed: the STREAM does not use CSRF, so only the web UI breaks, a silent failure by
      # definition. Back then the value pointed at the tailnet, whose IP changed on every
      # rejoin of the node. Now it is this machine's LAN IP, which is where the WireGuard peer
      # arrives (the router routes 10.10.10.x to the LAN with no NAT). It is still a SNAPSHOT:
      # an IP cannot be derived at build time. It is worth guaranteeing a static lease on the
      # router, because without one, changing IP breaks the panel again, and you only find out
      # when you try to open it.
      csrf_allowed_origins = "https://192.168.1.10:47990";
      # MANDATORY because access goes through a tunnel. Sunshine's default is 1392, calibrated
      # for MTU 1500; in a tunnel it overflows, and WireGuard drops it SILENTLY (no ICMP, no
      # log): the host streams normally, the client receives half of it, fails to reassemble
      # the frame and disconnects in ~4 s. That is what happened on 29/07 with tailscale0
      # (MTU 1280). KEPT at 1024 through the switch to WireGuard (MTU ~1420) even with room to
      # spare: it is a PROVEN value, and raising it would be optimizing without measuring,
      # risking reintroducing exactly the silent bug that cost that debug.
      #
      # SINCE 10/08/2026 THIS IS LOCKED AT 1024, and it is no longer conservatism, it is a
      # constraint. This value is GLOBAL, one for every client, and now there are two paths
      # with DIFFERENT MTU: the tunnel (~1420) and the direct one from UFSCar (1492 from
      # PPPoE). Whoever calibrates for the direct path breaks the tunnel one, and breaks it in
      # the worst way this file already documents: WireGuard drops it SILENTLY, with no ICMP
      # and no log, and the client falls in ~4 s. The useful ceiling is the SMALLER path's,
      # always.
      # It only makes sense to raise it if the tunnel path is RETIRED, and then the number to
      # aim for is the one from the test in docs/tests/wireguard-moonlight.md, not a guess.
      packet_size = 1024;
      # A BITRATE CEILING on the host. The default is 0 = "obey whatever Moonlight asks", and
      # the client asked for up to 79 Mbps: measuring the 67 sessions over 7 days (jul/2026),
      # the 79 Mbps ones had a median lifetime of 22 s against 290 s for the 23.8 Mbps ones.
      # The cap is on the HOST and not on the client's slider on purpose: it is declarative and
      # it holds for ANY client that pairs, without depending on remembering the Moonlight
      # config on each machine.
      #
      # 10000 became 20000 (31/07). Two measurements changed the arithmetic:
      #   1. The encoder in use is AV1 (av1_vaapi, confirmed on the live instance), not h264
      #      as this comment used to say. AV1 delivers ~40 to 50% more per bit, so 10 Mbps here
      #      already amounted to ~18 to 20 Mbps of h264. The ceiling was looser than it looked,
      #      but by a mistaken premise, not by choice.
      #   2. The "79 Mbps" is NOT what the client asked for that week: cross-referencing
      #      bitrate against encoder in the journal, the 7 days ran at 19.4 Mbps, and the SHORT
      #      ones on 31/07 (15 to 68 s) were also at 19.4. Which means a short drop happens at
      #      a moderate bitrate, and the cap is not what prevents it. The confounder is the
      #      hour: they cluster in the 08:00 window, the same one in which the FAI network
      #      dropped the VPN 52 times that week (system/net/vpn.nix).
      # So 20000 is NOT an experiment, it is going back to the bitrate that was already the de
      # facto one, now explicit and declared. The ceiling still exists to stop a client from
      # asking for 79. It serves Cities Skylines II, where a camera pan changes EVERY pixel of
      # the frame (the worst case for interframe compression, despite the game being "calm");
      # Hearthstone, with a fixed camera, fit comfortably in 10.
      # THE SAMPLE at 10 Mbps was ONE session, which did not even complete, so the previous
      # ceiling never had a stability record. There is no A/B to preserve here.
      #
      # CORRECTION (03/08/2026): item 1 above is WRONG for the FAI client. The encoder is NOT
      # the host's choice, it is NEGOTIATED, and who picks is Moonlight. Measured in today's
      # log, on a real session coming from faidell6035:
      #     Creating encoder [h264_vaapi] / Color depth: 8-bit / Rec. 601
      # while the host announces hevc_vaapi AND av1_vaapi (both 10-bit) at startup. Which
      # means: that client asks for H.264 8-bit, the LEAST efficient codec available, and the
      # "AV1 delivers 40 to 50% more per bit" arithmetic does not apply to it. At the 16.8 Mbps
      # negotiated it spends bandwidth the way H.264 spends it.
      # The practical consequence: turning HEVC/AV1 on IN THE CLIENT'S MOONLIGHT is worth more
      # than any tweak in this file, and it is where to look first when the stream suffers.
      # There is no host setting that forces it (`hevc_mode`/`av1_mode` only ANNOUNCE support,
      # which is already announced): it is a checkbox on the client.
      max_bitrate = 20000; # Kbps
      # More error correction (the default is 20%): the path to the FAI network LOSES packets.
      # Measured at 1.67% loss with RTT jumping from 20 to 312 ms in a burst of 300 packets of
      # 1 KB. FEC recovers loss without retransmitting (which in real time would arrive late).
      # It costs bandwidth, and that is why it travels with the ceiling above: there is room to
      # pay for it.
      # CAVEAT: the measurement is ICMP, which switches and firewalls tend to deprioritize, so
      # it is an indication of a bad path, not proof of what the video flow suffers.
      fec_percentage = 30;
      # Tolerates a transient hole before dropping the stream (the default is 10 s). It only
      # helps in the case where the HOST is the one giving up; in the logs there is no way to
      # tell that from the client giving up, since "CLIENT DISCONNECTED" is the same line in
      # both cases. It is not free: a dead client's session holds hypridle paused for longer
      # (the global_prep_cmd guard only turns it back on in the undo).
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

    # ── Apps exposed to Moonlight, DECLARATIVE (rule 3) ─────────────────────────
    # Until 03/08/2026 this was NOT declared, and Sunshine created its own
    # ~/.config/sunshine/apps.json with the FACTORY apps. One of them dropped the stream in
    # 2.5s:
    #
    #   "Low Res Desktop" with the prep-cmd `xrandr --output HDMI-1 --mode 1920x1080`
    #
    # Two mistakes in the same factory command: `xrandr` is X11 (here it is pure Wayland, with
    # no Xwayland in the capture path) and `HDMI-1` does not exist, since the real outputs are
    # DP-2 and HDMI-A-3. A prep-cmd that FAILS makes Sunshine abort the session, so clicking
    # that app was a guaranteed drop. Worse: the global guard's undo does not run on that
    # abort, leaving hypridle stopped (see lock_cmd in lockscreen.nix).
    #
    # I did NOT reimplement "Low Res Desktop" with `hyprctl output`, on purpose: changing the
    # video mode WITH the wlr capture active is the same class of risk as dpms under capture,
    # which caused a GPU ENGINE RESET on xe (see the header). A lower resolution is asked for
    # on the CLIENT (Moonlight picks the mode and Sunshine scales), without touching the host's
    # scanout.
    #
    # TRADE-OFF: declaring `applications` makes the module point `file_apps` at the store
    # (nixos/modules/services/networking/sunshine.nix:128, gated on apps != []), so the web
    # UI's Applications tab becomes READ ONLY. That is the price of being declarative, and it
    # is the right side of rule 14 (one owner per artifact). The old
    # ~/.config/sunshine/apps.json is now IGNORED; do not delete it by reflex upon seeing that
    # it exists and has no effect, it is just leftover from the non-declarative period.
    applications = {
      apps = [
        # Remote desktop: Sunshine's "special" app (with no cmd it streams the session).
        { name = "Desktop"; }
        # Steam in Big Picture. `detached`: Sunshine does not wait for the process to end
        # (otherwise the session would die along with Steam); the undo closes BP on disconnect.
        # `setsid` by absolute path (rule 7); `steam` stays as a NAME on purpose, because what
        # resolves it is the programs.steam FHS wrapper on the session PATH, and a
        # ${pkgs.steam}/bin/steam here would bypass that wrapper.
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

  # ── HTTPS handler healthcheck ───────────────────────────────────────────────
  # On 29/07 Sunshine ended up with 47984 (HTTPS) accepting TCP and NEVER completing the TLS
  # handshake, with 22 connections stacked in CLOSE-WAIT, while 47989 (HTTP) answered 200
  # normally. Moonlight uses HTTPS on an already paired host, so it showed "offline". The
  # worst part: the service stayed `active`, with ExecMainStatus=0 and NOT ONE line of log.
  # There was no way to notice; only a `systemctl restart` fixed it.
  #
  # Hence the active probe: the only way to detect it is to ATTEMPT the handshake. 3 attempts
  # in ~10 s before restarting, so a hang is not confused with the service starting up. It
  # restarts even with an active stream, because a host with a hung HTTPS is already useless.
  systemd.user.services.sunshine-healthcheck = lib.mkIf config.my.services.sunshine {
    description = "Restarts Sunshine if the HTTPS handler (47984) is hung";
    serviceConfig = {
      Type = "oneshot";
      ExecStart = "${sunshineHealth}/bin/sunshine-health";
      # A 2min timer means systemd would log "Starting…/Finished…" every time (440 lines/day
      # measured). `warning` cuts the info out; the probe's failures come out with the <4>/<3>
      # prefix and stay visible, which is what is worth investigating.
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

  # ── Internet access, with no VPN, restricted to UFSCar ──────────────────────
  # The other half of this lives ON THE ROUTER (the `Moonlight-*` redirects), which Nix does
  # not reach, see the header of ../net/router.nix. This rule on its own exposes nothing:
  # without the DNAT over there, no packet from the internet reaches these ports. That is why
  # it can land FIRST, and that is the right order, since the reverse would leave the router
  # forwarding to a host that refuses.
  #
  # The `-s` is NOT redundant with the router's `src_ip`: it is the second lock, and the one
  # that survives somebody touching LuCI without reading this file.
  #
  # `-I nixos-fw 1`: the same idiom and the same reason as the LocalSend rule in
  # ../net/localsend.nix. `-A` would work in today's extraCommands, but `-I 1` does not depend
  # on where upstream decides to inject it tomorrow.
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
