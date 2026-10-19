# LOCK SCREEN v2 plus IDLE: hyprlock over PRE-RENDERED glass, and hypridle. Rendering never runs on
# the lock path; the design, the lessons NOT to undo and the rollback: docs/notes/desktop/lockscreen.md
{
  config,
  lib,
  pkgs,
  osConfig,
  ...
}:

let
  # Rule 19: everything this module reaches for, named once. deadnix fails the build on an
  # entry that stops being used, so the list cannot rot into a lie (rule 16).
  inherit (pkgs)
    bash
    coreutils
    curl
    gnugrep
    hyprlock
    jq
    nixos-artwork
    playerctl
    procps
    python3
    runCommand
    systemd
    writeShellApplication
    writeShellScript
    writeText
    ;
  hyprland = osConfig.programs.hyprland.package; # hyprctl from the RUNNING compositor
  python = python3.withPackages (ps: [ ps.pillow ]); # the renderer's whole closure

  # Monitors: the SSOT is modules/nixos/desktop/monitors.nix (rule 11).
  inherit (osConfig.my.monitors) primary secondary;

  # Colors from my.theme (palette.nix), the font from my.fonts.ui, the corner from my.theme.rounding.
  p = config.my.theme.palette;
  font = osConfig.my.fonts.ui;
  motionOff = config.my.theme.motion == "off";
  geo = import ./geometry.nix { inherit (config.my.theme) rounding; };
  inherit (geo) cards at;

  # The packaged art, for an empty pool and for the build-time fallback (no binary in git).
  art = nixos-artwork.wallpapers;
  wallMain = "${art.catppuccin-mocha}/share/backgrounds/nixos/nixos-wallpaper-catppuccin-mocha.png";
  wallSecondary = "${art.waterfall}/share/backgrounds/nixos/nix-wallpaper-waterfall.png";

  # MY OWN art, as STATE and not config (rule 6): each monitor draws the files that suit it.
  wallDir = "${config.home.homeDirectory}/Pictures/lockscreen";

  cacheDir = "${config.xdg.cacheHome}/lockscreen";
  v2 = "${cacheDir}/v2"; # the renderer's cache, the ready set, the session links, the data files
  session = "${v2}/session";
  quotesJson = "${v2}/quotes.json";
  weatherFile = "${v2}/weather";

  # The glass PROFILE's numbers, one row per my.theme.glass value. They MIRROR Theme.qml's card
  # level and glass.lua's preset; test_render.py fails if either side moves without the other.
  profiles = {
    clear-gradient = {
      solid = false;
      gradient = true;
      alphaMin = 0.62; # dark backdrops may go clearer than the desktop's 0.70...
      alphaMax = 0.9; # ...and bright ones denser, only as far as contrast needs
      tint = 0.2;
      brightness = 0.95;
      contrast = 0.95;
      blurSigma = 18.0; # HyprGlass blur_strength 0.9, by eye: docs/notes/desktop/lockscreen.md
    };
    perceptible = {
      solid = false;
      gradient = false;
      alphaMin = 0.92;
      alphaMax = 0.96;
      tint = 0.33;
      brightness = 0.85;
      contrast = 0.95;
      blurSigma = 24.0;
    };
    solid = {
      solid = true;
      gradient = false;
      alphaMin = 1.0;
      alphaMax = 1.0;
      tint = 0.0;
      brightness = 1.0;
      contrast = 1.0;
      blurSigma = 0.0;
    };
  };

  # Type sizes (pt; hyprlock renders at 96 dpi, so one JetBrains Mono column is 0.8 px per pt).
  pt = {
    clock = 84;
    date = 16;
    weatherTitle = 12;
    weather = 20;
    media = 15;
    artist = 13;
    quote = 14;
  };
  pad = 48; # a card's horizontal padding, each side
  cols = size: card: builtins.floor ((builtins.elemAt card.size 0 - 2 * pad) / (0.8 * size));

  # The ONE spec the renderer reads: palette, profile, geometry, pools, fallbacks (rule 11).
  aa = {
    text = 4.5;
    subtext = 4.5;
  }; # WCAG AA, measured on the composited pixels
  spec = {
    palette = p;
    glass = profiles.${config.my.theme.glass};
    edge = {
      edge = 0.55; # colEdge: border at 0x8c
      sheen = 0.06; # colSheen: text at 0x0f
      hairline = 1;
    };
    contrast = aa;
    quotesFile = quotesJson;
    quote = {
      columns = cols pt.quote cards.quote;
      lines = 4;
      fallback = {
        q = "A melhor forma de prever o futuro é inventá-lo.";
        a = "Alan Kay";
      };
    };
    monitors = {
      primary = {
        name = primary;
        inherit (geo.monitors.primary) size;
        # The astronomy collection (with its captions) plus any landscape art in my lock folder.
        pools = [
          config.my.wallpaper.pools.wide
          wallDir
        ];
        fallback = wallMain;
        layouts.main = [
          (cards.clock // { contrast = aa; })
          # hyprlock draws the field's own state border, so the glass under it has none baked in.
          (
            cards.auth
            // {
              edge = false;
              contrast = aa // {
                red = 4.5;
              };
            }
          )
        ];
      };
      secondary = {
        name = secondary;
        inherit (geo.monitors.secondary) size layouts;
        pools = [ wallDir ]; # the art I keep for the standing monitor, as in v1
        fallback = wallSecondary;
      };
    };
  };
  specFile = writeText "lockscreen-spec.json" (builtins.toJSON spec);

  # Built ONCE from the packaged art: the lock has glass even before the first render.
  fallback = runCommand "lockscreen-fallback" { nativeBuildInputs = [ python ]; } ''
    python3 -I ${./scripts/render.py} fallback --spec ${specFile} --out $out
  '';

  # The BACKGROUND half: pick, render, publish `ready`, collect. Never on the lock path.
  render = writeShellApplication {
    name = "lockscreen-render";
    runtimeInputs = [
      python
      hyprland
    ];
    text = ''exec python3 -I ${./scripts/render.py} "$@"'';
  };

  # The LOCK half: milliseconds of links, then hyprlock (rule 7: logic in the build).
  lockStart = writeShellApplication {
    name = "lockscreen-start";
    runtimeInputs = [
      coreutils
      playerctl
    ];
    runtimeEnv = {
      LOCK_CACHE = v2;
      LOCK_FALLBACK = fallback;
    };
    text = builtins.readFile ./scripts/lock-start.sh;
  };

  # The strings on screen, pt-BR on purpose (the lock's language exception, see the notes).
  txt = {
    noWeather = "Clima indisponível";
    noMedia = "Nada tocando";
    hint = "Tela principal desconectada · digite a senha e pressione Enter";
  };

  label = writeShellApplication {
    name = "lockscreen-label";
    runtimeInputs = [ coreutils ]; # sleep, only in the clock's last 10 ms
    runtimeEnv = {
      LOCK_CACHE = v2;
      LOCK_PRIMARY = primary;
      LOCK_WEATHER_MAX_AGE = toString (12 * 3600); # two missed model runs (ECMWF IFS: every 6 h)
      LOCK_COL_SUBTEXT = p.subtext;
      LOCK_COL_TEXT = p.text;
      LOCK_COL_BG = p.bg;
      LOCK_TXT_NO_WEATHER = txt.noWeather;
      LOCK_TXT_NO_MEDIA = txt.noMedia;
      LOCK_TXT_HINT = txt.hint;
    };
    text = builtins.readFile ./scripts/label.sh;
  };
  labelBin = lib.getExe label;
  # The clock, inlined (its last line), with hyprlang's `##` for every `#`.
  clockCmd = lib.replaceStrings [ "#" ] [ "##" ] (
    lib.last (lib.splitString "\n" (lib.removeSuffix "\n" (builtins.readFile ./scripts/clock.sh)))
  );

  mediaBridge = writeShellApplication {
    name = "lockscreen-media-bridge";
    runtimeInputs = [
      coreutils
      playerctl
    ];
    runtimeEnv = {
      LOCK_CACHE = v2;
      LC_ALL = "C.UTF-8"; # ${#s} counts characters, not bytes
      LOCK_TITLE_COLS = toString (cols pt.media cards.media - 3); # the state glyph and its gap
      LOCK_ARTIST_COLS = toString (cols pt.artist cards.media);
      LOCK_COL_SUBTEXT = p.subtext;
      LOCK_TXT_NO_MEDIA = txt.noMedia;
    };
    text = builtins.readFile ./scripts/media-bridge.sh;
  };

  # Binaries at absolute paths, so nothing depends on the PATH (rule 7).
  pidof = "${procps}/bin/pidof"; # the unit's ExecCondition: do not start a 2nd hyprlock
  loginctlBin = "${systemd}/bin/loginctl";
  systemctlBin = "${systemd}/bin/systemctl";

  # Quote: a daily timer fetches ~50 from ZenQuotes and batch-translates them through DeepL into a
  # JSON batch; the renderer wraps one per lock. The layered fallbacks are in the notes.
  deeplKeyFile = "/run/secrets/deepl_api_key"; # sops (owner v1cferr); if absent, it stays EN
  quotesFetch = writeShellScript "lockscreen-quotes-fetch" ''
    ${coreutils}/bin/mkdir -p ${v2}
    tmp="${quotesJson}.tmp"
    ${coreutils}/bin/rm -f "$tmp"

    # 1) A filtered EN batch into a compact array [{q,a}].
    filtered="$(${curl}/bin/curl -s --max-time 15 'https://zenquotes.io/api/quotes' \
      | ${jq}/bin/jq -c '[.[]
          | select((.q | length) > 0 and (.q | length) <= 200 and .a != "zenquotes.io")
          | {q, a}]' 2>/dev/null || true)"

    # 2) With a batch and a DeepL key, translate the QUOTES in 1 request and recombine them with
    #    the original author IN ORDER. A mismatch leaves it empty, so it falls back to EN.
    translated=""
    if [ -n "$filtered" ] && [ "$filtered" != "[]" ] && [ -r "${deeplKeyFile}" ]; then
      key="$(${coreutils}/bin/cat "${deeplKeyFile}")"
      payload="$(${coreutils}/bin/printf '%s' "$filtered" \
        | ${jq}/bin/jq -c '{text: [.[].q], target_lang: "PT-BR", source_lang: "EN"}')"
      resp="$(${curl}/bin/curl -s --max-time 30 \
        -H "Authorization: DeepL-Auth-Key $key" -H 'Content-Type: application/json' \
        -d "$payload" 'https://api-free.deepl.com/v2/translate' 2>/dev/null || true)"
      translated="$(${jq}/bin/jq -cn --argjson f "$filtered" --argjson r "$resp" \
        'if ($r.translations | type) == "array" and ($r.translations | length) == ($f | length)
         then [range(0; ($f | length)) | {q: $r.translations[.].text, a: $f[.].a}]
         else empty end' 2>/dev/null || true)"
    fi

    # 3) The translated batch if it worked, otherwise the EN one; published atomically, and the
    #    previous batch stays when both failed. The renderer escapes and wraps.
    if [ -n "$translated" ] && [ "$translated" != "null" ] && [ "$translated" != "[]" ]; then
      ${coreutils}/bin/printf '%s' "$translated" > "$tmp"
    elif [ -n "$filtered" ] && [ "$filtered" != "[]" ]; then
      ${coreutils}/bin/printf '%s' "$filtered" > "$tmp"
    fi
    if [ -s "$tmp" ]; then ${coreutils}/bin/mv "$tmp" ${quotesJson}; else ${coreutils}/bin/rm -f "$tmp"; fi
  '';

  # Weather: a 10-min timer turns glance-feed's forecast into the card's markup, stamped with how
  # long it is valid. The case arms are GENERATED from the same attrset, so the lock and the bar never drift (rule 16).
  weatherCase = lib.concatStrings (
    lib.mapAttrsToList (
      code: text: "  ${code}) text=${lib.escapeShellArg text} ;;\n"
    ) config.my.weather.conditions
  );
  # The SAME forecast the bar draws (one fetch per model run, glance-feed), read locally: the
  # current hour's sky and temperature, so the lock and the bar cannot disagree about the minute.
  weatherFetch = writeShellScript "lockscreen-weather-fetch" ''
    ${coreutils}/bin/mkdir -p ${v2}
    hour=$(${coreutils}/bin/date +%Y-%m-%dT%H:00)
    # ONE jq pass, and `select` drops the whole line if a field is missing: a partial read must not
    # become a label. weather_code 0 survives it, since only null/false are falsy in jq.
    fields=$(${config.my.glance.feed}/bin/glance-feed read weather | ${jq}/bin/jq -r --arg h "$hour" '
      (.updated_at) as $u | .json.hourly
      | (.time | index($h)) as $i | select($i != null and $u != null)
      | select(.weather_code[$i] != null and .temperature_2m[$i] != null)
      | "\($u) \(.weather_code[$i]) \(.temperature_2m[$i] | round)"' || true)
    # No data: nothing is written, and the label turns the old file into "unavailable" on its own.
    [ -n "$fields" ] || exit 0
    set -- $fields
    # The arms are generated; the fallback shows the temperature ALONE, never an invented condition.
    case "$2" in
    ${weatherCase}  *) text="" ;;
    esac
    # Valid for this hour plus the timer's 10 min and a margin, then the label stops trusting it.
    valid=$(( $(${coreutils}/bin/date -d "$hour" +%s) + 3600 + 900 ))
    tmp="${weatherFile}.tmp"
    {
      ${coreutils}/bin/printf '%s\n%s\n<b>%s°C</b>' "$valid" "$1" "$3"
      [ -z "$text" ] || ${coreutils}/bin/printf '  <span foreground="#${p.subtext}">%s</span>' "$text"
    } > "$tmp"
    ${coreutils}/bin/mv "$tmp" ${weatherFile}
  '';

  # The idle lock, held back ONLY by fullscreen video and never past a cap; audio no longer
  # holds it. It WAITS instead of skipping, since hypridle fires each timeout ONCE. See the notes.
  idleGate = writeShellApplication {
    name = "lockscreen-idle-gate";
    runtimeInputs = [
      hyprland
      jq
      systemd # busctl and loginctl
      coreutils
      gnugrep
    ];
    runtimeEnv = {
      LOCKGATE_MAX_HOLD = toString (3 * 3600); # 3 h: a long film, never a looping video forever
      LOCKGATE_POLL = "30";
    };
    text = builtins.readFile ./scripts/idle-gate.sh;
  };

  # hyprlock colors: "rgba(rrggbbaa)" from a palette key and an alpha byte.
  c = key: a: "rgba(${p.${key}}${a})";
  # A label at a point inside a card, centered on it.
  textAt = card: dx: dy: {
    position = at card dx dy;
    halign = "center";
    valign = "center";
    text_align = "center";
  };
