# The FAI and UFSCar VPNs, 100% declarative and on demand (they do not come up at boot; the
# `vpn` CLI plus the SUPER+N / SUPER+SHIFT+N / SUPER+CTRL+N binds turn them on and off). They
# run as system systemd services (a VPN needs tun and routes, so root).
#   • UFSCar goes to GlobalProtect (Palo Alto) through openconnect --protocol=gp (FOSS, in
#     nixpkgs).
#   • FAI goes to the SonicWall SSL VPN through nxBender (FOSS, pkgs/nxbender.nix; it replaces
#     the proprietary netExtender from the Arch days). If it stops connecting, the fallback is
#     packaging netExtender.
# Passwords come from sops (Bitwarden): openconnect reads on STDIN (out of `ps`), and nxBender
# reads a config rendered by sops.templates (out of the store and out of git). The `vpn` CLI
# starts the services without `sudo` thanks to the polkit rule below (otherwise the bind would
# ask for a password).
{ pkgs, config, ... }:

let
  # EXPONENTIAL BACKOFF, with no hard ceiling. The previous ceiling (6 attempts/10 min) had a
  # hole: when the SonicWall ACCEPTS the connection and drops it in ~24s (SIGHUP), each cycle
  # lasts ~34s, so the 6 attempts burned in ~3.5 min and systemd marked start-limit-hit,
  # leaving the unit PERMANENTLY in `failed`. Worse than the original bug: not even
  # `vpn connect fai` would come up anymore, without a manual `systemctl reset-failed`.
  # Now it is 10s to 300s progressively and it never gives up. A wrong password means ~12
  # attempts/h in the worst case, gentle enough not to trigger an account lockout at the
  # portal.
  vpnRestart = {
    Restart = "always";
    RestartSec = 10;
    RestartSteps = 5; # 10s, ~26s, ~68s, and so on up to the ceiling
    RestartMaxDelaySec = 300;
  };

  # The `vpn` CLI: connect/disconnect ufscar|fai|all plus status-json (which feeds the pill AND
  # the action popover, quickshell/bar/VpnPopover.qml) plus stats-json (tunnel latency, jitter,
  # loss and traffic, for the hover popover, VpnStatsPopover.qml) plus diagnose/watch (below).
  #
  # DIAGNOSE/WATCH (31/07): a connection failure was SILENT. You clicked Connect, nothing
  # happened, and from this side it looked like a problem with the personal machine. The goal
  # here is not dumping logs, it is having the notification SAY WHOSE FAULT IT IS, because that
  # is the information that changes what you do next (wait for FAI to come back vs touch your
  # own network or password).
  #
  # WHY A WATCHER and not systemd's `OnFailure=`: these units have Restart=always with
  # startLimitIntervalSec=0, so they NEVER enter `failed`, they stay in an eternal crash-loop
  # and an OnFailure would never fire. The trigger has to be time: 45s after the connection
  # request, if there is no tunnel, diagnose and warn once.
  #
  # THE CLASSIFICATION comes from signatures MEASURED in this machine's journal (2 days), not
  # invented: a ConnectTimeout on /cgi-bin/userLogin (the portal is down) is the most common
  # case, 152 occurrences; "Connection reset by peer" (27); "Modem hangup"/"Peer not
  # responding"/"No response to N echo-requests" (the tunnel came up and dropped). The order of
  # the tests matters: internet from here, then the portal being reachable, and only then the
  # log. Without that, a "timeout" in the log would be read as FAI's fault even with your own
  # network down.
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
      # "Connected" means the unit is active AND the tunnel actually exists. `is-active` alone
      # LIES: with the FAI portal down, nxBender enters a crash-loop and systemd reports active
      # during each attempt (~2min), with zero ppp0, so the pill stayed green for nothing.
      # UFSCar: it filters tun[0-9] because `type tun` matches ANY tun (tailscale0 was the
      # concrete case until 08/08/2026; the filter stays, the reason still holds).
      fai_conn()    { systemctl is-active --quiet vpn-fai.service    && [ -n "$(ip -o link show type ppp)" ]; }
      ufscar_conn() { systemctl is-active --quiet vpn-ufscar.service && ip -o link show type tun | grep -q ': tun[0-9]'; }
      # The rclone mount of the FAI workstation (~/FAI-workstation) comes up and goes down WITH
      # the FAI VPN (home/services/fai-workstation-mount.nix). --no-block: it does not block
      # waiting for the tunnel; the service retries on its own until the host is reachable.
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

      # ── Self-healing the HANG ──────────────────────────────────────────────
      # nxBender calls the portal WITHOUT a timeout (seen in the traceback: "connect
      # timeout=None"). When the SonicWall accepts the TCP but does NOT answer the session
      # request, the process sleeps forever: the unit stays `active/running`, with not ONE log
      # line and no tunnel, and Restart=always never acts, because it only reacts to a process
      # that EXITS. MEASURED on 31/07: 11 min hung with the connection in ESTAB and Recv-Q and
      # Send-Q at zero; a `systemctl restart` connected in 10s. The same shape as the Sunshine
      # HTTPS handler hang (system/services/sunshine.nix): active, exit 0, invisible by
      # definition.
      #
      # It only acts when all THREE conditions hold: the unit is active (which means somebody
      # asked to connect), the tunnel is absent, and it has been active for longer than the
      # grace. The grace exists because connecting legitimately takes ~10 to 30s; without it
      # the watchdog would kill the connection in progress and become the problem itself.
      # AUTO-STOP on an UNRECOVERABLE error. `Restart=always` is right for the common case (the
      # FAI portal flapping) and WRONG for a credential: an expired password does not improve
      # with retries, and each cycle is one failed login at the SonicWall, 59 of them in ~18h
      # during the 11-12/08/2026 episode, with a real risk of locking the account. Here the
      # policy INVERTS: if the log signature is a credential one, it STOPS the unit instead of
      # restarting. Only I can solve it (changing the password in AD), and until then insisting
      # only accumulates damage.
      #
      # A 10 min window on the log: the evidence has to be from the attempt in progress, not
      # from yesterday's episode, which would make this stop a healthy VPN.
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
        # The SAME care as the diag() gate, and this was the THIRD appearance of that mistake
        # in this file: `is-active --quiet` is false while `activating`, which is precisely the
        # crash-loop state, so this healer NEVER acted during the login storm, at the exact
        # minute it was needed. Without this, the auto-stop above would be dead code: it would
        # not even be called.
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

        # A STOPPED unit is not a failure, it is "you did not ask to connect". Without this
        # gate the diagnosis classified using a log from DAYS earlier and said "still trying"
        # about a VPN nobody tried to bring up, caught on the 1st real test (UFSCar, 31/07).
        #
        # Do NOT use `is-active --quiet` HERE, and this was the bite of 12/08/2026: in a
        # crash-loop the unit is `activating` (SubState=auto-restart) and `is-active` exits
        # NON-ZERO. The gate then announced "unit stopped, no attempt in progress" while
        # nxBender had been trying for 18 hours, the exact opposite of the truth, in precisely
        # the scenario this diagnosis was written for. It cost the whole session: it sent me
        # looking for a network problem in a credential failure.
        # `ActiveState` separates the three cases that matter: inactive = nobody asked;
        # activating = trying right now; failed = tried and gave up (the last two MUST go on to
        # the classifier). `fai_conn`/`ufscar_conn` up top keep `is-active` on purpose, since
        # there "connected" requires it to be REALLY active.
        state="$(systemctl show "$unit" -p ActiveState --value)"
        case "$state" in
          inactive | deactivating)
            printf 'not connecting -- the unit is stopped\nno attempt in progress; use: vpn connect %s\n' "$id"
            return 1
            ;;
        esac

        # A 15 min window: it guarantees the evidence is from the CURRENT attempt and not from
        # an old session left in the journal (the same trap as the gate above).
        # `-o cat` means only the MESSAGE, with no "date host unit[pid]:" prefix. That used to
        # be done afterwards, with `sed 's/.*nixos-sandisk //'`, which became a no-op the day
        # the hostname changed, and then the evidence came out with the prefix again. Asking
        # the tool for the right format cannot age; cutting by name can.
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
            # AN EXPIRED PASSWORD comes FIRST on purpose: it is the only case on this list
            # where RETRYING NEVER WORKS, and Restart=always turns that into a login storm,
            # 59 attempts in ~18h between 11 and 12/08/2026, with a real risk of locking the
            # account. Without this case the failure fell into "unclassified cause" and the
            # evidence alone misled: the SonicWall phrase ("please check TLS, server writable
            # or other config") looks like a configuration error on OUR side, and it actually
            # says the APPLIANCE cannot write the password change into AD.
            # MEASURED on 12/08: the web portal refuses the same way (E_UNAUTHORIZED /
            # "Password expired.") and does not even offer a change form, so no client solves
            # it and the cure is elsewhere. What worked: Ctrl+Alt+Del on a domain machine.
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

      # ── Tunnel statistics (the pill's hover) ───────────────────────────────
      # SEPARATE from status-json on purpose: that one answers "is there a tunnel?" every 5s
      # and is what paints the pill; this one answers "with what?", meaning interface, IP, MTU,
      # uptime, session bytes and WHICH host serves as the probe target. The bar only calls it
      # when there is a tunnel (every 20s in the background, every 3s with the panel open).
      # LATENCY DOES NOT COME FROM HERE: what measures it is the bar, with a continuous ping
      # (see stats_one).
      iface_of() {
        case "$1" in
          fai)    ip -o link show type ppp | awk -F': ' 'NR==1 { print $2 }' ;;
          # the same tun[0-9] filter as ufscar_conn: `type tun` also matches tailscale0
          ufscar) ip -o link show type tun | awk -F': ' '$2 ~ /^tun[0-9]+$/ { print $2; exit }' ;;
        esac
      }
      nstat() { cat "/sys/class/net/$1/statistics/$2" 2>/dev/null || echo 0; }

      # THE PROBE TARGET. Tunnel latency requires somebody who answers INSIDE it, and the
      # obvious candidate does NOT work: the FAI ppp peer is 192.0.2.1, TEST-NET-1, a facade
      # address of the SonicWall, and it ignores ICMP (MEASURED on 14/08/2026: 100% loss). What
      # answers is 200.136.209.236 (fai.ufscar.br): a public IP, but the 200.136.209.128/25
      # route goes out through ppp0, so the ping measures the TUNNEL (31ms, 0%).
      # I do not use the workstation host: `my.fai.workstation` is a home-manager option and a
      # system module cannot read an HM option (rule 11), and an institutional server goes down
      # less often than a workstation.
      # UFSCar enters with NO fixed candidate: I never measured an internal host of theirs with
      # the tunnel up, and guessing an address would produce a wrong number, which is worse
      # than a missing number. It falls back to the routes; if a target ever proves itself, the
      # place is here.
      probe_candidates() {
        case "$1" in
          fai) echo "200.136.209.236" ;;
          *) ;;
        esac
        ip -4 route show dev "$2" 2>/dev/null | awk '/ via /{ print $3 }' | sort -u
      }

      # The `-I <iface>` is not a detail: it pins the packet to the tunnel (SO_BINDTODEVICE).
      # Without it, a target that stopped being routed through the VPN would go out over the
      # home internet and the panel would display a GREAT latency that is not the tunnel's.
      # With the bind, that case becomes silence, and "no probe" is an honest answer while 8ms
      # lying is not.
      probe_alive() { ping -n -q -c 1 -W 1 -I "$1" "$2" >/dev/null 2>&1; }

      # Discovers and MEMORIZES the target (otherwise every sample would sweep the list again).
      # The cache key is iface+IP: a new tunnel means a new probe. A live target holds for the
      # whole session; "not found" is reevaluated every 5 min, otherwise a target that was down
      # at the instant of connection would condemn the panel to "no probe" until disconnecting.
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

      # One JSON object per VPN. A disconnected one comes out with just connected:false, since
      # with no iface there is nothing to measure, and emitting zeroed fields would make the
      # panel draw a graph of nothing.
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

        # Latency is NOT measured here, and the division is the point: what measures it is the
        # bar, with a CONTINUOUS ping of 1 packet/s (Bar.qml, VpnProbe). This command only
        # delivers the TARGET, because discovering who answers inside the tunnel is shell work
        # (sweeping routes, testing candidates, memorizing) while measuring is the work of
        # whoever watches all the time. The previous version measured here, in bursts of 3
        # packets, and the number came out PRETTY AND FALSE: see the VpnProbe block for the
        # measurement that proved it.
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
        # Called by vpn-watch@<id>.service, triggered by fai_up/ufscar_up. It waits and, if it
        # did not connect, warns ONCE with the verdict. Total silence when it connects, because
        # a notification that shows up on the happy path becomes noise and starts being
        # ignored.
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
        # Tunnel state for the HOVER popover (bar/VpnStatsPopover.qml). The same shape as
        # status-json (a list of vpns) because it is the same consumer, but it does not replace
        # that one: this only works with a tunnel up. See the stats_one block above.
        stats-json)
          printf '{"vpns":[%s,%s]}\n' "$(stats_one fai FAI)" "$(stats_one ufscar UFSCar)" ;;
        # REMOVED (30/07): the `menu` subcommand, which opened a loose rofi in the middle of
        # the screen. The UI is now a popover ANCHORED to the bar
        # (quickshell/bar/VpnPopover.qml), in the shell's theme. It is not only cosmetic: the
        # rofi menu built its labels with `systemctl is-active`, which LIES (see
        # fai_conn/ufscar_conn above), so it said "Disconnect" during the nxBender crash-loop,
        # with no tunnel existing. The popover reads status-json, which checks the real tunnel.
        # One source of truth, and the correct one.
        *) echo "usage: vpn connect|disconnect <ufscar|fai|all> | status-json | stats-json | diagnose <id> | watch <id> [sec] | heal [id]" >&2; exit 1 ;;
      esac
    '';
  };
