# WALLPAPER (hyprpaper), the same 2 images as the lockscreen so unlocking changes nothing.
# The 0.8 format change that turned the screen BLACK: docs/notes/desktop-plumbing.md
{ pkgs, osConfig, ... }:

let
  art = pkgs.nixos-artwork.wallpapers;

  # THE CHOICE: 1 line each. `nix eval nixpkgs#nixos-artwork.wallpapers --apply builtins.attrNames`
  main = art.catppuccin-mocha; # the main one: the SAME image as the lockscreen (home/desktop/lockscreen.nix)
  tv = art.moonscape; # the TV: the same image as the lockscreen

  # The FILE name follows no pattern across packages, so building the path by string breaks on a
  # swap. It reads the directory and takes whatever is in there.
  pathOf =
    wp:
    let
      dir = "${wp}/share/backgrounds/nixos";
    in
    "${dir}/${builtins.head (builtins.attrNames (builtins.readDir dir))}";

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

  xdg.configFile."hypr/hyprpaper.conf".text = ''
    splash = false
    ${wallpaperFor osConfig.my.monitors.primary (pathOf main)}
    ${wallpaperFor osConfig.my.monitors.secondary (pathOf tv)}
  '';
}
