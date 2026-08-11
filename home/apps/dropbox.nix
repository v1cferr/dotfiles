# ═══════════════════════════════════════════════════════════════════════════
# DROPBOX — pasta ~/Dropbox sincronizada (cofre do Obsidian + documentos).
#
# Exceção consciente à regra "home/ não instala": services.dropbox é um SERVIÇO
# do usuário (systemd --user), não um pacote no environment.systemPackages. O
# módulo do home-manager já traz o dropbox-cli e sobe o daemon — aqui só HABILITA.
#
# Por que o cliente oficial e não Maestral: o home-manager tem módulo oficial
# mantido pra este; o Maestral foi arquivado upstream, não tem módulo e tem bug
# conhecido no NixOS (perde config no logout, nixpkgs#307898).
#
# Uso previsto: só notas .md do Obsidian e documentos (plano grátis, 2 GB) —
# nada de binário/arquivo grande. O repo restic (backup pesado) NÃO vem pra cá.
#
# 1º uso / RE-vínculo: o daemon imprime uma URL pra autorizar no navegador
#   dropbox-hm status   # copie o link, autorize; NÃO use `dropbox status` (ver abaixo)
# O cliente baixa o próprio binário em ~/.dropbox-dist (estado, fora do Nix) —
# é a parte imperativa que o Dropbox impõe; o resto (habilitar/subir) é declarado.
#
# ── TRAY: O ÍCONE EXIGE SESSÃO, E ISSO CUSTA O 24/7 ────────────────────────
# O módulo do home-manager fixa `DISPLAY=` VAZIO na unit, de propósito: pra ele
# isto é um daemon headless. O preço é não haver ícone na tray — MEDIDO em
# 11/08/2026 no processo vivo: zero fd de Wayland/X11 aberto, e o watcher SNI
# listando LocalSend/Sunshine/Discord SEM o Dropbox. Nunca foi falha da barra.
#
# Aqui esse default é INVERTIDO, porque o ícone é pedido. Basta o daemon herdar o
# display da sessão pra ele registrar `dropbox_client_<pid>` no watcher na hora
# (medido). E a barra já sabe desenhá-lo: o `image://icon/<nome>?path=<dir>` que o
# Dropbox publica tem tratamento próprio em desktop/quickshell/bar/Bar.qml.
#
# Não se CRAVA `DISPLAY=:0`/`WAYLAND_DISPLAY=wayland-1` aqui: o nome do socket é da
# sessão, não do host, e amanhã é `wayland-2`. O autostart.lua já faz
# `systemctl --user import-environment WAYLAND_DISPLAY …`, então o gerenciador de
# usuário TEM as duas variáveis — o remédio é só PARAR de zerar o DISPLAY e deixar
# a unit herdar (por isso o `Environment` vai com mkForce, sem o `DISPLAY=`).
#
# O CUSTO, explícito: herdar display exige ser INICIADO pela sessão gráfica.
# `After=` sozinho não resolveria — quem levanta o graphical-session.target é o
# exec-once do compositor, FORA da transação do default.target, então no boot o
# serviço partia antes e caía em headless de novo (era o que se via: dropbox e
# quickshell ambos às 07:11:42). Logo o Install passa a ser
# graphical-session.target, e a consequência é honesta: SEM SESSÃO NÃO HÁ SYNC.
# Nesta máquina isso é barato (autologin, sempre ligada — system/core/users.nix),
# mas é troca de verdade, e herda a pegadinha já anotada em desktop/polkit-agent.nix
# (home-manager#8547): se um dia o graphical-session.target ficar inativo, o sync
# para junto. É por isso que o watcher do bloco 2 também LOGA em nível warning, e
# não só notifica: sem sessão não há toast pra ver, mas o journal continua lá.
#
# ── O INCIDENTE QUE ESTE ARQUIVO EXISTE PRA NÃO REPETIR ─────────────────────
# Descoberto em 11/08/2026: o daemon estava `active (running)` há 6 h, sem uma
# linha de erro… e DESVINCULADO desde ~01/08 (`unlink.db` reescrito; hostkeys e
# sync_history.db congelados em 31/07). Ou seja: 10 dias sem sincronizar NADA, com
# o serviço se declarando saudável. Duas causas independentes, e cada uma tem seu
# remédio aqui embaixo:
#   1. systemd NÃO percebia morte do daemon  → ExitType/Restart (bloco 1)
#   2. NADA percebia o "vivo mas desvinculado" → healthcheck (bloco 2)
# ═══════════════════════════════════════════════════════════════════════════
{
  config,
  lib,
  osConfig,
  pkgs,
  ...
}:

let
  enabled = osConfig.my.services.dropbox;

  # O daemon roda com HOME PRÓPRIO (~/.dropbox-hm) — decisão do módulo do
  # home-manager, não deste repo. E a CLI só acha o socket do daemon se herdar o
  # MESMO HOME: no shell normal, `dropbox status` responde "Dropbox isn't
  # running!" com o daemon vivo do lado. Essa MENTIRA é o que faz o diagnóstico
  # à mão dar errado (foi como o incidente acima passou batido) — daí o wrapper.
  dropboxHome = "${config.home.homeDirectory}/.dropbox-hm";
  dropboxCmd = lib.getExe' config.services.dropbox.package "dropbox";

  # A CLI com o HOME certo: `dropbox-hm status`, `dropbox-hm start`, `… exclude`.
  # Não reinstala o dropbox-cli — referencia o MESMO store path do módulo, igual
  # o autostart faz com o LocalSend (não fere a regra 4).
  dropboxHm = pkgs.writeShellApplication {
    name = "dropbox-hm";
    text = ''
      export HOME=${lib.escapeShellArg dropboxHome}
      exec ${dropboxCmd} "$@"
    '';
  };

  linkWatch = pkgs.writeShellApplication {
    name = "dropbox-link-watch";
    runtimeInputs = with pkgs; [
      coreutils
      libnotify
    ];
    text = ''
          # `timeout` porque a CLI BLOQUEIA esperando o socket do daemon: daemon
          # pendurado penduraria o timer junto — e timer preso não avisa nada, que é
          # exatamente o modo de falha que este script existe pra cobrir.
          out="$(timeout 30 ${dropboxHm}/bin/dropbox-hm status 2>&1 || true)"

          # `case` e NUNCA `grep -q`: com o pipefail do writeShellApplication o grep
          # sai no 1º match, o produtor morre de SIGPIPE e o pipeline retorna ERRO
          # apesar do match (mesma pegadinha já anotada em home/net/mega.nix).
          # Os textos vêm da CLI oficial: "To link this computer to a Dropbox
          # account, visit the following url" e "Dropbox isn't running!".
          case "$out" in
            *"To link this computer"*) estado=desvinculado ;;
            *"isn't running"*) estado=morto ;;
            *) estado=ok ;;
          esac

          state="''${XDG_RUNTIME_DIR:-/tmp}/dropbox-link-watch.state"
          if [ "$estado" = ok ]; then
            rm -f "$state" # voltou ao normal → a próxima quebra avisa na hora
            exit 0
          fi

          # Anti-spam, mesmo idioma do disk-watch: 12 h por estado. Sem isto um
          # desvínculo viraria uma notificação a cada 30 min e a pessoa aprenderia a
          # ignorar — alarme que cansa é alarme que não protege.
          now="$(date +%s)"
          if [ -f "$state" ]; then
            read -r last_estado last_ts < "$state" || true
            if [ "$last_estado" = "$estado" ] && [ "$((now - last_ts))" -lt 43200 ]; then
              exit 0
            fi
          fi

          # Só NOTIFICA, nunca reinicia: quem sustenta o daemon de pé é o systemd
          # (bloco 1). Dois donos pra mesma automação é a regra 15 — e no caso do
          # desvínculo reiniciar não resolveria nada, porque religar exige autorizar
          # no NAVEGADOR: é imperativo por imposição do Dropbox, não por preguiça.
          case "$estado" in
            desvinculado)
              titulo="Dropbox DESVINCULADO — nada está sincronizando"
              corpo="O daemon está de pé, mas sem conta. Religue com:
      dropbox-hm status   (copie a URL e autorize no navegador)"
              ;;
            *)
              titulo="Dropbox fora do ar"
              corpo="O daemon não respondeu. Investigue com:
      systemctl --user status dropbox"
              ;;
          esac

          # `<4>` é o prefixo de nível do systemd (warning) — sem ele a linha sairia
          # em `info` e o LogLevelMax=warning da unit a ENGOLIRIA. Loga SEMPRE, não
          # só quando o toast falha: o sync agora depende do graphical-session
          # (ver cabeçalho), e se essa sessão for justamente o que quebrou não há
          # notification daemon pra receber o aviso. O journal é o fallback.
          printf '<4>%s — %s\n' "$titulo" "$estado" >&2
          notify-send -a "Dropbox" -u critical -i dropbox "$titulo" "$corpo" || true

          printf '%s %s\n' "$estado" "$now" > "$state"
    '';
  };
