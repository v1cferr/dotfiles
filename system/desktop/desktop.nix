# ═══════════════════════════════════════════════════════════════════════════
# DESKTOP: Hyprland (Wayland) ─────────────────────────────────────────────────
# Compositor Wayland. LightDM (greeter X11) lança a sessão Hyprland; Xwayland
# cobre apps X11. Atenção: na sessão Wayland o teclado e os monitores NÃO vêm
# do xkb/xrandr do sistema — são config do Hyprland (~/.config/hypr/hyprland.conf:
# input.kb_layout p/ ABNT2 e linhas `monitor=` p/ o arranjo/primário).
# ═══════════════════════════════════════════════════════════════════════════
{ pkgs, ... }:

{
  services.xserver.enable = true; # habilita LightDM (greeter X11) + Xwayland
  services.xserver.displayManager.lightdm.enable = true;
  programs.hyprland.enable = true;
  # xkb do sistema: cobre o greeter (LightDM/X11) e apps Xwayland.
  services.xserver.xkb = {
    layout = "br"; # variante padrão do "br" = ABNT2
    variant = "";
  };
  # Apps Electron/Chromium (vscode, spotify, chrome, claude-code) rodam nativos
  # em Wayland em vez de Xwayland.
  environment.sessionVariables.NIXOS_OZONE_WL = "1";

  # ── Portais do xdg-desktop-portal ─────────────────────────────────────────
  # O programs.hyprland já habilita o xdg.portal + o portal-hyprland (screencast).
  #   • portal-gtk: serve org.freedesktop.appearance (color-scheme) → é assim que
  #     apps Electron/Chromium (vscode, chrome, spotify) escurecem com o sistema.
  #   • portal-wlr: implementa a interface Screenshot (o portal-hyprland 1.3.12 SÓ a
  #     DECLARA, mas responde "Unknown method" → o flameshot v14 dava "Unable to
  #     capture screen"). É o mesmo portal que eu tinha no Arch. Screencopy do wlroots.
  xdg.portal.extraPortals = [
    pkgs.xdg-desktop-portal-gtk
    pkgs.xdg-desktop-portal-wlr
  ];
  # Roteamento explícito: Screenshot → wlr (o hyprland não implementa); o resto segue
  # o default (hyprland p/ ScreenCast/GlobalShortcuts, gtk p/ appearance/FileChooser).
  xdg.portal.config.common = {
    default = [ "hyprland" "gtk" ];
    "org.freedesktop.impl.portal.Screenshot" = [ "wlr" ];
  };

  # ── Keyring / Secret Service (gnome-keyring) ──────────────────────────────
  # Provê o org.freedesktop.secrets — onde apps guardam segredos CIFRADOS em vez
  # de texto plano (git via libsecret, NetworkManager, navegadores, etc.).
  # Destranca automaticamente no login do LightDM (PAM, com a senha do usuário).
  services.gnome.gnome-keyring.enable = true;
  security.pam.services.lightdm.enableGnomeKeyring = true;
  programs.seahorse.enable = true; # GUI "Senhas e Chaves" pra gerenciar

  # ── Lockscreen (hyprlock) ──────────────────────────────────────────────────
  # PAM p/ o hyprlock autenticar a senha do usuário. SEM isto ele não desbloqueia
  # e TRANCA você pra fora. O pacote/config são do usuário (home/lockscreen.nix);
  # aqui é só o serviço PAM (nível-sistema). {} = herda a stack de login padrão.
  security.pam.services.hyprlock = { };
}
