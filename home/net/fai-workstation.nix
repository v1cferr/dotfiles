# The FAI workstation: the host's SSOT (rule 11, at the lowest level that needs it) plus
# `wake-workstation`. Why 3 WoL paths and why python: docs/notes/network/fai-workstation.md
{
  config,
  lib,
  pkgs,
  ...
}:

let
  # Every package this module reaches for, named ONCE and up front: an entry that stops being
  # used fails the build under deadnix, so the list cannot rot into a lie (rule 16).
  inherit (pkgs)
    iproute2
    iputils
    openssh
    python3
    writeShellApplication
    writeText
    ;

  ws = config.my.fai.workstation;
  macHex = lib.toLower (lib.replaceStrings [ ":" "-" ] [ "" "" ] ws.mac);

  # A magic packet, in python because nixpkgs' wakeonlan is Perl and it is also the code that
  # runs on the relay. SO_BROADCAST is mandatory; ports 9 and 7, since an old NIC may want 7.
  mkSender =
    targets:
    writeText "wol-send.py" ''
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
  # The relay runs ON the fai-vm, on the same subnet, so it is a real L2 broadcast.
  senderRelay = mkSender [ "255.255.255.255" ];

  wakeCli = writeShellApplication {
    name = "wake-workstation";
    runtimeInputs = [
      python3
      iputils
      openssh
      iproute2
    ];
    text = ''
      host='${ws.host}'

      up() { ping -c1 -W2 "$host" >/dev/null 2>&1; }

      if up; then echo "the workstation is already up ($host)"; exit 0; fi

      # With no tunnel there is no route to FAI, and failing here with the right cause avoids ghosts.
      if [ -z "$(ip -o link show type ppp)" ]; then
        echo "the FAI VPN is down, run 'vpn connect fai' first ($host only exists through the tunnel)." >&2
        exit 1
      fi

      echo "sending a magic packet to ${ws.mac}..."
      # 1) The RELAY is the only path that wakes a machine off FOR A WHILE (a real L2 broadcast); the
      #    other two need a warm ARP/CAM cache. The script goes in through the remote python's stdin.
      if ssh -o BatchMode=yes -o ConnectTimeout=8 fai-vm python3 - < ${senderRelay} 2>/dev/null; then
        echo "  ok: an L2 broadcast through the fai-vm"
      else
        echo "  the fai-vm is unavailable (host key not accepted? VM down?), only the weak paths left"
      fi
      # 2) unicast (warm ARP) and 3) a directed broadcast, which a router usually drops (RFC 2644)
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
  # THE RECEIVING SIDE IS NOT DECLARABLE FROM HERE (somebody else's Ubuntu). Arming WoL there is a
  # manual netplan step, and it is measured as NOT armed: docs/notes/network/fai-workstation.md
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
