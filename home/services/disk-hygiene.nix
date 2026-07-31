# ═══════════════════════════════════════════════════════════════════════════
# HIGIENE DE DISCO — alarme de espaço livre + expiração da lixeira.
#
# POR QUE ISTO EXISTE, e por que NÃO é mais GC: o GC do Nix já é automático
# (system/core/core.nix) e funciona, mas MEDIDO em 30/07 ele cobre 9% do disco —
# /nix/store tinha 58 GiB contra 626 GiB usados. Os outros 91% são jogos e mídia
# (Bottles 319 GiB, Jellyfin 132, Games 47, Steam 8), e NADA disso pode ser
# apagado automaticamente: ninguém deve deletar o jogo de alguém por conta
# própria. Então a resposta certa p/ "não deixar o disco encher" não é apagar
# mais — é AVISAR com dado suficiente p/ o dono decidir.
#
# DUAS COISAS, de naturezas diferentes, juntas porque são a mesma tarefa
# (manter o disco sob controle) e ambas são timer de usuário:
#   • disk-watch  → alarme: notifica quando o livre cai, JÁ COM os maiores
#                   consumidores na mensagem (o pedido era "avaliar se quero
#                   remover", e p/ isso a notificação precisa dizer O QUE cresceu).
#   • trash-expire→ a lixeira era o único lixo REAL achado na medição: 1.7 GiB
#                   parados, que ninguém expirava e que o restic já exclui do
#                   backup (restic.nix) — ou seja, desperdício puro.
#
# DESENHO do alarme (o motivo de ser em duas fases): `du` na árvore inteira leva
# MINUTOS nesta máquina (medido). Rodar isso a cada 30 min seria absurdo. Então o
# timer faz só o check BARATO (`df`, instantâneo) e a varredura CARA só acontece
# quando o disco de fato está baixo — momento em que gastar alguns minutos é
# exatamente o que se quer. `nice`+`ionice` p/ não competir com a sessão.
#
# ANTI-SPAM: notificação que repete a cada 30 min vira ruído e passa a ser
# ignorada — o mesmo erro dos meus timers que afogaram o journal (ver bb8690c).
# Reavisa no máximo 1×/12h por severidade, mas IMEDIATAMENTE se a severidade
# subir (warn → crit). O estado mora em $XDG_RUNTIME_DIR, que zera no boot.
#
# DONO (regra 15): timer systemd --user, preso ao graphical-session — precisa da
# sessão porque quem entrega a notificação é o Quickshell (daemon de
# org.freedesktop.Notifications).
# ═══════════════════════════════════════════════════════════════════════════
{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.my.disk;

  # Lista de caminhos como argumentos de shell, já com aspas.
  watchArgs = lib.escapeShellArgs cfg.watchPaths;

  diskWatch = pkgs.writeShellApplication {
    name = "disk-watch";
    runtimeInputs = with pkgs; [ coreutils libnotify util-linux gnused gawk ];
    text = ''
      # --- fase 1: check barato -------------------------------------------
      # `df --output=avail -BG` sai como "  123G"; tira o G e o espaço.
      free="$(df --output=avail -BG ${lib.escapeShellArg cfg.filesystem} | tail -1 | tr -dc '0-9')"
      [ -n "$free" ] || exit 0   # df falhou (fs sumiu?) → não inventa alarme

      if   [ "$free" -lt ${toString cfg.critFreeGiB} ]; then sev=crit
      elif [ "$free" -lt ${toString cfg.warnFreeGiB} ]; then sev=warn
      else sev=ok
      fi

      state="''${XDG_RUNTIME_DIR:-/tmp}/disk-watch.state"
      if [ "$sev" = ok ]; then
        rm -f "$state"   # voltou ao normal → o próximo aperto avisa na hora
        exit 0
      fi

      # --- anti-spam ------------------------------------------------------
      now="$(date +%s)"
      if [ -f "$state" ]; then
        read -r last_sev last_ts < "$state" || true
        # mesma severidade e faz menos de 12h → cala. Severidade que SUBIU passa.
        if [ "$last_sev" = "$sev" ] && [ "$((now - last_ts))" -lt 43200 ]; then
          exit 0
        fi
      fi

      # --- fase 2: varredura CARA, só agora -------------------------------
      # MiB p/ poder ordenar numericamente; formata em GiB na saída. `|| true`:
      # caminho inexistente ou sem permissão não pode derrubar o alarme.
      body="$(
        nice -n 19 ionice -c 3 du -sx --block-size=1M ${watchArgs} 2>/dev/null \
          | sort -rn \
          | head -n ${toString cfg.topN} \
          | awk -v home="$HOME" '{
              size = $1 / 1024
              $1 = ""
              sub(/^ /, "")
              path = $0
              sub("^" home, "~", path)
              printf "%6.1f GiB  %s\n", size, path
            }' || true
      )"

      case "$sev" in
        crit) urgency=critical; title="Disco crítico — $free GiB livres" ;;
        *)    urgency=normal;   title="Disco baixo — $free GiB livres" ;;
      esac

      notify-send -a "Disco" -u "$urgency" -i drive-harddisk \
        "$title" "$body" || true

      printf '%s %s\n' "$sev" "$now" > "$state"
    '';
  };

  trashExpire = pkgs.writeShellApplication {
    name = "trash-expire";
    runtimeInputs = [ pkgs.trash-cli ];
    text = ''
      # -f = não pergunta (o default só pergunta com -i, mas em timer é melhor
      # ser explícito: unit que espera resposta fica pendurada p/ sempre).
      trash-empty -f ${toString cfg.trashDays}
    '';
  };
