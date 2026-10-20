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
    librsvg
    nixos-artwork
    notify
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
  inherit (geo)
    cards
    at
    atLeft
    ;
  lgSize = geo.monitors.secondary.size;

  # The packaged art, for an empty pool and for the build-time fallback (no binary in git).
  art = nixos-artwork.wallpapers;
  wallMain = "${art.catppuccin-mocha}/share/backgrounds/nixos/nixos-wallpaper-catppuccin-mocha.png";
  wallSecondary = "${art.waterfall}/share/backgrounds/nixos/nix-wallpaper-waterfall.png";

  # MY OWN art, as STATE and not config (rule 6): Japanese prints and photos, landscape for the
  # main monitor in `wide/`, portrait for the standing one at the top. Never the desktop's astronomy.
  wallDir = "${config.home.homeDirectory}/Pictures/lockscreen";
  wallWide = "${wallDir}/wide";

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
      alphaMin = 0.45; # the floor; each card starts at its own baseline (geometry.nix)...
      alphaMax = 0.92; # ...and goes denser only as far as contrast needs
      tint = 0.2;
      brightness = 0.95;
      contrast = 0.95;
      blurSigma = 28.0; # Glass+: a deep frost, so a clear card still reads as glass: docs/notes/desktop/lockscreen.md
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

  # Type sizes (pt). One JetBrains Mono column is 0.8 px per pt at 96 dpi; hyprlock rounds the size
  # up, and a 12 pt column MEASURED 10 px on screen, so the columns are counted at 0.84 px per pt.
  pt = {
    clock = 88;
    date = 16;
    name = 17;
    nick = 12;
    quote = 17;
    title = 10; # a card's caption on the LG
    body = 14; # the LG cards' running text, read from the chair: 36 columns in a 472 px card
    weather = 20;
    media = 15;
    artist = 13;
  };
  pad = 48; # a card's horizontal padding, each side
  cols = size: card: builtins.floor ((builtins.elemAt card.size 0 - 2 * pad) / (0.84 * size));
  colsLg = size: card: builtins.floor ((builtins.elemAt card.size 0 - 48) / (0.84 * size)); # LG: 24 px insets

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
      rim = 0.28; # the optical rim: text-colored light, full at the top edge, gone by mid-height
      sheen = 0.06; # colSheen: text at 0x0f
      hairline = 1;
    };
    # Glass+: a soft shadow under each card, light from above, and a whisper of lens at the rim.
    shadow = {
      alpha = 0.3;
      sigma = 14;
      dy = 4;
    };
    highlight = {
      alpha = 0.09;
      depth = 0.45;
    };
    # The palette's accent breathed into the frost: Tokyo Night's blue, not a neutral gray glass.
    hue = {
      color = "accent";
      alpha = 0.06;
    };
    refraction = 1.2e-2;
    rimBand = 6;
    # The logo is STATE (my file, never in git): baked into the identity card, and simply left out
    # if the file is missing, so it can never stand between me and the lock.
    logo = {
      path = config.my.lockscreen.logo;
      size = 68;
      card = "identity";
      dy = -34;
      color = "text";
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
        pools = [ wallWide ];
        fallback = wallMain;
        layouts.main = [
          (cards.identity // { contrast = aa; })
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
          (cards.quote // { contrast = aa; })
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
      librsvg # rsvg-convert: the logo's SVG, rasterized at render time
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

  # The observability adapter (docs/notes/desktop/lockscreen.md#the-lg-while-locked): stdlib only.
  # `observe json energy` is also what the glance band's energy panel runs (dash/EnergyLog.qml).
  observe = writeShellApplication {
    name = "observe";
    runtimeInputs = [ python3 ];
    text = ''exec python3 -I ${./scripts/observe.py} "$@"'';
  };
  paletteFile = writeText "lockscreen-palette.json" (builtins.toJSON p);

  # The strings on screen, pt-BR on purpose (the lock's language exception, see the notes).
  txt = {
    noWeather = "Clima indisponível";
    noMedia = "Nada tocando";
    noData = "Sem dados no momento";
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
      LOCK_COL_DIM = p.dim;
      LOCK_CAPTION_SIZE = toString (pt.title * 1024);
      LOCK_COL_TEXT = p.text;
      LOCK_COL_BG = p.bg;
      LOCK_TXT_NO_WEATHER = txt.noWeather;
      LOCK_TXT_NO_MEDIA = txt.noMedia;
      LOCK_TXT_HINT = txt.hint;
      LOCK_TXT_NO_DATA = txt.noData;
      LOCK_OBS_MAX_AGE = "180"; # three missed rounds of the slowest card
    };
    text = builtins.readFile ./scripts/label.sh;
  };
  labelBin = lib.getExe label;
  # The clock, inlined (its last line), with hyprlang's `##` for every `#`.
  clockCmd = lib.replaceStrings [ "#" "@ACCENT@" ] [ "##" p.accent ] (
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
      LOCK_TITLE_COLS = toString (colsLg pt.media cards.media - 3); # the state glyph and its gap
      LOCK_ARTIST_COLS = toString (colsLg pt.artist cards.media);
      LOCK_COL_SUBTEXT = p.subtext;
      LOCK_COL_DIM = p.dim;
      LOCK_CAPTION_SIZE = toString (pt.title * 1024); # absolute: pango here ignores a percentage
      LOCK_TXT_NO_MEDIA = txt.noMedia;
    };
    text = builtins.readFile ./scripts/media-bridge.sh;
  };

  # hyprlock on the SESSION's compositor, even when the manager's WAYLAND_DISPLAY went stale
  # (every idle lock failed that way on 18/10/2026, leaving the screen open).
  lockLaunch = writeShellApplication {
    name = "lockscreen-launch";
    runtimeInputs = [
      hyprland
      hyprlock
      jq
      coreutils
    ];
    text = builtins.readFile ./scripts/lock-launch.sh;
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
  # The glyph per code, day and night, from the same table the bar reads (my.weather.icons).
  weatherIconCase = lib.concatStrings (
    lib.mapAttrsToList (
      code: v: "  ${code}) iday=${lib.escapeShellArg v.day}; inight=${lib.escapeShellArg v.night} ;;\n"
    ) config.my.weather.icons
  );
  # The SAME forecast the bar draws (one fetch per model run, glance-feed), read locally: the
  # current hour's sky and temperature, so the lock and the bar cannot disagree about the minute.
  weatherFetch = writeShellScript "lockscreen-weather-fetch" ''
    ${coreutils}/bin/mkdir -p ${v2}
    hour=$(${coreutils}/bin/date +%Y-%m-%dT%H:00)
    # ONE jq pass, and `select` drops the whole line if a field is missing: a partial read must not
    # become a label. weather_code 0 survives it, since only null/false are falsy in jq.
    # The day's extremes, rain chance and the hour's feels-like ride along; a missing one is "-".
    fields=$(${config.my.glance.feed}/bin/glance-feed read weather | ${jq}/bin/jq -r --arg h "$hour" --arg d "''${hour%T*}" '
      (.updated_at) as $u | .json as $j | $j.hourly
      | (.time | index($h)) as $i | select($i != null and $u != null)
      | select(.weather_code[$i] != null and .temperature_2m[$i] != null)
      | (($j.daily.time // []) | index($d)) as $k
      | def r(x): if x == null then "-" else (x | round | tostring) end;
      "\($u) \(.weather_code[$i]) \(.temperature_2m[$i] | round) \(r(if $k == null then null else $j.daily.temperature_2m_max[$k] end)) \(r(if $k == null then null else $j.daily.temperature_2m_min[$k] end)) \(r(if $k == null then null else $j.daily.precipitation_probability_max[$k] end)) \(r(.apparent_temperature[$i])) \(if .is_day[$i] == 0 then 0 else 1 end)"' || true)
    # No data: nothing is written, and the label turns the old file into "unavailable" on its own.
    [ -n "$fields" ] || exit 0
    set -- $fields
    # The arms are generated; the fallback shows the temperature ALONE, never an invented condition.
    case "$2" in
    ${weatherCase}  *) text="" ;;
    esac
    # The sky as a glyph, by day or by night; an unknown code shows no glyph rather than a wrong one.
    iday="" inight=""
    case "$2" in
    ${weatherIconCase}  *) ;;
    esac
    icon="$iday"
    [ "$8" = 1 ] || icon="$inight"
    # Valid for this hour plus the timer's 10 min and a margin, then the label stops trusting it.
    valid=$(( $(${coreutils}/bin/date -d "$hour" +%s) + 3600 + 900 ))
    tmp="${weatherFile}.tmp"
    # Line 2 only with what was actually read: a "-" field drops out instead of becoming a number.
    # Two short lines, so they fit the half-width card of the Media layout too.
    day="" now=""
    [ "$4" = - ] || day="máx $4°"
    [ "$5" = - ] || day="''${day:+$day · }mín $5°"
    [ "$6" = - ] || now="chuva $6%"
    [ "$7" = - ] || now="''${now:+$now · }sensação $7°"
    extra="$day''${day:+''${now:+$'\n'}}$now"
    {
      ${coreutils}/bin/printf '%s\n%s\n' "$valid" "$1"
      [ -z "$icon" ] || ${coreutils}/bin/printf '<span size="${toString (28 * 1024)}" foreground="#${p.sky}">%s</span>  ' "$icon"
      ${coreutils}/bin/printf '<b>%s°C</b>' "$3"
      [ -z "$text" ] || ${coreutils}/bin/printf '  <span foreground="#${p.subtext}">%s</span>' "$text"
      [ -z "$extra" ] || ${coreutils}/bin/printf '\n<span size="${toString (pt.body * 1024)}" foreground="#${p.subtext}">%s</span>' "$extra"
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
  # A soft shadow under text: the clearer glass keeps its legibility without a denser tint.
  shade = {
    shadow_passes = 2;
    shadow_size = 4;
    shadow_color = c "shadow" "cc";
    shadow_boost = 1.0;
  };
  # A label at a point inside a card, centered on it.
  textAt =
    card: dx: dy:
    shade
    // {
      position = at card dx dy;
      halign = "center";
      valign = "center";
      text_align = "center";
    };
in
{
  # The spec, readable by the flake's check, which runs the renderer's tests against THIS JSON.
  options.my.lockscreen.logo = lib.mkOption {
    type = lib.types.str;
    default = "${config.home.homeDirectory}/.dropbox-hm/Dropbox/Obsidian/v1cferr/5-Planning/5.7-@v1cferr/5.7.1-Logo/As Profile Pic/SVG/1018x1018.svg";
    description = "My logo's SVG, as STATE: read when the lock's images render, never copied into git. Missing means no logo, never no lock.";
  };

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
          placeholder_text = ''<span foreground="##${p.subtext}">󰌾  Digite a senha…</span>'';
          fail_text = ''<span foreground="##${p.red}">$PAMFAIL</span>'';
          dots_size = 0.22;
          dots_spacing = 0.35;
          fade_on_empty = false;
          position = at cards.auth 0 0;
          halign = "center";
          valign = "center";
        };

        label =
          let
            # A label at a point inside a card on the LG, from its top-left corner (left-aligned text).
            lgText = card: dx: dy: {
              monitor = secondary;
              position = atLeft lgSize card dx dy;
              halign = "left";
              valign = "top";
              text_align = "left";
              font_family = font;
            };
            # A card's caption: its icon and title in the card's own color, small, in the corner.
            caption =
              card: tone: words:
              lgText card 24 20
              // {
                text = words;
                color = c tone "ff";
                font_size = pt.title;
              };
            obs =
              card: name: every:
              lgText card 24 46
              // shade
              // {
                text = "cmd[update:${toString every}] ${labelBin} obs ${name}";
                color = c "text" "ff";
                font_size = pt.body;
              };
          in
          [
            # ── ASUS: who, when, the way in, a thought. All on one axis. ──
            (
              textAt cards.identity 0 22
              // {
                monitor = primary;
                text = config.programs.git.settings.user.name;
                color = c "text" "ff";
                font_size = pt.name;
                font_family = "${font} SemiBold";
              }
            )
            (
              textAt cards.identity 0 52
              // {
                monitor = primary;
                text = config.home.username;
                color = c "subtext" "ff";
                font_size = pt.nick;
                font_family = font;
              }
            )
            # The time, with seconds, from the system clock (chrony/NTS). 995 and not 1000: hyprlock's
            # timer runs ~0.7 ms long, and a period over 1 s MUST skip a second (measured in the notes).
            (
              textAt cards.clock 0 (-17)
              // {
                monitor = primary;
                text = "cmd[update:995] ${clockCmd}";
                color = c "text" "ff";
                font_size = pt.clock;
                font_family = "${font} Light";
              }
            )
            (
              textAt cards.clock 0 80
              // {
                monitor = primary;
                text = "cmd[update:60000] ${labelBin} date ${p.accent}";
                color = c "subtext" "ff";
                font_size = pt.date;
                font_family = font;
              }
            )
            # The quote card's mark: a large, quiet opening quote in the corner, saying what the card is.
            (
              textAt cards.quote (-440) (-82)
              // {
                monitor = primary;
                text = "󰝗"; # the Nerd Font's open quote: the dingbat ❝ fell back to a tiny glyph
                color = c "accent" "73";
                font_size = 34;
                font_family = font;
              }
            )
            (
              textAt cards.quote 0 0
              // {
                monitor = primary;
                text = "cmd[update:0] ${labelBin} quote"; # once per surface: the quote of THIS lock
                color = c "text" "ff";
                font_size = pt.quote;
                font_family = font;
              }
            )

            # ── LG: what the machine is doing while I am away. Captions are static; the rest reads
            # files the observe service and the bridges write (no network, no /proc walk here). ──
            (caption cards.energy "orange" "󱐋  ENERGIA")
            (obs cards.energy "energy" 60000)
            (caption cards.claude "magenta" "✦  CLAUDE CODE")
            (obs cards.claude "claude" 60000)
            (caption cards.system "blue" "󰍛  SISTEMA")
            (obs cards.system "system" 30000)
            (caption cards.procs "teal" "󰒋  PROCESSOS")
            (obs cards.procs "procs" 30000)
            (caption cards.weather "sky" "󰖐  CLIMA  ·  ${config.my.weather.place}")
            (
              lgText cards.weather 24 50
              // shade
              // {
                text = "cmd[update:60000] ${labelBin} weather";
                color = c "text" "ff";
                font_size = pt.weather;
              }
            )
            (
              lgText cards.media 24 20
              // shade
              // {
                # Empty in Ambient, where there is no media card: its caption rides in the markup.
                text = "cmd[update:3000] ${labelBin} media";
                color = c "text" "ff";
                font_size = pt.media;
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

    home.packages = [ observe ]; # on the PATH for the glance band, one adapter for both screens

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
        # A lock that fails is a screen left OPEN: say so on the phone, since nobody is at the desk.
        OnFailure = [ "lockscreen-lock-failed.service" ];
        # The media card's writer lives exactly as long as this lock; Wants, so it can never fail it.
        Wants = [
          "lockscreen-media.service"
          "lockscreen-observe.service"
        ];
      };
      Service = {
        Type = "simple"; # it runs while the screen is locked and exits on unlock
        # The heir of the old `pidof hyprlock ||`, now covering only the TTY rescue. ExecCondition and
        # not ExecStartPre: failing here SKIPS silently instead of marking the unit failed.
        ExecCondition = "${bash}/bin/bash -c '! ${pidof} hyprlock'";
        # The leading `-` makes it BEST EFFORT, and it only links files that already exist: the lock
        # never waits on a render, and never refuses to start over a wallpaper.
        ExecStartPre = "-${lib.getExe lockStart}";
        ExecStart = lib.getExe lockLaunch;
        # After the unlock, render the NEXT lock's images in the background.
        ExecStopPost = "-${systemctlBin} --user start --no-block lockscreen-prepare.service";
      };
      # NO Install/wantedBy ON PURPOSE: what locks is the click or the idle, never the boot.
    };

    # The alarm for a failed lock: urgent on the phone (ntfy), with where to look.
    systemd.user.services.lockscreen-lock-failed = {
      Unit.Description = "Pushes an alarm when the lock screen fails to start or crashes";
      Service = {
        Type = "oneshot";
        ExecStart = "${lib.getExe notify} -p urgent -T lock \"Lock screen FAILED on %H\" \"hyprlock.service failed; the screen may be UNLOCKED. journalctl --user -u hyprlock\"";
      };
    };

    # The media card's writer: only inside a Media lock, event-driven, gone with the unlock.
    # The LG's data while locked: power-log, glance-feed's cache and /proc, read every 30 to 60 s
    # and written as ready markup. Lives exactly as long as the lock; never a permanent daemon.
    systemd.user.services.lockscreen-observe = {
      Unit = {
        Description = "Feeds the lock screen's observability cards while locked";
        BindsTo = [ "hyprlock.service" ];
        After = [ "hyprlock.service" ];
      };
      Service = {
        Type = "simple";
        ExecStart = "${lib.getExe observe} lock-loop --out ${session}/obs --palette ${paletteFile} --cols ${toString (colsLg pt.body cards.procs)}";
        Restart = "on-failure";
        RestartSec = 5;
        Nice = 10;
        MemoryMax = "96M";
      };
    };

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
