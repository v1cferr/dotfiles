# WALLPAPER (hyprpaper): one random DARK image per monitor, out of my own folders, one pool per
# ORIENTATION. Why it stopped matching the lockscreen: docs/notes/desktop/desktop-plumbing.md
{
  config,
  lib,
  pkgs,
  osConfig,
  ...
}:

let
  # Rule 19: everything this module reaches for, named once.
  inherit (pkgs)
    coreutils
    hyprland
    nixos-artwork
    writeShellApplication
    ;

  art = nixos-artwork.wallpapers;

  # The FILE name follows no pattern across packages, so building the path by string breaks on a
  # swap. It reads the directory and takes whatever is in there.
  pathOf =
    wp:
    let
      dir = "${wp}/share/backgrounds/nixos";
    in
    "${dir}/${builtins.head (builtins.attrNames (builtins.readDir dir))}";

  # The packaged FALLBACK, for an empty pool: a desktop with NO wallpaper is the outcome to avoid.
  fallbackWide = pathOf art.catppuccin-mocha;
  fallbackTall = pathOf art.waterfall;

  # MY OWN photos, as STATE and not config (rule 6), which restic already backs up. One pool per
  # orientation: a 16:9 frame on the standing panel would keep 56% of its width.
  poolWide = "${config.home.homeDirectory}/Pictures/wallpapers/wide";
  poolTall = "${config.home.homeDirectory}/Pictures/wallpapers/tall";

  linkDir = "${config.xdg.cacheHome}/wallpaper";
  linkWide = "${linkDir}/wide";
  linkTall = "${linkDir}/tall";

  # One draw per pool, or just the one asked for. The symlink is what the config reads at START;
  # the IPC is what applies it NOW, with the REAL path, since hyprpaper caches by path.
  shuffle = writeShellApplication {
    name = "wallpaper-shuffle";
    runtimeInputs = [
      coreutils
      hyprland
    ];
    text = ''
      pick() { # $1 = pool, $2 = link, $3 = fallback; prints what it drew
        local files=() f chosen
        for f in "$1"/*; do
          if [ -f "$f" ]; then files+=("$f"); fi
        done
        chosen="$3"
        if [ ''${#files[@]} -gt 0 ]; then chosen="''${files[RANDOM % ''${#files[@]}]}"; fi
        ln -sfn "$chosen" "$2"
        printf '%s' "$chosen"
      }

      apply() { # $1 = monitor, $2 = image
        hyprctl hyprpaper preload "$2" >/dev/null 2>&1 || true
        hyprctl hyprpaper wallpaper "$1,$2" >/dev/null 2>&1 || true
      }

      # 1 is the MAIN panel and 2 the standing one, the same numbering my.monitors uses.
      target="''${1:-both}"
      case "$target" in
        1 | 2 | both) ;;
        *)
          echo "usage: wallpaper-shuffle [1|2]  (1 = main, 2 = standing, none = both)" >&2
          exit 2
          ;;
      esac

      mkdir -p ${linkDir} ${poolWide} ${poolTall}

      # Every branch below is an `if` and never `[ x ] && y`: under set -e a failing left side
      # takes the whole script with it, and the empty-pool path lands exactly there.
      live=no
      if hyprctl hyprpaper listactive >/dev/null 2>&1; then live=yes; fi

      if [ "$target" != 2 ]; then
        wide=$(pick ${poolWide} ${linkWide} ${fallbackWide})
        if [ "$live" = yes ]; then apply "${osConfig.my.monitors.primary}" "$wide"; fi
      fi
      if [ "$target" != 1 ]; then
        tall=$(pick ${poolTall} ${linkTall} ${fallbackTall})
        if [ "$live" = yes ]; then apply "${osConfig.my.monitors.secondary}" "$tall"; fi
      fi
      if [ "$live" = yes ]; then hyprctl hyprpaper unload unused >/dev/null 2>&1 || true; fi
    '';
  };

  # One `wallpaper { }` category per monitor, which is the format 0.8.x understands.
  wallpaperFor = monitor: path: ''
    wallpaper {
      monitor = ${monitor}
      path = ${path}
    }
  '';
in
{
  services.hyprpaper.enable = true; # only the service/package; the config's content comes below

  home.packages = [ shuffle ]; # `wallpaper-shuffle` by hand, for a new photo without a rebuild

  xdg.configFile."hypr/hyprpaper.conf".text = ''
    splash = false
    ${wallpaperFor osConfig.my.monitors.primary linkWide}
    ${wallpaperFor osConfig.my.monitors.secondary linkTall}
  '';

  # The links have to exist BEFORE hyprpaper reads the config, both on a switch and on every start.
  home.activation.wallpaperShuffle = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    run ${shuffle}/bin/wallpaper-shuffle
  '';
  systemd.user.services.hyprpaper.Service.ExecStartPre = "-${shuffle}/bin/wallpaper-shuffle";
}
