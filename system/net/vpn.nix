# The FAI (nxBender/SonicWall) and UFSCar (openconnect/GlobalProtect) VPNs, on demand.
# Why `is-active` lies, the two watchdogs and the probe target: docs/notes/network/vpn.md
{ pkgs, config, ... }:

let
  # Exponential backoff with NO ceiling: a hard limit left the unit permanently `failed`.
  vpnRestart = {
    Restart = "always";
    RestartSec = 10;
    RestartSteps = 5; # 10s, ~26s, ~68s, and so on up to the ceiling
    RestartMaxDelaySec = 300;
  };

  # The `vpn` CLI: connect/disconnect, status-json (the pill), stats-json (the hover panel)
  # and diagnose/watch, whose job is to name WHOSE fault a failure is.
  vpnCli = pkgs.writeShellApplication {
    name = "vpn";
    runtimeInputs = with pkgs; [
      systemd
      libnotify
      iproute2
      gnugrep
      gawk # awk, already used by heal_one, and now by stats-json too
      iputils # ping, for discovering the probe target (runs without root: ping_group_range)
      coreutils
      bash
    ];
    text = ''
      note() { notify-send -a VPN "VPN" "$1" 2>/dev/null || true; }
      # Connected = the unit is active AND the tunnel exists; `is-active` alone lies.
      fai_conn()    { systemctl is-active --quiet vpn-fai.service    && [ -n "$(ip -o link show type ppp)" ]; }
      ufscar_conn() { systemctl is-active --quiet vpn-ufscar.service && ip -o link show type tun | grep -q ': tun[0-9]'; }
      # ~/FAI-workstation rises and falls with this tunnel; --no-block, the mount retries.
      mnt='rclone-mount:.@faiws.service'
      # reset-failed before every start: a unit that died in `failed` REFUSES `start` until it
      # is cleared, and then the SUPER+N bind did nothing with no explanation. Idempotent.
      fai_up()      { systemctl reset-failed vpn-fai.service 2>/dev/null || true; systemctl start vpn-fai.service && note "FAI connecting..."; systemctl --user start --no-block "$mnt" 2>/dev/null || true; systemctl --user start --no-block vpn-watch@fai.service 2>/dev/null || true; }
      fai_down()    { systemctl stop  vpn-fai.service 2>/dev/null || true; systemctl --user stop "$mnt" 2>/dev/null || true; note "FAI disconnected"; }
      ufscar_up()   { systemctl reset-failed vpn-ufscar.service 2>/dev/null || true; systemctl start vpn-ufscar.service && note "UFSCar connecting..."; systemctl --user start --no-block vpn-watch@ufscar.service 2>/dev/null || true; }
      ufscar_down() { systemctl stop  vpn-ufscar.service 2>/dev/null || true; note "UFSCar disconnected"; }

      # ── Diagnosis ──────────────────────────────────────────────────────────
      # Per-VPN metadata: the unit plus the portal (host/port) that has to be up.
      vpn_meta() {
        case "$1" in
          fai)    echo "vpn-fai.service 200.133.233.101 4433" ;;
          ufscar) echo "vpn-ufscar.service acessoremoto-scl.ufscar.br 443" ;;
          *)      return 1 ;;
        esac
      }
      conn_of() { case "$1" in fai) fai_conn ;; ufscar) ufscar_conn ;; *) return 1 ;; esac; }
      # Plain TCP through /dev/tcp: it does not depend on `nc` (whose `-z` varies per
      # implementation; this machine's `nc -zv` exits silently, which already fooled me once).
      tcp_open() { timeout "''${3:-6}" bash -c "exec 3<>/dev/tcp/$1/$2" 2>/dev/null; }

      # Heals the HANG (active, no tunnel, no log) and STOPS on a credential error, because
      # retrying a wrong password is a login storm, not a recovery.
      stop_if_unrecoverable() {
        id="$1"
        unit="$2"
        log="$(journalctl -u "$unit" --since '-10 min' --no-pager -o cat 2>/dev/null || true)"
        case "$log" in
          *"Password change needed"* | *"Password expired"* | *"password has expired"*) ;;
          *) return 1 ;;
        esac
        # <3> = err: higher than the hang's <4>, because this one demands HUMAN ACTION
        echo "<3>$id: password expired in AD, stopping the unit (retrying does not fix it)"
        systemctl stop "$unit" 2>/dev/null || true
        notify-send -a VPN -u critical -i network-vpn "VPN ''${id^^}: password expired" \
          "I stopped retrying so your account does not get locked. Change the password on a domain machine (Ctrl+Alt+Del), then sops plus nixos-rebuild switch." 2>/dev/null || true
        return 0
      }

      heal_one() {
        id="$1"
        meta="$(vpn_meta "$id")" || return 0
        read -r unit _ _ <<< "$meta"
        # ActiveState, never `is-active --quiet`: it is false while `activating`.
        case "$(systemctl show "$unit" -p ActiveState --value)" in
          inactive | deactivating) return 0 ;; # nobody asked for a connection
        esac
        conn_of "$id" && return 0 # the tunnel is up: nothing to do
        # PRECEDENCE: credential before hang. If the cause is the password, restarting (which
        # is what the rest of this function does) is exactly the opposite of right.
        stop_if_unrecoverable "$id" "$unit" && return 0
        since_us="$(systemctl show "$unit" -p ActiveEnterTimestampMonotonic --value)"
        up_s="$(cut -d' ' -f1 /proc/uptime)"
        # monotonic (immune to a clock adjustment); the grace is in seconds
        awk -v s="''${since_us:-0}" -v u="$up_s" -v g=180 \
          'BEGIN { exit !(s > 0 && u - s/1000000 > g) }' || return 0
        # <4> = warning: it survives LogLevelMax and marks the time it ACTED
        echo "<4>$id: active with no tunnel past the grace, restarting (portal hang)"
        notify-send -a VPN -u critical -i network-vpn "VPN ''${id^^} is stuck" \
          "Active with no tunnel for over 3 min. The portal accepted the connection and stopped answering, restarting." 2>/dev/null || true
        systemctl restart "$unit" 2>/dev/null || true
      }

      # Echoes: line 1 = the VERDICT (whose fault it is), line 2 = the detail, the rest =
      # evidence.
      diag() {
        id="$1"
        meta="$(vpn_meta "$id")" || { echo "usage: vpn diagnose fai|ufscar" >&2; return 2; }
        read -r unit host port <<< "$meta"

        if conn_of "$id"; then
          printf 'connected\ntunnel is up (unit active AND interface present)\n'
          return 0
        fi

        # ActiveState separates inactive (nobody asked) from activating (trying now) and
        # failed (gave up). `is-active --quiet` here announced the opposite of the truth.
        state="$(systemctl show "$unit" -p ActiveState --value)"
        case "$state" in
          inactive | deactivating)
            printf 'not connecting -- the unit is stopped\nno attempt in progress; use: vpn connect %s\n' "$id"
            return 1
            ;;
        esac

        # 15 min so the evidence is from THIS attempt. `-o cat` asks for the bare message:
        # stripping the prefix with sed died silently when the hostname changed.
        log="$(journalctl -u "$unit" --since '-15 min' --no-pager -o cat 2>/dev/null || true)"

        # A deliberate ORDER: the most local first. Blaming FAI for a "timeout" in the log
        # while the network here is down would be the classic mistake of this kind of alert.
        if ! tcp_open 1.1.1.1 443 4; then
          verdict="NO INTERNET on this machine"
          detail="1.1.1.1:443 did not open, so the problem is your network, before the VPN"
        elif ! tcp_open "$host" "$port"; then
          verdict="THE VPN PORTAL IS DOWN, it is not your machine"
          detail="$host:$port refuses the connection and the internet from here is fine"
        else
          case "$log" in
            # FIRST on purpose: the only case where retrying never works. The SonicWall
            # phrase blames our config, but it means the appliance cannot write AD.
            *"Password change needed"* | *"Password expired"* | *"password has expired"*)
              verdict="PASSWORD EXPIRED in AD, retrying does NOT fix it"
              detail="change it on a domain machine (Ctrl+Alt+Del), then sops plus nixos-rebuild switch. Run 'vpn disconnect $id' NOW, to stop accumulating failed logins." ;;
            *"Login failed"*|*"Authentication failed"*|*"invalid credential"*)
              verdict="CREDENTIAL REJECTED"
              detail="the portal answered and refused the login, so review the password in sops" ;;
            *"Connection reset by peer"*)
              verdict="FAI DROPPED the connection (reset by peer)"
              detail="the portal is up, but it closed the session mid-process" ;;
            *"echo-requests"*|*"Modem hangup"*|*"Peer not responding"*)
              verdict="THE TUNNEL CAME UP AND FELL, on the FAI side"
              detail="pppd stopped getting answers with the tunnel already active" ;;
            *)
              verdict="still trying (unclassified cause)"
              detail="the portal is reachable; the lines below are the most recent the log has" ;;
          esac
        fi

        printf '%s\n%s\n' "$verdict" "$detail"
        # evidence: the last error lines (already without a prefix, from the `-o cat` above)
        printf '%s\n' "$log" \
          | grep -iE 'error|failed|timed out|hangup|refused|reset by peer|not responding' \
          | tail -n 3 || true
        return 1
      }

      # Tunnel stats for the hover panel. Separate from status-json, and it does NOT measure
      # latency: the bar does that with a continuous ping.
      iface_of() {
        case "$1" in
          fai)    ip -o link show type ppp | awk -F': ' 'NR==1 { print $2 }' ;;
          # the same tun[0-9] filter as ufscar_conn: `type tun` also matches tailscale0
          ufscar) ip -o link show type tun | awk -F': ' '$2 ~ /^tun[0-9]+$/ { print $2; exit }' ;;
        esac
      }
      nstat() { cat "/sys/class/net/$1/statistics/$2" 2>/dev/null || echo 0; }

      # The probe target. The FAI ppp peer (192.0.2.1) ignores ICMP; .236 answers through the
      # tunnel. UFSCar has no fixed candidate, because a guessed one would be a wrong number.
      probe_candidates() {
        case "$1" in
          fai) echo "200.136.209.236" ;;
          *) ;;
        esac
        ip -4 route show dev "$2" 2>/dev/null | awk '/ via /{ print $3 }' | sort -u
      }

      # -I pins the packet to the tunnel: without it a stray route would time a LIE.
      probe_alive() { ping -n -q -c 1 -W 1 -I "$1" "$2" >/dev/null 2>&1; }

      # Memorized per iface+IP. "Not found" is retried every 5 min, never cached forever.
      probe_for() {
        id="$1"; ifc="$2"; ipaddr="$3"
        f="''${XDG_RUNTIME_DIR:-/tmp}/vpn-probe-$id"
        now="$(date +%s)"
        c_if=""; c_ip=""; c_tgt=""; c_ts=0
        if [ -r "$f" ]; then
          read -r c_if c_ip c_tgt c_ts < "$f" || true
        fi
        case "$c_ts" in "" | *[!0-9]*) c_ts=0 ;; esac
        if [ "$c_if" = "$ifc" ] && [ "$c_ip" = "$ipaddr" ] && { [ "$c_tgt" != "-" ] || [ $((now - c_ts)) -lt 300 ]; }; then
          echo "$c_tgt"; return 0
        fi
        found="-"
        while read -r t; do
          [ -n "$t" ] || continue
          if probe_alive "$ifc" "$t"; then found="$t"; break; fi
        done <<< "$(probe_candidates "$id" "$ifc")"
        echo "$ifc $ipaddr $found $now" > "$f"
        echo "$found"
      }

      # A disconnected VPN emits only connected:false: zeroed fields would draw a fake graph.
      stats_one() {
        id="$1"; name="$2"
        ifc=""
        conn_of "$id" && ifc="$(iface_of "$id")"
        if [ -z "$ifc" ]; then
          printf '{"id":"%s","name":"%s","connected":false}' "$id" "$name"
          return 0
        fi
        # ppp returns "inet <local> peer <remote>/32"; tun returns "inet <ip>/32". Field 4 is
        # the local address in both cases, and the cut removes the prefix when there is one.
        ipaddr="$(ip -o -4 addr show dev "$ifc" 2>/dev/null | awk 'NR==1 { print $4 }' | cut -d/ -f1)"
        mtu="$(cat "/sys/class/net/$ifc/mtu" 2>/dev/null || echo 0)"
        case "$mtu" in "" | *[!0-9]*) mtu=0 ;; esac
        rx="$(nstat "$ifc" rx_bytes)"; tx="$(nstat "$ifc" tx_bytes)"
        errs=$(( $(nstat "$ifc" rx_errors) + $(nstat "$ifc" tx_errors) ))
        drops=$(( $(nstat "$ifc" rx_dropped) + $(nstat "$ifc" tx_dropped) ))
        # The sysfs counters are born with the interface, so they are already "per session":
        # ppp0 and tun0 are created on connect and destroyed on disconnect.
        read -r unit _ _ <<< "$(vpn_meta "$id")"
        since_us="$(systemctl show "$unit" -p ActiveEnterTimestampMonotonic --value)"
        up_s="$(cut -d' ' -f1 /proc/uptime)"
        uptime_s="$(awk -v s="''${since_us:-0}" -v u="$up_s" \
          'BEGIN { v = (s > 0) ? int(u - s / 1000000) : 0; if (v < 0) v = 0; print v }')"

        # This delivers the TARGET only. Measuring is the bar's job, continuously.
        probe=null
        tgt="$(probe_for "$id" "$ifc" "$ipaddr")"
        [ "$tgt" = "-" ] || probe="\"$tgt\""
        printf '{"id":"%s","name":"%s","connected":true,"iface":"%s","ip":"%s","mtu":%s,"uptime":%s,"rx":%s,"tx":%s,"errors":%s,"drops":%s,"probe":%s}' \
          "$id" "$name" "$ifc" "$ipaddr" "$mtu" "$uptime_s" "$rx" "$tx" "$errs" "$drops" "$probe"
      }

      case "''${1:-}" in
        connect)
          case "''${2:-}" in
            ufscar) ufscar_up ;;
            fai)    fai_up ;;
            *) echo "usage: vpn connect ufscar|fai" >&2; exit 1 ;;
          esac ;;
        disconnect)
          case "''${2:-all}" in
            ufscar) ufscar_down ;;
            fai)    fai_down ;;
            all)    ufscar_down; fai_down ;;
            *) echo "usage: vpn disconnect ufscar|fai|all" >&2; exit 1 ;;
          esac ;;
        # Called by the vpn-heal timer: unsticks a hung VPN (see heal_one).
        heal)
          for id in ''${2:-fai ufscar}; do heal_one "$id"; done ;;
        # On-demand diagnosis, in the terminal: `vpn diagnose fai`.
        diagnose)
          diag "''${2:-fai}" ;;
        # Warns ONCE, and only on failure: a notification on the happy path becomes noise.
        watch)
          id="''${2:-fai}"
          sleep "''${3:-45}"
          conn_of "$id" && exit 0
          out="$(diag "$id" || true)"
          title="$(printf '%s' "$out" | head -n 1)"
          body="$(printf '%s' "$out" | tail -n +2)"
          notify-send -a VPN -u critical -i network-vpn \
            "VPN ''${id^^}: $title" "$body" 2>/dev/null || true
          printf '%s\n' "$out" ;;
        # Stable output for the Quickshell pill (Bar.qml polls it every 5s).
        status-json)
          fai=false; ufscar=false
          fai_conn    && fai=true
          ufscar_conn && ufscar=true
          printf '{"vpns":[{"id":"fai","name":"FAI","connected":%s},{"id":"ufscar","name":"UFSCar","connected":%s}]}\n' "$fai" "$ufscar" ;;
        # For the hover popover. Same shape as status-json, but only works with a tunnel up.
        stats-json)
          printf '{"vpns":[%s,%s]}\n' "$(stats_one fai FAI)" "$(stats_one ufscar UFSCar)" ;;
        # The `menu` subcommand was REMOVED on 30/07: the UI is a popover anchored to the bar.
        *) echo "usage: vpn connect|disconnect <ufscar|fai|all> | status-json | stats-json | diagnose <id> | watch <id> [sec] | heal [id]" >&2; exit 1 ;;
      esac
    '';
  };
