# ROUTER LOG: the OpenWrt's syslog, received here and kept 30 days, so its record survives a reboot
# and its DNS queries become evidence. Accepts the ROUTER only: docs/notes/network/router-log.md
{ config, ... }:

let
  router = config.my.router.address; # SSOT: hosts/cudy-wr3000/default.nix
  port = 5514; # unprivileged and not 514, so nothing else on the LAN mistakes it for a public sink
  dir = "/var/log/router";
in
{
  services.rsyslogd = {
    enable = true;
    # No local rules: this machine's own logs stay in the journal, rsyslog only takes the router's.
    defaultConfig = "";
    # Two locks on the door: the firewall below admits the router's address only, and the ruleset
    # drops anything whose source is not that address, so a forged line needs both to slip.
    extraConfig = ''
      module(load="imudp")
      input(type="imudp" port="${toString port}" ruleset="router")
      ruleset(name="router") {
        if $fromhost-ip == "${router}" then {
          action(type="omfile" file="${dir}/router.log" fileCreateMode="0640" fileGroup="wheel")
        }
        stop
      }
    '';
  };

  systemd.tmpfiles.rules = [ "d ${dir} 0750 root wheel - -" ];

  # 30 days, the retention the owner chose: the DNS log is everyone's browsing, so it does not linger.
  services.logrotate.settings.router-log = {
    files = "${dir}/router.log";
    frequency = "daily";
    rotate = 30;
    compress = true;
    delaycompress = true;
    missingok = true;
    notifempty = true;
    postrotate = "systemctl kill -s HUP syslog.service # NixOS names the rsyslog unit syslog.service";
  };

  # The port is open to the ROUTER only, the same idiom as localsend.nix.
  networking.firewall = {
    extraCommands = ''
      iptables -I nixos-fw 1 -s ${router} -p udp --dport ${toString port} -j nixos-fw-accept
    '';
    extraStopCommands = ''
      iptables -D nixos-fw -s ${router} -p udp --dport ${toString port} -j nixos-fw-accept 2>/dev/null || true
    '';
  };
}
