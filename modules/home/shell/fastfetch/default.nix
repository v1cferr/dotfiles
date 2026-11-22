# fastfetch: boxed sections and a donut.c-style logo rendered at build time. Why: docs/notes/apps/fastfetch.md
# The terminal field uses {process-name}, and owfetch mirrors it: docs/notes/network/network.md
{
  config,
  lib,
  osConfig,
  pkgs,
  ...
}:

let
  inherit (pkgs)
    coreutils
    gawk
    git
    jq
    lm_sensors
    nixos-icons
    playerctl
    python3
    runCommand
    unstable # the CHANNEL and not a package, so `unstable.x` stays greppable at each use site
    ;

  date = lib.getExe' coreutils "date";
  stat = lib.getExe' coreutils "stat";
  awk = lib.getExe gawk;
  jqBin = lib.getExe jq;
  gitRepo = "${lib.getExe git} -C ${osConfig.programs.nh.flake}"; # nh.flake = the repo path (SSOT)

  # The version of the binary on PATH, from its store path (…-vscode-1.143.1/bin/code): never the
  # evaluated package, which can differ from what is installed, and never running the program.
  storeVersion =
    bin:
    ''$(p=$(readlink -f "$(command -v ${bin})"); p=''${p#/nix/store/*-}; p=''${p%%/*}; echo "''${p##*-}")'';
  # One row per connector, in my.monitors order (main first), since fastfetch cannot sort displays.
  monitor = connector: {
    text = ''hyprctl -i 0 -j monitors | ${jqBin} -r '.[] | select(.name == "${connector}") | "\(.model) · \(.width)x\(.height) @ \(.refreshRate | round) Hz"' '';
  };
  inherit (config.programs.kitty) font;
  inherit (config.my.theme) iconTheme cursor;

  # Every module prints exactly one line (one row per display, a static font), so the boxes are as
  # tall as the module list, and the logo is sized from that count instead of by hand.
  rows = builtins.length (mkModules boxed);

  # The logo tumbling in 3D like donut.c, rendered at build time into `rows`-tall ASCII frames,
  # 2*rows cells wide (square); scripts/spin-frames.py says how. 314 frames step 0.04 rad about X,
  # donut.c's own pace, and loop in ~10 s at 30 fps.
  spinWidth = 2 * rows;
  spin =
    runCommand "fastfetch-nixos-spin"
      {
        nativeBuildInputs = [
          (python3.withPackages (p: [
            p.numpy
            p.pillow
          ]))
        ];
      }
      "python3 ${./scripts/spin-frames.py} ${nixos-icons}/share/icons/hicolor/1024x1024/apps/nix-snowflake.png ${toString rows} 314 $out";

  # Each section is its own box: a 13-cell key column ("icon label") and a value column of `value`
  # cells. Nix measures bytes, so widths are computed on the ASCII parts only, never on glyphs.
  value = 46;
  boxWidth = value + 18; # "│ " + 11 + " │" + " " + value + " │"
  pad = n: s: s + lib.concatStrings (lib.replicate (n - lib.stringLength s) " ");
  line = n: lib.concatStrings (lib.replicate n "─");

  # fastfetch has no line suffix, so the right border is drawn from the key: save the cursor (ESC 7),
  # jump over the value column, print the border, restore (ESC 8), and the value prints in between.
  esc = builtins.fromJSON ''"\u001b"'';
  rightBorder = "${esc}7${esc}[${toString (value + 2)}C│${esc}8";

  # The two drawing styles share one module list: boxed for a wide terminal, plain for a narrow one,
  # where the boxes cannot fit. color is an ANSI number, so rows follow the theme preset.
  boxed = rec {
    edge = left: mid: right: keyPart: {
      type = "custom";
      key = "${left}${keyPart}${mid}${line (value + 2)}${right}";
    };
    open = title: edge "╭" "┬" "╮" "─ {#1}${title}{#keys} ${line (10 - lib.stringLength title)}";
    close = edge "╰" "┴" "╯" (line 13);
    row =
      color: icon: label: type: extra:
      {
        inherit type;
        key = "│ {#${color}}${icon} ${pad 9 label}{#keys} │${rightBorder}";
      }
      // extra;
  };
  plain = {
    open = title: {
      type = "custom";
      key = "{#1}${title}";
    };
    close = "break";
    row =
      color: icon: label: type: extra:
      {
        inherit type;
        key = "{#${color}}${icon} ${pad 9 label}{#keys}";
      }
      // extra;
  };

  mkModules =
    {
      open,
      close,
      row,
      ...
    }:
    [
      (open "nixos")
      (row "34" "󱄅" "os" "os" { })
      (row "34" "󰌽" "kernel" "kernel" { })
      (row "34" "󰐥" "boot" "bootmgr" {
        # Secure Boot from the declaration (limine.nix), not fastfetch's guess at the EFI variable.
        format = "{name}${lib.optionalString osConfig.boot.loader.limine.secureBoot.enable " · Secure Boot"}";
      })
      (row "34" "󰘬" "nixpkgs" "command" {
        # nixos-version is <release>.<YYYYMMDD>.<rev> (<codename>): the pin's commit and date.
        text = ''
          v=$(nixos-version); v=''${v%% *}; d=''${v#*.*.}
          echo "''${v##*.} ($(${date} -d "''${d%%.*}" +%F))"
        '';
      })
      (row "34" "󰜗" "nix" "command" {
        text = ''v=$(nix --version); echo "Nix ''${v##* }"'';
      })
      (row "34" "󰌾" "inputs" "command" {
        # Direct inputs, every locked node, and how old the newest lock is: when the flake last moved.
        text = ''
          ${jqBin} -r '(.nodes.root.inputs | length) as $d | [.nodes[].locked.lastModified // empty] as $l
            | "\($d) direct · \($l | length) locked · \((now - ($l | max)) / 86400 | floor)d old"' \
            ${osConfig.programs.nh.flake}/flake.lock
        '';
      })
      (row "34" "󰜘" "dotfiles" "command" {
        text = ''echo "$(${gitRepo} rev-list --count HEAD) commits · last $(${gitRepo} log -1 --format=%cr)"'';
      })
      (row "34" "󰏖" "packages" "packages" { })
      (row "34" "󰆼" "closure" "command" {
        # The current system's closure, from the store database: the fetch's slowest row (~0.5 s).
        text = ''nix path-info -S /run/current-system | ${awk} '{ printf "%.2f GiB\n", $2 / 2^30 }' '';
      })
      (row "34" "󰋚" "gen" "command" {
        # The profile LINK's own mtime (stat without -L): following it lands on the store, at epoch 1.
        text = ''
          l=$(readlink /nix/var/nix/profiles/system); n=''${l#system-}
          echo "#''${n%-link} ($(${date} -d @$(${stat} -c %Y /nix/var/nix/profiles/$l) +%F))"
        '';
      })
      (row "34" "󰅐" "uptime" "uptime" { })
      (row "34" "󰃭" "age" "command" {
        # The birth time of / is the Kingston install, not the first NixOS one (history is in git).
        text = "echo $(( ($(${date} +%s) - $(${stat} -c %W /)) / 86400 )) days";
      })
      close

      (open "desktop")
      (row "35" "󰖯" "wm" "wm" { })
      (row "35" "󱂩" "bar" "command" { text = "echo quickshell ${storeVersion "quickshell"}"; })
      (row "35" "󰍉" "launcher" "command" { text = "echo vicinae ${storeVersion "vicinae"}"; })
      (row "35" "󰍹" "display" "command" (monitor osConfig.my.monitors.primary))
      (row "35" "󰍹" "display" "command" (monitor osConfig.my.monitors.secondary))
      (row "35" "󰞷" "terminal" "terminal" {
        # {?version}…{?} = a conditional block: with no version detected, no loose space is left.
        format = "{process-name}{?version} {version}{?}";
      })
      (row "35" "󱆃" "shell" "command" {
        text = "echo zsh ${storeVersion "zsh"} · starship ${storeVersion "starship"}";
      })
      (row "35" "󰝚" "playing" "command" {
        # The first player that is PLAYING, cut to the value column; a dash when none is, so the
        # row (and the boxes' height) never disappears.
        text = ''
          for p in $(${lib.getExe playerctl} -l 2>/dev/null); do
            [ "$(${lib.getExe playerctl} -p "$p" status 2>/dev/null)" = Playing ] || continue
            ${lib.getExe playerctl} -p "$p" metadata --format '{{artist}} - {{title}}' \
              | ${awk} '{ print (length > 46 ? substr($0, 1, 45) "…" : $0) }'
            exit
          done
          echo —
        '';
      })
      (row "35" "󰨞" "editor" "command" { text = "echo VS Code ${storeVersion "code"}"; })
      # kitty's declared font: terminalfont finds nothing outside kitty, which shifted the rows.
      (row "35" "󰛖" "font" "custom" { format = "${font.name} (${toString font.size}pt)"; })
      # Qt and GTK on one line overflow the box, so each gets its own.
      (row "35" "󰏘" "theme" "theme" { format = "{theme1}"; })
      (row "35" "󰏘" "theme" "theme" { format = "{theme2}"; })
      # The declared names (my.theme), on one line: two rows of theme names were the box's filler.
      (row "35" "󰆿" "cursor" "custom" {
        format = "${iconTheme} icons · ${cursor.name} ${toString cursor.size}";
      })
      close

      (open "hardware")
      (row "36" "󰚗" "board" "command" {
        text = "echo \"$(</sys/class/dmi/id/board_name) · BIOS $(</sys/class/dmi/id/bios_version)\"";
      })
      # temp reads coretemp's package and xe's pkg sensor, the same ones `sensors` shows.
      (row "36" "󰻠" "cpu" "cpu" {
        temp = true;
        format = "{name} · {temperature}";
      })
      (row "36" "󰢮" "gpu" "gpu" {
        temp = true;
        format = "{name} ({driver}) · {temperature}";
      })
      # The codec module prints encoders and decoders on two lines, so its JSON is read instead:
      # what the GPU encodes, newest codec first.
      (row "36" "󰕧" "codec" "command" {
        text = ''
          ${lib.getExe config.programs.fastfetch.package} --logo none -s codec --format json | ${jqBin} -r '
            (.[0].result[0].encoders // []) | map(sub(" / H.265"; "")) | reverse
            | if length > 0 then join(" · ") + " encode" else "—" end'
        '';
      })
      # The board's spinning fans (nct6775), then the GPU's (xe), which stops at idle (zero RPM mode)
      # and so is named instead of vanishing.
      (row "36" "󰈐" "fans" "command" {
        text = ''
          ${lib.getExe lm_sensors} -j 2>/dev/null | ${jqBin} -r '
            def rpm: [to_entries[] | select(.key | test("^fan")) | .value | to_entries[]
              | select(.key | test("_input$")) | .value | floor];
            ([to_entries[] | select(.key | test("^xe-") | not) | .value | rpm[] | select(. > 0)]
              | map(tostring) | join(" · ")) as $board
            | ([to_entries[] | select(.key | test("^xe-")) | .value | rpm[]] | first) as $gpu
            | [($board | select(. != "") | . + " RPM"),
               ($gpu | if . == null then empty elif . > 0 then "gpu \(.) RPM" else "gpu stopped" end)]
            | if length > 0 then join(" · ") else "—" end'
        '';
      })
      (row "36" "󰍛" "memory" "memory" { })
      (row "36" "󰓡" "swap" "swap" { })
      # btrfs and not disk: the same used/total, plus how much of it is already allocated in chunks.
      (row "36" "󰋊" "storage" "btrfs" { format = "{5} / {7} ({8}) · {9} alloc"; })
      close

      (open "palette")
      (row "37" "󰉦" "colors" "colors" { symbol = "circle"; })
      close
    ];

in
{
  programs.fastfetch = {
    enable = true;
    package = unstable.fastfetch; # bleeding-edge: new hardware/versions

    settings = {
      # ASCII by default, so VS Code, SSH and the TTY get a clean logo; the kitty image is the
      # zsh wrapper's upgrade below.
      logo.type = "none"; # the spinning logo is the zsh wrapper's, only where it fits
      display = {
        separator = " ";
        color.keys = "90"; # the box itself in dim gray, so the icons and values stand out
      };

      modules = mkModules boxed;
    };
  };

  # The plain list for terminals too narrow for the boxes: same modules, no borders, no logo.
  xdg.configFile."fastfetch/compact.jsonc".text = builtins.toJSON (
    config.programs.fastfetch.settings
    // {
      logo.type = "none";
      modules = mkModules plain;
    }
  );

  # The layout follows the terminal: spinning logo plus boxes, boxes alone, or the plain list. A
  # logo taller than the window breaks fastfetch, which draws it first and then climbs back up.
  # The first frame reserves the logo's space; then the frames redraw over it from the bottom of
  # the output (ESC 7/8 save and restore the cursor) until a key, which goes on to the prompt.
  programs.zsh.siteFunctions.fastfetch = ''
    if (( COLUMNS < ${toString boxWidth} )); then
      command fastfetch -c ${config.xdg.configHome}/fastfetch/compact.jsonc "$@"
      return
    fi
    if (( $# || LINES <= ${toString rows} || COLUMNS < ${
      toString (spinWidth + 5 + boxWidth)
    } )) || [[ ! -t 0 || ! -t 1 ]]; then
      command fastfetch "$@"
      return
    fi
    command fastfetch --logo-type file-raw --logo ${spin}/first --logo-padding-top 0 \
      --logo-width ${toString spinWidth} --logo-height ${toString rows}
    setopt localoptions localtraps
    local -a frames=("''${(@ps:\036:)"$(<${spin}/frames)"}")
    local key i=1
    trap 'print -n "\e[?25h"; return 130' INT
    print -n '\e[?25l'
    while ! read -sk 1 -t 0.033 key; do
      print -nr -- $'\e7\e[${toString rows}A\r'"''${frames[i]}"$'\e8'
      (( i = i % $#frames + 1 ))
    done
    print -n '\e[?25h'
    [[ $key == [[:print:]] ]] && print -z -- "$key"
  '';
}
