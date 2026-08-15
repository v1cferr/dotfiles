# LOCK SCREEN + IDLE: hyprlock (lock) plus hypridle (idle), declared.
#
# This module's philosophy: NO loose .sh scripts. The heavy logic lives where it is
# declarative and reproducible, in the BUILD (pure Nix) or in SYSTEMD, and the runtime is a
# 1-line command with the binary at an ABSOLUTE path (${pkgs...}/bin/x), not depending on the
# PATH. That is how this survives upgrades (durable into 2032+):
#   • quote   -> a systemd service plus timer fetches a batch from the ZenQuotes API once a
#                day, translates it to pt-BR (DeepL) and formats it in pango into a cache; the
#                lock only runs `shuf -n1`.
#   • weather -> a systemd service plus timer fetches wttr.in every 10 min into a cache; the
#                lock only runs `cat`. A stable source, with no HTML scraping.
#   • idle    -> it only LOCKS after 5min (loginctl lock-session). NO dpms-off, see point 3.
#   • lock    -> `hyprlock.service`, a DECLARED unit. Locking does not depend on hypridle
#                being alive; see the unit's block for the incident that motivated it.
#
# The folder rule: USER apps go to home/. programs.hyprlock installs hyprlock and
# services.hypridle brings the daemon up (systemd --user, like hyprsunset). That is why
# hypridle left system/packages.nix. PAM (system/desktop.nix) is MANDATORY: without it
# hyprlock does not authenticate and LOCKS YOU OUT. The pt_BR locale (system/core.nix) is for
# the clock's spelled-out date.
#
# LANGUAGE, and it is a deliberate exception: the system is en-US, and the LOCKSCREEN is full
# pt-BR (the spelled-out date, the weather, "Digite a senha…", the DeepL-translated quotes).
# That decision is recorded in the july history, so the strings below are NOT untranslated
# debt, they are the product.
#
# HARDWARE LESSONS (durable, independent of the GPU), do NOT touch:
#   1. A STATIC wallpaper, never `path = screenshot`: screencopy/DMA segfaults hyprlock when
#      waking from idle (the DMA frame is destroyed on exit, so a lockout).
#   2. No GIF and no continuous reload: the asynchronous gatherer races with exit() and
#      corrupts the heap (SIGABRT on unlock).
#   3. dpms-off REMOVED (jul/2026): turning the screen off on idle BROKE remote access,
#      because Sunshine (wlr capture on the xe driver) got a BLACK SCREEN from the powered-off
#      monitor, and toggling dpms under capture caused a GPU ENGINE RESET (xe RCS, which froze
#      the scanout). Now idle ONLY locks. If dimming is ever wanted, use hyprsunset's gamma.
# Ref: https://wiki.hypr.land/Hypr-Ecosystem/hyprlock/
{
  config,
  pkgs,
  osConfig,
  ...
}:

