# Sunshine — servidor de streaming de tela/desktop remoto (cliente = Moonlight). É
# a forma recomendada de acesso remoto no Hyprland/Wayland: captura via wlr-screencopy
# (o `wlr`, auto-selecionado) e encoda na GPU. O Arc B580 tem encoder AV1/HEVC (VA-API)
# → stream fluido e de baixa latência. Chega-se no Sunshine PELO WIREGUARD do roteador,
# não pela LAN nem pela internet: `openFirewall = false` mantém as portas fechadas, e
# quem abre é a regra de origem 10.10.10.0/24 em ../net/network.nix. Era Tailscale até
# 08/08/2026 — a troca está registrada em docs/historico/2026/08-agosto.md.
#
# APRENDIZADO (jul/2026, debug longo): "tela preta no Moonlight" era o wlr capturando o
# monitor DPMS-OFF (apagado) — NÃO regressão de versão nem encoder. Captura funciona
# desde que o monitor esteja LIGADO durante o stream (por isso o guard streamBegin). O
# `capture=kms` seria uma alternativa, mas o kmsgrab NÃO enumera no driver `xe`. CUIDADO:
# alternar dpms COM a captura+encode ativos deu engine-reset da GPU (xe RCS) — por isso o
# guard acorda a tela ANTES do stream (no prep-cmd), nunca no meio.
#
# Setup interativo (1x, do navegador de qualquer peer do WireGuard):
#   https://192.168.1.10:47990  → cria usuário/senha admin → pareia o Moonlight (PIN).
# O estado (clientes pareados) mora em ~/.config/sunshine (não declarável → é ESTADO).
#
# GUARD DE IDLE (conflito com o hypridle): a captura é do monitor FÍSICO via wlr, que
# funciona DESDE QUE o monitor esteja ligado. O idle NÃO desliga mais a tela (dpms-off
# removido — bugava isto aqui: tela preta + engine-reset da GPU no xe; ver
# home/desktop/lockscreen.nix). Sobra só o LOCK aos 5min — que, no meio de um stream,
# trancaria a sessão remota. Então o guard só PAUSA o hypridle enquanto o stream roda
# (global_prep_cmd do/undo) e RELIGA ao desconectar. Nada de dpms/settle: o monitor já
# está sempre aceso.
{
  pkgs,
  lib,
  config,
  ...
}:

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
  # exatamente o estado pendurado de 29/07. Probe em 127.0.0.1: não depende da VPN.
  #
  # SEM PIPE de propósito: o writeShellApplication liga `set -o pipefail`, e com
  # `| grep -q` o grep sai no 1º match → o openssl morre de SIGPIPE → o pipeline
  # retorna ERRO mesmo tendo dado match. Isso invertia o resultado: handshake OK era
  # lido como falha, e o timer reiniciaria o Sunshine a cada 2 min p/ sempre. Captura
  # em variável + `case` evita o pipe inteiro.
  sunshineHealth = pkgs.writeShellApplication {
    name = "sunshine-health";
    runtimeInputs = with pkgs; [
      openssl
      systemd
      coreutils
    ];
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
  # moonlight-stats: relatório de QUALIDADE das sessões, porque "cai toda hora" não é
  # mensurável e o log do Sunshine só diz "CLIENT DISCONNECTED" — a mesma linha para
  # cliente que fechou, cliente que desistiu e host que derrubou.
  #
  # O que ele responde, e que foi o que fechou o diagnóstico de 31/07: a distribuição é
  # BIMODAL — ou a sessão dura horas, ou morre em 3-60 s. Isso sozinho já separa "rede
  # ruim" de "algo derruba", que era a dúvida.
  #
  # ENCOLHEU em 08/08/2026, com a saída do Tailscale. Ele cruzava cada sessão com os
  # eventos do tailscaled (troca de caminho IPv4↔IPv6, link change) e com as amostras do
  # sunshine-path-probe, pra responder "esta sessão foi direta ou caiu no DERP?". Com
  # WireGuard não existe relay: a pergunta perdeu o objeto, e as seções que a respondiam
  # foram removidas em vez de adaptadas. Ficou o que continua verdadeiro — duração das
  # sessões e a divisão curtas/longas.
  statsPy = pkgs.writeText "moonlight-stats.py" ''
    import datetime, statistics, subprocess, sys

    DAYS = sys.argv[1] if len(sys.argv) > 1 else "7"

    def journal(*args):
        cmd = ["journalctl", "--no-pager", "-o", "short-iso", "--since", f"-{DAYS} days", *args]
        return subprocess.run(cmd, capture_output=True, text=True).stdout

    def stamp(line):
        try:
            return datetime.datetime.fromisoformat(line.split()[0])
        except (ValueError, IndexError):
            return None

    # Sessões: pares CONNECTED→DISCONNECTED. Sessão em curso (sem par) fica de fora — sem
    # fim não há duração, e contá-la como "curta" mentiria justamente na sessão de agora.
    sessions, start = [], None
    for line in journal("--user", "-u", "sunshine.service").splitlines():
        t = stamp(line)
        if t is None:
            continue
        if "CLIENT CONNECTED" in line:
            start = t
        elif "CLIENT DISCONNECTED" in line and start:
            sessions.append((start, t, (t - start).total_seconds()))
            start = None

    if not sessions:
        print(f"nenhuma sessão concluída nos últimos {DAYS} dias.")
        sys.exit(0)

    print(f"=== sessões Moonlight — últimos {DAYS} dias ===\n")
    print(f"{'início':<15}{'duração':>10}")
    short, long = [], []
    for a, b, d in sessions:
        (short if d < 120 else long).append(d)
        mark = "  <-- curta" if d < 120 else ""
        print(f"{a.strftime('%m-%d %H:%M:%S'):<15}{d:>9.0f}s{mark}")

    print(f"\n=== resumo ===")
    alld = sorted(d for _, _, d in sessions)
    print(f"sessões: {len(alld)}   mediana: {statistics.median(alld):.0f}s   "
          f"min: {alld[0]:.0f}s   max: {alld[-1]:.0f}s")
    print(f"curtas (<120s): {len(short)}/{len(alld)}   longas: {len(long)}/{len(alld)}")

  '';

  # Wrapper: a lógica mora no build (regra 7) e o runtime é uma linha. `python3` explícito
  # em runtimeInputs — o script é um artefato do store, não um .sh solto no repo.
  moonlightStats = pkgs.writeShellApplication {
    name = "moonlight-stats";
    runtimeInputs = with pkgs; [
      python3
      systemd
    ];
    text = ''exec python3 ${statsPy} "$@"'';
  };
in
{
  services.sunshine = {
    enable = config.my.services.sunshine;
    # SEM capSysAdmin: a captura é wlr (wlr-screencopy), que NÃO precisa de CAP_SYS_ADMIN
    # — só o KMS-grab precisaria, e o KMS nem funciona no driver xe. Menos privilégio.
    autoStart = true; # sobe junto da sessão gráfica (serviço --user, WantedBy graphical-session)
    openFirewall = false; # fechado em todo lugar; quem abre é a regra 10.10.10.0/24 (../net/network.nix)
    settings = {
      # Nome que aparece no Moonlight. DERIVADO do hostname, nunca literal: ficou
      # "nixos-sandisk" por um mês depois do cutover, mentindo sobre qual máquina é.
      sunshine_name = config.networking.hostName;
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
      # QUAL monitor capturar. Sem isto o wlgrab pega o PRIMEIRO da enumeração, e a TV
      # enumera antes do LG — então o Moonlight abria no monitor SECUNDÁRIO (medido no
      # log: "Monitor 0 is HDMI-A-3 / Monitor 1 is DP-2" → "Selected monitor [... LG TV]").
      # Não é escolha do cliente: o Moonlight recebe o que o host manda. Casa pelo NOME
      # do conector (o mesmo da lista de monitores do log), não por índice — índice
      # depende da ordem de enumeração, que é justamente o que deu errado aqui.
      output_name = config.my.monitors.primary; # SSOT: system/desktop/monitors.nix
      # "wan" e não "lan": mantido no valor mais permissivo DE PROPÓSITO, porque quem
      # decide o alcance aqui é o firewall, não o Sunshine — só a faixa do WireGuard
      # chega nesta porta. Apertar isto ganharia nada e arrisca quebrar o web UI em
      # silêncio (o stream não usa CSRF, então o sintoma só aparece ao abrir o painel).
      origin_web_ui_allowed = "wan";
      # CSRF: libera a origem pela qual o painel é aberto. Sem isto, criar o
      # usuário/salvar pelo web UI é bloqueado quando o host != localhost.
      #
      # ⚠️ JÁ FICOU ERRADO ANTES, entre o cutover (01/08) e 02/08/2026, e ninguém notou:
      # o STREAM não usa CSRF, então só o web UI quebra — falha silenciosa por definição.
      # Na época o valor apontava pra tailnet, cujo IP mudava a cada re-entrada do nó.
      # Agora é o IP de LAN desta máquina, que é por onde o peer do WireGuard chega (o
      # roteador roteia 10.10.10.x → LAN sem NAT). Continua sendo SNAPSHOT: não dá pra
      # derivar IP em tempo de build. Vale garantir lease fixa no roteador — sem ela,
      # trocar de IP quebra o painel de novo, e só se descobre ao tentar abri-lo.
      csrf_allowed_origins = "https://192.168.1.10:47990";
      # OBRIGATÓRIO porque o acesso é por túnel. O default do Sunshine é 1392, calibrado
      # pra MTU 1500 — em túnel ele estoura, e o WireGuard descarta em SILÊNCIO (sem
      # ICMP, sem log): o host streama normal, o cliente recebe pela metade, não remonta
      # frame e desconecta em ~4 s. Foi o que aconteceu em 29/07 com a tailscale0 (MTU
      # 1280). MANTIDO em 1024 na troca pro WireGuard (MTU ~1420) mesmo sobrando espaço:
      # é valor PROVADO, e subir seria otimização sem medição correndo o risco de
      # reintroduzir exatamente o bug silencioso que custou aquele debug.
      packet_size = 1024;
      # TETO DE BITRATE no host. O default é 0 = "obedece o que o Moonlight pedir", e o
      # cliente pedia até 79 Mbps: medindo as 67 sessões de 7 dias (jul/2026), as de
      # 79 Mbps tiveram mediana de vida de 22 s contra 290 s nas de 23.8 Mbps. Cap no
      # HOST e não no slider do cliente de propósito — é declarativo e vale p/ QUALQUER
      # cliente que parear, sem depender de lembrar da config do Moonlight em cada
      # máquina.
      #
      # 10000 -> 20000 (31/07). Duas medições mudaram a conta:
      #   1. O encoder em uso é AV1 (av1_vaapi, confirmado na instância viva), não h264
      #      como este comentário dizia. AV1 rende ~40-50% mais por bit, então 10 Mbps
      #      aqui já equivaliam a ~18-20 Mbps de h264 — o teto era mais folgado do que
      #      parecia, mas por engano de premissa, não por escolha.
      #   2. O "79 Mbps" NÃO é o que o cliente pedia nesta semana: cruzando bitrate com
      #      encoder no journal, as sessões de 7 dias rodaram a 19.4 Mbps, e as CURTAS de
      #      31/07 (15-68 s) também foram a 19.4 — ou seja, queda curta acontece em
      #      bitrate moderado, e o cap não é o que a evita. O confundidor é o horário:
      #      elas caem na janela das 08h, a mesma em que a rede da FAI derrubou a VPN 52x
      #      na semana (system/net/vpn.nix).
      # Portanto 20000 NÃO é experimento — é voltar ao bitrate que já era o de fato, agora
      # explícito e declarado. O teto continua existindo p/ impedir que um cliente peça 79.
      # Serve p/ Cities Skylines II, onde pan de câmera muda TODO pixel do quadro (pior
      # caso de compressão interframe, apesar de o jogo ser "calmo"); Hearthstone, com
      # câmera fixa, cabia bem em 10.
      # AMOSTRA a 10 Mbps: UMA sessão, que nem fechou — o teto anterior nunca chegou a
      # ter registro de estabilidade. Não há A/B a preservar aqui.
      #
      # ⚠️ CORREÇÃO (03/08/2026): o item 1 acima está ERRADO para o cliente da FAI. O
      # encoder NÃO é escolha do host — é NEGOCIADO, e quem escolhe é o Moonlight.
      # Medido no log de hoje, sessão real vinda do faidell6035:
      #     Creating encoder [h264_vaapi] / Color depth: 8-bit / Rec. 601
      # enquanto o host anuncia hevc_vaapi E av1_vaapi (ambos 10-bit) no startup. Ou
      # seja: aquele cliente pede H.264 8-bit, o codec MENOS eficiente disponível, e
      # a conta de "AV1 rende 40-50% mais por bit" não vale pra ele — a 16,8 Mbps
      # negociados ele gasta banda como H.264 gasta.
      # Consequência prática: ligar HEVC/AV1 NO MOONLIGHT do cliente vale mais que
      # qualquer ajuste deste arquivo, e é onde mexer primeiro quando o stream sofrer.
      # Não há setting de host que force isso (o `hevc_mode`/`av1_mode` só ANUNCIA
      # suporte, que já está anunciado) — é caixa de seleção no cliente.
      max_bitrate = 20000; # Kbps
      # Mais correção de erro (default 20%): o caminho até a rede da FAI PERDE pacote —
      # medido 1.67% de perda e RTT saltando de 20 p/ 312 ms numa rajada de 300 pacotes
      # de 1 KB. FEC recupera perda sem retransmitir (que em tempo real chegaria tarde).
      # Custa banda, e é por isso que anda junto do teto acima: sobra folga p/ pagar.
      # RESSALVA: a medição é ICMP, que switch/firewall costuma despriorizar — trata-se
      # de indício de caminho ruim, não de prova do que o fluxo de vídeo sofre.
      fec_percentage = 30;
      # Tolera buraco transitório antes de derrubar o stream (default 10 s). Só ajuda no
      # caso em que o HOST é quem desiste; nos logs não há como distinguir isso do
      # cliente desistindo — "CLIENT DISCONNECTED" é a mesma linha nos dois casos.
      # Não sai de graça: sessão de cliente morto segura o hypridle pausado por mais
      # tempo (o guard global_prep_cmd só religa no undo).
      ping_timeout = 20000; # ms
      # Guard de idle: do/undo acordam a tela + pausam o hypridle durante o stream (ver
      # header). JSON no sunshine.conf; vale p/ TODOS os apps (inclui o "Desktop" remoto).
      global_prep_cmd = builtins.toJSON [
        {
          do = "${streamBegin}";
          undo = "${streamEnd}";
        }
      ];
    };

    # ── Apps expostos ao Moonlight — DECLARATIVOS (regra 3) ────────────────────
    # Até 03/08/2026 isto NÃO era declarado, e o Sunshine criava o próprio
    # ~/.config/sunshine/apps.json com os apps DE FÁBRICA. Um deles derrubava o
    # stream em 2,5s:
    #
    #   "Low Res Desktop" → prep-cmd `xrandr --output HDMI-1 --mode 1920x1080`
    #
    # Dois erros no mesmo comando de fábrica: `xrandr` é X11 (aqui é Wayland puro,
    # sem Xwayland no caminho da captura) e `HDMI-1` não existe — as saídas reais
    # são DP-2 e HDMI-A-3. Prep-cmd que FALHA faz o Sunshine abortar a sessão, então
    # clicar nesse app era garantia de queda. Pior: o undo do guard global não roda
    # nesse aborto, deixando o hypridle parado (ver lock_cmd em lockscreen.nix).
    #
    # NÃO reimplementei o "Low Res Desktop" com `hyprctl output`, de propósito:
    # trocar modo de vídeo COM a captura wlr ativa é a mesma classe de risco que o
    # dpms sob captura, que deu ENGINE-RESET da GPU no xe (ver cabeçalho). Resolução
    # menor se pede no CLIENTE (Moonlight escolhe o modo e o Sunshine escala) — sem
    # tocar no scanout do host.
    #
    # ⚠️ TRADE-OFF: declarar `applications` faz o módulo apontar `file_apps` pro
    # store (nixos/modules/services/networking/sunshine.nix:128, gated em apps != [])
    # → a aba Applications do web UI vira SOMENTE LEITURA. É o preço do declarativo,
    # e é o lado certo da regra 14 (um dono por artefato). O
    # ~/.config/sunshine/apps.json antigo passa a ser IGNORADO — não apagar por
    # reflexo ao ver que ele existe e não tem efeito; ele é só lixo do período
    # não-declarativo.
    applications = {
      apps = [
        # Desktop remoto: o app "especial" do Sunshine (sem cmd = streama a sessão).
        { name = "Desktop"; }
        # Steam em Big Picture. `detached`: o Sunshine não espera o processo terminar
        # (senão a sessão morreria junto do Steam); o undo fecha o BP ao desconectar.
        # `setsid` por caminho absoluto (regra 7); `steam` fica por NOME de propósito
        # — quem resolve é o wrapper FHS do programs.steam no PATH da sessão, e um
        # ${pkgs.steam}/bin/steam aqui furaria esse wrapper.
        {
          name = "Steam Big Picture";
          detached = [ "${pkgs.util-linux}/bin/setsid steam steam://open/bigpicture" ];
          prep-cmd = [
            {
              do = "";
              undo = "${pkgs.util-linux}/bin/setsid steam steam://close/bigpicture";
            }
          ];
        }
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

  # Diagnóstico fica no system/ junto do que ele diagnostica (o healthcheck acima mora
  # aqui pelo mesmo motivo): system/ é resgate/base/DIAGNÓSTICO.
  environment.systemPackages = lib.mkIf config.my.services.sunshine [ moonlightStats ];

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
