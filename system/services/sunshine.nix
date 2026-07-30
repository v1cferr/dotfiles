# Sunshine — servidor de streaming de tela/desktop remoto (cliente = Moonlight). É
# a forma recomendada de acesso remoto no Hyprland/Wayland: captura via wlr-screencopy
# (o `wlr`, auto-selecionado) e encoda na GPU. O Arc B580 tem encoder AV1/HEVC (VA-API)
# → stream fluido e de baixa latência. Chega-se no Sunshine PELA tailnet (Tailscale),
# não pela LAN/internet (openFirewall=false → só a interface tailscale0, que é trusted).
#
# APRENDIZADO (jul/2026, debug longo): "tela preta no Moonlight" era o wlr capturando o
# monitor DPMS-OFF (apagado) — NÃO regressão de versão nem encoder. Captura funciona
# desde que o monitor esteja LIGADO durante o stream (por isso o guard streamBegin). O
# `capture=kms` seria uma alternativa, mas o kmsgrab NÃO enumera no driver `xe`. CUIDADO:
# alternar dpms COM a captura+encode ativos deu engine-reset da GPU (xe RCS) — por isso o
# guard acorda a tela ANTES do stream (no prep-cmd), nunca no meio.
#
# Setup interativo (1x, do navegador de qualquer máquina na tailnet):
#   https://<ip-tailnet>:47990  → cria usuário/senha admin → pareia o Moonlight (PIN).
# O estado (clientes pareados) mora em ~/.config/sunshine (não declarável → é ESTADO).
#
# GUARD DE IDLE (conflito com o hypridle): a captura é do monitor FÍSICO via wlr, que
# funciona DESDE QUE o monitor esteja ligado. O idle NÃO desliga mais a tela (dpms-off
# removido — bugava isto aqui: tela preta + engine-reset da GPU no xe; ver
# home/desktop/lockscreen.nix). Sobra só o LOCK aos 5min — que, no meio de um stream,
# trancaria a sessão remota. Então o guard só PAUSA o hypridle enquanto o stream roda
# (global_prep_cmd do/undo) e RELIGA ao desconectar. Nada de dpms/settle: o monitor já
# está sempre aceso.
{ pkgs, lib, config, ... }:

let
  # Início do stream: para o hypridle p/ a sessão remota não TRANCAR no meio por idle.
  # `|| true`: um prep-cmd que falha cancelaria o stream no Sunshine.
  streamBegin = pkgs.writeShellScript "sunshine-stream-begin" ''
    ${pkgs.systemd}/bin/systemctl --user stop hypridle.service || true
  '';
  # Fim do stream: religa o hypridle → volta a trancar aos 5min de ociosidade.
  streamEnd = pkgs.writeShellScript "sunshine-stream-end" ''
    ${pkgs.systemd}/bin/systemctl --user start hypridle.service || true
  '';

  # sunshine-health: handshake TLS de verdade na 47984. `-brief` imprime "Protocol
  # version:" só quando o handshake COMPLETA — é o sinal; TCP aceito não basta, foi
  # exatamente o estado pendurado de 29/07. Probe em 127.0.0.1: não depende da tailnet.
  #
  # SEM PIPE de propósito: o writeShellApplication liga `set -o pipefail`, e com
  # `| grep -q` o grep sai no 1º match → o openssl morre de SIGPIPE → o pipeline
  # retorna ERRO mesmo tendo dado match. Isso invertia o resultado: handshake OK era
  # lido como falha, e o timer reiniciaria o Sunshine a cada 2 min p/ sempre. Captura
  # em variável + `case` evita o pipe inteiro.
  sunshineHealth = pkgs.writeShellApplication {
    name = "sunshine-health";
    runtimeInputs = with pkgs; [ openssl systemd coreutils ];
    text = ''
      for attempt in 1 2 3; do
        out="$(timeout 8 openssl s_client -connect 127.0.0.1:47984 -brief </dev/null 2>&1 || true)"
        case "$out" in
          *"Protocol version:"*) exit 0 ;;
        esac
        echo "<4>handshake TLS na 47984 falhou (tentativa $attempt/3)" # <4>=warning
        [ "$attempt" = 3 ] || sleep 5
      done
      echo "<3>handler HTTPS pendurado — reiniciando o sunshine.service" >&2 # <3>=err
      systemctl --user restart sunshine.service
    '';
  };
