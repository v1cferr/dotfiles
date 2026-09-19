# NETWORK AND REMOTE ACCESS: NetworkManager, exposed SSH, fail2ban, dynamic DNS, no suspend.
# The WoL trap, the DDNS wildcard and why split-DNS lies to dig: docs/notes/network/network.md
{ config, pkgs, ... }:

let
  # Rule 19: what this module reaches for, named once. `pam` is here for pam_exec.so, the only
  # hook sshd offers for "a session just opened".
  inherit (pkgs)
    grepcidr
    notify
    pam
    systemd
    util-linux
    writeShellApplication
    ;

  # The ONLY detection on this machine: everything else in this file is prevention.
  # Why pam_exec and not a journal tail, and why systemd-run: docs/notes/network/network.md
  sshLoginAlert = writeShellApplication {
    name = "ssh-login-alert";
    runtimeInputs = [
      grepcidr
      systemd
      util-linux # logger, for the case where the push itself cannot be queued
    ];
    text = ''
      # pam_exec fires on every phase; only an OPENING session is a login.
      [ "''${PAM_TYPE:-}" = "open_session" ] || exit 0

      rhost="''${PAM_RHOST:-}"
      [ -n "$rhost" ] || exit 0 # no remote host at all is the local console

      # The house is the ONLY silence: it is the one place where a login is not news.
      if printf '%s\n' "$rhost" | grepcidr '${config.my.net.lanSubnet}' >/dev/null 2>&1; then
        exit 0
      fi

      # The tunnel is REPORTED and labelled, not skipped. Skipping it left the detection blind to
      # the path actually used, and to anyone who got hold of a WireGuard key.
      if printf '%s\n' "$rhost" | grepcidr '${config.my.net.vpnSubnet}' >/dev/null 2>&1; then
        origin="through the tunnel"
        priority=default
      else
        origin="from outside"
        priority=high
      fi

      # --no-block so a login NEVER waits on ntfy, and the transient unit owns it (rule 15).
      # The failure goes to the journal: a detector that cannot report its own silence is the
      # defect this hook exists to avoid.
      systemd-run --quiet --collect --no-block \
        ${notify}/bin/notify -p "$priority" -T warning \
        "SSH $origin" "''${PAM_USER:-?} from $rhost" \
        || logger -t ssh-login-alert -p auth.warning \
             "could not queue the alert for $rhost; the push did NOT go out"

      exit 0 # `optional` already covers this, but a hook that can cost a login is not worth having
    '';
  };
