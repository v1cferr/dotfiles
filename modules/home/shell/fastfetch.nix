# fastfetch, as a boxed key column split into System / Desktop / Hardware, Catnap style.
# The terminal field uses {process-name}, and owfetch mirrors it: docs/notes/network/network.md
{ lib, pkgs, ... }:

let
  inherit (pkgs)
    coreutils
    gawk
    nixos-icons
    unstable # the CHANNEL and not a package, so `unstable.x` stays greppable at each use site
    ;

  date = lib.getExe' coreutils "date";
  stat = lib.getExe' coreutils "stat";
  awk = lib.getExe gawk;

  snowflake = "${nixos-icons}/share/icons/hicolor/256x256/apps/nix-snowflake.png";

  # Each section is its own box: a 13-cell key column ("icon label") and a value column of `value`
  # cells. Nix measures bytes, so widths are computed on the ASCII parts only, never on glyphs.
  value = 46;
  pad = n: s: s + lib.concatStrings (lib.replicate (n - lib.stringLength s) " ");
  line = n: lib.concatStrings (lib.replicate n "─");
  edge = left: mid: right: keyPart: {
    type = "custom";
    key = "${left}${keyPart}${mid}${line (value + 2)}${right}";
  };
  open = title: edge "╭" "┬" "╮" "─ {#1}${title}{#keys} ${line (10 - lib.stringLength title)}";
  close = edge "╰" "┴" "╯" (line 13);

  # fastfetch has no line suffix, so the right border is drawn from the key: save the cursor (ESC 7),
  # jump over the value column, print the border, restore (ESC 8), and the value prints in between.
  esc = builtins.fromJSON ''"\u001b"'';
  rightBorder = "${esc}7${esc}[${toString (value + 2)}C│${esc}8";
  # color is an ANSI number, so the rows follow the terminal's theme preset instead of fixed hex.
  row =
    color: icon: label: type: extra:
    {
      inherit type;
      key = "│ {#${color}}${icon} ${pad 9 label}{#keys} │${rightBorder}";
    }
    // extra;
in
{
  programs.fastfetch = {
    enable = true;
    package = unstable.fastfetch; # bleeding-edge: new hardware/versions

    settings = {
      # ASCII by default, so VS Code, SSH and the TTY get a clean logo; the kitty image is the
      # zsh wrapper's upgrade below.
      logo = {
        source = "NixOS";
        type = "builtin";
        padding.top = 5; # the logo is 20 rows and the boxes about 30, so 5 centers it
      };
      display = {
        separator = " ";
        color.keys = "90"; # the box itself in dim gray, so the icons and values stand out
      };

      modules = [
        (open "nixos")
        (row "34" "󱄅" "os" "os" { })
        (row "34" "󰌽" "kernel" "kernel" { })
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
        (row "34" "󱆃" "shell" "shell" { })
        close

        (open "desktop")
        (row "35" "󰖯" "wm" "wm" { })
        (row "35" "󰍹" "display" "display" { format = "{width}x{height} @ {refresh-rate} Hz, {inch}\""; })
        (row "35" "󰞷" "terminal" "terminal" {
          # {?version}…{?} = a conditional block: with no version detected, no loose space is left.
          format = "{process-name}{?version} {version}{?}";
        })
        (row "35" "󰛖" "font" "terminalfont" { })
        # Qt and GTK on one line overflow the box, so each gets its own, like the two displays.
        (row "35" "󰏘" "theme" "theme" { format = "{theme1}"; })
        (row "35" "󰏘" "theme" "theme" { format = "{theme2}"; })
        close

        (open "hardware")
        # temp reads coretemp's package and xe's pkg sensor, the same ones `sensors` shows.
        (row "36" "󰻠" "cpu" "cpu" {
          temp = true;
          format = "{name} · {temperature}";
        })
        (row "36" "󰢮" "gpu" "gpu" {
          temp = true;
          format = "{name} ({driver}) · {temperature}";
        })
        (row "36" "󰆧" "vulkan" "vulkan" { format = "{api-version}"; })
        (row "36" "󰍛" "memory" "memory" { })
        (row "36" "󰓡" "swap" "swap" { })
        (row "36" "󰋊" "disk" "disk" { folders = "/"; })
        close

        (open "palette")
        (row "37" "󰉦" "colors" "colors" { symbol = "circle"; })
        close
      ];
    };
  };

  # In kitty (local, or over SSH from it, since the bytes travel inline) the real snowflake image
  # replaces the ASCII logo. KITTY_WINDOW_ID is what kitty exports; TERM is often overridden.
  programs.zsh.siteFunctions.fastfetch = ''
    if [[ -n $KITTY_WINDOW_ID || $TERM == xterm-kitty ]]; then
      command fastfetch --logo-type kitty --logo ${snowflake} --logo-width 40 --logo-height 20 "$@"
    else
      command fastfetch "$@"
    fi
  '';
}