in
{
  # The spec, readable by the flake's check, which runs the renderer's tests against THIS JSON.
  options.my.lockscreen.spec = lib.mkOption {
    type = lib.types.path;
    readOnly = true;
    internal = true;
    default = specFile;
    description = "The renderer's generated spec (geometry, palette, glass profile, pools).";
  };

  config = {
    # hyprlock: the lock screen itself. Glass is in the IMAGES; hyprlock only draws text and the field.
    programs.hyprlock = {
      enable = true;
      settings = {
        general.hide_cursor = true;

        # The desktop's motion (docs/notes/desktop/motion.md): 180 ms ease-out in, 120 ms out, no
        # overshoot; hyprlock's speed unit is 100 ms. motion = "off" turns it all off.
        animations = {
          enabled = !motionOff;
          bezier = [
            "easeOutQuint, 0.23, 1, 0.32, 1"
            "almostLinear, 0.5, 0.5, 0.75, 1"
          ];
          animation = [
            "fadeIn, 1, 1.8, easeOutQuint"
            "fadeOut, 1, 1.2, almostLinear"
            "inputFieldColors, 1, 2, almostLinear"
            "inputFieldDots, 1, 1, easeOutQuint"
          ];
        };

        # Static images only, NEVER reloaded during a lock (lesson 2). The session links point at the
        # ready set or at the build-time fallback; `color` shows if a link ever dangles.
        background = [
          {
            monitor = ""; # any output nobody planned for gets the palette's bg, not undefined pixels
            color = c "bg" "ff";
            zindex = -2;
          }
          {
            monitor = primary;
            color = c "bg" "ff";
            path = "${session}/primary";
          }
          {
            monitor = secondary;
            color = c "bg" "ff";
            path = "${session}/secondary";
          }
        ];

        # On its pre-rendered glass: a clear inside, a hairline carrying the state. 0.9.5 has no focus
        # state, so neutral at rest, blue checking, red failed, yellow with Caps Lock.
        input-field = {
          monitor = primary;
          size = "${toString (builtins.elemAt cards.auth.size 0)}, ${toString (builtins.elemAt cards.auth.size 1)}";
          outline_thickness = 1;
          rounding = cards.auth.radius;
          inner_color = "rgba(00000000)";
          outer_color = c "border" "8c";
          check_color = c "accent" "ff";
          fail_color = c "red" "ff";
          capslock_color = c "yellow" "ff";
          font_color = c "text" "ff";
          font_family = font;
          placeholder_text = ''<span foreground="##${p.subtext}">Digite a senha…</span>'';
          fail_text = ''<span foreground="##${p.red}">$PAMFAIL</span>'';
          dots_size = 0.22;
          dots_spacing = 0.35;
          fade_on_empty = false;
          position = at cards.auth 0 0;
          halign = "center";
          valign = "center";
        };

        label = [
          # The time, with seconds, from the system clock (chrony/NTS). 995 and not 1000: hyprlock's
          # timer runs ~0.7 ms long, and a period over 1 s MUST skip a second (measured in the notes).
          (
            textAt cards.clock 0 (-22)
            // {
              monitor = primary;
              text = "cmd[update:995] ${clockCmd}";
              color = c "text" "ff";
              font_size = pt.clock;
              font_family = "${font} Light";
            }
          )
          (
            textAt cards.clock 0 78
            // {
              monitor = primary;
              text = "cmd[update:60000] ${labelBin} date";
              color = c "subtext" "ff";
              font_size = pt.date;
              font_family = font;
            }
          )
          # The standing monitor: weather, media (Media layout only), the quote of this lock.
          (
            textAt cards.weather 0 (-28)
            // {
              monitor = secondary;
              text = config.my.weather.place;
              color = c "subtext" "ff";
              font_size = pt.weatherTitle;
              font_family = font;
            }
          )
          (
            textAt cards.weather 0 18
            // {
              monitor = secondary;
              text = "cmd[update:60000] ${labelBin} weather";
              color = c "text" "ff";
              font_size = pt.weather;
              font_family = font;
            }
          )
          (
            textAt cards.media 0 0
            // {
              monitor = secondary;
              # A file the bridge rewrites on every MPRIS event, read here: SIGUSR2 is not used,
              # its 0.9.5 handler runs label code inside the signal handler (see the notes).
              text = "cmd[update:3000] ${labelBin} media";
              color = c "text" "ff";
              font_size = pt.media;
              font_family = font;
            }
          )
          (
            textAt cards.quote 0 0
            // {
              monitor = secondary;
              text = "cmd[update:0] ${labelBin} quote"; # once per surface: the quote of THIS lock
              color = c "text" "ff";
              font_size = pt.quote;
              font_family = font;
            }
          )
          # Every output: empty while the main monitor is connected, the way out when it is not.
          {
            monitor = "";
            text = "cmd[update:5000] ${labelBin} hint";
            color = c "text" "ff";
            font_size = pt.date;
            font_family = font;
            position = "0, -120";
            halign = "center";
            valign = "top";
          }
        ];
      };
    };

    # The session links exist BEFORE the first lock after a switch, the same step the unit runs.
    home.activation.lockscreenSession = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      run ${lib.getExe lockStart}
    '';

    # hyprlock as its OWN UNIT, because locking is a SECURITY function and cannot be hostage to an
    # idle daemon anything can stop. The 6h outage and the remote lockout: the notes.
    systemd.user.services.hyprlock = {
      Unit = {
        Description = "Lock screen (hyprlock)";
        # With no graphical session there is nothing to lock, and the lock dies with it.
        PartOf = [ "graphical-session.target" ];
        After = [ "graphical-session.target" ];
        # The media card's writer lives exactly as long as this lock; Wants, so it can never fail it.
        Wants = [ "lockscreen-media.service" ];
      };
      Service = {
        Type = "simple"; # it runs while the screen is locked and exits on unlock
        # The heir of the old `pidof hyprlock ||`, now covering only the TTY rescue. ExecCondition and
        # not ExecStartPre: failing here SKIPS silently instead of marking the unit failed.
        ExecCondition = "${bash}/bin/bash -c '! ${pidof} hyprlock'";
        # The leading `-` makes it BEST EFFORT, and it only links files that already exist: the lock
        # never waits on a render, and never refuses to start over a wallpaper.
        ExecStartPre = "-${lib.getExe lockStart}";
        ExecStart = "${hyprlock}/bin/hyprlock";
        # After the unlock, render the NEXT lock's images in the background.
        ExecStopPost = "-${systemctlBin} --user start --no-block lockscreen-prepare.service";
      };
      # NO Install/wantedBy ON PURPOSE: what locks is the click or the idle, never the boot.
    };

    # The media card's writer: only inside a Media lock, event-driven, gone with the unlock.
    systemd.user.services.lockscreen-media = {
      Unit = {
        Description = "Feeds the lock screen's media card from MPRIS while locked";
        BindsTo = [ "hyprlock.service" ];
        After = [ "hyprlock.service" ];
      };
      Service = {
        Type = "simple";
        ExecCondition = "${gnugrep}/bin/grep -qx media ${session}/layout";
        ExecStart = lib.getExe mediaBridge;
        Restart = "on-failure";
        RestartSec = 2;
      };
    };

    # The renderer: idle priority, bounded memory, one at a time (it holds a lock on the cache).
    systemd.user.services.lockscreen-prepare = {
      Unit.Description = "Renders the next lock screen's glass backgrounds";
      Service = {
        Type = "oneshot";
        ExecStart = "${lib.getExe render} prepare --spec ${config.my.lockscreen.spec} --cache ${v2}";
        Nice = 19;
        CPUSchedulingPolicy = "idle";
        IOSchedulingClass = "idle";
        MemoryMax = "1G";
      };
    };
    systemd.user.timers.lockscreen-prepare = {
      Unit.Description = "Renders a fresh lock screen after login and every 6 h";
      Timer = {
        OnStartupSec = "1min"; # the first set, out of the boot's way
        OnUnitActiveSec = "6h"; # new art and a new quote even without an unlock
      };
      Install.WantedBy = [ "timers.target" ];
    };

    # The idle lock deferred by fullscreen video. A unit of its own because it has to OUTLIVE the
    # `on-timeout` that fired it, sometimes by a whole movie, and rule 15 wants one declared owner.
    systemd.user.services.lockscreen-idle-lock = {
      Unit = {
        Description = "Locks on idle, holding it back while fullscreen video plays";
        # A PENDING lock belongs to the daemon that scheduled it: the Sunshine guard stops hypridle
        # so the stream does not lock, and this has to die with it.
        PartOf = [ "hypridle.service" ];
        After = [ "hypridle.service" ];
      };
      Service = {
        Type = "simple"; # it stays alive while a video plays and exits right after locking
        ExecStart = lib.getExe idleGate;
      };
      # NO Install: hypridle's listener is the only trigger, the same as hyprlock above.
    };

    # hypridle: after 5 min it locks (not under fullscreen video) and holds Eco. NO dpms-off, which
    # broke moon/Sunshine (see the notes).
    services.hypridle = {
      enable = true;
      settings = {
        general = {
          # It delegates to the unit above; `start` is idempotent, so never a second hyprlock.
          lock_cmd = "${systemctlBin} --user start hyprlock.service";
          # If it ever suspends (it does not today), lock before sleeping.
          before_sleep_cmd = "${loginctlBin} lock-session";
          # Kept true: the gate below is the SINGLE decision point, so no app can hold an inhibit
          # forever and disable locking in silence.
          ignore_dbus_inhibit = true;
        };
        listener = [
          # 5 min: lock THROUGH the gate. There is NO dpms-off listener; the monitor stays on so moon
          # always captures.
          {
            timeout = 300;
            on-timeout = "${systemctlBin} --user start lockscreen-idle-lock.service";
            # Back at the keyboard cancels a lock that was still waiting for the video to end.
            on-resume = "${systemctlBin} --user stop lockscreen-idle-lock.service";
          }
          # 5 min away: the automatic Eco hold (modules/nixos/hardware/power.nix), skipped under a game.
          {
            timeout = 300;
            on-timeout = "${systemctlBin} --user start power-idle-eco.service";
            on-resume = "${systemctlBin} --user stop power-idle-eco.service";
          }
        ];
      };
    };

    # Weather: the card's markup from the glance cache, as a oneshot plus a timer (no loose script).
    systemd.user.services.lockscreen-weather = {
      Unit.Description = "Refreshes the lock screen weather card from the glance cache";
      Service = {
        Type = "oneshot";
        ExecStart = "${weatherFetch}";
      };
    };
    systemd.user.timers.lockscreen-weather = {
      Unit.Description = "Refreshes the lock screen weather card every 10 min";
      Timer = {
        OnBootSec = "1min"; # the 1st fetch right after boot
        OnUnitActiveSec = "10min"; # and every 10 min afterwards
        Persistent = true;
      };
      Install.WantedBy = [ "timers.target" ];
    };

    # Quotes: the ZenQuotes batch, as a oneshot plus a timer (it replaced the vendored TSV).
    systemd.user.services.lockscreen-quotes = {
      Unit.Description = "Refreshes the lock screen quote batch (ZenQuotes)";
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
  };
}
