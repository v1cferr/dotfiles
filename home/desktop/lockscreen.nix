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
#   • idle    → `dpms off/on` NATIVO do hypridle (sem script de dim).
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
#   3. dpms: usamos o `dpms off/on` NATIVO do hypridle. Histórico: na antiga NVIDIA
#      (Arch, driver velho) o `dpms on` sob lock CONGELAVA o page-flip atomic (só
#      reboot); na Arc B580 (xe) não reproduz. Se algum dia congelar, o fallback é
#      dim por gamma do hyprsunset (ver histórico git). TESTAR com um TTY aberto.
# Ref: https://wiki.hypr.land/Hypr-Ecosystem/hyprlock/
{ config, pkgs, ... }:

let
  # ── Wallpapers: oficiais do NixOS via pkgs.nixos-artwork (declarativos, sem
  #    binário no git; bump junto com o nixpkgs). ──
  art = pkgs.nixos-artwork.wallpapers;
  wallMain = "${art.catppuccin-mocha}/share/backgrounds/nixos/nixos-wallpaper-catppuccin-mocha.png"; # principal (borrado no lock)
  wallTv   = "${art.moonscape}/share/backgrounds/nixos/nix-wallpaper-moonscape.png"; # TV (imagem estática, sem login)

  # ── Monitores (mesmos nomes de conector do home/hypr.nix) ────────────────────
  primary   = "DP-2";      # LG ULTRAGEAR — desktop borrado + login
  secondary = "HDMI-A-3";  # TV — imagem estática + cadeado

  # ── Paleta Tokyo Night + fonte ───────────────────────────────────────────────
  font    = "JetBrainsMono Nerd Font";
  bg      = "rgba(26, 27, 38, 0.85)";
  fg      = "rgb(192, 202, 245)";
  muted   = "rgb(86, 95, 137)";
  blue    = "rgba(7aa2f7ee)";
  magenta = "rgba(bb9af7ee)";
  green   = "rgba(9ece6aee)";
  red     = "rgba(f7768eee)";

  # ── Binários por caminho absoluto (não dependem de PATH — durável) ────────────
  hyprctl     = "${pkgs.hyprland}/bin/hyprctl";
  hyprlockBin = "${pkgs.hyprlock}/bin/hyprlock";
  pidof       = "${pkgs.procps}/bin/pidof";
  loginctlBin = "${pkgs.systemd}/bin/loginctl";
  shuf        = "${pkgs.coreutils}/bin/shuf";
  catBin      = "${pkgs.coreutils}/bin/cat";

  # ── Quote: cache atualizado por timer systemd (ZenQuotes + DeepL; runtime = shuf -n1)
  # Substituiu o quotes.tsv vendorizado. O timer busca um LOTE (~50) do zenquotes.io
  # /api/quotes (EN), filtra (não-vazio, <=120 chars, sem o placeholder de rate-limit)
  # e TRADUZ p/ pt-BR via DeepL (chave em /run/secrets/deepl_api_key, sops) — só as
  # FRASES num único request em lote; o autor fica no original. Escapa &<> (pango) e
  # grava atômico; o lock só roda shuf -n1. FALLBACK seguro: sem chave/DeepL fora →
  # usa o lote em INGLÊS; sem rede na 1ª vez → uma frase embutida (pt-BR).
  quotesCache  = "${config.xdg.cacheHome}/lockscreen/quotes";
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
  weatherDir   = "${config.xdg.cacheHome}/lockscreen";
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
          color = "rgba(1a1b26ff)"; # fallback enquanto a imagem carrega
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
        check_color = "${green} ${blue} 120deg";  # verificando a senha
        fail_color = red;                          # senha errada
        placeholder_text = ''<span foreground="##565f89">Digite a senha…</span>'';
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

  # ── hypridle: lock aos 5 min + dpms (tela off) logo depois ───────────────────
  services.hypridle = {
    enable = true;
    settings = {
      general = {
        # `pidof ... ||` evita subir 2 hyprlock: 2 superfícies de session-lock
        # confundem o grab do teclado e o campo de senha para de digitar.
        lock_cmd = "${pidof} hyprlock || ${hyprlockBin}";
        # Se um dia suspender (hoje não), tranca antes de dormir.
        before_sleep_cmd = "${loginctlBin} lock-session";
        ignore_dbus_inhibit = true;
      };
      listener = [
        # 5 min: tranca. loginctl → lock_cmd (protegido), nunca duplica o hyprlock.
        {
          timeout = 300;
          on-timeout = "${loginctlBin} lock-session";
        }
        # +30s: desliga a tela via dpms NATIVO. on-resume religa ao voltar.
        {
          timeout = 330;
          on-timeout = "${hyprctl} dispatch dpms off";
          on-resume = "${hyprctl} dispatch dpms on";
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
      OnBootSec = "1min";        # 1ª busca logo após o boot
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
      OnBootSec = "1min";       # 1º lote logo após o boot
      OnUnitActiveSec = "1d";   # renova 1×/dia: ~50 frases ⇒ folga na cota grátis do DeepL (500k/mês)
      Persistent = true;
    };
    Install.WantedBy = [ "timers.target" ];
  };
}
