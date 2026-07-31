# VPNs da FAI e da UFSCar — 100% declarativo, sob demanda (não sobem no boot; o CLI
# `vpn` + os binds SUPER+N / SUPER+SHIFT+N / SUPER+CTRL+N ligam/desligam). Rodam como
# serviço systemd de sistema (VPN precisa de tun/rotas = root).
#   • UFSCar → GlobalProtect (Palo Alto) via openconnect --protocol=gp (FOSS, nixpkgs).
#   • FAI    → SonicWall SSL VPN via nxBender (FOSS, pkgs/nxbender.nix; substitui o
#              netExtender proprietário do Arch). Se não conectar → empacotar netExtender.
# Senhas via sops (Bitwarden): openconnect lê por STDIN (fora do `ps`); nxBender lê de um
# config renderizado pelo sops.templates (fora da store/git). O `vpn` dispara os serviços
# sem `sudo` graças à regra polkit abaixo (senão o bind pediria senha).
{ pkgs, config, ... }:

let
  # BACKOFF EXPONENCIAL, sem teto rígido. O teto anterior (6 tentativas/10 min) tinha um
  # buraco: quando o SonicWall ACEITA a conexão e derruba em ~24s (SIGHUP), cada ciclo dura
  # ~34s — as 6 tentativas queimavam em ~3,5 min e o systemd marcava start-limit-hit,
  # deixando a unidade em `failed` PERMANENTE. Pior que o bug original: nem `vpn connect
  # fai` subia mais, sem um `systemctl reset-failed` na mão.
  # Agora 10s → 300s progressivo e nunca desiste. Senha errada = ~12 tentativas/h no pior
  # caso, gentil o bastante p/ não disparar bloqueio de conta no portal.
  vpnRestart = {
    Restart = "always";
    RestartSec = 10;
    RestartSteps = 5; # 10s, ~26s, ~68s, ~force… até o teto
    RestartMaxDelaySec = 300;
  };

  # CLI `vpn`: connect/disconnect ufscar|fai|all + status-json (que alimenta o pill E o
  # popover da barra — quickshell/bar/VpnPopover.qml) + diagnose/watch (abaixo).
  #
  # DIAGNOSE/WATCH (31/07) — falha de conexão era SILENCIOSA: clicava em Conectar, nada
  # acontecia, e do lado de cá parecia problema da máquina pessoal. O objetivo aqui não é
  # despejar log: é a notificação DIZER DE QUEM É A CULPA, porque essa é a informação que
  # muda o que você faz em seguida (esperar a FAI voltar vs. mexer na sua rede/senha).
  #
  # POR QUE UM WATCHER e não `OnFailure=` do systemd: estas units têm Restart=always com
  # startLimitIntervalSec=0, então elas NUNCA entram em `failed` — ficam em crash-loop
  # eterno, e um OnFailure jamais dispararia. O gatilho tem de ser tempo: 45s depois do
  # pedido de conexão, se não houver túnel, diagnostica e avisa uma vez.
  #
  # A CLASSIFICAÇÃO sai de assinaturas MEDIDAS no journal desta máquina (2 dias), não
  # inventadas: ConnectTimeout em /cgi-bin/userLogin (portal fora) = o caso mais comum,
  # 152 ocorrências; "Connection reset by peer" (27); "Modem hangup"/"Peer not
  # responding"/"No response to N echo-requests" (túnel subiu e caiu). A ordem dos testes
  # importa: internet daqui -> portal alcançável -> só então o log. Sem isso, "timeout" no
  # log seria lido como culpa da FAI mesmo com a sua rede caída.
  vpnCli = pkgs.writeShellApplication {
    name = "vpn";
    runtimeInputs = with pkgs; [ systemd libnotify iproute2 gnugrep coreutils bash ];
    text = ''
      note() { notify-send -a VPN "VPN" "$1" 2>/dev/null || true; }
      # "Conectado" = unidade ativa E túnel existindo de fato. Só `is-active` MENTE: com
      # o portal da FAI fora do ar o nxBender entra em crash-loop e o systemd reporta
      # active durante cada tentativa (~2min), com zero ppp0 — o pill ficava verde à toa.
      # UFSCar: filtra tun[0-9] porque `type tun` também casa o tailscale0.
      fai_conn()    { systemctl is-active --quiet vpn-fai.service    && [ -n "$(ip -o link show type ppp)" ]; }
      ufscar_conn() { systemctl is-active --quiet vpn-ufscar.service && ip -o link show type tun | grep -q ': tun[0-9]'; }
      # Mount rclone da workstation FAI (~/FAI-workstation) sobe/derruba JUNTO com a VPN
      # FAI (home/services/fai-workstation-mount.nix). --no-block: não trava esperando o
      # túnel; o serviço retenta sozinho até o host ficar alcançável.
      mnt='rclone-mount:.@faiws.service'
      # reset-failed antes de todo start: unidade que morreu em `failed` RECUSA `start` até
      # ser limpa, e aí o bind SUPER+N não fazia nada sem explicação. Idempotente.
      fai_up()      { systemctl reset-failed vpn-fai.service 2>/dev/null || true; systemctl start vpn-fai.service && note "FAI conectando…"; systemctl --user start --no-block "$mnt" 2>/dev/null || true; systemctl --user start --no-block vpn-watch@fai.service 2>/dev/null || true; }
      fai_down()    { systemctl stop  vpn-fai.service 2>/dev/null || true; systemctl --user stop "$mnt" 2>/dev/null || true; note "FAI desconectada"; }
      ufscar_up()   { systemctl reset-failed vpn-ufscar.service 2>/dev/null || true; systemctl start vpn-ufscar.service && note "UFSCar conectando…"; systemctl --user start --no-block vpn-watch@ufscar.service 2>/dev/null || true; }
      ufscar_down() { systemctl stop  vpn-ufscar.service 2>/dev/null || true; note "UFSCar desconectada"; }

      # ── Diagnóstico ────────────────────────────────────────────────────────
      # metadados por VPN: unidade + portal (host/porta) que precisa estar de pé.
      vpn_meta() {
        case "$1" in
          fai)    echo "vpn-fai.service 200.133.233.101 4433" ;;
          ufscar) echo "vpn-ufscar.service acessoremoto-scl.ufscar.br 443" ;;
          *)      return 1 ;;
        esac
      }
      conn_of() { case "$1" in fai) fai_conn ;; ufscar) ufscar_conn ;; *) return 1 ;; esac; }
      # TCP puro via /dev/tcp: não depende do `nc` (cujo `-z` varia por implementação —
      # o `nc -zv` desta máquina sai calado, o que já me enganou uma vez).
      tcp_open() { timeout "''${3:-6}" bash -c "exec 3<>/dev/tcp/$1/$2" 2>/dev/null; }

      # Ecoa: linha1 = VEREDITO (de quem é a culpa), linha2 = detalhe, resto = evidência.
      diag() {
        id="$1"
        meta="$(vpn_meta "$id")" || { echo "uso: vpn diagnose fai|ufscar" >&2; return 2; }
        read -r unit host port <<< "$meta"

        if conn_of "$id"; then
          printf 'conectada\ntúnel de pé (unidade ativa E interface presente)\n'
          return 0
        fi

        # Unidade PARADA não é falha: é "você não pediu p/ conectar". Sem este gate o
        # diagnóstico classificava com log de DIAS atrás e dizia "ainda tentando" sobre
        # uma VPN que ninguém tentou subir — pego no 1º teste real (UFSCar, 31/07).
        if ! systemctl is-active --quiet "$unit"; then
          # SEM backticks aqui: dentro de aspas simples o shellcheck acusa SC2016 e o
          # build FALHA. Pior, a mensagem sai ilegível — o shellcheck crasha ao imprimir
          # ("cannot encode character") porque o sandbox não tem locale UTF-8 e a linha
          # tem acento. Warning em linha acentuada = erro que não se explica sozinho.
          printf 'nao esta conectando -- unidade parada\nnenhuma tentativa em curso; use: vpn connect %s\n' "$id"
          return 1
        fi

        # Janela de 15 min: garante que a evidência é da tentativa ATUAL, não de uma
        # sessão antiga que sobrou no journal (mesma armadilha do gate acima).
        log="$(journalctl -u "$unit" --since '-15 min' --no-pager 2>/dev/null || true)"

        # ORDEM proposital: o mais local primeiro. Culpar a FAI por um "timeout" no log
        # enquanto a rede daqui está caída seria o erro clássico deste tipo de alerta.
        if ! tcp_open 1.1.1.1 443 4; then
          verdict="SEM INTERNET nesta máquina"
          detail="não abriu 1.1.1.1:443 — o problema é a sua rede, antes da VPN"
        elif ! tcp_open "$host" "$port"; then
          verdict="PORTAL DA VPN FORA DO AR — não é a sua máquina"
          detail="$host:$port não aceita conexão e a internet daqui está OK"
        else
          case "$log" in
            *"Login failed"*|*"Authentication failed"*|*"invalid credential"*)
              verdict="CREDENCIAL REJEITADA"
              detail="o portal respondeu e recusou o login — revisar a senha no sops" ;;
            *"Connection reset by peer"*)
              verdict="A FAI DERRUBOU a conexão (reset by peer)"
              detail="o portal está de pé, mas fechou a sessão no meio do processo" ;;
            *"echo-requests"*|*"Modem hangup"*|*"Peer not responding"*)
              verdict="TÚNEL SUBIU E CAIU — lado da FAI"
              detail="o pppd deixou de receber resposta com o túnel já ativo" ;;
            *)
              verdict="ainda tentando (causa não classificada)"
              detail="portal alcançável; as linhas abaixo são o que o log tem de mais recente" ;;
          esac
        fi

        printf '%s\n%s\n' "$verdict" "$detail"
        # evidência: as últimas linhas de erro, sem o prefixo de host/unidade
        printf '%s\n' "$log" \
          | grep -iE 'error|failed|timed out|hangup|refused|reset by peer|not responding' \
          | tail -n 3 | sed 's/.*nixos-sandisk //' || true
        return 1
      }
      case "''${1:-}" in
        connect)
          case "''${2:-}" in
            ufscar) ufscar_up ;;
            fai)    fai_up ;;
            *) echo "uso: vpn connect ufscar|fai" >&2; exit 1 ;;
          esac ;;
        disconnect)
          case "''${2:-all}" in
            ufscar) ufscar_down ;;
            fai)    fai_down ;;
            all)    ufscar_down; fai_down ;;
            *) echo "uso: vpn disconnect ufscar|fai|all" >&2; exit 1 ;;
          esac ;;
        # Diagnóstico sob demanda, no terminal: `vpn diagnose fai`.
        diagnose)
          diag "''${2:-fai}" ;;
        # Chamado pelo vpn-watch@<id>.service, disparado por fai_up/ufscar_up. Espera e,
        # se não conectou, avisa UMA vez com o veredito. Silêncio total quando conecta —
        # notificação que aparece no caminho felizmente vira ruído e passa a ser ignorada.
        watch)
          id="''${2:-fai}"
          sleep "''${3:-45}"
          conn_of "$id" && exit 0
          out="$(diag "$id" || true)"
          title="$(printf '%s' "$out" | head -n 1)"
          body="$(printf '%s' "$out" | tail -n +2)"
          notify-send -a VPN -u critical -i network-vpn \
            "VPN ''${id^^}: $title" "$body" 2>/dev/null || true
          printf '%s\n' "$out" ;;
        # Saída estável p/ o pill do Quickshell (Bar.qml faz o polling a cada 5s).
        status-json)
          fai=false; ufscar=false
          fai_conn    && fai=true
          ufscar_conn && ufscar=true
          printf '{"vpns":[{"id":"fai","name":"FAI","connected":%s},{"id":"ufscar","name":"UFSCar","connected":%s}]}\n' "$fai" "$ufscar" ;;
        # REMOVIDO (30/07) o subcomando `menu`, que abria um rofi solto no meio da tela.
        # A UI agora é um popover ANCORADO na barra (quickshell/bar/VpnPopover.qml), no tema
        # do shell. Não é só estética: o menu do rofi montava os rótulos com `systemctl
        # is-active`, que MENTE (ver fai_conn/ufscar_conn acima) — ele dizia "Desconectar"
        # durante o crash-loop do nxBender, sem existir túnel. O popover lê o status-json,
        # que checa o túnel de verdade. Uma fonte de verdade só, e a correta.
        *) echo "uso: vpn connect|disconnect <ufscar|fai|all> | status-json | diagnose <id> | watch <id> [seg]" >&2; exit 1 ;;
      esac
    '';
  };