let
  # ── Wallpapers: the official NixOS ones through pkgs.nixos-artwork (declarative, with no
  #    binary in git; they bump along with nixpkgs). ──
  art = pkgs.nixos-artwork.wallpapers;
  wallMain = "${art.catppuccin-mocha}/share/backgrounds/nixos/nixos-wallpaper-catppuccin-mocha.png"; # main (blurred on the lock)
  wallTv = "${art.moonscape}/share/backgrounds/nixos/nix-wallpaper-moonscape.png"; # TV (a static image, no login)

  # ── Monitors: the SSOT is system/desktop/monitors.nix (rule 11) ──────────────
  primary = osConfig.my.monitors.primary; # LG ULTRAGEAR: blurred desktop plus login
  secondary = osConfig.my.monitors.secondary; # TV: static image plus a padlock

  # ── Colors from the active theme (my.theme) plus the font ────────────────────
  palette = config.my.theme.palette; # the single source (home/desktop/palette.nix)
  font = osConfig.my.fonts.ui; # SSOT (system/hardware/fonts.nix)
  bg = "rgba(${palette.bg}d9)"; # the lock's background (d9 is ~85% opacity)
  fg = "rgb(${palette.text})";
  muted = "rgb(${palette.dim})";
  blue = "rgba(${palette.blue}ee)";
  magenta = "rgba(${palette.magenta}ee)";
  green = "rgba(${palette.green}ee)";
  red = "rgba(${palette.red}ee)";

  # ── Binaries at absolute paths (not depending on the PATH, which is durable) ──
  hyprlockBin = "${pkgs.hyprlock}/bin/hyprlock";
  pidof = "${pkgs.procps}/bin/pidof"; # the unit's ExecCondition: do not start a 2nd hyprlock
  loginctlBin = "${pkgs.systemd}/bin/loginctl";
  systemctlBin = "${pkgs.systemd}/bin/systemctl";
  shuf = "${pkgs.coreutils}/bin/shuf";
  catBin = "${pkgs.coreutils}/bin/cat";

  # ── Quote: a cache refreshed by a systemd timer (ZenQuotes + DeepL; the runtime is
  # shuf -n1). It replaced the vendored quotes.tsv. The timer fetches a BATCH (~50) from
  # zenquotes.io /api/quotes (EN), filters it (non-empty, <=120 chars, without the rate-limit
  # placeholder) and TRANSLATES it to pt-BR through DeepL (the key is in
  # /run/secrets/deepl_api_key, from sops), sending only the QUOTES in a single batched
  # request while the author stays in the original. It escapes &<> (pango) and writes
  # atomically; the lock only runs shuf -n1. A safe FALLBACK: with no key or DeepL down it
  # uses the ENGLISH batch; with no network on the first run, one built-in quote (pt-BR).
  quotesCache = "${config.xdg.cacheHome}/lockscreen/quotes";
  deeplKeyFile = "/run/secrets/deepl_api_key"; # sops (owner v1cferr); if absent, it stays EN
  quotesFetch = pkgs.writeShellScript "lockscreen-quotes-fetch" ''
    ${pkgs.coreutils}/bin/mkdir -p ${config.xdg.cacheHome}/lockscreen
    tmp="${quotesCache}.tmp"
    ${pkgs.coreutils}/bin/rm -f "$tmp"

    # 1) A filtered EN batch into a compact array [{q,a}] (q=quote, a=author).
    filtered="$(${pkgs.curl}/bin/curl -s --max-time 15 'https://zenquotes.io/api/quotes' \
      | ${pkgs.jq}/bin/jq -c '[.[]
          | select((.q | length) > 0 and (.q | length) <= 120 and .a != "zenquotes.io")
          | {q, a}]' 2>/dev/null || true)"

    # 2) If there is a batch and the DeepL key exists, translate the QUOTES (1 batched
    #    request, target PT-BR) and recombine them with the original author IN ORDER. An
    #    error or a length mismatch leaves 'translated' empty, so it falls back to EN below.
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

    # 3) The final source: the translated one if it worked, otherwise the EN batch. Formatted
    #    in pango.
    src=""
    if   [ -n "$translated" ] && [ "$translated" != "null" ] && [ "$translated" != "[]" ]; then src="$translated"
    elif [ -n "$filtered" ]   && [ "$filtered"   != "[]" ];                                 then src="$filtered"
    fi
    if [ -n "$src" ]; then
      ${pkgs.coreutils}/bin/printf '%s' "$src" | ${pkgs.jq}/bin/jq -r '.[]
          | "<i>“" + (.q | gsub("&";"&amp;") | gsub("<";"&lt;") | gsub(">";"&gt;")) + "”</i>  <b>"
            + (.a | gsub("&";"&amp;") | gsub("<";"&lt;") | gsub(">";"&gt;")) + "</b>"' > "$tmp" 2>/dev/null || true
    fi

    # 4) Publish atomically if it worked; otherwise discard and keep the previous cache.
    if [ -s "$tmp" ]; then ${pkgs.coreutils}/bin/mv "$tmp" ${quotesCache}; else ${pkgs.coreutils}/bin/rm -f "$tmp"; fi
    # fallback: guarantees at least 1 quote (first boot with no network) so shuf is not empty.
    [ -s ${quotesCache} ] || echo '<i>“A melhor forma de prever o futuro é inventá-lo.”</i>  <b>Alan Kay</b>' > ${quotesCache}
  '';

  # ── Weather: a cache refreshed by a systemd timer (wttr.in; the runtime is cat) ──
  weatherDir = "${config.xdg.cacheHome}/lockscreen";
  weatherCache = "${weatherDir}/weather";
  # São Carlos/SP by COORDINATES (no geocoding ambiguity). It writes atomically (.tmp plus mv)
  # so hyprlock never reads a half-written cache.
  weatherFetch = pkgs.writeShellScript "lockscreen-weather-fetch" ''
    ${pkgs.coreutils}/bin/mkdir -p ${weatherDir}
    ${pkgs.curl}/bin/curl -s --max-time 15 -H 'Accept-Language: pt' \
      'https://wttr.in/-22.0087,-47.8909?format=%C,+%t' -o ${weatherCache}.tmp \
      && ${pkgs.coreutils}/bin/mv ${weatherCache}.tmp ${weatherCache}
  '';
