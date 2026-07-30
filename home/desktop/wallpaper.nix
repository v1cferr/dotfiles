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

  # ESCOLHA dos wallpapers — trocar aqui é 1 linha de verdade (ver pathOf abaixo).
  # Opções em `nix eval nixpkgs#nixos-artwork.wallpapers --apply builtins.attrNames`.
  main = art.nineish-dark-gray; # principal: cinza escuro, casa com o Tokyo Night
  tv = art.moonscape; # TV: mesma imagem do lockscreen

  # O nome do ARQUIVO dentro do pacote NÃO segue padrão: a maioria é nix-wallpaper-<attr>.png,
  # os catppuccin são nixos-wallpaper-<attr>.png e o gradient-grey é NixOS-Gradient-grey.png.
  # Montar o caminho por string quebraria na troca — e é o que fazia o comentário "trocar =
  # 1 linha" ser mentira. Lê o diretório do pacote e pega o arquivo que está lá.
  pathOf =
    wp:
    let
      dir = "${wp}/share/backgrounds/nixos";
    in
    "${dir}/${builtins.head (builtins.attrNames (builtins.readDir dir))}";

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
    ${wallpaperFor config.my.monitors.primary (pathOf main)}
    ${wallpaperFor config.my.monitors.secondary (pathOf tv)}
  '';
}