in
{
  options.my.disk = {
    filesystem = lib.mkOption {
      type = lib.types.str;
      default = "/";
      description = "Filesystem observado pelo alarme (df).";
    };
    warnFreeGiB = lib.mkOption {
      type = lib.types.int;
      default = 100;
      description = "Abaixo disto, notifica (urgência normal).";
    };
    critFreeGiB = lib.mkOption {
      type = lib.types.int;
      default = 40;
      description = "Abaixo disto, notifica como crítico (fica na tela).";
    };
    topN = lib.mkOption {
      type = lib.types.int;
      default = 5;
      description = "Quantos maiores consumidores listar na notificação.";
    };
    trashDays = lib.mkOption {
      type = lib.types.int;
      default = 30;
      description = "Idade em dias p/ a lixeira expirar sozinha.";
    };
    watchPaths = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      description = "Caminhos medidos quando o alarme dispara (os suspeitos de peso).";
    };
  };

  config = {
    # ── PAINEL: limiares e o que medir ─────────────────────────────────────
    # 100/40 GiB e não porcentagem: o que importa é se cabe o PRÓXIMO jogo ou
    # patch, e isso é um número absoluto. (Aqui são 915 G no total; em 30/07
    # havia 243 GiB livres, então 100 dá aviso com folga real p/ decidir.)
    my.disk = {
      warnFreeGiB = 100;
      critFreeGiB = 40;
      # Os pesos medidos em 30/07, do maior p/ o menor. NÃO é `du /` inteiro de
      # propósito: varrer tudo levaria minutos a mais e traria ruído (/proc,
      # /sys, mounts de rede). Se aparecer um consumidor novo fora desta lista,
      # é 1 linha aqui — e o filelight/czkawka existem justamente p/ descobrir.
      watchPaths = [
        "${config.home.homeDirectory}/.local/share/bottles" # 319 GiB (Wine/Bottles: Battlenet, CS-II, Ascension)
        "/srv/media" # 132 GiB — biblioteca do Jellyfin
        "${config.home.homeDirectory}/Games" # 47 GiB
        "/nix/store" # 58 GiB — quem cuida é o GC (core.nix), não dá p/ apagar à mão
        "${config.home.homeDirectory}/.local/share/Steam" # 8 GiB
        "${config.home.homeDirectory}/.cache" # 3.9 GiB
        "${config.home.homeDirectory}/Downloads" # 2.5 GiB
        "${config.home.homeDirectory}/.local/share/Trash" # 1.7 GiB (expira sozinha, abaixo)
      ];
    };

    home.packages = [ diskWatch trashExpire ];

    # ── Alarme de espaço ───────────────────────────────────────────────────
    systemd.user.services.disk-watch = {
      Unit = {
        Description = "Alarme de espaço em disco (notifica com os maiores consumidores)";
        PartOf = [ "graphical-session.target" ];
        After = [ "graphical-session.target" ];
        StartLimitIntervalSec = 3600;
        StartLimitBurst = 5;
      };
      Service = {
        Type = "oneshot";
        ExecStart = "${diskWatch}/bin/disk-watch";
        # O script já sai calado quando não há nada a dizer; isto corta o
        # "Starting…/Finished…" que o SYSTEMD loga por conta própria — a lição
        # de bb8690c, onde dois timers meus somaram 2148 linhas/dia no journal.
        LogLevelMax = "warning";
      };
      Install.WantedBy = [ "graphical-session.target" ];
    };

    systemd.user.timers.disk-watch = {
      Unit.Description = "Checagem periódica de espaço em disco";
      Timer = {
        OnActiveSec = "2min"; # dá tempo da sessão subir antes do 1º check
        OnUnitActiveSec = "30min";
      };
      Install.WantedBy = [ "timers.target" ];
    };

    # ── Expiração da lixeira ───────────────────────────────────────────────
    systemd.user.services.trash-expire = {
      Unit.Description = "Expira itens da lixeira com mais de ${toString cfg.trashDays} dias";
      Service = {
        Type = "oneshot";
        ExecStart = "${trashExpire}/bin/trash-expire";
        LogLevelMax = "warning";
      };
    };

    systemd.user.timers.trash-expire = {
      Unit.Description = "Expiração diária da lixeira";
      Timer = {
        OnCalendar = "daily";
        Persistent = true; # máquina desligada na hora marcada → roda no próximo boot
      };
      Install.WantedBy = [ "timers.target" ];
    };
  };
}
