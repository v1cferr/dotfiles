# Wallpaper de desktop — hyprpaper (daemon oficial do Hyprland: estático, leve, declarativo).
# Imagens oficiais do NixOS via pkgs.nixos-artwork (sem binário no git; bump junto ao nixpkgs).
# DP-2 (principal) = nineish-dark-gray (dark, casa com o Tokyo Night); HDMI-A-3 (TV) = moonscape
# (mesmo do lockscreen). Trocar = mudar o attr do nixos-artwork (1 linha; ~30 opções). Sobe no
# graphical-session (serviço --user do próprio módulo).
{ pkgs, ... }:

let
  art = pkgs.nixos-artwork.wallpapers;
  main = "${art.nineish-dark-gray}/share/backgrounds/nixos/nix-wallpaper-nineish-dark-gray.png";
  tv = "${art.moonscape}/share/backgrounds/nixos/nix-wallpaper-moonscape.png";
in
{
  services.hyprpaper = {
    enable = true;
    settings = {
      ipc = "on"; # aceita hyprctl hyprpaper (trocar wallpaper ao vivo, se quiser)
      splash = false; # sem o splash "Hyprland" por cima
      preload = [ main tv ]; # carrega na RAM antes de aplicar (troca instantânea)
      wallpaper = [ "DP-2,${main}" "HDMI-A-3,${tv}" ];
    };
  };
}
