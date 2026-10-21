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

  # Colors from my.theme (palette.nix), the corner from my.theme.rounding.
  p = config.my.theme.palette;
  motionOff = config.my.theme.motion == "off";
  geo = import ./geometry.nix {
    inherit lib;
    inherit (config.my.theme) rounding;
  };
  inherit (geo)
    cards
    at
    lg
    ;

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
  weatherFile = "${v2}/weather";

  # The glass PROFILE's numbers, one row per my.theme.glass value. They MIRROR Theme.qml's card
  # level and glass.lua's preset; test_render.py fails if either side moves without the other.
  profiles = {
    clear-gradient = {
      solid = false;
      gradient = true;
      alphaMin = 0.2; # the lightest base a card may have (each sets its own)...
      alphaMax = 0.92; # ...and the most a text zone may be shaded on top of it, only as contrast needs
      tint = 0.2;
      brightness = 0.95;
      contrast = 0.95;
      blurSigma = 22.0; # Bento cards: a frost that still shows the print's shapes: docs/notes/desktop/lockscreen.md
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

  # The lock's TYPE (v5), never the desktop's: Geist for display and body, Geist Mono for data and
  # labels, Material Symbols for icons at the text's weight, Sparks for charts. Fonts: fonts.nix.
  type = {
    display = "Geist";
    data = "Geist Mono";
    icons = "Material Symbols Rounded";
    iconWeight = 300;
    chart = "Sparks Dot-line Thick,"; # the comma ends the family: pango would read "Thick" as a weight
    chartEm = 0.35; # one data point's width in em, measured with pango 1.57
    bars = "Sparks Bar Medium,"; # held values (Claude's week): bars, never a line across a reset
    barsEm = 0.30;
  };
  typeFile = writeText "lockscreen-type.json" (builtins.toJSON type);
  # An icon by its ligature name, at the type's weight (a variable axis, `@wght`).
  icon =
    size: name:
    ''<span font_desc="${type.icons} ${toString size} @wght=${toString type.iconWeight}">${name}</span>'';

  # Type sizes (pt). One mono column is 0.8 px per pt at 96 dpi; hyprlock rounds the size up, and a
  # 12 pt column MEASURED 10 px on screen, so the columns are counted at 0.84 px per pt.
  pt = {
    clock = 144; # editorial: HH:MM:SS at ONE size, Thin, tabular, the seconds in a quieter blue
    date = 15;
    name = 20; # the identity group, under the logo
    nick = 13;
    quote = 21;
    title = 12; # a card's header on the LG: tracked caps
    body = 15; # the LG cards' running text, read from the chair
  };
  colsOf = width: size: builtins.floor (width / (0.84 * size)); # how many columns a width holds

  # The LG cards' glass (v5.2), picked from a Crystal / Adaptive Glass+ / Frosted study on the same
  # print and data: a light base and a light frost so the print reads through, contrast added only
  # under the text (docs/notes/desktop/lockscreen.md). The ASUS field and quote share its frost.
  lgMaterial = {
    alpha = 0.42;
    glass = {
      blurSigma = 12.0;
      tint = 0.12;
    };
  };

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
      # HyprGlass's fresnel, static: light along the whole inner edge, gone 14 px in.
      fresnel = {
        alpha = 0.1;
        width = 14;
      };
    };
    # Editorial (v5.2): a soft halo under each line of type on the ASUS, as dense as THAT line needs.
    halo = {
      feather = 70; # wide and soft: atmosphere under a line, never a shape of its own
      max = 0.5; # with the ink chosen per print, a halo is the exception, and a gentle one
      paper = "f4efe4"; # under DARK ink the halo lightens like mist on washi, not with a palette tint
    };
    # Glass+: a soft, deep elevation under the panel, light from above, a whisper of lens at the rim.
    shadow = {
      alpha = 0.35;
      sigma = 36;
      dy = 14;
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
    # The logo is STATE (my file, never in git): baked in at the head of the column, and simply left
    # out if the file is missing, so it can never stand between me and the lock.
    logo = {
      path = config.my.lockscreen.logo;
      size = 64; # frameless, by its ink, above the name: a signature, not a badge
      card = "column";
      dy = 33;
      color = "text";
    };
    contrast = aa;
    # The quotes are CONTENT in the repo (curated, sourced); what was shown is STATE.
    quotesFile = ./quotes.json;
    quotesSeen = "${config.xdg.stateHome}/lockscreen/quotes-seen.json";
    quote = {
      columns = 66; # the quote card's 1104 px at 21 pt: Geist is proportional, ~7% narrower than a mono count
      lines = 4;
      originalColumns = 93; # the original and the credit, smaller, on the same 1104 px
      originalLines = 2;
      originalSize = 14;
      metaSize = 13;
      originalFonts.grc = "Noto Sans"; # Geist has no polytonic Greek; Noto Sans does (fonts.nix)
      haikuShare = 0.34; # beside a print, about one draw in three is a haiku
      fallback = {
        id = "kay-predict-the-future";
        kind = "computing";
        text = "A melhor forma de prever o futuro é inventá-lo.";
        original = "The best way to predict the future is to invent it.";
        lang = "en";
        author = "Alan Kay";
        source = "reunião no Xerox PARC";
        year = "1971";
      };
    };
    monitors = {
      primary = {
        name = primary;
        inherit (geo.monitors.primary) size;
        pools = [ wallWide ];
        fallback = wallMain;
        layouts.main = [
          # Every line of the column is in `text`, so only it needs AA: a lighter shade over bright paper.
          # The ink follows the print (render.py); a halo of the opposite tone only where a line needs it.
          (
            cards.column
            // {
              contrast.text = aa.text;
              inks = {
                light = "text";
                dark = "bg";
              };
            }
          )
          # The field's failure text and the red hairline sit on this glass.
          (
            cards.auth
            // {
              inherit (lgMaterial) glass;
              contrast.text = aa.text; # the placeholder, the dots and the PAM text are all `text`
            }
          )
          (
            cards.quote
            // {
              inherit (lgMaterial) glass;
              contrast.text = aa.text; # the quote, its original and its credit are all `text`
            }
          )
        ];
      };
      secondary = {
        name = secondary;
        inherit (geo.monitors.secondary) size;
        layouts = lib.mapAttrs (_: map (c: c // lgMaterial)) geo.monitors.secondary.layouts;
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
      LOCK_META_SIZE = toString (13 * 1024); # a card's meta line, absolute: pango ignores a percentage
      LOCK_COL_TEXT = p.text;
      LOCK_COL_BG = p.bg;
      LOCK_COL_INK_DARK = p.bg; # the ASUS type on a light print: Tokyo Night's own dark, as sumi
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
  clockCmd =
    lib.replaceStrings
      [ "#" "@ACCENT@" "@TEXT@" "@DARK@" "@DARKACCENT@" "@INK@" ]
      [
        "##"
        p.accent
        p.text
        p.bg
        p.border # the seconds on a light print: Tokyo Night's dark indigo, still a blue
        "${session}/ink"
      ]
      (lib.last (lib.splitString "\n" (lib.removeSuffix "\n" (builtins.readFile ./scripts/clock.sh))));

  mediaBridge = writeShellApplication {
    name = "lockscreen-media-bridge";
    runtimeInputs = [
      coreutils
      playerctl
    ];
    runtimeEnv = {
      LOCK_CACHE = v2;
      LC_ALL = "C.UTF-8"; # ${#s} counts characters, not bytes
      LOCK_TITLE_COLS = toString (colsOf (lg.inner cards.media) 20); # the title at 20 pt, Light
      LOCK_TITLE_SIZE = toString (20 * 1024); # absolute: pango here ignores a percentage
      LOCK_COL_TONE = p.green; # the media section's color, as each LG section has one
      LOCK_ARTIST_COLS = toString (colsOf (lg.inner cards.media) pt.body);
      LOCK_COL_SUBTEXT = p.subtext;
      LOCK_TXT_NO_MEDIA = txt.noMedia;
      LOCK_ICON_FONT = "${type.icons} 16 @wght=${toString type.iconWeight}";
      LOCK_TITLE_FONT = type.display;
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

  # Weather: a 10-min timer turns glance-feed's forecast into the card's markup, stamped with how
  # long it is valid. The case arms are GENERATED from the same attrset, so the lock and the bar never drift (rule 16).
  weatherCase = lib.concatStrings (
    lib.mapAttrsToList (
      code: text: "  ${code}) text=${lib.escapeShellArg text} ;;\n"
    ) config.my.weather.conditions
  );
  # The sky per WMO code as a Material Symbols name, day and night: the lock's own table in the
  # lock's icon font, over the SAME codes as my.weather.conditions (the bar keeps its Nerd glyphs).
  weatherIcons =
    let
      same = name: {
        day = name;
        night = name;
      };
      sky = {
        day = "partly_cloudy_day";
        night = "partly_cloudy_night";
      };
    in
    {
      "0" = {
        day = "clear_day";
        night = "clear_night";
      };
      "1" = sky;
      "2" = sky;
      "3" = same "cloud";
    }
    // lib.genAttrs [ "45" "48" ] (_: same "foggy")
    // lib.genAttrs [ "51" "53" "55" "61" ] (_: same "rainy_light")
    // lib.genAttrs [ "63" "80" "81" ] (_: same "rainy")
    // lib.genAttrs [ "65" "82" ] (_: same "rainy_heavy")
    // lib.genAttrs [ "56" "57" "66" "67" ] (_: same "weather_mix")
    // lib.genAttrs [ "71" "73" "75" "77" ] (_: same "weather_snowy")
    // lib.genAttrs [ "85" "86" ] (_: same "cloudy_snowing")
    // {
      "95" = same "thunderstorm";
    }
    // lib.genAttrs [ "96" "99" ] (_: same "weather_hail");
  weatherIconCase = lib.concatStrings (
    lib.mapAttrsToList (
      code: v: "  ${code}) iday=${lib.escapeShellArg v.day}; inight=${lib.escapeShellArg v.night} ;;\n"
    ) weatherIcons
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
      [ -z "$icon" ] || ${coreutils}/bin/printf '<span font_desc="${type.icons} 40 @wght=${toString type.iconWeight}" foreground="#${p.sky}">%s</span>  ' "$icon"
      ${coreutils}/bin/printf '<span font_family="${type.display}" size="${toString (44 * 1024)}" font_weight="200">%s°</span>' "$3"
      [ -z "$text" ] || ${coreutils}/bin/printf '\n%s' "$text"
      # The day's context after a `--` line: the lock shows it under the now, or beside it.
      [ -z "$extra" ] || ${coreutils}/bin/printf '\n--\n<span size="${toString (13 * 1024)}" foreground="#${p.subtext}">%s</span>' "$extra"
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
  # A light shadow under the LG's text: the glass holds AA, this only lifts the type off it.
  shade = {
    shadow_passes = 1;
    shadow_size = 3;
    shadow_color = c "shadow" "99";
    shadow_boost = 1.0;
  };
  # A label at a point inside a card, centered on it. No text shadow on the ASUS: the ink follows the
  # print, and a dark shadow under dark ink would only blur it.
  textAt = card: dx: dy: {
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

        # A faint pill over the shaded column, its hairline carrying the state. 0.9.5 has no focus
        # state, so neutral at rest, blue checking, red failed, yellow with Caps Lock.
        input-field = {
          monitor = primary;
          size = "${toString (builtins.elemAt cards.auth.size 0)}, ${toString (builtins.elemAt cards.auth.size 1)}";
          outline_thickness = 1;
          rounding = cards.auth.radius; # the glass under it has the same corner
          inner_color = "rgba(00000000)";
          outer_color = c "text" "33"; # a quiet hairline at rest; the states below are the loud ones
          check_color = c "accent" "ff";
          fail_color = c "red" "ff";
          capslock_color = c "yellow" "ff";
          font_color = c "text" "ff";
          font_family = type.data;
          placeholder_text = ''<span size="${toString (16 * 1024)}">${icon 16 "lock"}  Digite sua senha</span>''; # in `text`: one AA target, a lighter glass
          fail_text = "$PAMFAIL"; # in `text`: the red is the hairline's, the shade is measured for text
          dots_size = 0.25;
          dots_spacing = 0.35;
          fade_on_empty = false;
          position = at cards.auth 0 0;
          halign = "center";
          valign = "center";
        };

        label =
          let
            inherit (cards)
              energy
              claude
              system
              procs
              weather
              media
              weatherWide
              ;
            # A label on the LG, `dx`/`dy` from a card's top-left corner; the block is centered on dy.
            lgAt = card: dx: dy: {
              monitor = secondary;
              position = geo.lgPos (lg.x card dx) (lg.y card dy);
              halign = "left";
              valign = "center";
              text_align = "left";
              font_family = type.data;
            };
            # Every card's header, one policy: a 16 pt icon at the type's weight, two spaces, tracked caps,
            # in the card's color, 40 px from its top.
            header = glyph: words: ''${icon 16 glyph}  <span letter_spacing="2048">${words}</span>'';
            caption =
              card: tone: glyph: words:
              lgAt card lg.pad 40
              // {
                text = header glyph words;
                color = c tone "ff";
                font_size = pt.title;
                font_family = "${type.data} SemiBold";
              };
            body =
              card: dx: dy: cmd: every:
              lgAt card dx dy
              // shade
              // {
                text = "cmd[update:${toString every}] ${cmd}";
                color = c "text" "ff";
                font_size = pt.body;
              };
            # The observe service starts WITH the lock and writes ~1 s later, after the first label
            # read: so every card re-reads its file each 5 s (a builtin), or it would say "Sem dados"
            # for a whole 30 to 60 s round. The data itself still moves every 30 to 60 s.
            obs =
              card: dx: dy: name:
              body card dx dy "${labelBin} obs ${name}" 5000;
            half = lg.inner energy / 2 + lg.pad; # where the right half of a full-width card starts
          in
          [
            # ── ASUS: the time on top; who is unlocking as ONE group with the field; a thought at the
            # foot. One axis. Offsets are from the column's center (geometry.nix). ──
            # The time, with seconds, from the system clock (chrony/NTS). 995 and not 1000: hyprlock's
            # timer runs ~0.7 ms long, and a period over 1 s MUST skip a second (measured in the notes).
            (
              textAt cards.column 0 (-217)
              // {
                monitor = primary;
                text = "cmd[update:995] ${clockCmd}";
                color = c "text" "ff";
                font_size = pt.clock;
                font_family = "${type.display} Thin";
              }
            )
            (
              textAt cards.column 0 (-107)
              // {
                monitor = primary;
                text = "cmd[update:60000] ${labelBin} date";
                color = c "text" "ff";
                font_size = pt.date;
                font_family = type.display;
              }
            )
            # Under the logo (frameless, drawn into the image): the name and the handle.
            (
              textAt cards.column 0 127
              // {
                monitor = primary;
                text = "cmd[update:0] ${labelBin} ink ${lib.escapeShellArg config.programs.git.settings.user.name}";
                color = c "text" "ff";
                font_size = pt.name;
                font_family = type.display;
              }
            )
            (
              textAt cards.column 0 157
              // {
                monitor = primary;
                text = "cmd[update:0] ${labelBin} ink ${config.home.username}";
                color = c "text" "ff";
                font_size = pt.nick;
                font_family = type.data;
              }
            )
            (
              textAt cards.quote 0 0
              // {
                monitor = primary;
                text = "cmd[update:0] ${labelBin} quote"; # once per surface: the quote of THIS lock
                color = c "text" "ff";
                font_size = pt.quote;
                font_family = type.display;
              }
            )

            # ── LG: what the machine is doing while I am away, one glass card per context. Headers are
            # static; the rest reads files the observe service and the bridges write. ──
            (caption energy "orange" "bolt" "ENERGIA")
            (obs energy lg.pad 188 "energy")
            (caption claude "magenta" "terminal" "CLAUDE CODE")
            (obs claude lg.pad 124 "claude-s")
            (obs claude half 124 "claude-w")
            (obs claude lg.pad 254 "claude-h")
            (caption system "blue" "memory" "SISTEMA")
            (obs system lg.pad 182 "system")
            (caption procs "teal" "leaderboard" "PROCESSOS")
            (obs procs lg.pad 176 "apps")
            # The weather card's header sits where both layouts put it; its body follows the layout.
            (caption weather "sky" "cloud" "CLIMA  ·  ${config.my.weather.place}")
            (body weather lg.pad 144 "${labelBin} weather all media" 60000)
            (body weatherWide lg.pad 144 "${labelBin} weather now ambient" 60000)
            (body weatherWide half 144 "${labelBin} weather day ambient" 60000)
            # The media card exists only in a Media lock: its header asks the layout.
            (
              lgAt media lg.pad 40
              // {
                text = "cmd[update:0] ${labelBin} only media '${header "music_note" "MÍDIA"}'";
                color = c "green" "ff";
                font_size = pt.title;
                font_family = "${type.data} SemiBold";
              }
            )
            (body media lg.pad 144 "${labelBin} media" 3000)
            # Every output: empty while the main monitor is connected, the way out when it is not.
            {
              monitor = "";
              text = "cmd[update:5000] ${labelBin} hint";
              color = c "text" "ff";
              font_size = pt.date;
              font_family = type.display;
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
        ExecStart = "${lib.getExe observe} lock-loop --out ${session}/obs --palette ${paletteFile} --cols ${toString (colsOf (lg.inner cards.energy) pt.body)} --half ${toString (colsOf (lg.inner cards.system) pt.body)} --type ${typeFile}";
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
  };
}