in
{
  services.dropbox.enable = enabled; # pasta padrão: ~/Dropbox

  home.packages = lib.mkIf enabled [ dropboxHm ];

  # ── BLOCO 1: fazer o systemd PERCEBER a morte do daemon ────────────────────
  # O módulo do home-manager entrega Type=forking + PIDFile + Restart=on-failure,
  # e o systemd loga a cada partida:
  #   "Supervising process 1806 which is not our child. We'll most likely not
  #    notice when it exits."
  # Isso não é ruído: é o systemd DIZENDO que o Restart=on-failure dele é
  # decorativo. O `dropbox start` da CLI faz double-fork e o processo do PIDFile
  # não é filho do systemd, então a morte não chega como SIGCHLD — o serviço
  # ficaria `active` com o daemon já morto, e nada reiniciaria.
  #
  # ExitType=cgroup troca o critério: a unit está viva enquanto HOUVER processo no
  # cgroup dela, e o cgroup o systemd controla de verdade (o daemon não escapa
  # dele — conferido no `systemctl status`, PIDs 1797/1806 ambos dentro).
  # Requer systemd ≥ 250; esta máquina está na 260.
  #
  # `always` e não `on-failure` — e aqui a escolha é o OPOSTO da do
  # home/desktop/autostart.nix, de propósito: lá fechar o app na mão é uma
  # decisão a respeitar; aqui um daemon de sync parado é sempre defeito, inclusive
  # quando quem o parou foi `dropbox-hm stop`. `systemctl --user stop dropbox`
  # continua parando de verdade (stop explícito nunca dispara Restart).
  systemd.user.services.dropbox = lib.mkIf enabled {
    Unit = {
      # Com `always` + RestartSec=10, um crash-loop de verdade estoura o limite e
      # a unit MORRE visível em `systemctl --user --failed`, em vez de reiniciar
      # calada pra sempre — a lição das 4145 partidas do Spotify (ver autostart).
      StartLimitIntervalSec = 300;
      StartLimitBurst = 5;
      # Preso à sessão porque é ela que dá o display do ícone (ver cabeçalho).
      # Mesmo trio dos autostart-* e do polkit-agent: PartOf pra cair junto, After
      # pra ordenar, e o WantedBy lá embaixo pra SUBIR junto.
      PartOf = [ "graphical-session.target" ];
      After = [ "graphical-session.target" ];
    };
    Service = {
      ExitType = "cgroup";
      Restart = lib.mkForce "always"; # mkForce: o módulo já define on-failure
      RestartSec = 10;
      # mkForce e não um item a mais: `Environment` é LISTA, e uma 2ª entrada
      # `DISPLAY=…` dependeria da ORDEM de merge do módulo pra vencer o
      # `DISPLAY=` vazio do upstream — ordem que ninguém garante. Reescrever a
      # lista inteira é determinístico. Fica só o HOME; DISPLAY e WAYLAND_DISPLAY
      # vêm HERDADOS do gerenciador de usuário (import-environment do
      # desktop/hypr/lua/autostart.lua), que é o que evita cravar `wayland-1`.
      Environment = lib.mkForce [ "HOME=${dropboxHome}" ];
    };
    # mkForce: o módulo declara `default.target`, e MANTER os dois seria pior que
    # não mexer — no boot o default.target subiria o daemon ANTES da sessão, em
    # headless e sem ícone, e o graphical-session.target depois não o reiniciaria
    # (unit já ativa não parte de novo). Aqui só a sessão inicia.
    Install.WantedBy = lib.mkForce [ "graphical-session.target" ];
  };

  # ── BLOCO 2: perceber o "vivo mas não sincroniza" ─────────────────────────
  # O bloco 1 cobre o daemon MORTO. O modo de falha que custou 10 dias é outro: o
  # daemon vivo, `active`, exit 0, log limpo — e desvinculado. Nenhuma métrica de
  # processo enxerga isso, então o único jeito é PERGUNTAR pra ele, igual ao probe
  # ativo do Sunshine (system/services/sunshine.nix).
  #
  # Preso ao graphical-session.target porque o remédio é uma notificação: sem
  # sessão não há notification daemon pra receber, e o alarme se perderia. O
  # daemon do Dropbox NÃO fica preso à sessão (segue 24/7 com linger) — só o
  # aviso é que precisa de alguém na frente da tela pra ter sentido.
  systemd.user.services.dropbox-link-watch = lib.mkIf enabled {
    Unit = {
      Description = "Avisa se o Dropbox está no ar mas não sincronizando (desvinculado)";
      PartOf = [ "graphical-session.target" ];
      After = [ "graphical-session.target" ];
      StartLimitIntervalSec = 3600;
      StartLimitBurst = 5;
    };
    Service = {
      Type = "oneshot";
      ExecStart = "${linkWatch}/bin/dropbox-link-watch";
      # O script sai calado quando está tudo bem; isto corta o "Starting…/
      # Finished…" que o SYSTEMD loga sozinho a cada disparo (mesma lição de
      # bb8690c, onde dois timers somaram 2148 linhas/dia no journal).
      LogLevelMax = "warning";
    };
    Install.WantedBy = [ "graphical-session.target" ];
  };

  systemd.user.timers.dropbox-link-watch = lib.mkIf enabled {
    Unit.Description = "Checagem periódica do vínculo do Dropbox";
    Timer = {
      # 3min: o daemon precisa subir e handshake com a nuvem antes do 1º probe,
      # senão o estado transitório de partida viraria alarme falso.
      OnActiveSec = "3min";
      # 30min é resolução de sobra: desvínculo não se resolve sozinho, e o
      # prejuízo cresce em dias (10, no incidente), não em minutos.
      OnUnitActiveSec = "30min";
    };
    Install.WantedBy = [ "timers.target" ];
  };
}
