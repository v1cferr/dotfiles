# NETWORK AND REMOTE ACCESS: NetworkManager, exposed SSH, fail2ban, dynamic DNS, no suspend.
# The WoL trap, the DDNS wildcard and why split-DNS lies to dig: docs/notes/network/network.md
{ config, ... }:

{
  # ── Network ────────────────────────────────────────────────────────────────
  networking.networkmanager.enable = true;

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
      PasswordAuthentication = true;
      KbdInteractiveAuthentication = false;

      # The ONLY name that can be tried, so `admin`, `support` and `ubnt` die before PAM.
      AllowUsers = [ "v1cferr" ];
      # 4 and not 3: the client spends one try per key the agent offers BEFORE the password.
      MaxAuthTries = 4;
      # Enough to type a passphrase on a phone, short for a bot that opens and sits (was 120s).
      LoginGraceTime = 45;
      # sshd refusing the source BY ITSELF, no fail2ban involved. The defaults are symbolic (5s);
      # `invaliduser` is the safe one to stretch, since a real login never uses a name that is gone.
      PerSourcePenalties = "authfail:30s invaliduser:10m grace-exceeded:2m max:1h min:20s";
      # The house and the tunnel are never penalised: a typo from inside cannot cost the way back.
      PerSourcePenaltyExemptList = "${config.my.net.lanSubnet},${config.my.net.vpnSubnet}";
    };
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
