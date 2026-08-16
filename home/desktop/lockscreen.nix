# LOCK SCREEN plus IDLE: hyprlock and hypridle. No loose scripts: the work is in systemd timers
# and the runtime is 1 line. The 3 hardware lessons NOT to undo: docs/notes/lockscreen.md
{
  config,
  pkgs,
  osConfig,
  ...
}:

let
  # Wallpapers: pkgs.nixos-artwork, so no binary in git and they bump with nixpkgs.
  art = pkgs.nixos-artwork.wallpapers;
  wallMain = "${art.catppuccin-mocha}/share/backgrounds/nixos/nixos-wallpaper-catppuccin-mocha.png"; # main (blurred on the lock)
  wallTv = "${art.moonscape}/share/backgrounds/nixos/nix-wallpaper-moonscape.png"; # TV (a static image, no login)

  # Monitors: the SSOT is system/desktop/monitors.nix (rule 11).
  primary = osConfig.my.monitors.primary; # LG ULTRAGEAR: blurred desktop plus login
  secondary = osConfig.my.monitors.secondary; # TV: static image plus a padlock

  # Colors from my.theme (palette.nix) plus the font from my.fonts.ui.
  palette = config.my.theme.palette; # the single source (home/desktop/palette.nix)
  font = osConfig.my.fonts.ui; # SSOT (system/hardware/fonts.nix)
  bg = "rgba(${palette.bg}d9)"; # the lock's background (d9 is ~85% opacity)
  fg = "rgb(${palette.text})";
  muted = "rgb(${palette.dim})";
  blue = "rgba(${palette.blue}ee)";
  magenta = "rgba(${palette.magenta}ee)";
  green = "rgba(${palette.green}ee)";
  red = "rgba(${palette.red}ee)";

  # Binaries at absolute paths, so nothing depends on the PATH (rule 7).
  hyprlockBin = "${pkgs.hyprlock}/bin/hyprlock";
  pidof = "${pkgs.procps}/bin/pidof"; # the unit's ExecCondition: do not start a 2nd hyprlock
  loginctlBin = "${pkgs.systemd}/bin/loginctl";
  systemctlBin = "${pkgs.systemd}/bin/systemctl";
  shuf = "${pkgs.coreutils}/bin/shuf";
  catBin = "${pkgs.coreutils}/bin/cat";

  # Quote: a daily timer fetches ~50 from ZenQuotes and batch-translates them through DeepL; the
  # lock only runs shuf. The layered fallbacks are in docs/notes/lockscreen.md
  quotesCache = "${config.xdg.cacheHome}/lockscreen/quotes";
  deeplKeyFile = "/run/secrets/deepl_api_key"; # sops (owner v1cferr); if absent, it stays EN
  quotesFetch = pkgs.writeShellScript "lockscreen-quotes-fetch" ''
    ${pkgs.coreutils}/bin/mkdir -p ${config.xdg.cacheHome}/lockscreen
    tmp="${quotesCache}.tmp"
    ${pkgs.coreutils}/bin/rm -f "$tmp"

    # 1) A filtered EN batch into a compact array [{q,a}].
    filtered="$(${pkgs.curl}/bin/curl -s --max-time 15 'https://zenquotes.io/api/quotes' \
      | ${pkgs.jq}/bin/jq -c '[.[]
          | select((.q | length) > 0 and (.q | length) <= 120 and .a != "zenquotes.io")
          | {q, a}]' 2>/dev/null || true)"

    # 2) With a batch and a DeepL key, translate the QUOTES in 1 request and recombine them with
    #    the original author IN ORDER. A mismatch leaves it empty, so it falls back to EN.
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

    # 3) The translated one if it worked, otherwise the EN batch. Formatted in pango.
    src=""
    if   [ -n "$translated" ] && [ "$translated" != "null" ] && [ "$translated" != "[]" ]; then src="$translated"
    elif [ -n "$filtered" ]   && [ "$filtered"   != "[]" ];                                 then src="$filtered"
    fi
    if [ -n "$src" ]; then
      ${pkgs.coreutils}/bin/printf '%s' "$src" | ${pkgs.jq}/bin/jq -r '.[]
          | "<i>“" + (.q | gsub("&";"&amp;") | gsub("<";"&lt;") | gsub(">";"&gt;")) + "”</i>  <b>"
            + (.a | gsub("&";"&amp;") | gsub("<";"&lt;") | gsub(">";"&gt;")) + "</b>"' > "$tmp" 2>/dev/null || true
    fi

    # 4) Publish atomically if it worked; otherwise keep the previous cache.
    if [ -s "$tmp" ]; then ${pkgs.coreutils}/bin/mv "$tmp" ${quotesCache}; else ${pkgs.coreutils}/bin/rm -f "$tmp"; fi
    # fallback: at least 1 quote on a first boot with no network, so shuf is never empty.
    [ -s ${quotesCache} ] || echo '<i>“A melhor forma de prever o futuro é inventá-lo.”</i>  <b>Alan Kay</b>' > ${quotesCache}
  '';

  # Weather: a 10-min timer caches wttr.in; the runtime is cat.
  weatherDir = "${config.xdg.cacheHome}/lockscreen";
  weatherCache = "${weatherDir}/weather";
  # São Carlos/SP by COORDINATES (no geocoding ambiguity), written atomically.
  weatherFetch = pkgs.writeShellScript "lockscreen-weather-fetch" ''
    ${pkgs.coreutils}/bin/mkdir -p ${weatherDir}
    ${pkgs.curl}/bin/curl -s --max-time 15 -H 'Accept-Language: pt' \
      'https://wttr.in/-22.0087,-47.8909?format=%C,+%t' -o ${weatherCache}.tmp \
      && ${pkgs.coreutils}/bin/mv ${weatherCache}.tmp ${weatherCache}
  '';