in
{
  environment.systemPackages = [ vpnCli ];

  # Watcher de conexão: quem o dispara é o próprio CLI (fai_up/ufscar_up), e ele existe
  # como UNIT DECLARADA e não como subshell em background de propósito — regra 15, dono
  # explícito. Um `&` solto no CLI ficaria parenteado ao Quickshell (que o invoca via
  # Process) e sumiria num restart do shell, justamente no minuto em que deveria avisar.
  # Template @<id> porque são duas VPNs com portais e sintomas diferentes.
  # É unidade de USUÁRIO porque quem entrega a notificação é o Quickshell, na sessão.
  systemd.user.services."vpn-watch@" = {
    description = "Diagnostica e notifica se a VPN %i não conectar";
    serviceConfig = {
      Type = "oneshot";
      ExecStart = "${vpnCli}/bin/vpn watch %i";
      # O `watch` sai calado quando conecta; isto corta o "Starting…/Finished…" que o
      # systemd loga sozinho (lição de bb8690c, os 2148 linhas/dia no journal).
      LogLevelMax = "warning";
    };
  };

  # Config do nxBender (FAI) renderizado pelo sops: params estáticos + a senha do cofre.
  # Vive em /run/secrets/rendered (root-only), nunca na store nem no git. A fingerprint
  # é do cert SELF-SIGNED da FAI (público, não é segredo) — sem ela o nxBender recusa o
  # SSL. Se a FAI trocar o certificado, pegar a nova:
  #   openssl s_client -connect 200.133.233.101:4433 | openssl x509 -noout -fingerprint -sha1
  #   (formato nxBender = sha1 minúsculo com ':').
  sops.templates."nxbender-fai.conf".content = ''
    server = 200.133.233.101
    port = 4433
    username = victor.ferreira
    domain = fai2008
    fingerprint = a9:db:84:93:e3:09:96:c7:33:6f:4d:05:ba:fa:1d:aa:59:0e:77:01
    password = ${config.sops.placeholder.fai_vpn_password}
  '';

  # UFSCar — GlobalProtect via openconnect; senha do sops por STDIN (não vaza no ps).
  # --authgroup escolhe o gateway (o portal oferece 5); senão o openconnect pede
  # interativamente e o serviço morre (stdin é só a senha → EOF).
  systemd.services.vpn-ufscar = {
    description = "VPN UFSCar (GlobalProtect via openconnect)";
    wants = [ "network-online.target" ];
    after = [ "network-online.target" ];
    restartIfChanged = false; # rebuild não derruba túnel em uso; o daemon-reload já aplica o Restart= novo
    # sem wantedBy → SOB DEMANDA (o CLI `vpn` liga)
    serviceConfig = {
      Type = "simple";
      ExecStart = pkgs.writeShellScript "vpn-ufscar-up" ''
        ${pkgs.coreutils}/bin/cat ${config.sops.secrets.ufscar_vpn_password.path} \
          | ${pkgs.openconnect}/bin/openconnect --protocol=gp --user=857722 \
              --authgroup=acessoremoto.ufscar.br --passwd-on-stdin acessoremoto-scl.ufscar.br
      '';
    } // vpnRestart;
    # `vpn disconnect` usa systemctl stop → o systemd NÃO reinicia (stop explícito não conta).
    startLimitIntervalSec = 0; # sem teto: quem segura o ritmo é o backoff acima
  };

  # FAI — SonicWall via nxBender, lendo o config renderizado pelo sops (com a senha).
  systemd.services.vpn-fai = {
    description = "VPN FAI (SonicWall via nxBender)";
    wants = [ "network-online.target" ];
    after = [ "network-online.target" ];
    restartIfChanged = false; # idem: reconectar a VPN é decisão sua, não efeito colateral de rebuild
    serviceConfig = {
      Type = "simple";
      ExecStart = "${pkgs.nxbender}/bin/nxBender -c ${config.sops.templates."nxbender-fai.conf".path}";
    } // vpnRestart;
    startLimitIntervalSec = 0;
  };

  # polkit: deixa o usuário ligar/desligar SÓ os serviços vpn-* sem senha (pro bind
  # funcionar sem prompt). Qualquer outra unidade continua exigindo autenticação.
  security.polkit.extraConfig = ''
    polkit.addRule(function(action, subject) {
      if (action.id == "org.freedesktop.systemd1.manage-units" &&
          subject.user == "v1cferr") {
        var unit = action.lookup("unit");
        if (unit == "vpn-ufscar.service" || unit == "vpn-fai.service") {
          return polkit.Result.YES;
        }
      }
    });
  '';
}
