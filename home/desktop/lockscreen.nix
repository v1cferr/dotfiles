# TELA DE BLOQUEIO + OCIOSIDADE — hyprlock (lock) + hypridle (idle), declarados.
#
# Filosofia deste módulo: NADA de scripts .sh soltos. A lógica pesada mora onde é
# declarativa e reprodutível — no BUILD (Nix puro) ou no SYSTEMD — e o runtime é
# só comando de 1 linha, com binário por caminho ABSOLUTO (${pkgs...}/bin/x), sem
# depender de PATH. Assim isto sobrevive a upgrades (durável 2032+):
#   • quote   → serviço+timer systemd busca um lote da ZenQuotes API 1×/dia, traduz
#               p/ pt-BR (DeepL) e formata em pango num cache; no lock só `shuf -n1`.
#   • weather → um serviço+timer systemd busca o wttr.in a cada 10 min p/ um cache;
#               no lock só roda `cat`. Fonte estável, sem raspar HTML.
#   • idle    → só TRANCA aos 5min (loginctl lock-session). SEM dpms-off — ver ponto 3.
#   • lock    → `hyprlock.service`, unit DECLARADA. Trancar não depende do hypridle
#               estar vivo; ver o bloco da unit para o incidente que motivou isso.
#
# Regra da pasta: apps de USUÁRIO → home/. programs.hyprlock instala o hyprlock e
# services.hypridle sobe o daemon (systemd --user, igual ao hyprsunset). Por isso o
# hypridle saiu do system/packages.nix. PAM (system/desktop.nix) é OBRIGATÓRIO —
# sem ele o hyprlock não autentica e TRANCA você pra fora. Locale pt_BR
# (system/core.nix) é p/ a data por extenso do relógio.
#
# APRENDIZADOS DE HARDWARE (duráveis, independem da GPU), NÃO mexer:
#   1. Wallpaper ESTÁTICO, nunca `path = screenshot`: o screencopy/DMA segfalha o
#      hyprlock ao acordar do idle (frame DMA destruído no exit → lockout).
#   2. Nada de GIF/reload contínuo: o gatherer assíncrono corre com o exit() e
#      corrompe a heap (SIGABRT no unlock).
#   3. dpms-off REMOVIDO (jul/2026): desligar a tela no idle BUGAVA o acesso remoto —
#      o Sunshine (captura wlr no driver xe) pegava TELA PRETA do monitor apagado, e
#      alternar dpms sob captura deu ENGINE-RESET da GPU (xe RCS, travou o scanout).
#      Agora o idle SÓ tranca. Se um dia quiser escurecer, use gamma do hyprsunset.
# Ref: https://wiki.hypr.land/Hypr-Ecosystem/hyprlock/
{
  config,
  pkgs,
  osConfig,
  ...
}:

