# The FAI workstation: the host's SSOT (rule 11) plus `wake-workstation` (Wake-on-LAN).
# The IP/user were literals repeated in 3 consumers (ssh.nix, the rclone mount and this module);
# now they come from here. All the consumers are in home/, so the option lives in home/ (rule 11:
# it lives at the LOWEST level that needs it).
{
  config,
  lib,
  pkgs,
  ...
}:

let
  ws = config.my.fai.workstation;
  macHex = lib.toLower (lib.replaceStrings [ ":" "-" ] [ "" "" ] ws.mac);

  # A magic packet = 6x 0xFF plus 16x the MAC. Python (not nixpkgs' wakeonlan, which is Perl and
  # drags Perl-Critic/Perl-Tidy into the build), and it is the SAME code that runs on the relay,
  # where I cannot install anything. SO_BROADCAST is mandatory: without it the kernel refuses to
  # send to a broadcast address. Ports 9 and 7 because an old NIC sometimes only listens on 7.
  mkSender =
    targets:
    pkgs.writeText "wol-send.py" ''
      import socket
      pkt = bytes.fromhex("ff" * 6 + "${macHex}" * 16)
      s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
      s.setsockopt(socket.SOL_SOCKET, socket.SO_BROADCAST, 1)
      for t in [${lib.concatMapStringsSep ", " (t: "\"${t}\"") targets}]:
          for port in (9, 7):
              s.sendto(pkt, (t, port))
    '';

  # Local: unicast through the tunnel plus a directed broadcast to the /25.
  senderLocal = mkSender [
    ws.host
    ws.broadcast
  ];
  # The relay: it runs ON the fai-vm, which is on the same subnet, so a real L2 broadcast.
  senderRelay = mkSender [ "255.255.255.255" ];

  wakeCli = pkgs.writeShellApplication {
    name = "wake-workstation";
    runtimeInputs = with pkgs; [
      python3
      iputils
      openssh
      iproute2
    ];
    text = ''
      host='${ws.host}'

      up() { ping -c1 -W2 "$host" >/dev/null 2>&1; }

      if up; then echo "the workstation is already up ($host)"; exit 0; fi

      # With no tunnel there is no route to FAI, and failing here with the right cause avoids
      # chasing ghosts.
      if [ -z "$(ip -o link show type ppp)" ]; then
        echo "the FAI VPN is down, run 'vpn connect fai' first ($host only exists through the tunnel)." >&2
        exit 1
      fi

      echo "sending a magic packet to ${ws.mac}..."
      # 1) A RELAY through the fai-vm: the only path that wakes a machine that has been off FOR A
      #    WHILE, because it broadcasts on the L2 segment. The other two depend on a warm cache
      #    (ARP/CAM). The script goes through the remote python3's STDIN, so there is nothing to
      #    install on the other side.
      if ssh -o BatchMode=yes -o ConnectTimeout=8 fai-vm python3 - < ${senderRelay} 2>/dev/null; then
        echo "  ok: an L2 broadcast through the fai-vm"
      else
        echo "  the fai-vm is unavailable (host key not accepted? VM down?), only the weak paths left"
      fi
      # 2) unicast through the tunnel (it works while the router's ARP is warm) plus
      # 3) a directed broadcast to ${ws.broadcast} (a router usually drops it, RFC 2644)
      python3 ${senderLocal} && echo "  ok: unicast plus a directed broadcast through the tunnel"

      echo -n "waiting for the host to answer (up to 120s)"
      for _ in $(seq 1 40); do
        if up; then echo; echo "IT WOKE UP: $host is answering."; exit 0; fi
        echo -n "."; sleep 3
      done
      echo
      echo "it did not answer in 120s." >&2
      echo "If no boot happens at all, WoL is probably not armed on the workstation's" >&2
      echo "NIC, which needs root THERE (see this module's comment)." >&2
      exit 1
    '';
  };
in
{
  # ─────────────────────────────────────────────────────────────────────────
  # THE RECEIVING SIDE IS NOT DECLARABLE FROM HERE. The workstation is somebody else's
  # Ubuntu 26.04 (superintendencia-server), out of these dotfiles' reach, and sudo over
  # there asks for a password. To arm WoL, run ON THE WORKSTATION, once:
  #   sudo ethtool enp7s0 | grep -i wake   # "Supports Wake-on: ...g" means it can be used
  #   sudo ethtool -s enp7s0 wol g         # arms it now (it does NOT survive a reboot)
  # To persist it: that machine uses NETPLAN plus systemd-networkd (NOT NetworkManager, so no
  # nmcli). In /etc/netplan/00-installer-config.yaml, under `ethernets: enp7s0:`, add
  # `wakeonlan: true` and run `sudo netplan apply`.
  # It usually also requires "Wake on LAN/PCIe" TURNED ON in the BIOS/UEFI.
  # THE MEASURED STATE (jul/2026): /sys/class/net/enp7s0/device/power/wakeup = disabled, so
  # almost certainly NOT armed. There is no confirming it from here: ethtool's Wake-on fields
  # require root and without it the read gives "netlink error: Operation not permitted".
  # ─────────────────────────────────────────────────────────────────────────
  options.my.fai.workstation = {
    host = lib.mkOption {
      type = lib.types.str;
      default = "200.136.209.229";
      description = "The FAI workstation's IP (reachable only through the FAI VPN).";
    };
    user = lib.mkOption {
      type = lib.types.str;
      default = "v1cferr";
      description = "The login user on the workstation.";
    };
    mac = lib.mkOption {
      type = lib.types.str;
      default = "8c:86:dd:61:22:12";
      description = "The MAC of enp7s0 (the wired NIC that carries the IP), the Wake-on-LAN target.";
    };
    broadcast = lib.mkOption {
      type = lib.types.str;
      default = "200.136.209.255";
      description = "The broadcast of the workstation's /25, for the directed magic packet.";
    };
  };

  config.home.packages = [ wakeCli ];
}