in
{
  environment.systemPackages = [ vpnCli ];

  # A DECLARED unit (rule 15): a loose `&` would be parented to Quickshell and vanish on a
  # shell restart, at the exact minute it should warn.
  systemd.user.services.vpn-heal = {
    description = "Unsticks a hung VPN (active, no tunnel, past the grace)";
    serviceConfig = {
      Type = "oneshot";
      ExecStart = "${vpnCli}/bin/vpn heal";
      LogLevelMax = "warning"; # silences the no-op; heal_one's <4> gets through
    };
  };

  systemd.user.timers.vpn-heal = {
    description = "Periodic check for a hung VPN";
    timerConfig = {
      OnActiveSec = "3min";
      OnUnitActiveSec = "2min";
    };
    wantedBy = [ "timers.target" ];
  };

  systemd.user.services."vpn-watch@" = {
    description = "Diagnoses and notifies if VPN %i does not connect";
    serviceConfig = {
      Type = "oneshot";
      ExecStart = "${vpnCli}/bin/vpn watch %i";
      # `watch` exits silently when it connects; this cuts the "Starting…/Finished…" systemd
      # logs on its own (the lesson of bb8690c, the 2148 lines/day in the journal).
      LogLevelMax = "warning";
    };
  };

  # Rendered by sops into /run/secrets/rendered, never the store. The fingerprint is FAI's
  # self-signed cert (public); how to refresh it is in the note.
  sops.templates."nxbender-fai.conf".content = ''
    server = 200.133.233.101
    port = 4433
    username = victor.ferreira
    domain = fai2008
    fingerprint = a9:db:84:93:e3:09:96:c7:33:6f:4d:05:ba:fa:1d:aa:59:0e:77:01
    password = ${config.sops.placeholder.fai_vpn_password}
  '';

  # The password goes on STDIN (out of `ps`); --authgroup picks one of the portal's 5 gateways.
  systemd.services.vpn-ufscar = {
    description = "UFSCar VPN (GlobalProtect through openconnect)";
    wants = [ "network-online.target" ];
    after = [ "network-online.target" ];
    restartIfChanged = false; # a rebuild does not drop a tunnel in use; the daemon-reload already applies the new Restart=
    # no wantedBy, so it is ON DEMAND (the `vpn` CLI turns it on)
    serviceConfig = {
      Type = "simple";
      ExecStart = pkgs.writeShellScript "vpn-ufscar-up" ''
        ${pkgs.coreutils}/bin/cat ${config.sops.secrets.ufscar_vpn_password.path} \
          | ${pkgs.openconnect}/bin/openconnect --protocol=gp --user=857722 \
              --authgroup=acessoremoto.ufscar.br --passwd-on-stdin acessoremoto-scl.ufscar.br
      '';
    }
    // vpnRestart;
    # `vpn disconnect` uses systemctl stop, so systemd does NOT restart (an explicit stop does
    # not count).
    startLimitIntervalSec = 0; # no ceiling: what paces it is the backoff above
  };

  # FAI: SonicWall through nxBender, reading the config rendered by sops (with the password).
  systemd.services.vpn-fai = {
    description = "FAI VPN (SonicWall through nxBender)";
    wants = [ "network-online.target" ];
    after = [ "network-online.target" ];
    restartIfChanged = false; # same: reconnecting the VPN is my decision, not a rebuild side effect
    serviceConfig = {
      Type = "simple";
      ExecStart = "${pkgs.nxbender}/bin/nxBender -c ${config.sops.templates."nxbender-fai.conf".path}";
    }
    // vpnRestart;
    startLimitIntervalSec = 0;
  };

  # polkit: lets the user start and stop ONLY the vpn-* services without a password (so the
  # bind works with no prompt). Any other unit still requires authentication.
  security.polkit.extraConfig = ''
    polkit.addRule(function(action, subject) {
      if (action.id == "org.freedesktop.systemd1.manage-units" &&
          subject.user == "v1cferr") {
        var unit = action.lookup("unit");
        if (unit == "vpn-ufscar.service" || unit == "vpn-fai.service") {
          return polkit.Result.YES;
        }
      }
    });
  '';
}