let
  # ── Wallpapers: oficiais do NixOS via pkgs.nixos-artwork (declarativos, sem
  #    binário no git; bump junto com o nixpkgs). ──
  art = pkgs.nixos-artwork.wallpapers;
  wallMain = "${art.catppuccin-mocha}/share/backgrounds/nixos/nixos-wallpaper-catppuccin-mocha.png"; # principal (borrado no lock)
  wallTv = "${art.moonscape}/share/backgrounds/nixos/nix-wallpaper-moonscape.png"; # TV (imagem estática, sem login)

  # ── Monitores: SSOT em system/desktop/monitors.nix (regra 11) ────────────────
  primary = osConfig.my.monitors.primary; # LG ULTRAGEAR — desktop borrado + login
  secondary = osConfig.my.monitors.secondary; # TV — imagem estática + cadeado

  # ── Cores do tema ativo (my.theme) + fonte ───────────────────────────────────
  palette = config.my.theme.palette; # fonte única (home/desktop/palette.nix)
  font = osConfig.my.fonts.ui; # SSOT (system/hardware/fonts.nix)
  bg = "rgba(${palette.bg}d9)"; # fundo do lock (d9 ≈ 85% opacidade)
  fg = "rgb(${palette.text})";
  muted = "rgb(${palette.dim})";
  blue = "rgba(${palette.blue}ee)";
  magenta = "rgba(${palette.magenta}ee)";
  green = "rgba(${palette.green}ee)";
  red = "rgba(${palette.red}ee)";

  # ── Binários por caminho absoluto (não dependem de PATH — durável) ────────────
  hyprlockBin = "${pkgs.hyprlock}/bin/hyprlock";
  pidof = "${pkgs.procps}/bin/pidof"; # ExecCondition da unit: não sobe 2º hyprlock
  loginctlBin = "${pkgs.systemd}/bin/loginctl";
  systemctlBin = "${pkgs.systemd}/bin/systemctl";
  shuf = "${pkgs.coreutils}/bin/shuf";
  catBin = "${pkgs.coreutils}/bin/cat";

  # ── Quote: cache atualizado por timer systemd (ZenQuotes + DeepL; runtime = shuf -n1)
  # Substituiu o quotes.tsv vendorizado. O timer busca um LOTE (~50) do zenquotes.io
  # /api/quotes (EN), filtra (não-vazio, <=120 chars, sem o placeholder de rate-limit)
  # e TRADUZ p/ pt-BR via DeepL (chave em /run/secrets/deepl_api_key, sops) — só as
  # FRASES num único request em lote; o autor fica no original. Escapa &<> (pango) e
  # grava atômico; o lock só roda shuf -n1. FALLBACK seguro: sem chave/DeepL fora →
  # usa o lote em INGLÊS; sem rede na 1ª vez → uma frase embutida (pt-BR).
  quotesCache = "${config.xdg.cacheHome}/lockscreen/quotes";
  deeplKeyFile = "/run/secrets/deepl_api_key"; # sops (owner v1cferr); ausente ⇒ mantém EN
  quotesFetch = pkgs.writeShellScript "lockscreen-quotes-fetch" ''
    ${pkgs.coreutils}/bin/mkdir -p ${config.xdg.cacheHome}/lockscreen
    tmp="${quotesCache}.tmp"
    ${pkgs.coreutils}/bin/rm -f "$tmp"

    # 1) Lote EN filtrado → array compacto [{q,a}] (q=frase, a=autor).
    filtered="$(${pkgs.curl}/bin/curl -s --max-time 15 'https://zenquotes.io/api/quotes' \
      | ${pkgs.jq}/bin/jq -c '[.[]
          | select((.q | length) > 0 and (.q | length) <= 120 and .a != "zenquotes.io")
          | {q, a}]' 2>/dev/null || true)"

    # 2) Se há lote e a chave do DeepL existe, traduz as FRASES (1 request em lote,
    #    target PT-BR) e recombina com o autor original NA ORDEM. Erro/len divergente
    #    → 'translated' vazio ⇒ cai no EN adiante.
    translated=""
    if [ -n "$filtered" ] && [ "$filtered" != "[]" ] && [ -r "${deeplKeyFile}" ]; then
      key="$(${pkgs.coreutils}/bin/cat "${deeplKeyFile}")"
      payload="$(${pkgs.coreutils}/bin/printf '%s' "$filtered" \
        | ${pkgs.jq}/bin/jq -c '{text: [.[].q], target_lang: "PT-BR", source_lang: "EN"}')"
      resp="$(${pkgs.curl}/bin/curl -s --max-time 30 \
        -H "Authorization: DeepL-Auth-Key $key" -H 'Content-Type: application/json' \
        -d "$payload" 'https://api-free.deepl.com/v2/translate' 2>/dev/null || true)"
      translated="$(${pkgs.jq}/bin/jq -cn --argjson f "$filtered" --argjson r "$resp" \
        'if ($r.translations | type) == "array" and ($r.translations | length) == ($f | length)
         then [range(0; ($f | length)) | {q: $r.translations[.].text, a: $f[.].a}]
         else empty end' 2>/dev/null || true)"
    fi

    # 3) Fonte final: traduzida se deu certo, senão o lote EN. Formata em pango.
    src=""
    if   [ -n "$translated" ] && [ "$translated" != "null" ] && [ "$translated" != "[]" ]; then src="$translated"
    elif [ -n "$filtered" ]   && [ "$filtered"   != "[]" ];                                 then src="$filtered"
    fi
    if [ -n "$src" ]; then
      ${pkgs.coreutils}/bin/printf '%s' "$src" | ${pkgs.jq}/bin/jq -r '.[]
          | "<i>“" + (.q | gsub("&";"&amp;") | gsub("<";"&lt;") | gsub(">";"&gt;")) + "”</i>  <b>— "
            + (.a | gsub("&";"&amp;") | gsub("<";"&lt;") | gsub(">";"&gt;")) + "</b>"' > "$tmp" 2>/dev/null || true
    fi

    # 4) Publica atômico se deu certo; senão descarta e mantém o cache anterior.
    if [ -s "$tmp" ]; then ${pkgs.coreutils}/bin/mv "$tmp" ${quotesCache}; else ${pkgs.coreutils}/bin/rm -f "$tmp"; fi
    # fallback: garante ao menos 1 frase (1º boot sem rede) p/ o shuf não vir vazio.
    [ -s ${quotesCache} ] || echo '<i>“A melhor forma de prever o futuro é inventá-lo.”</i>  <b>— Alan Kay</b>' > ${quotesCache}
  '';

  # ── Weather: cache atualizado por timer systemd (wttr.in; runtime = cat) ───────
  weatherDir = "${config.xdg.cacheHome}/lockscreen";
  weatherCache = "${weatherDir}/weather";
  # São Carlos/SP por COORDENADAS (sem ambiguidade de geocoding). Escreve atômico
  # (.tmp + mv) p/ o hyprlock nunca ler um cache pela metade.
  weatherFetch = pkgs.writeShellScript "lockscreen-weather-fetch" ''
    ${pkgs.coreutils}/bin/mkdir -p ${weatherDir}
    ${pkgs.curl}/bin/curl -s --max-time 15 -H 'Accept-Language: pt' \
      'https://wttr.in/-22.0087,-47.8909?format=%C,+%t' -o ${weatherCache}.tmp \
      && ${pkgs.coreutils}/bin/mv ${weatherCache}.tmp ${weatherCache}
  '';
