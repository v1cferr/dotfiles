# Flameshot (screenshot) — v14 do canal UNSTABLE (pkgs.unstable.*, via overlay do
# flake.nix) + config, no home (regra 4). Os keybinds (Print / SUPER+SHIFT+S) e a
# windowrule do overlay vivem em home/desktop/hypr/lua/.
#
# Captura via xdg-desktop-portal (org.freedesktop.portal.Screenshot), servido pelo
# xdg-desktop-portal-hyprland (programs.hyprland já habilita) — MESMO caminho do meu
# Arch, onde o v14 capturava sem grim direto. O portal usa screencopy por baixo, então
# o flameshot NÃO cospe o aviso "grim ... GNOME" (aquele vinha do useGrimAdapter, que o
# v14 nem suporta mais). Roteamento OK: XDG_CURRENT_DESKTOP=Hyprland casa com o UseIn.
#
# Por que unstable: o v14 não está no nixos-26.05 estável (tem 13.3.0); o overlay
# pkgs.unstable.* (flake.nix) puxa SÓ o flameshot do unstable — o resto do sistema
# fica estável. Bump da versão = `nix flake update nixpkgs-unstable`.
#
# NB: o .ini vem do /nix/store (read-only) → mudanças pela GUI NÃO persistem;
# editar aqui e rebuild. Qt QSettings NÃO aceita comentário inline no .ini.
{ config, pkgs, ... }:

{
  # v14 (unstable). Já vem Wayland-ready (qtwayland + grim no wrapper); captura pelo
  # portal por padrão — sem useGrimAdapter, sem o aviso do grim.
  home.packages = [ pkgs.unstable.flameshot ];

  # Pasta de saída dos prints (flameshot não cria sozinho de forma confiável).
  home.file."Pictures/Screenshots/.keep".text = "";

  xdg.configFile."flameshot/flameshot.ini".text = ''
    [General]
    disabledTrayIcon=true
    showStartupLaunchMessage=false
    showDesktopNotification=true
    savePath=${config.home.homeDirectory}/Pictures/Screenshots
    savePathFixed=true
    saveAsFileExtension=.png
    contrastOpacity=128
    showHelp=false
    drawColor=#ff0000
    drawThickness=3
    uiColor=#8b5cf6
  '';
}
