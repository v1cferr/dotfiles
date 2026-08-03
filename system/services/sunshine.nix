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
  # sunshine-path-probe: amostra o CAMINHO da tailnet por peer, 1×/min, no journal.
  #
  # POR QUE AMOSTRAR, se o tailscaled já loga caminho: porque ele loga só a TRANSIÇÃO
  # PARA DIRETO. Medido em 03/08/2026 — em 7 dias de journal existem OITO linhas
  # `magicsock: … now using <ep>`, e todas são endpoint direto (IPv4 público da FAI e
  # IPv6). O relay NÃO aparece nesse fluxo. Então "não houve evento" é ambíguo: pode ser
  # "seguiu direto" ou "está em DERP desde sempre" — e o estado inicial de cada boot é
  # desconhecido. Evento dá o INSTANTE da mudança; só amostra dá o ESTADO, que é o que
  # responde "essa sessão foi direta?".
  #
  # Isto existe porque em 03/08 a resposta veio de SORTE: eu rodei `tailscale ping` no
  # momento certo e vi DERP. Nas 4 sessões de 3-7s daquele dia o relatório não tinha como
  # provar nada; nas seguintes, diretas, a sessão passou de 8 min. É a variável que mais
  # prevê queda e era justamente a que não ficava registrada.
  #
  # 1 min é grosso pra sessão de 3s DE PROPÓSITO: caminho persiste por minutos, então a
  # amostra vizinha descreve bem o instante, e 1440 linhas/dia é ruído irrelevante. O
  # `<5>` (notice) + LogLevelMax=notice na unit é o mesmo truque do healthcheck acima:
  # mata o "Starting…/Finished…" do systemd (info) e preserva a linha que importa.
  pathProbePy = pkgs.writeText "sunshine-path-probe.py" ''
    import json, subprocess, sys

    out = subprocess.run(
        ["${pkgs.tailscale}/bin/tailscale", "status", "--json"],
        capture_output=True, text=True,
    )
    if out.returncode != 0:
        print("<4>path probe: `tailscale status --json` falhou", file=sys.stderr)
        sys.exit(0)

    # Só peer que interessa: online OU com tráfego ativo. Peer dormindo não tem caminho.
    for p in json.loads(out.stdout).get("Peer", {}).values():
        if not (p.get("Online") or p.get("Active")):
            continue
        # CurAddr VAZIO é a definição de relayed no tailscale: sem endpoint direto, o
        # tráfego vai pelo DERP nomeado em Relay. Não inferir por latência.
        addr = p.get("CurAddr") or ""
        if addr:
            kind = "direct6" if addr.startswith("[") else "direct4"
        else:
            kind = "relay:" + (p.get("Relay") or "?")
        print(
            f"<5>path peer={p.get('HostName')} kind={kind} "
            f"addr={addr or '-'} active={str(bool(p.get('Active'))).lower()}"
        )
  '';

  # moonlight-stats: relatório de QUALIDADE das sessões, porque "cai toda hora" não é
  # mensurável e o log do Sunshine só diz "CLIENT DISCONNECTED" — a mesma linha para
  # cliente que fechou, cliente que desistiu e host que derrubou (é a queixa da issue
  # tailscale/tailscale#14208, que segue sem causa-raiz justamente por falta disto).
  #
  # O que ele responde, e que foi o que fechou o diagnóstico de 31/07: a distribuição é
  # BIMODAL — ou a sessão dura horas, ou morre em 3-60 s. Com isso dá p/ testar hipótese
  # em vez de chutar: o relatório cruza cada sessão com os eventos do tailscaled no MESMO
  # intervalo (troca de caminho IPv4↔IPv6 e link change/rebind), então uma causa candidata
  # se REFUTA na hora se as sessões longas a sofrem mais que as curtas — foi o que
  # aconteceu com as quatro primeiras suspeitas (ver ANOTACOES).
  statsPy = pkgs.writeText "moonlight-stats.py" ''
    import datetime, re, statistics, subprocess, sys

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

    ts = journal("-u", "tailscaled").splitlines()
    paths = [stamp(x) for x in ts if "now using" in x and stamp(x)]
    links = [stamp(x) for x in ts if re.search(r"[Ll]ink [Cc]hange|LinkChange", x) and stamp(x)]

    # Amostras do sunshine-path-probe: (instante, kind). Só peer ATIVO — é o que está
    # streamando; peer online e parado descreveria o caminho de outra máquina.
    samples = []
    for line in journal("-u", "sunshine-path-probe.service").splitlines():
        t = stamp(line)
        if t is None or "path peer=" not in line:
            continue
        kv = dict(x.split("=", 1) for x in line.split() if "=" in x)
        if kv.get("active") == "true" and kv.get("kind"):
            samples.append((t, kv["kind"]))

    def path_of(a, b):
        """Caminho vigente na sessão [a,b]. CARRY-FORWARD é o ponto: sessão de 3s não
        contém amostra nenhuma (probe é de 1 min), e aí o estado válido é o da última
        amostra ANTES dela — sem isso, justamente as sessões curtas, que são as que
        interessam, sairiam todas como '?'."""
        inside = [k for t, k in samples if a <= t <= b]
        if not inside:
            before = [k for t, k in samples if t < a]
            inside = before[-1:]
        if not inside:
            return "?"
        uniq = sorted(set(inside))
        # "misto" = trocou DURANTE a sessão. Medido em 03/08: a sessão de 8 min
        # atravessou direct4→direct6 duas vezes e sobreviveu — misto não é veredito
        # de culpa, é só o registro de que houve troca.
        return uniq[0] if len(uniq) == 1 else "misto"

    if not sessions:
        print(f"nenhuma sessão concluída nos últimos {DAYS} dias.")
        sys.exit(0)

    print(f"=== sessões Moonlight — últimos {DAYS} dias ===\n")
    print(f"{'início':<15}{'duração':>10}{'caminho':>10}{'trocas-caminho':>16}{'link-change':>13}")
    short, long = [], []
    for a, b, d in sessions:
        np = sum(1 for x in paths if a <= x <= b)
        nl = sum(1 for x in links if a <= x <= b)
        kind = path_of(a, b)
        (short if d < 120 else long).append((d, np, nl, kind))
        mark = "  <-- curta" if d < 120 else ""
        print(f"{a.strftime('%m-%d %H:%M:%S'):<15}{d:>9.0f}s{kind:>10}{np:>16}{nl:>13}{mark}")

    print(f"\n=== resumo ===")
    alld = sorted(d for _, _, d in sessions)
    print(f"sessões: {len(alld)}   mediana: {statistics.median(alld):.0f}s   "
          f"min: {alld[0]:.0f}s   max: {alld[-1]:.0f}s")
    print(f"curtas (<120s): {len(short)}/{len(alld)}   longas: {len(long)}/{len(alld)}")

    # A comparação que refuta/confirma causa: se as LONGAS sofrem MAIS o evento que as
    # curtas, o evento não é o que derruba. Taxa por minuto, senão sessão de 3 s "nunca"
    # tem evento só por ser curta — o viés que quase levou a uma conclusão errada.
    print("\n=== eventos de rede por minuto de sessão (curtas vs longas) ===")
    for name, group in [("curtas <120s", short), ("longas >=120s", long)]:
        if not group:
            continue
        pr = [np / (d / 60) for d, np, _, _ in group if d > 0]
        lr = [nl / (d / 60) for d, _, nl, _ in group if d > 0]
        print(f"  {name:<14} n={len(group):<4} "
              f"caminho: mediana={statistics.median(pr):.2f} média={statistics.mean(pr):.2f}   "
              f"link: mediana={statistics.median(lr):.2f} média={statistics.mean(lr):.2f}")
    print("  (LONGAS com taxa MAIOR = esse evento é sobrevivível, não é a causa)")

    # A comparação que o relatório NÃO tinha e que era a mais preditiva. Aqui a leitura é
    # direta, sem o viés de taxa-por-minuto: agrupa por caminho e olha a mediana de vida.
    # Se `relay:*` tiver mediana de segundos e `direct*` de minutos, o veredito é o
    # caminho — e nenhum ajuste de bitrate/FEC deste arquivo conserta isso.
    print("\n=== duração por CAMINHO (o mais preditivo) ===")
    by_kind = {}
    for d, _, _, kind in short + long:
        by_kind.setdefault(kind, []).append(d)
    if set(by_kind) <= {"?"}:
        print("  sem amostra ainda — o sunshine-path-probe começa a gravar no próximo")
        print("  boot/rebuild; sessões anteriores a ele ficam como '?' pra sempre.")
    for kind in sorted(by_kind):
        ds = sorted(by_kind[kind])
        curtas = sum(1 for x in ds if x < 120)
        print(f"  {kind:<12} n={len(ds):<4} mediana={statistics.median(ds):>6.0f}s   "
              f"min={ds[0]:>4.0f}s max={ds[-1]:>6.0f}s   curtas={curtas}/{len(ds)}")

    print("\n=== caminho atual do Tailscale ===")
    out = subprocess.run(["tailscale", "status"], capture_output=True, text=True).stdout
    for line in out.splitlines():
        if "direct" in line or "relay" in line:
            kind = "DIRETO" if "direct" in line else "RELAY (DERP - latência alta!)"
            print(f"  {line.split()[1] if len(line.split()) > 1 else '?'}: {kind}")
  '';

  # Wrapper: a lógica mora no build (regra 7) e o runtime é uma linha. `python3` explícito
  # em runtimeInputs — o script é um artefato do store, não um .sh solto no repo.
  moonlightStats = pkgs.writeShellApplication {
    name = "moonlight-stats";
    runtimeInputs = with pkgs; [ python3 systemd tailscale ];
    text = ''exec python3 ${statsPy} "$@"'';
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
      # Acesso vem pela tailnet (IP 100.x, que o Sunshine classifica como WAN) →
      # "wan" p/ não bloquear o web UI. NÃO é exposição real: o firewall só deixa a
      # tailscale0 (trusted) chegar aqui; LAN/internet continuam fechadas.
      origin_web_ui_allowed = "wan";
      # CSRF: libera as origens da tailnet (IP + nome MagicDNS). Sem isto, criar o
      # usuário/salvar pelo web UI é bloqueado quando o host != localhost.
      #
      # ⚠️ AMBOS OS VALORES FICARAM ERRADOS entre o cutover (01/08) e 02/08/2026, e
      # ninguém notou: o STREAM não usa CSRF, então só o web UI estava quebrado —
      # falha silenciosa por definição. O hostname virou nixos-kingston e o IP da
      # tailnet mudou (100.92.126.90 → 100.116.22.4) quando o nó re-entrou na tailnet.
      # O nome agora é DERIVADO (regra 11: literal repetido é dívida); o IP não dá
      # pra derivar em tempo de build — é runtime — então é SNAPSHOT e vai errar de
      # novo se o nó re-entrar. Preferir o MagicDNS; conferir com `tailscale ip -4`.
      csrf_allowed_origins =
        "https://100.116.22.4:47990,https://${config.networking.hostName}.tailf2731d.ts.net:47990";
      # OBRIGATÓRIO porque o acesso é pela tailnet: a tailscale0 tem MTU 1280 e o default
      # do Sunshine é 1392 → todo pacote de vídeo estoura o túnel. WireGuard descarta em
      # SILÊNCIO (sem ICMP, sem log): o host streama normal, o cliente recebe pela metade,
      # não remonta frame e desconecta em ~4 s — foi o que aconteceu em 29/07. 1024 cabe
      # com folga em 1280 depois de IP+UDP+cabeçalhos do Moonlight.
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
        { do = "${streamBegin}"; undo = "${streamEnd}"; }
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
            { do = ""; undo = "${pkgs.util-linux}/bin/setsid steam steam://close/bigpicture"; }
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

  # ── Probe de caminho da tailnet ──────────────────────────────────────────────
  # Unit de SISTEMA, não --user, por dois motivos: caminho da tailnet muda com ou sem
  # sessão gráfica (e a lacuna que isso fecha é justamente "qual era o caminho ANTES de
  # eu conectar"), e o journal do sistema é onde o tailscaled já loga — o relatório lê
  # os dois do mesmo lugar.
  systemd.services.sunshine-path-probe = lib.mkIf config.my.services.sunshine {
    description = "Registra o caminho da tailnet (direto/relay) por peer no journal";
    # Sem tailscaled no ar o `status --json` falha e o probe só emite <4> e sai 0 — não
    # quero um `failed` de boot por dependência que sobe depois (a lição do ddns).
    after = [ "tailscaled.service" ];
    serviceConfig = {
      Type = "oneshot";
      ExecStart = "${pkgs.python3}/bin/python3 ${pathProbePy}";
      # Deixa passar o <5>/notice da amostra e corta o "Starting…/Finished…" (info) do
      # systemd — senão 1×/min viraria ~4300 linhas/dia de ruído pra 1440 de sinal.
      LogLevelMax = "notice";
    };
  };

  systemd.timers.sunshine-path-probe = lib.mkIf config.my.services.sunshine {
    description = "Amostra o caminho da tailnet a cada minuto";
    timerConfig = {
      OnBootSec = "2min"; # dá tempo do tailscaled negociar caminho antes da 1ª amostra
      OnUnitActiveSec = "1min";
    };
    wantedBy = [ "timers.target" ];
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
