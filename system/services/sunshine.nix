# Sunshine — servidor de streaming de tela/desktop remoto (cliente = Moonlight). É
# a forma recomendada de acesso remoto no Hyprland/Wayland: captura via wlr-screencopy
# (o `wlr`, auto-selecionado) e encoda na GPU. O Arc B580 tem encoder AV1/HEVC (VA-API)
# → stream fluido e de baixa latência. Era Tailscale até 08/08/2026 — a troca está
# registrada em docs/historico/2026/08-agosto.md.
#
# COMO SE CHEGA AQUI — DOIS caminhos desde 10/08/2026, e `openFirewall = false`
# continua valendo nos dois (nenhum deles abre porta em toda interface):
#   1. WireGuard do roteador — regra de origem 10.10.10.0/24 em ../net/network.nix.
#   2. INTERNET, direto, restrito aos blocos da UFSCar — as regras no fim deste
#      arquivo, mais as redirects `Moonlight-*` no roteador (router/uci/firewall.conf).
# O caminho 2 existe porque o notebook da FAI já roda nxBender + openconnect, e somar
# um terceiro cliente de VPN ali é conflito de rota esperando acontecer.
#
# ⚠️ O caminho 2 NÃO é "mais direto" que o 1, e essa era a premissa que o motivou: o
# endpoint do WireGuard é o PRÓPRIO roteador de casa, então os dois percorrem UFSCar →
# internet → 177.52.84.188. Não há relay (isso era risco do Tailscale, que saiu). O que
# o caminho 2 ganha de verdade é MTU — 1492 da PPPoE contra 1420 do túnel — e o que ele
# ganha em latência é ruído. Não reescrever isto como ganho de rota.
#
# CRIPTOGRAFIA, e o motivo de não ser um downgrade: o Sunshine classifica o cliente por
# IP. Pelo túnel ele chega como 10.10.10.x = LAN → `lan_encryption_mode = 0` (o túnel já
# cifra). Pela internet ele chega público = WAN → `wan_encryption_mode = 1`, que é o
# default e fica LIGADO. Não mexer nesses dois: são o que impede o caminho 2 de streamar
# em claro.
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
# está sempre aceso. O `undo` NÃO é confiável (cliente que morre sem teardown nunca o
# dispara) — daí o watchdog `hypridle-guard` neste arquivo, que fecha essa brecha.
{
  pkgs,
  lib,
  config,
  ...
}:

let
  # ── Portas, e de onde se aceita chegar nelas ───────────────────────────────
  # DERIVADAS da base com os MESMOS offsets que o próprio Sunshine usa pra montar a
  # tabela de portas do web UI. Lidos do build em uso (2026.516.143833), em
  # `assets/web/assets/config-*.js`: tcp `port-5`, `port`, `port+1`, `port+21` e udp
  # `port+9`…`port+11`. Escrever os números à mão seria copiar de blog, e blog erra:
  # quase toda lista na internet inclui uma UDP 48002 ("mic") que NÃO EXISTE nesta
  # versão — são três portas UDP, não quatro. Conferir no js do store ao atualizar.
  basePort = 47989; # o `port` do Sunshine; mover isto move todas as outras
  sp = n: toString (basePort + n);

  # O que o Moonlight precisa alcançar — e o que ele NÃO precisa. A `port+1` (47990) é
  # o PAINEL ADMIN e está fora desta lista DE PROPÓSITO: ela nunca sai de casa. Quem a
  # adicionar aqui publica na internet a tela que cria usuário e pareia cliente.
  moonlightPorts = [
    {
      proto = "tcp";
      dport = sp (-5);
    } # 47984 — HTTPS: é por aqui que host JÁ PAREADO entra
    {
      proto = "tcp";
      dport = sp 0;
    } # 47989 — HTTP: /serverinfo e o pareamento por PIN
    {
      proto = "tcp";
      dport = sp 21;
    } # 48010 — RTSP: negociação da sessão
    {
      proto = "udp";
      dport = "${sp 9}:${sp 11}";
    } # 47998-48000 — vídeo, áudio e controle
  ];

  # De ONDE se aceita. Blocos públicos da UFSCar, confirmados no registro.br em
  # 10/08/2026 (ambos registrados sob o CNPJ 45.358.058/0001-40).
  #
  # ⚠️ NÃO trocar por `0.0.0.0/0` "pra funcionar de qualquer lugar". A casa NÃO está
  # atrás de CGNAT — medido em 10/08/2026, a 2222 responde de Áustria, Canadá e Irã —
  # então `0.0.0.0/0` aqui significa literalmente o planeta. O que estas portas
  # entregam a quem as alcança é o `/serverinfo` SEM autenticação nenhuma: hostname,
  # GPU, lista de apps e se há sessão ativa. Parear ainda exige o PIN digitado no
  # host; inventariar a máquina não exige nada.
  #
  # Literal, e não opção em ../net/subnets.nix, porque a regra 11 pede 2+ consumidores
  # e aqui o consumidor é UM. Mas há um espelho a manter em sincronia à mão: o
  # `src_ip` das redirects `Moonlight-*` em router/uci/firewall.conf. Se as duas listas
  # divergirem, o roteador encaminha e o host derruba — e o sintoma é "Moonlight não
  # conecta", que é indistinguível de tudo o mais.
  #
  # OS DOIS BLOCOS NÃO VALEM O MESMO, e isso está medido (docs/historico/2026/08-agosto.md,
  # entrada do falso alarme de CGNAT): a rede da FAI DESCARTA O SYN-ACK de volta — o SYN
  # sai de lá, chega aqui, o host responde, o conntrack do roteador fica em `SYN_RECV` e o
  # ACK final nunca volta. Ou seja, do /21 a conexão pode simplesmente não fechar, e não há
  # nada deste lado que conserte isso. O /20 (campus) PASSA — provado pela sessão SSH de
  # 10/08/2026, vinda de 200.133.233.101. O /21 fica na lista mesmo assim: custa uma regra,
  # e o bloqueio é do firewall DELES, que pode mudar sem aviso.
  moonlightSources = [
    "200.133.224.0/20" # UFSCar — campus. É por aqui que o notebook sai hoje, e FUNCIONA
    "200.136.192.0/21" # UFSCar — faixa da FAI. Ver acima: pode não fechar conexão
  ];

  # Produto origem × porta = 8 regras. GERADO e não escrito à mão porque a lista do
  # stop tem que casar EXATAMENTE com a do start: regra que não casa não é removida no
  # reload e empilha duplicata a cada rebuild. Escrever 16 linhas espelhadas na mão é
  # exatamente o jeito de deixar uma para trás.
  fwMatches = lib.concatMap (
    src: map (p: "-s ${src} -p ${p.proto} --dport ${p.dport}") moonlightPorts
  ) moonlightSources;

  # Marca de que a pausa do hypridle é DESTE guard, e não do usuário. A pill da barra
  # (quickshell, Bar.qml) também para o hypridle, de propósito — sem esta marca o
  # watchdog abaixo desfaria esse toggle manual em até 5 min. Fica no XDG_RUNTIME_DIR:
  # some no reboot, que é exatamente quando o hypridle volta sozinho de qualquer jeito.
  pauseStamp = ''"''${XDG_RUNTIME_DIR:-/run/user/$(${pkgs.coreutils}/bin/id -u)}/sunshine-hypridle-paused"'';

  # Início do stream: para o hypridle p/ a sessão remota não TRANCAR no meio por idle.
  # `|| true`: um prep-cmd que falha cancelaria o stream no Sunshine.
  streamBegin = pkgs.writeShellScript "sunshine-stream-begin" ''
    ${pkgs.coreutils}/bin/touch ${pauseStamp} || true
    ${pkgs.systemd}/bin/systemctl --user stop hypridle.service || true
  '';
  # Fim do stream: religa o hypridle → volta a trancar aos 5min de ociosidade.
  streamEnd = pkgs.writeShellScript "sunshine-stream-end" ''
    ${pkgs.coreutils}/bin/rm -f ${pauseStamp} || true
    ${pkgs.systemd}/bin/systemctl --user start hypridle.service || true
  '';

  # ── Watchdog do guard: o `undo` acima NÃO é garantia ─────────────────────────
  # Medido em 10/08/2026: cliente sumiu sem teardown limpo às ~14:57, o Sunshine
  # nunca fechou a sessão, o `undo` nunca rodou, e o hypridle ficou parado por 6h.
  # O `ping_timeout` não cobre isso — ele derruba o STREAM, não a contabilidade da
  # sessão. E enquanto o hypridle está parado a máquina não tranca sozinha nunca.
  #
  # O SINAL TEM QUE SER A REALIDADE, NÃO A CONTABILIDADE DO SUNSHINE. O caminho
  # óbvio seria o `/serverinfo` (sem auth na 47989, é o que o header cita), mas ele
  # é justamente quem mente: às 17:30 daquele dia ainda dizia SUNSHINE_SERVER_BUSY
  # com o cliente morto havia 2h30. Um watchdog keyado nele nunca dispararia.
  #
  # O que NÃO mentiu na mesma medição: os sockets. Com a sessão fantasma "ativa", o
  # Sunshine tinha ZERO sockets UDP nas portas de vídeo — ele os cria por sessão e
  # os fecha ao fim. Então `bound` = stream de verdade.
  # ⚠️ Medi o lado NEGATIVO (sem stream ⇒ sem socket); o positivo é inferência forte
  # (é por essas portas que o cliente manda vídeo/áudio/controle — são as mesmas do
  # `moonlightPorts`), mas não observada. Conferir no próximo stream com
  # `ss -uan | grep 4799` antes de tratar como fato.
  hypridleGuard = pkgs.writeShellApplication {
    name = "hypridle-guard";
    runtimeInputs = with pkgs; [
      systemd
      iproute2
      coreutils
    ];
    text = ''
      stamp=${pauseStamp}

      # 1) Pausa que não é deste guard (pill da barra) — não é da nossa conta.
      [ -e "$stamp" ] || exit 0

      # 2) hypridle já vivo: o undo rodou. Só limpa a marca.
      if systemctl --user is-active --quiet hypridle.service; then
        rm -f "$stamp"
        exit 0
      fi

      # 3) CARÊNCIA de 2 min. Entre o `do` (que para o hypridle) e o bind das portas
      #    de vídeo existe uma janela — no "Steam Big Picture" ela dura o launch do
      #    Steam inteiro. Religar dentro dela é o lockout remoto de 03/08 de novo.
      paused=$(systemctl --user show hypridle.service -p InactiveEnterTimestampMonotonic --value)
      now=$(awk '{printf "%d", $1 * 1000000}' /proc/uptime)
      if [ "$paused" -gt 0 ] && [ "$((now - paused))" -lt 120000000 ]; then exit 0; fi

      # 4) Stream de verdade? UDP de vídeo bound, ou TCP de controle ESTABELECIDO com
      #    peer não-loopback (cobre a janela de setup, antes do vídeo subir; o loopback
      #    sai fora porque o sunshine-healthcheck abre uma na 47984 a cada 2 min).
      #    Filtro do próprio ss, SEM PIPE pro grep: `set -o pipefail` + `grep -q` que
      #    sai no 1º match dá SIGPIPE e inverte o resultado — a lição do sunshineHealth.
      #    `not dst X` e NÃO `dst != X`: o segundo parece natural e o parser do ss
      #    rejeita com "bison bellows (syntax error)". Testado em 10/08/2026.
      [ -z "$(ss -uanH "sport >= :${sp 9} and sport <= :${sp 11}")" ] || exit 0
      [ -z "$(ss -tanH state established "( sport = :${sp (-5)} or sport = :${sp 21} ) and not dst 127.0.0.0/8 and not dst [::1]")" ] || exit 0

      echo "<4>hypridle parado sem stream ativo — religando (o undo do Sunshine não rodou)"
      rm -f "$stamp"
      systemctl --user start hypridle.service
    '';
  };

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
      # decide o alcance aqui é o firewall, não o Sunshine. Apertar isto ganharia nada
      # e arrisca quebrar o web UI em silêncio (o stream não usa CSRF, então o sintoma
      # só aparece ao abrir o painel).
      #
      # ⚠️ ISTO SÓ CONTINUA SEGURO ENQUANTO A 47990 NÃO FOR ENCAMINHADA. Até 10/08/2026
      # a frase aqui era "só a faixa do WireGuard chega nesta porta", e ela deixou de
      # ser verdade no dia em que o acesso direto entrou: agora chega também a UFSCar,
      # nas portas de STREAM. A 47990 ficou de fora das duas listas (`moonlightPorts`
      # no topo e as redirects do roteador) justamente porque este valor é "wan" —
      # encaminhá-la publicaria o painel admin sem gate nenhum.
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
      #
      # ⚠️ DESDE 10/08/2026 ISTO ESTÁ TRAVADO EM 1024, e não é mais conservadorismo — é
      # restrição. Este valor é GLOBAL, um só para todos os clientes, e agora existem dois
      # caminhos com MTU DIFERENTE: o túnel (~1420) e o direto da UFSCar (1492 da PPPoE).
      # Quem calibrar para o caminho direto quebra o do túnel, e quebra do jeito pior que
      # este arquivo já documenta: o WireGuard descarta em SILÊNCIO, sem ICMP e sem log, e
      # o cliente cai em ~4 s. O teto útil é o do MENOR caminho, sempre.
      # Só faz sentido subir se o caminho do túnel for APOSENTADO — e aí o número a mirar
      # é o do teste em docs/testes/wireguard-moonlight.md, não um chute.
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

  # Watchdog do guard de idle — ver o bloco `hypridleGuard` acima para o incidente.
  systemd.user.services.hypridle-guard = lib.mkIf config.my.services.sunshine {
    description = "Religa o hypridle se o guard do Sunshine o deixou parado sem stream";
    serviceConfig = {
      Type = "oneshot";
      ExecStart = "${hypridleGuard}/bin/hypridle-guard";
      LogLevelMax = "warning"; # mesmo motivo do healthcheck: sem Starting/Finished
    };
  };

  # ── Acesso pela internet, sem VPN, restrito à UFSCar ────────────────────────
  # A outra metade disto mora NO ROTEADOR (redirects `Moonlight-*`), que o Nix não
  # alcança — ver o cabeçalho de ../net/router.nix. Esta regra sozinha não expõe nada:
  # sem o DNAT lá, nenhum pacote da internet chega nestas portas. É por isso que ela
  # pode entrar ANTES, e é a ordem certa — o inverso deixaria o roteador encaminhando
  # pra um host que rejeita.
  #
  # O `-s` NÃO é redundante com o `src_ip` do roteador: é a segunda tranca, e a que
  # sobrevive a alguém mexer no LuCI sem olhar este arquivo.
  #
  # `-I nixos-fw 1`: mesmo idioma e mesmo motivo da regra do LocalSend em
  # ../net/localsend.nix — `-A` funcionaria no extraCommands de hoje, mas `-I 1` não
  # depende de onde o upstream decide injetá-lo amanhã.
  networking.firewall = lib.mkIf config.my.services.sunshine {
    extraCommands = lib.concatMapStringsSep "\n" (
      m: "iptables -I nixos-fw 1 ${m} -j nixos-fw-accept"
    ) fwMatches;
    # Sem isto, `reload` do firewall empilha duplicatas das regras acima.
    extraStopCommands = lib.concatMapStringsSep "\n" (
      m: "iptables -D nixos-fw ${m} -j nixos-fw-accept 2>/dev/null || true"
    ) fwMatches;
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

  # 5min e não 2: o idle tranca aos 5min de qualquer forma, então resolução mais fina
  # não compra nada — e o custo de religar tarde é ínfimo perto de religar cedo demais.
  systemd.user.timers.hypridle-guard = lib.mkIf config.my.services.sunshine {
    description = "Verificação periódica do guard de idle do Sunshine";
    timerConfig = {
      OnActiveSec = "5min";
      OnUnitActiveSec = "5min";
    };
    partOf = [ "graphical-session.target" ];
    wantedBy = [ "graphical-session.target" ];
  };
}