in
{
  services.sunshine = {
    enable = config.my.services.sunshine;
    # SEM capSysAdmin: a captura é wlr (wlr-screencopy), que NÃO precisa de CAP_SYS_ADMIN
    # — só o KMS-grab precisaria, e o KMS nem funciona no driver xe. Menos privilégio.
    autoStart = true; # sobe junto da sessão gráfica (serviço --user, WantedBy graphical-session)
    openFirewall = false; # NÃO abre na LAN/internet; acesso só pela tailnet (tailscale0 trusted)
    settings = {
      sunshine_name = "nixos-sandisk"; # nome que aparece no Moonlight
      # FORÇA o backend wlr (wlr-screencopy). Sem isto, o Sunshine PROBA o backend
      # `portalgrab` (portal ScreenCast/RemoteDesktop) no startup — e no Hyprland esse
      # probe dispara o `hyprland-share-picker`, que não renderiza (falta plugin Qt) e
      # PENDURA o Sunshine → nunca abre as portas (não conectava o Moonlight pós-VPN/boot).
      # wlr é o backend correto p/ wlroots; forçá-lo pula o probe do portal. (Vídeo=wlr,
      # input=uinput via ACL uaccess do /dev/uinput — ambos sem portal.)
      capture = "wlr";
      # NÃO forçar capture=kms: o kmsgrab NÃO enumera no driver `xe` (Battlemage) →
      # "Unable to find display" e o serviço nem streama. Deixa auto = `wlr` (funciona
      # DESDE QUE o monitor esteja ligado — ver o guard streamBegin abaixo).
      # Acesso vem pela tailnet (IP 100.x, que o Sunshine classifica como WAN) →
      # "wan" p/ não bloquear o web UI. NÃO é exposição real: o firewall só deixa a
      # tailscale0 (trusted) chegar aqui; LAN/internet continuam fechadas.
      origin_web_ui_allowed = "wan";
      # CSRF: libera as origens da tailnet (IP + nome MagicDNS). Sem isto, criar o
      # usuário/salvar pelo web UI é bloqueado quando o host != localhost.
      csrf_allowed_origins = "https://100.92.126.90:47990,https://nixos-sandisk.tailf2731d.ts.net:47990";
      # OBRIGATÓRIO porque o acesso é pela tailnet: a tailscale0 tem MTU 1280 e o default
      # do Sunshine é 1392 → todo pacote de vídeo estoura o túnel. WireGuard descarta em
      # SILÊNCIO (sem ICMP, sem log): o host streama normal, o cliente recebe pela metade,
      # não remonta frame e desconecta em ~4 s — foi o que aconteceu em 29/07. 1024 cabe
      # com folga em 1280 depois de IP+UDP+cabeçalhos do Moonlight.
      packet_size = 1024;
      # Guard de idle: do/undo acordam a tela + pausam o hypridle durante o stream (ver
      # header). JSON no sunshine.conf; vale p/ TODOS os apps (inclui o "Desktop" remoto).
      global_prep_cmd = builtins.toJSON [
        { do = "${streamBegin}"; undo = "${streamEnd}"; }
      ];
    };
  };

  # ── Healthcheck do handler HTTPS ────────────────────────────────────────────
  # Em 29/07 o Sunshine ficou com a 47984 (HTTPS) aceitando TCP e NUNCA completando o
  # handshake TLS — 22 conexões empilhadas em CLOSE-WAIT — enquanto a 47989 (HTTP)
  # respondia 200 normalmente. O Moonlight usa a HTTPS em host já pareado, então ele
  # mostrava "offline". O pior: o serviço ficava `active`, ExecMainStatus=0 e SEM UMA
  # LINHA de log. Não havia como perceber; só `systemctl restart` resolveu.
  #
  # Daí o probe ativo: o único jeito de detectar é TENTAR o handshake. 3 tentativas em
  # ~10 s antes de reiniciar, p/ não confundir hang com o startup do serviço. Reinicia
  # mesmo se houver stream ativo — host com HTTPS pendurado já está inútil.
  systemd.user.services.sunshine-healthcheck = lib.mkIf config.my.services.sunshine {
    description = "Reinicia o Sunshine se o handler HTTPS (47984) estiver pendurado";
    serviceConfig = {
      Type = "oneshot";
      ExecStart = "${sunshineHealth}/bin/sunshine-health";
      # Timer de 2min → o systemd logaria "Starting…/Finished…" sempre (440 linhas/dia
      # medidas). `warning` corta o info; as falhas do probe saem com prefixo <4>/<3> e
      # continuam visíveis, que é o que importa investigar.
      LogLevelMax = "warning";
    };
  };

  systemd.user.timers.sunshine-healthcheck = lib.mkIf config.my.services.sunshine {
    description = "Probe periódico do handler HTTPS do Sunshine";
    timerConfig = {
      OnActiveSec = "2min"; # dá tempo do serviço subir antes do 1º probe
      OnUnitActiveSec = "2min";
    };
    partOf = [ "graphical-session.target" ]; # sem sessão não há Sunshine p/ checar
    wantedBy = [ "graphical-session.target" ];
  };
}