in
{
  # ── hyprlock: the lock screen itself ─────────────────────────────────────────
  programs.hyprlock = {
    enable = true;
    settings = {
      general.hide_cursor = true; # hides the cursor on the lock

      # A smooth fade in and out (the bezier goes to the top of the block through
      # importantPrefixes)
      animations = {
        enabled = true;
        bezier = "easeOut, 0.25, 1, 0.5, 1";
        animation = [
          "fadeIn, 1, 4, easeOut"
          "fadeOut, 1, 4, easeOut"
          "inputFieldDots, 1, 2, easeOut"
        ];
      };

      # Backgrounds: the main one blurred (hyprlock's native blur) plus a static TV.
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
        # A big clock (with seconds)
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
        # The full date in pt-BR (the LOCKSCREEN is the exception: full pt-BR even with the
        # system in en-US). LC_TIME pt_BR gives the spelled-out date, and sed capitalizes the
        # 1st letter and adds the week number.
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
        # The logged-in user
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
        # The quote in the bottom left (the ZenQuotes API cache refreshed by a timer, then
        # shuf -n1)
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
        # The weather in the top left corner (it only reads the systemd timer's cache)
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
        # A discreet padlock on the TV
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

  # ── hyprlock as a DECLARED UNIT: LOCKING CANNOT DEPEND ON HYPRIDLE ───────────
  # Until 10/08/2026 the only path to locking was `loginctl lock-session`, which does NOT lock
  # anything on its own: it only sets LockedHint and emits the Lock signal on D-Bus. What
  # listened and brought hyprlock up was hypridle, through lock_cmd. The consequence: with
  # hypridle stopped, the signal fell into the VOID, so the bar's "Lock" button clicked and
  # nothing happened, with no error at all. That is what happened for 6h on 10/08/2026, with
  # the Sunshine guard (../../system/services/sunshine.nix) holding hypridle stopped after a
  # client died with no teardown.
  #
  # It is the wrong dependency: locking the screen is a SECURITY FUNCTION, and it cannot be
  # hostage to an IDLE daemon that anything can stop (the Sunshine guard, the bar's pill, a
  # crash). Now hyprlock is a unit of its own and whoever wants to lock runs
  # `systemctl --user start hyprlock.service`, directly.
  #
  # A UNIT OF ITS OWN, and not a transient `systemd-run` (which was the previous trick), for
  # the same reason as before PLUS two more: it stays OUTSIDE the hypridle.service cgroup,
  # which is what prevents the REMOTE LOCKOUT diagnosed on 03/08/2026, when the Sunshine
  # guard's `systemctl --user stop hypridle` killed the whole cgroup (KillMode=control-group)
  # and took hyprlock with it, leaving the compositor LOCKED WITH NO CLIENT to draw the
  # password field. And as a bonus:
  #   • idempotence for free, since `start` on an already active unit is a no-op, so the old
  #     `pidof hyprlock ||` goes away. Two session-lock surfaces confuse the keyboard grab and
  #     the password field stops typing; systemd guarantees one.
  #   • the name is not left occupied after the unlock (which was `--collect`'s job).
  # The env (WAYLAND_DISPLAY, HYPRLAND_INSTANCE_SIGNATURE) comes from systemd --user, which the
  # session already imports. No Restart: a hyprlock that exits is an unlock, not a failure to
  # bring back up.
  systemd.user.services.hyprlock = {
    Unit = {
      Description = "Lock screen (hyprlock)";
      # With no graphical session there is nothing to lock, and the lock dies with it.
      PartOf = [ "graphical-session.target" ];
      After = [ "graphical-session.target" ];
    };
    Service = {
      Type = "simple"; # it runs while the screen is locked and exits on unlock
      # The heir of the old `pidof hyprlock ||`: it covers a hyprlock that was NOT born from
      # this unit, which today is only the TTY lockout rescue (see allow_session_lock_restore
      # in hypr/lua/appearance.lua), since boot, idle and the button all go through here.
      # ExecCondition and not ExecStartPre on purpose: failing here SKIPS the start silently
      # (the unit stays inactive), while a StartPre would mark it as `failed`.
      ExecCondition = "${pkgs.bash}/bin/bash -c '! ${pidof} hyprlock'";
      ExecStart = hyprlockBin;
    };
    # NO Install/wantedBy ON PURPOSE: what locks is the click or the idle, never the boot. The
    # hyprlock at boot is still the autostart one (../autostart.nix).
  };

  # ── hypridle: it only LOCKS after 5 min (NO dpms-off, which broke moon/Sunshine) ──
  services.hypridle = {
    enable = true;
    settings = {
      general = {
        # It delegates to the unit declared above; see there why it is neither hyprlock
        # directly (remote lockout) nor a transient `systemd-run`. `start` is idempotent, so
        # this never brings up a second hyprlock.
        lock_cmd = "${systemctlBin} --user start hyprlock.service";
        # If it ever suspends (it does not today), lock before sleeping.
        before_sleep_cmd = "${loginctlBin} lock-session";
        ignore_dbus_inhibit = true;
      };
      listener = [
        # 5 min: lock. loginctl leads to lock_cmd (protected), and it never duplicates
        # hyprlock.
        # There is NO dpms-off listener: turning the screen off broke remote access (see the
        # header, point 3). The monitor stays on; moon always captures.
        {
          timeout = 300;
          on-timeout = "${loginctlBin} lock-session";
        }
      ];
    };
  };

  # ── Weather: the wttr.in cache through a oneshot service plus a timer (no loose script)
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

  # ── Quotes: the ZenQuotes cache through a oneshot service plus a timer (it replaced the TSV)
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