in
{
  # ── Network ────────────────────────────────────────────────────────────────
  networking.networkmanager.enable = true;

  # cubic reads the ~0.4% loss of the FAI tunnel's path as congestion and pins the window shut.
  # Measured 19/09/2026 in one window: +7% down, +10% up, retransmission 0.38% to 0.10%.
  boot.kernelModules = [ "tcp_bbr" ];
  boot.kernel.sysctl = {
    "net.ipv4.tcp_congestion_control" = "bbr";
    "net.core.default_qdisc" = "fq"; # BBR paces its packets; fq is what executes the pacing
  };

  # The WireGuard server is the ROUTER, so there is no local wg0: trust goes by SOURCE.
  # It is what keeps Sunshine reachable through the tunnel with openFirewall = false.
  networking.firewall = {
    extraCommands = ''
      iptables -I nixos-fw 1 -s ${config.my.net.vpnSubnet} -j nixos-fw-accept
    '';
    # Without this, a firewall `reload` stacks duplicates of the rule above.
    extraStopCommands = ''
      iptables -D nixos-fw -s ${config.my.net.vpnSubnet} -j nixos-fw-accept 2>/dev/null || true
    '';
  };

  # ── SSH (mirrors Arch: port 2222, root off, password as a fallback) ────────
  # The password STAYS: one command from any borrowed machine is the feature. What defends it
  # instead, and the three hardenings deliberately left out: docs/notes/network/network.md
  services.openssh = {
    enable = true;
    ports = [ 2222 ];
    openFirewall = true; # opens 2222 in the firewall
    settings = {
      PermitRootLogin = "no";
      # STAYS true even though the password now travels inside PAM: the module derives
      # `security.pam.services.sshd.unixAuth` from this flag, and turning it off would silently drop
      # `pam_unix`, leaving the six digits ALONE as the whole authentication. What gates the door is
      # `AuthenticationMethods` below, not this.
      PasswordAuthentication = true;
      # The channel PAM needs to ask two things (password, then code) in one authentication.
      KbdInteractiveAuthentication = true;
      # A key by ITSELF, or password plus TOTP. Publickey never runs the PAM auth stack, so it is
      # also the way back in the day the code stops working.
      AuthenticationMethods = "publickey keyboard-interactive:pam";

      # The ONLY name that can be tried, so `admin`, `support` and `ubnt` die before PAM.
      AllowUsers = [ "v1cferr" ];
      # 4 and not 3: the client spends one try per key the agent offers BEFORE the password.
      MaxAuthTries = 4;
      # BACK to the default, and 45 was the mistake: it fits one prompt, not the two that the TOTP
      # asks for. Measured 06/09/2026, four connections from the phone died in
      # `Timeout before authentication` while typing the password and then the code.
      LoginGraceTime = 120;
      # sshd refusing the source BY ITSELF, no fail2ban involved. The defaults are symbolic (5s);
      # `invaliduser` is the safe one to stretch, since a real login never uses a name that is gone.
      PerSourcePenalties = "authfail:30s invaliduser:10m grace-exceeded:2m max:1h min:20s";
      # The house and the tunnel are never penalised: a typo from inside cannot cost the way back.
      PerSourcePenaltyExemptList = "${config.my.net.lanSubnet},${config.my.net.vpnSubnet}";
    };
  };

  # The SECOND FACTOR of the exposed port, `required` and with no `nullok`: whoever has no
  # `~/.google_authenticator` does not log in by password at all. That file is STATE, created once
  # per user by hand (the command and the remote-safe order: docs/notes/network/network.md).
  security.pam.services.sshd.googleAuthenticator.enable = true;

  # The hook needs a path with NO store context: a `settings` key is an attribute NAME, and those
  # cannot refer to the store. This is that stable path, and pam_exec follows the symlink fine.
  environment.etc."pam-exec/ssh-login-alert".source = "${sshLoginAlert}/bin/ssh-login-alert";

  # The alert for any login that is not from the house, `optional` so it can never cost one. The
  # program is a `settings` KEY: the rule DERIVES `args` from settings and defining `args` clashes.
  security.pam.services.sshd.rules.session.ssh-login-alert = {
    order = 13000; # last in the stack: after pam_systemd (12000) and pam_limits (12200)
    control = "optional";
    modulePath = "${pam}/lib/security/pam_exec.so";
    settings."/etc/pam-exec/ssh-login-alert" = true;
  };

  # NEVER SUSPEND: this is a remote-access desktop, and a suspend drops SSH with no way back in.
  systemd.targets.sleep.enable = false;
  systemd.targets.suspend.enable = false;
  systemd.targets.hibernate.enable = false;
  systemd.targets.hybrid-sleep.enable = false;

  # Wake-on-LAN, DECLARATIVE because the r8169 resets it on every boot. It does not survive a
  # power outage (the NIC loses +5VSB); that one is a BIOS setting.
  networking.interfaces.enp7s0.wakeOnLan.enable = true;

  # fail2ban is mandatory: 2222 is open to the world WITH passwords enabled.
  services.fail2ban = {
    enable = true;
    bantime = "1h";
    # The same address comes back after the hour, so each new ban DOUBLES it: 1h, 2h, 4h, up to a
    # week. Measured: one single address ate 26 bans in 30 days under the flat 1h.
    bantime-increment = {
      enable = true;
      maxtime = "168h";
    };
    # The ban count lives in the sqlite, and fail2ban's own default forgets it in 1d, which would
    # cap the escalation above at its second step. It has to outlive `maxtime`.
    daemonSettings.Definition.dbpurgeage = "30d";
    # This is fail2ban's [DEFAULT], so ALL jails inherit it. Loopback is deliberately ABSENT: the
    # module already prepends it, and declaring it again came out duplicated in jail.local.
    ignoreIP = [
      config.my.net.lanSubnet
      # The WireGuard range goes in with it: coming in from outside through the VPN and
      # mistyping the SSH password cannot ban your own way back.
      config.my.net.vpnSubnet
    ];
    jails.sshd.settings = {
      enabled = true;
      port = 2222;
      backend = "systemd"; # sshd logs to journald
      maxretry = 4;
      findtime = "10m";
    };
  };
}
