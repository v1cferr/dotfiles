# The t480s's WireGuard tunnel to the house router, up from boot and carrying ALL traffic, so a
# public Wi-Fi only ever sees encrypted UDP: docs/decisions/0018-a-shared-laptop.md
{
  config,
  lib,
  pkgs,
  ...
}:

let
  inherit (pkgs) writeShellApplication wireguard-tools;

  iface = "wg0";
  unit = "wg-quick-${iface}";
  # The router's wg0, public by definition (`sudo -n wg-status` on the router, 15/11/2026).
  routerKey = "umZC8s1j9Y7RcSF8UgeBFuQpSDrbc4zzPNqvAcqHKDA=";

  # A tunnel with no handshake for 3 minutes is DEAD (a new DDNS address, a network that changed
  # under it), and only a restart resolves the endpoint again. A stopped tunnel is left alone.
  watchdog = writeShellApplication {
    name = "wg-watchdog";
    runtimeInputs = [ wireguard-tools ];
    text = ''
      systemctl is-active --quiet ${unit} || exit 0
      last="$(wg show ${iface} latest-handshakes | awk '{print $2}')"
      if [ "$(( $(date +%s) - ''${last:-0} ))" -gt 180 ]; then
        echo "no handshake for over 3 min, restarting ${unit}"
        systemctl restart ${unit}
      fi
    '';
  };

  # `vpn off` before a captive portal (a hotel or airport login page), `vpn on` after it.
  vpnCli = writeShellApplication {
    name = "vpn";
    runtimeInputs = [ wireguard-tools ];
    text = ''
      case "''${1:-status}" in
        on) sudo systemctl start ${unit} ;;
        off) sudo systemctl stop ${unit}; echo "VPN OFF: traffic now goes out unprotected. 'vpn on' to restore." ;;
        status) systemctl is-active ${unit} && sudo wg show ${iface} | grep -E "endpoint|handshake|transfer" ;;
        *) echo "usage: vpn [on|off|status]" >&2; exit 2 ;;
      esac
    '';
  };
in
{
  networking.wg-quick.interfaces.${iface} = {
    address = [ "10.10.10.7/32" ]; # its own slot in my.net.vpnSubnet; the router lists it as `t480s`
    # The key is made HERE on first start and never leaves the machine (rule 12): only its public
    # half goes to the router. A reinstall makes a new one, and the router's peer must follow.
    privateKeyFile = "/var/lib/wireguard/${iface}.key";
    generatePrivateKeyFile = true;
    dns = [ "10.10.10.1" ]; # the router: split DNS and the ad block, through the tunnel
    peers = [
      {
        publicKey = routerKey;
        endpoint = "vpn.${config.my.net.domain}:51820";
        # EVERYTHING through the tunnel. ::/0 too, so IPv6 cannot leak around it; the router has no
        # IPv6 inside the tunnel, so it dies there and apps fall back to IPv4.
        allowedIPs = [
          "0.0.0.0/0"
          "::/0"
        ];
        persistentKeepalive = 25; # keeps the NAT of a public network from forgetting the tunnel
      }
    ];
  };

  # At boot the Wi-Fi may come up after network-online, and the endpoint then fails to resolve:
  # retry instead of giving up, for as long as it takes.
  systemd.services.${unit} = {
    serviceConfig = {
      Restart = "on-failure";
      RestartSec = 15;
    };
    unitConfig.StartLimitIntervalSec = 0;
  };

  systemd.services.wg-watchdog = {
    description = "Restarts the WireGuard tunnel when it has stopped handshaking";
    serviceConfig = {
      Type = "oneshot";
      ExecStart = lib.getExe watchdog;
    };
  };
  systemd.timers.wg-watchdog = {
    wantedBy = [ "timers.target" ];
    timerConfig.OnUnitActiveSec = "1min";
    timerConfig.OnBootSec = "2min";
  };

  environment.systemPackages = [
    vpnCli
    wireguard-tools
  ];
}
