# TELA DE BLOQUEIO + OCIOSIDADE — hyprlock (lock) + hypridle (idle), declarados.
#
# Filosofia deste módulo: NADA de scripts .sh soltos. A lógica pesada mora onde é
# declarativa e reprodutível — no BUILD (Nix puro) ou no SYSTEMD — e o runtime é
# só comando de 1 linha, com binário por caminho ABSOLUTO (${pkgs...}/bin/x), sem
# depender de PATH. Assim isto sobrevive a upgrades (durável 2032+):
#   • quote   → o TSV vira frases pango prontas NO BUILD (runCommand); no lock só
#               roda `shuf -n1` no arquivo já formatado.
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
# APRENDIZADOS DE HARDWARE (mesma NVIDIA do Arch), NÃO mexer:
#   1. Wallpaper ESTÁTICO, nunca `path = screenshot`: o screencopy/DMA segfalha o
#      hyprlock ao acordar do idle (frame DMA destruído no exit → lockout).
#   2. Nada de GIF/reload contínuo: o gatherer assíncrono corre com o exit() e
#      corrompe a heap (SIGABRT no unlock).
#   3. dpms: no Arch (driver antigo) o `dpms on` sob lock CONGELAVA o page-flip
#      atomic desta NVIDIA (só reboot). Aqui optamos pelo dpms nativo p/ testar no
#      kernel/driver novos — se voltar a congelar, o fallback é dim por gamma do
#      hyprsunset (ver histórico git deste arquivo). TESTAR com um TTY aberto.
# Ref: https://wiki.hypr.land/Hypr-Ecosystem/hyprlock/
{ config, pkgs, ... }:

let
  # ── Assets vendorizados no repo (vão pro /nix/store → 100% reprodutível) ─────
  wallMain = ./lockscreen/wallpaper-main.png; # monitor principal (borrado no lock)
  wallTv   = ./lockscreen/wallpaper-tv.jpg;   # TV (imagem estática, sem login)
  quotesDb = ./lockscreen/quotes.tsv;         # banco offline de frases (en<TAB>pt<TAB>autor)

  # ── Monitores (mesmos nomes de conector do home/hypr.nix) ────────────────────
  primary   = "DP-1";      # LG ULTRAGEAR — desktop borrado + login
  secondary = "HDMI-A-1";  # TV — imagem estática + cadeado

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

  # ── Quote: TSV → frases pango prontas NO BUILD (Nix puro; runtime = shuf -n1) ──
  # sed escapa &<> (pango) e o awk reordena p/ "«pt» — autor", filtrando frases
  # longas (>120) que estourariam a linha. Resultado: 1 frase pango por linha.
  quotes = pkgs.runCommand "lockscreen-quotes" { } ''
    ${pkgs.gnused}/bin/sed -e 's/&/\&amp;/g' -e 's/</\&lt;/g' -e 's/>/\&gt;/g' ${quotesDb} \
      | ${pkgs.gawk}/bin/awk -F'\t' 'length($2) <= 120 {
          print "<i>“" $2 "”</i>  <b>— " $3 "</b>"
        }' > $out
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
          blur_passes = 3;
          blur_size = 6;
          noise = 0.012;
          contrast = 0.92;
          brightness = 0.55;
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
        placeholder_text = ''<span foreground="##565f89">Enter password…</span>'';
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
        # Data completa em pt-BR (1ª letra maiúscula) + nº da semana
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
        # Frase pt-BR no rodapé esquerdo (arquivo pré-formatado no build → shuf -n1)
        {
          monitor = primary;
          text = "cmd[update:150000] ${shuf} -n1 ${quotes}";
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
}
