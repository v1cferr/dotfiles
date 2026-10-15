# fastfetch as a boxed key column (System / Desktop / Hardware), plus `fetch`, the spinning 3D logo.
# The terminal field uses {process-name}, and owfetch mirrors it: docs/notes/network/network.md
{ lib, pkgs, ... }:

let
  inherit (pkgs)
    coreutils
    nixos-icons
    unstable # the CHANNEL and not a package, so `unstable.x` stays greppable at each use site
    ;

  date = lib.getExe' coreutils "date";
  stat = lib.getExe' coreutils "stat";

  snowflake = "${nixos-icons}/share/icons/hicolor/256x256/apps/nix-snowflake.png";

  # The key column is 15 cells: "│ " + icon + " " + a 9-cell label + " │". Nix measures bytes,
  # so the padding is computed on the ASCII label only, never on the glyphs.
  pad = n: s: s + lib.concatStrings (lib.replicate (n - lib.stringLength s) " ");
  line = n: lib.concatStrings (lib.replicate n "─");
  header = left: right: title: {
    type = "custom";
    key = "${left}─ {#1}${title}{#keys} ${line (10 - lib.stringLength title)}${right}";
  };
  # color is an ANSI number, so the rows follow the terminal's theme preset instead of fixed hex.
  row =
    color: icon: label: type: extra:
    {
      inherit type;
      key = "│ {#${color}}${icon} ${pad 9 label}{#keys} │";
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
        padding.top = 1;
      };
      display = {
        separator = " ";
        color.keys = "90"; # the box itself in dim gray, so the icons and values stand out
      };

      modules = [
        (header "╭" "╮" "system")
        (row "34" "" "os" "os" { })
        (row "34" "" "kernel" "kernel" { })
        (row "34" "󰏖" "packages" "packages" { })
        (row "34" "" "gen" "command" {
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
        (row "34" "" "shell" "shell" { })

        (header "├" "┤" "desktop")
        (row "35" "" "wm" "wm" { })
        (row "35" "󰍹" "display" "display" { })
        (row "35" "" "terminal" "terminal" {
          # {?version}…{?} = a conditional block: with no version detected, no loose space is left.
          format = "{process-name}{?version} {version}{?}";
        })
        (row "35" "" "font" "terminalfont" { })
        (row "35" "󰉼" "theme" "theme" { })

        (header "├" "┤" "hardware")
        (row "36" "󰻠" "cpu" "cpu" { })
        (row "36" "󰢮" "gpu" "gpu" { format = "{name} ({driver})"; })
        (row "36" "" "vulkan" "vulkan" { })
        (row "36" "" "memory" "memory" { })
        (row "36" "󰾴" "swap" "swap" { })
        (row "36" "󰋊" "disk" "disk" { folders = "/"; })
        (row "36" "󰩟" "local ip" "localip" { format = "{ipv4} ({ifname})"; })
        # A network call: the timeout keeps an offline fetch from hanging on it.
        (row "36" "󰖟" "public ip" "publicip" { timeout = 1000; })

        (header "├" "┤" "palette")
        (row "37" "" "colors" "colors" { symbol = "circle"; })
        {
          type = "custom";
          key = "╰${line 13}╯";
        }
      ];
    };
  };

  # areofyl/fetch reads the logo from fastfetch and gathers its own, thinner info. Out: `ip` lists
  # every docker and libvirt bridge, `gpu` calls the B580 integrated and `packages` counts 271.
  home.packages = [ unstable.fetch ];
  xdg.configFile."fetch/config".text = ''
    os
    kernel
    uptime
    shell
    wm
    terminal
    cpu
    memory
    disk
    colors

    label_color=blue
    shading_mode=sextants
    box=1
  '';

  # In kitty (local, or over SSH from it, since the bytes travel inline) the real snowflake image
  # replaces the ASCII logo. KITTY_WINDOW_ID is what kitty exports; TERM is often overridden.
  programs.zsh.siteFunctions.fastfetch = ''
    if [[ -n $KITTY_WINDOW_ID || $TERM == xterm-kitty ]]; then
      command fastfetch --logo-type kitty --logo ${snowflake} --logo-width 30 --logo-height 15 "$@"
    else
      command fastfetch "$@"
    fi
  '';
}
