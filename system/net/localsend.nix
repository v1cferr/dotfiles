# ═══════════════════════════════════════════════════════════════════════════
# LOCALSEND — "AirDrop" de código aberto: arquivo direto entre celular e PC pela
# LAN, sem nuvem, sem conta e sem intermediário (cifra TLS ponta-a-ponta com
# certificado auto-assinado gerado em cada aparelho).
#
# POR QUE MORA NO system/ E NÃO NO home/ (regra 4): quem une PACOTE + PORTA de
# firewall é o módulo do nixpkgs (`programs.localsend`), e firewall é
# nível-sistema. É o mesmo caso do `programs.steam` (system/gaming/steam.nix) —
# o módulo upstream não é opcional, então o pacote vem com ele. O pacote NÃO se
# repete no home/packages.nix: quem precisa do binário lê
# `osConfig.programs.localsend.package` (é o que o home/desktop/autostart.nix faz).
#
# A 53317 é usada nos DOIS protocolos, e as duas são obrigatórias: TCP é a
# transferência e o `/api/localsend/v2/info`; UDP é o anúncio multicast em
# 224.0.0.167 que faz os aparelhos se DESCOBRIREM. Sem a UDP o app funciona, mas
# só por "adicionar por IP" na mão.
#
# ⚠️ `openFirewall = false` CONTRA o default do módulo, e o motivo NÃO é a
# internet: o roteador encaminha 80/443/2222 e as portas do Moonlight (47984,
# 47989, 48010/tcp + 47998-48000/udp, estas restritas à UFSCar desde 10/08/2026),
# e a 53317 não está em nenhuma dessas listas — o mundo nunca a alcançou.
# Quem alcançaria é a VPN — `openFirewall` abre a porta em TODA interface,
# e com o túnel da FAI de pé (`ppp0`) a rede corporativa inteira passaria a ver o
# serviço e a ler o `/info` (nome do dispositivo, modelo, fingerprint) sem
# autenticação nenhuma. A confiança aqui é por ORIGEM, igual à regra do Sunshine
# em ./network.nix: só a LAN de casa, lida da SSOT (regra 11).
#
# Os peers do WireGuard entram DE GRAÇA e não precisam de regra própria: eles
# chegam com origem 10.10.10.x e a regra de ./network.nix já aceita a faixa
# inteira antes de qualquer outra decisão.
#
# ⚠️ A porta é REPETIDA aqui porque o módulo não a expõe como opção (é um
# `firewallPort = 53317` interno ao arquivo dele). Se você trocar a porta DENTRO
# do app (Configurações → Rede), esta regra deixa de casar e a RECEPÇÃO MORRE EM
# SILÊNCIO — sem erro de build, sem log, só "o celular não me acha".
#
# Só IPv4, como todas as regras deste repo: a descoberta do LocalSend é multicast
# IPv4 e a LAN de casa não tem IPv6 roteado.
#
# Configurações do app (apelido, pasta de destino, salvar sem confirmar) e os
# arquivos recebidos são ESTADO (regra 6): o app reescreve o próprio
# `shared_preferences` em runtime, então o Nix não é dono dele (regra 14).
# ═══════════════════════════════════════════════════════════════════════════
{ config, ... }:

let
  # Porta única do protocolo — vale pro TCP e pro UDP, e aparece em 4 regras abaixo.
  port = 53317;
in
{
  programs.localsend = {
    enable = true;
    openFirewall = false; # ver header: a porta é aberta SÓ pra LAN, na regra abaixo
  };

  # `-I nixos-fw 1` e não `-A`, e o motivo MEDIDO no firewall-start gerado (26.05) é
  # mais estreito do que diz o vizinho em ./network.nix: o `extraCommands` é injetado
  # ANTES do `-A nixos-fw -j nixos-fw-log-refuse`, então hoje `-A` também seria
  # alcançado. O que de fato cai no vazio é a mesma regra digitada À MÃO num firewall
  # já de pé — aí sim a cadeia termina no refuse. `-I 1` é o que vale nos dois casos e
  # não depende de onde o upstream decide injetar o extraCommands amanhã.
  networking.firewall = {
    extraCommands = ''
      iptables -I nixos-fw 1 -s ${config.my.net.lanSubnet} -p tcp --dport ${toString port} -j nixos-fw-accept
      iptables -I nixos-fw 1 -s ${config.my.net.lanSubnet} -p udp --dport ${toString port} -j nixos-fw-accept
    '';
    # Sem isto, `reload` do firewall empilha duplicatas das regras acima.
    extraStopCommands = ''
      iptables -D nixos-fw -s ${config.my.net.lanSubnet} -p tcp --dport ${toString port} -j nixos-fw-accept 2>/dev/null || true
      iptables -D nixos-fw -s ${config.my.net.lanSubnet} -p udp --dport ${toString port} -j nixos-fw-accept 2>/dev/null || true
    '';
  };
}