in
{
  # hyprlock: the lock screen itself.
  programs.hyprlock = {
    enable = true;
    settings = {
      general.hide_cursor = true; # hides the cursor on the lock

      # A smooth fade in and out (the bezier goes to the top of the block through importantPrefixes).
      animations = {
        enabled = true;
        bezier = "easeOut, 0.25, 1, 0.5, 1";
        animation = [
          "fadeIn, 1, 4, easeOut"
          "fadeOut, 1, 4, easeOut"
          "inputFieldDots, 1, 2, easeOut"
        ];
      };

      # Backgrounds: the main one blurred by hyprlock itself, plus a static TV.
      background = [
        {
          monitor = primary;
          path = "${wallMain}"; # a sharp PNG; hyprlock does the blur and brightness
          blur_passes = 2; # eased from 3, so the wallpaper shows more (the widgets stay legible)
          blur_size = 6;
          noise = 0.012;
          contrast = 0.92;
          brightness = 0.40; # dark enough for the clock and quote to be well legible (the wallpaper still shows)
          vibrancy = 0.17;
        }
        {
          monitor = secondary;
          color = "rgba(${palette.bg}ff)"; # a fallback while the image loads
          path = "${wallTv}";
        }
      ];

      # The password field (main monitor only).
      input-field = {
        monitor = primary;
        size = "340, 56";
        outline_thickness = 2;
        rounding = 14;
        inner_color = bg;
        font_color = fg;
        font_family = font;
        outer_color = "${blue} ${magenta} 45deg"; # a gradient border
        check_color = "${green} ${blue} 120deg"; # while checking the password
        fail_color = red; # a wrong password
        placeholder_text = ''<span foreground="##${palette.dim}">Digite a senha…</span>'';
        fail_text = ''<span foreground="##f7768e">$PAMFAIL</span>'';
        dots_spacing = 0.3;
        fade_on_empty = false;
        position = "0, -190";
        halign = "center";
        valign = "center";
      };

      label = [
        # A big clock, with seconds.
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
        # The full date in pt-BR: the lockscreen is the deliberate language exception. LC_TIME gives
        # the spelled-out date, and sed capitalizes it and adds the week number.
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
        # The logged-in user.
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
        # The quote in the bottom left: shuf -n1 over the timer's cache.
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
        # The weather in the top left: it only reads the timer's cache.
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
        # A discreet padlock on the TV.
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

  # hyprlock as its OWN UNIT, because locking is a SECURITY function and cannot be hostage to an
  # idle daemon anything can stop. The 6h outage and the remote lockout: the notes.
  systemd.user.services.hyprlock = {
    Unit = {
      Description = "Lock screen (hyprlock)";
      # With no graphical session there is nothing to lock, and the lock dies with it.
      PartOf = [ "graphical-session.target" ];
      After = [ "graphical-session.target" ];
    };
    Service = {
      Type = "simple"; # it runs while the screen is locked and exits on unlock
      # The heir of the old `pidof hyprlock ||`, now covering only the TTY rescue. ExecCondition and
      # not ExecStartPre: failing here SKIPS silently instead of marking the unit failed.
      ExecCondition = "${pkgs.bash}/bin/bash -c '! ${pidof} hyprlock'";
      ExecStart = hyprlockBin;
    };
    # NO Install/wantedBy ON PURPOSE: what locks is the click or the idle, never the boot.
  };

  # hypridle: it ONLY locks after 5 min. NO dpms-off, which broke moon/Sunshine (see the notes).
  services.hypridle = {
    enable = true;
    settings = {
      general = {
        # It delegates to the unit above; `start` is idempotent, so never a second hyprlock.
        lock_cmd = "${systemctlBin} --user start hyprlock.service";
        # If it ever suspends (it does not today), lock before sleeping.
        before_sleep_cmd = "${loginctlBin} lock-session";
        ignore_dbus_inhibit = true;
      };
      listener = [
        # 5 min: lock. There is NO dpms-off listener; the monitor stays on so moon always captures.
        {
          timeout = 300;
          on-timeout = "${loginctlBin} lock-session";
        }
      ];
    };
  };

  # Weather: the wttr.in cache, as a oneshot plus a timer (no loose script).
  systemd.user.services.lockscreen-weather = {
    Unit.Description = "Refreshes the lock screen weather cache (wttr.in)";
    Service = {
      Type = "oneshot";
      ExecStart = "${weatherFetch}";
    };
  };
  systemd.user.timers.lockscreen-weather = {
    Unit.Description = "Refreshes the lock screen weather every 10 min";
    Timer = {
      OnBootSec = "1min"; # the 1st fetch right after boot
      OnUnitActiveSec = "10min"; # and every 10 min afterwards
      Persistent = true;
    };
    Install.WantedBy = [ "timers.target" ];
  };

  # Quotes: the ZenQuotes cache, as a oneshot plus a timer (it replaced the vendored TSV).
  systemd.user.services.lockscreen-quotes = {
    Unit.Description = "Refreshes the lock screen quote cache (ZenQuotes)";
    Service = {
      Type = "oneshot";
      ExecStart = "${quotesFetch}";
    };
  };
  systemd.user.timers.lockscreen-quotes = {
    Unit.Description = "Renews the lock screen quote batch once a day";
    Timer = {
      OnBootSec = "1min"; # the 1st batch right after boot
      OnUnitActiveSec = "1d"; # renews once a day: ~50 quotes leaves room in DeepL's free quota (500k/month)
      Persistent = true;
    };
    Install.WantedBy = [ "timers.target" ];
  };
}
