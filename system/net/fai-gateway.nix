# ═══════════════════════════════════════════════════════════════════════════
# GATEWAY DA VPN FAI — deixa a LAN de casa alcançar a rede da FAI pelo ppp0.
#
# O PEDIDO ERA "pôr a VPN no roteador", e isso NÃO CABE. Medido no aparelho em
# 12/08/2026: o Cudy WR3000 tem 1,3 MB livres em /overlay (de 6,1 MB, 78% usado) e
# nenhum python3. O nxBender é Python + requests + pyroute2 + configargparse +
# colorlog — 15-25 MB no OpenWrt. Falta uma ORDEM DE GRANDEZA. É a mesma parede que
# ../../docs/ideias.md já registrou pro Jellyfin/Sunshine/Caddy, pelos mesmos números.
#
# Então o túnel fica AQUI e esta máquina vira o gateway da rede:
#
#   celular/notebook → roteador → 192.168.1.10 → ppp0 → FAI
#         (rota estática)          (este arquivo)
#
# ⚠️ A CONTRAPARTE NÃO É DECLARÁVEL, e sem ela isto aqui não faz NADA visível: o PC
# encaminha, mas ninguém manda tráfego pra cá. As rotas estáticas e o split-DNS vivem
# no UCI do OpenWrt, e ./router.nix recusa push de propósito — "uma linha errada de
# rede ou firewall tranca você fora e a saída é modo failsafe com acesso FÍSICO".
# Os comandos estão em ../../docs/guias/fai-gateway-roteador.md.
#
# E o circuito estava aberto DESTE lado, não do outro: as seis rotas `fai_r1..fai_r6`
# JÁ EXISTIAM no roteador (e commitadas em ../../router/uci/network.conf) apontando pra
# 192.168.1.10 — sem NAT nem forward aqui, o pacote chegava e morria. Rota que aponta
# pra um gateway que não encaminha não dá erro em lugar nenhum: só não funciona.
# MEDIDO em 12/08/2026, DEPOIS deste módulo, do PC do irmão (192.168.1.40): 3× HTTP 200
# em https://dashboard.sup.fai.ufscar.br. O "antes" não foi medido — é inferência, mas
# sólida: `grep -rn networking.nat` no repo dava ZERO até hoje.
#
# SEM TOGGLE em my.services, seguindo a regra que o próprio ../services/toggles.nix
# escreve ("VPN é sob-demanda (fora)"): as regras abaixo são inertes enquanto não
# existir ppp0, e quem liga/desliga o túnel é o CLI `vpn` de ./vpn.nix.
# ═══════════════════════════════════════════════════════════════════════════
{ config, ... }:

{
  # MASQUERADE É OBRIGATÓRIO, não otimização: a FAI não tem rota de volta pra
  # 192.168.1.0/24 — o pacote chega lá e não tem caminho de retorno. Com o NAT tudo
  # sai como o endereço do ppp0 (192.168.50.10 na sessão de 12/08), que é o único
  # que a FAI sabe responder.
  #
  # `internalIPs` e não `internalInterfaces`: a decisão é por ORIGEM, não por placa —
  # mesmo idioma da regra do WireGuard em ./network.nix ("a confiança precisa ser por
  # ORIGEM"), e reusa a SSOT de ./subnets.nix em vez de fixar a faixa aqui.
  #
  # ⚠️ NÃO declarar ip_forward junto: ligar o nat já põe
  # `net.ipv4.conf.all.forwarding = mkOverride 99 true` (nixpkgs nat.nix:200). Hoje o
  # forwarding já está em 1, mas por efeito colateral do Docker — e depender disso
  # seria config existindo por acidente, que some no dia em que o Docker sair.
  networking.nat = {
    enable = true;
    externalInterface = "ppp0";
    internalIPs = [ config.my.net.lanSubnet ];
  };

  networking.firewall = {
    # A FORWARD precisa de ACCEPT EXPLÍCITO porque o Docker põe a policy em DROP
    # sempre que gerencia iptables — e este host tem docker0 + duas bridges. O módulo
    # `nat` acima NÃO cobre isso: ele só pendura a chain `nixos-filter-forward`, que
    # existe pros port-forwards (nixpkgs nat-iptables.nix:184).
    #
    # `-I FORWARD 1` pelo mesmo motivo do `-I nixos-fw 1` de ./network.nix: o Docker
    # insere as regras dele no TOPO da cadeia, e um append cairia depois de tudo.
    #
    # A volta é por conntrack, NÃO um ACCEPT simétrico: a FAI iniciar conexão PRA
    # DENTRO de casa não é o caso de uso, e liberar isso daria à rede da FAI acesso à
    # LAN inteira. Só volta o que esta casa começou.
    extraCommands = ''
      iptables -I FORWARD 1 -s ${config.my.net.lanSubnet} -o ppp0 -j ACCEPT
      iptables -I FORWARD 1 -d ${config.my.net.lanSubnet} -i ppp0 -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT
    '';

    # Sem isto, `reload` do firewall empilha duplicatas (mesma lição do ./network.nix).
    extraStopCommands = ''
      iptables -D FORWARD -s ${config.my.net.lanSubnet} -o ppp0 -j ACCEPT 2>/dev/null || true
      iptables -D FORWARD -d ${config.my.net.lanSubnet} -i ppp0 -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT 2>/dev/null || true
    '';
  };
}