in
{
  # ── hyprlock: a tela de bloqueio em si ───────────────────────────────────────
  programs.hyprlock = {
    enable = true;
    settings = {
      general.hide_cursor = true; # some o cursor no lock

      # Fade suave ao entrar/sair (bezier vai pro topo do bloco via importantPrefixes)
      animations = {
        enabled = true;
        bezier = "easeOut, 0.25, 1, 0.5, 1";
        animation = [
          "fadeIn, 1, 4, easeOut"
          "fadeOut, 1, 4, easeOut"
          "inputFieldDots, 1, 2, easeOut"
        ];
      };

      # Fundos: principal borrado (blur nativo do hyprlock) + TV estática.
      background = [
        {
          monitor = primary;
          path = "${wallMain}"; # PNG nítido; o hyprlock faz o blur/brilho
          blur_passes = 2; # aliviado de 3 → a wallpaper aparece mais (widgets seguem legíveis)
          blur_size = 6;
          noise = 0.012;
          contrast = 0.92;
          brightness = 0.40; # escuro o bastante p/ o relógio/frase ficarem bem legíveis (a wallpaper ainda aparece)
          vibrancy = 0.17;
        }
        {
          monitor = secondary;
          color = "rgba(${palette.bg}ff)"; # fallback enquanto a imagem carrega
          path = "${wallTv}";
        }
      ];

      # Campo de senha (só no monitor principal).
      input-field = {
        monitor = primary;
        size = "340, 56";
        outline_thickness = 2;
        rounding = 14;
        inner_color = bg;
        font_color = fg;
        font_family = font;
        outer_color = "${blue} ${magenta} 45deg"; # borda gradiente
        check_color = "${green} ${blue} 120deg"; # verificando a senha
        fail_color = red; # senha errada
        placeholder_text = ''<span foreground="##${palette.dim}">Digite a senha…</span>'';
        fail_text = ''<span foreground="##f7768e">$PAMFAIL</span>'';
        dots_spacing = 0.3;
        fade_on_empty = false;
        position = "0, -190";
        halign = "center";
        valign = "center";
      };

      label = [
        # Relógio grande (com segundos)
        {
          monitor = primary;
          text = ''cmd[update:1000] date +"%H:%M:%S" '';
          color = fg;
          font_size = 130;
          font_family = "${font} ExtraBold";
          position = "0, 220";
          halign = "center";
          valign = "center";
        }
        # Data completa em pt-BR (a LOCKSCREEN é exceção: full pt-BR mesmo com o
        # sistema em en-US) — LC_TIME pt_BR pra data por extenso; sed capitaliza a
        # 1ª letra + nº da semana.
        {
          monitor = primary;
          text = ''cmd[update:60000] LC_TIME=pt_BR.UTF-8 date +"%A, %d de %B de %Y  ·  Semana %V" | sed 's/./\u&/' '';
          color = muted;
          font_size = 22;
          font_family = font;
          position = "0, 110";
          halign = "center";
          valign = "center";
        }
        # Usuário logado
        {
          monitor = primary;
          text = "   ${config.home.username}";
          color = fg;
          font_size = 16;
          font_family = font;
          position = "0, -120";
          halign = "center";
          valign = "center";
        }
        # Frase no rodapé esquerdo (cache da ZenQuotes API atualizado por timer → shuf -n1)
        {
          monitor = primary;
          text = "cmd[update:150000] ${shuf} -n1 ${quotesCache}";
          color = "rgba(c0caf5cc)";
          font_size = 13;
          font_family = font;
          position = "40, 40";
          halign = "left";
          valign = "bottom";
        }
        # Clima no canto superior esquerdo (só lê o cache do timer systemd)
        {
          monitor = primary;
          text = "cmd[update:60000] ${catBin} ${weatherCache} 2>/dev/null";
          color = fg;
          font_size = 18;
          font_family = font;
          position = "40, -40";
          halign = "left";
          valign = "top";
        }
        # Cadeado discreto na TV
        {
          monitor = secondary;
          text = "󰌾";
          color = "rgba(c0caf5aa)";
          font_size = 28;
          font_family = font;
          position = "-40, -30";
          halign = "right";
          valign = "top";
        }
      ];
    };
  };

  # ── hyprlock como UNIT DECLARADA: TRANCAR NÃO PODE DEPENDER DO HYPRIDLE ──────
  # Até 10/08/2026 o único caminho pra trancar era `loginctl lock-session`, que NÃO
  # tranca nada sozinho: só marca LockedHint e emite o sinal Lock no D-Bus. Quem
  # escutava e subia o hyprlock era o hypridle, via lock_cmd. Consequência: com o
  # hypridle parado, o sinal caía no VAZIO — o botão "Bloquear" da barra clicava e
  # não acontecia nada, sem erro nenhum. Foi o que houve por 6h em 10/08/2026, com o
  # guard do Sunshine (../..//system/services/sunshine.nix) segurando o hypridle
  # parado depois de um cliente morrer sem teardown.
  #
  # É a dependência errada: bloquear a tela é FUNÇÃO DE SEGURANÇA, e não pode ficar
  # refém de um daemon de OCIOSIDADE que qualquer coisa pode parar (o guard do
  # Sunshine, a pill da barra, um crash). Agora o hyprlock é uma unit própria e quem
  # quer trancar dá `systemctl --user start hyprlock.service`, direto.
  #
  # UNIT PRÓPRIA, e não `systemd-run` transiente (que era o truque anterior), pelo
  # mesmo motivo de antes MAIS dois: continua FORA do cgroup do hypridle.service —
  # o que impede o LOCKOUT REMOTO diagnosticado em 03/08/2026, quando
  # `systemctl --user stop hypridle` do guard do Sunshine matava o cgroup inteiro
  # (KillMode=control-group) e levava junto o hyprlock, deixando o compositor
  # TRANCADO SEM CLIENTE pra desenhar o campo de senha. E de quebra:
  #   • idempotência de graça — `start` numa unit já ativa é no-op, então o antigo
  #     `pidof hyprlock ||` sai de cena. Duas superfícies de session-lock confundem
  #     o grab do teclado e o campo de senha para de digitar; o systemd garante uma.
  #   • o nome não fica ocupado após o unlock (era o papel do `--collect`).
  # O env (WAYLAND_DISPLAY, HYPRLAND_INSTANCE_SIGNATURE) vem do systemd --user, que
  # a sessão já importa. Sem Restart: hyprlock que sai é unlock, não falha a reerguer.
  systemd.user.services.hyprlock = {
    Unit = {
      Description = "Tela de bloqueio (hyprlock)";
      # Sem sessão gráfica não há o que trancar — e o lock morre junto com ela.
      PartOf = [ "graphical-session.target" ];
      After = [ "graphical-session.target" ];
    };
    Service = {
      Type = "simple"; # roda enquanto a tela está trancada; sai no unlock
      # Herdeiro do antigo `pidof hyprlock ||`: cobre o hyprlock que NÃO nasceu desta
      # unit — hoje só o do resgate de lockout por TTY (ver allow_session_lock_restore
      # em hypr/lua/appearance.lua), já que boot/idle/botão passam todos por aqui.
      # ExecCondition e não ExecStartPre de propósito: falhar aqui SALTA a partida em
      # silêncio (unit fica inactive), enquanto o StartPre a marcaria como `failed`.
      ExecCondition = "${pkgs.bash}/bin/bash -c '! ${pidof} hyprlock'";
      ExecStart = hyprlockBin;
    };
    # SEM Install/wantedBy DE PROPÓSITO: quem tranca é o clique ou o idle, nunca o
    # boot. O hyprlock do boot continua sendo o do autostart (../autostart.nix).
  };

  # ── hypridle: só TRANCA aos 5 min (SEM dpms-off — bugava o moon/Sunshine) ─────
  services.hypridle = {
    enable = true;
    settings = {
      general = {
        # Delega pra unit declarada acima — ver lá o porquê de não ser nem o hyprlock
        # direto (lockout remoto) nem `systemd-run` transiente. `start` é idempotente,
        # então isto nunca sobe um segundo hyprlock.
        lock_cmd = "${systemctlBin} --user start hyprlock.service";
        # Se um dia suspender (hoje não), tranca antes de dormir.
        before_sleep_cmd = "${loginctlBin} lock-session";
        ignore_dbus_inhibit = true;
      };
      listener = [
        # 5 min: tranca. loginctl → lock_cmd (protegido), nunca duplica o hyprlock.
        # NÃO há listener de dpms-off: desligar a tela quebrava o acesso remoto (ver
        # cabeçalho, ponto 3). O monitor fica ligado; o moon captura sempre.
        {
          timeout = 300;
          on-timeout = "${loginctlBin} lock-session";
        }
      ];
    };
  };

  # ── Weather: cache do wttr.in via serviço oneshot + timer (nada de script solto)
  systemd.user.services.lockscreen-weather = {
    Unit.Description = "Atualiza o cache de clima da tela de bloqueio (wttr.in)";
    Service = {
      Type = "oneshot";
      ExecStart = "${weatherFetch}";
    };
  };
  systemd.user.timers.lockscreen-weather = {
    Unit.Description = "Atualiza o clima da tela de bloqueio a cada 10 min";
    Timer = {
      OnBootSec = "1min"; # 1ª busca logo após o boot
      OnUnitActiveSec = "10min"; # e a cada 10 min depois
      Persistent = true;
    };
    Install.WantedBy = [ "timers.target" ];
  };

  # ── Quotes: cache do ZenQuotes via serviço oneshot + timer (substituiu o TSV) ──
  systemd.user.services.lockscreen-quotes = {
    Unit.Description = "Atualiza o cache de frases da tela de bloqueio (ZenQuotes)";
    Service = {
      Type = "oneshot";
      ExecStart = "${quotesFetch}";
    };
  };
  systemd.user.timers.lockscreen-quotes = {
    Unit.Description = "Renova o lote de frases da tela de bloqueio 1×/dia";
    Timer = {
      OnBootSec = "1min"; # 1º lote logo após o boot
      OnUnitActiveSec = "1d"; # renova 1×/dia: ~50 frases ⇒ folga na cota grátis do DeepL (500k/mês)
      Persistent = true;
    };
    Install.WantedBy = [ "timers.target" ];
  };
}
