# Wallpaper de desktop — hyprpaper (daemon oficial do Hyprland: estático, leve, declarativo).
# Imagens oficiais do NixOS via pkgs.nixos-artwork (sem binário no git; bump junto ao nixpkgs).
# Principal = nineish-dark-gray (dark, casa com o Tokyo Night); TV = moonscape
# (mesmo do lockscreen). Trocar = mudar o attr do nixos-artwork (1 linha; ~30 opções). Sobe no
# graphical-session (serviço --user do próprio módulo). Conectores vêm do my.monitors (regra 11).
#
# FORMATO DA CONFIG (hyprpaper 0.8.x) — é por isto que a tela ficava PRETA:
# a 0.8 trocou o formato achatado (`wallpaper = MONITOR,path` + `preload =` + `ipc =`) por
# CATEGORIA (`wallpaper { monitor = …; path = …; }`). O `preload` e o `ipc` nem existem mais no
# binário — `strings hyprpaper | grep -c preload` dá 0. Com o formato antigo o hyprpaper SOBE,
# acha os monitores e loga "Monitor DP-2 has no target: no wp will be created": nenhuma layer
# surface é criada e o fundo fica preto, sem erro de parse que denuncie o motivo.
#
# O módulo services.hyprpaper do home-manager ainda gera o formato antigo, então a config é
# escrita AQUI (xdg.configFile) e o módulo entra só com `enable` → ele fornece o serviço
# systemd --user e o pacote; o conteúdo é nosso. Se um dia o módulo aprender o formato novo,
# isto volta p/ `settings` e o arquivo encurta.
{ pkgs, config, ... }:

let
  art = pkgs.nixos-artwork.wallpapers;
  main = "${art.nineish-dark-gray}/share/backgrounds/nixos/nix-wallpaper-nineish-dark-gray.png";
  tv = "${art.moonscape}/share/backgrounds/nixos/nix-wallpaper-moonscape.png";

  # Uma categoria `wallpaper { }` por monitor — o formato que a 0.8.x entende.
  wallpaperFor = monitor: path: ''
    wallpaper {
      monitor = ${monitor}
      path = ${path}
    }
  '';
in
{
  services.hyprpaper.enable = true; # só o serviço/pacote; o conteúdo da config vem abaixo

  xdg.configFile."hypr/hyprpaper.conf".text = ''
    splash = false
    ${wallpaperFor config.my.monitors.primary main}
    ${wallpaperFor config.my.monitors.secondary tv}
  '';
}
