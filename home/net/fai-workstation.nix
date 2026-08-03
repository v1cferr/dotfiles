# Workstation da FAI: SSOT do host (regra 11) + `wake-workstation` (Wake-on-LAN).
# O IP/usuário eram literais repetidos em 3 consumidores (ssh.nix, o mount rclone e este
# módulo) — agora saem daqui. Todos os consumidores são do home/, então a opção é do home/
# (regra 11: mora no nível MAIS BAIXO que precisa dela).
{
  config,
  lib,
  pkgs,
  ...
}:

let
  ws = config.my.fai.workstation;
  macHex = lib.toLower (lib.replaceStrings [ ":" "-" ] [ "" "" ] ws.mac);

  # Magic packet = 6× 0xFF + 16× o MAC. Python (não o wakeonlan do nixpkgs, que é Perl e
  # arrasta Perl-Critic/Perl-Tidy pro build) — e é o MESMO código que roda no relay, onde
  # não posso instalar nada. SO_BROADCAST é obrigatório: sem ele o kernel recusa o envio
  # p/ endereço de broadcast. Portas 9 e 7 porque NIC velha às vezes só escuta a 7.
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

  # Local: unicast pelo túnel + broadcast dirigido da /25.
  senderLocal = mkSender [
    ws.host
    ws.broadcast
  ];
  # Relay: roda NA fai-vm, que está na mesma sub-rede → broadcast L2 de verdade.
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

      if up; then echo "workstation já está no ar ($host)"; exit 0; fi

      # Sem túnel não há rota p/ a FAI — falhar aqui com a causa certa evita caçar fantasma.
      if [ -z "$(ip -o link show type ppp)" ]; then
        echo "VPN FAI desligada — rode 'vpn connect fai' antes (o $host só existe pelo túnel)." >&2
        exit 1
      fi

      echo "enviando magic packet p/ ${ws.mac}…"
      # 1) RELAY pela fai-vm: o único caminho que acorda máquina desligada HÁ TEMPO, porque
      #    faz broadcast no segmento L2. Os outros dois dependem de cache (ARP/CAM) quente.
      #    O script vai pelo STDIN do python3 remoto — nada a instalar do outro lado.
      if ssh -o BatchMode=yes -o ConnectTimeout=8 fai-vm python3 - < ${senderRelay} 2>/dev/null; then
        echo "  ✓ broadcast L2 via fai-vm"
      else
        echo "  ✗ fai-vm indisponível (host key não aceita? VM fora?) — só os caminhos fracos"
      fi
      # 2) unicast pelo túnel (vale enquanto o ARP do roteador estiver quente) +
      # 3) broadcast dirigido p/ ${ws.broadcast} (roteador costuma descartar, RFC 2644)
      python3 ${senderLocal} && echo "  ✓ unicast + broadcast dirigido pelo túnel"

      echo -n "aguardando o host responder (até 120s)"
      for _ in $(seq 1 40); do
        if up; then echo; echo "ACORDOU: $host respondendo."; exit 0; fi
        echo -n "."; sleep 3
      done
      echo
      echo "não respondeu em 120s." >&2
      echo "Se nenhum boot acontece, o WoL provavelmente não está armado na NIC da" >&2
      echo "workstation — precisa de root LÁ (ver comentário deste módulo)." >&2
      exit 1
    '';
  };
in
{
  # ─────────────────────────────────────────────────────────────────────────
  # LADO RECEPTOR — NÃO É DECLARÁVEL DAQUI. A workstation é uma Ubuntu 26.04 de
  # terceiro (superintendencia-server), fora do alcance destes dotfiles, e o sudo
  # de lá pede senha. Para armar o WoL, rodar NA WORKSTATION, uma vez:
  #   sudo ethtool enp7s0 | grep -i wake   # "Supports Wake-on: ...g" = dá p/ usar
  #   sudo ethtool -s enp7s0 wol g         # arma agora (NÃO sobrevive a reboot)
  # Persistir: ela usa NETPLAN + systemd-networkd (NÃO NetworkManager, então nada de
  # nmcli) — em /etc/netplan/00-installer-config.yaml, sob `ethernets: enp7s0:`,
  # acrescentar `wakeonlan: true` e rodar `sudo netplan apply`.
  # Costuma exigir também "Wake on LAN/PCIe" LIGADO na BIOS/UEFI.
  # ESTADO MEDIDO (jul/2026): /sys/class/net/enp7s0/device/power/wakeup = disabled →
  # quase certamente NÃO armado. Não dá p/ confirmar daqui: os campos Wake-on do ethtool
  # exigem root e sem ele a leitura dá "netlink error: Operation not permitted".
  # ─────────────────────────────────────────────────────────────────────────
  options.my.fai.workstation = {
    host = lib.mkOption {
      type = lib.types.str;
      default = "200.136.209.229";
      description = "IP da workstation da FAI (alcançável só pela VPN FAI).";
    };
    user = lib.mkOption {
      type = lib.types.str;
      default = "v1cferr";
      description = "Usuário de login na workstation.";
    };
    mac = lib.mkOption {
      type = lib.types.str;
      default = "8c:86:dd:61:22:12";
      description = "MAC da enp7s0 (a NIC cabeada que carrega o IP) — alvo do Wake-on-LAN.";
    };
    broadcast = lib.mkOption {
      type = lib.types.str;
      default = "200.136.209.255";
      description = "Broadcast da /25 da workstation, p/ o magic packet dirigido.";
    };
  };

  config.home.packages = [ wakeCli ];
}