in
{
  environment.systemPackages = [ vpnCli ];

  # The connection watcher: what fires it is the CLI itself (fai_up/ufscar_up), and it exists
  # as a DECLARED UNIT and not as a background subshell on purpose, per rule 15, an explicit
  # owner. A loose `&` in the CLI would be parented to Quickshell (which invokes it through
  # Process) and would disappear on a shell restart, at exactly the minute it should warn.
  # A @<id> template because there are two VPNs with different portals and different symptoms.
  # It is a USER unit because what delivers the notification is Quickshell, in the session.
  # The hang watchdog (see heal_one in the CLI) is also a USER unit because it needs to notify
  # (Quickshell is the daemon) and because the polkit rule above already lets this user restart
  # the vpn-* units: no root needed for that. Under autologin the session is always up, so the
  # watchdog is always in effect; if that ever changes, it stops running without a session, and
  # that is the known limitation.
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

  # The nxBender config (FAI) rendered by sops: static params plus the password from the vault.
  # It lives in /run/secrets/rendered (root-only), never in the store and never in git. The
  # fingerprint belongs to FAI's SELF-SIGNED cert (public, not a secret), and without it
  # nxBender refuses the SSL. If FAI swaps the certificate, get the new one with:
  #   openssl s_client -connect 200.133.233.101:4433 | openssl x509 -noout -fingerprint -sha1
  #   (the nxBender format is lowercase sha1 with ':').
  sops.templates."nxbender-fai.conf".content = ''
    server = 200.133.233.101
    port = 4433
    username = victor.ferreira
    domain = fai2008
    fingerprint = a9:db:84:93:e3:09:96:c7:33:6f:4d:05:ba:fa:1d:aa:59:0e:77:01
    password = ${config.sops.placeholder.fai_vpn_password}
  '';

  # UFSCar: GlobalProtect through openconnect, with the sops password on STDIN (so it does not
  # leak into ps). --authgroup picks the gateway (the portal offers 5); without it openconnect
  # asks interactively and the service dies (stdin is only the password, so EOF).
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
