# The desktop wallpaper: hyprpaper (Hyprland's official daemon: static, light, declarative).
# The official NixOS images come through pkgs.nixos-artwork (no binary in git; it bumps along with
# nixpkgs). The main one is catppuccin-mocha and the TV is moonscape, the SAME two images as the
# lockscreen, so unlocking does not change the background underneath. Switching = changing the
# nixos-artwork attribute (1 line; ~30 options). It comes up on the graphical-session (a --user
# service from the module itself). The connectors come from my.monitors (rule 11).
#
# THE CONFIG FORMAT (hyprpaper 0.8.x): this is why the screen went BLACK. 0.8 swapped the flat
# format (`wallpaper = MONITOR,path` plus `preload =` plus `ipc =`) for a CATEGORY
# (`wallpaper { monitor = …; path = …; }`). `preload` and `ipc` do not even exist in the binary
# anymore: `strings hyprpaper | grep -c preload` gives 0. With the old format hyprpaper COMES UP,
# finds the monitors and logs "Monitor DP-2 has no target: no wp will be created": no layer
# surface is created and the background stays black, with no parse error to give away the reason.
#
# home-manager's services.hyprpaper module still generates the old format, so the config is
# written HERE (xdg.configFile) and the module comes in only with `enable`, providing the systemd
# --user service and the package; the content is ours. If the module ever learns the new format,
# this goes back into `settings` and the file gets shorter.
{ pkgs, osConfig, ... }:

let
  art = pkgs.nixos-artwork.wallpapers;

  # THE CHOICE of wallpapers: changing it here really is 1 line (see pathOf below).
  # The options are in `nix eval nixpkgs#nixos-artwork.wallpapers --apply builtins.attrNames`.
  main = art.catppuccin-mocha; # the main one: the SAME image as the lockscreen (home/desktop/lockscreen.nix)
  tv = art.moonscape; # the TV: the same image as the lockscreen

  # The FILE name inside the package does NOT follow a pattern: most are
  # nix-wallpaper-<attr>.png, the catppuccin ones are nixos-wallpaper-<attr>.png and gradient-grey
  # is NixOS-Gradient-grey.png. Building the path by string would break on a swap, and that is what
  # made the "switching = 1 line" comment a lie. It reads the package's directory and takes
  # whatever file is in there.
  pathOf =
    wp:
    let
      dir = "${wp}/share/backgrounds/nixos";
    in
    "${dir}/${builtins.head (builtins.attrNames (builtins.readDir dir))}";

  # One `wallpaper { }` category per monitor, the format 0.8.x understands.
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
