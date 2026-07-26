# Flameshot (screenshot) — pacote v13 (enableWlrSupport/grim) + config, no home
# (regra 4). Os keybinds (Print / SUPER+SHIFT+S) e a windowrule do overlay vivem
# no home/desktop/hypr.nix (config do Hyprland é um blob Lua único).
#
# Captura neste box = grim, via `useGrimAdapter=true`. Contexto: no Wayland o
# flameshot pode capturar por (a) xdg-desktop-portal ou (b) grim. O portal NÃO
# funciona neste Hyprland (flameshot dá "Unable to capture screen"); o grim SIM
# (testado, ~940 KB). O v14 removeu o grim e só tem portal → por isso ficamos no
# v13 (ver system/default.nix). `useGrimAdapter` é setting exclusiva do v13; se um
# dia migrar pro v14, ela vira inválida ("Unrecognized setting") e trava tudo.
#
# NB: o .ini vem do /nix/store (read-only) → mudanças pela GUI NÃO persistem;
# editar aqui e rebuild. Qt QSettings NÃO aceita comentário inline no .ini.
{ config, pkgs, ... }:

{
  # v13 ESTÁVEL + enableWlrSupport: captura por grim (via useGrimAdapter no .ini),
  # que funciona neste Hyprland — o v14 removeu o grim e só tem portal (que dá
  # "Unable to capture screen" aqui). enableWlrSupport põe o grim no PATH do wrapper.
  home.packages = [ (pkgs.flameshot.override { enableWlrSupport = true; }) ];

  # Pasta de saída dos prints (flameshot não cria sozinho de forma confiável).
  home.file."Pictures/Screenshots/.keep".text = "";

  xdg.configFile."flameshot/flameshot.ini".text = ''
    [General]
    useGrimAdapter=true
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
