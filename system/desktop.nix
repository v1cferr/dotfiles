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

  # ── Dark mode: portal p/ o color-scheme (config do tema vive em home/theme.nix) ─
  # O programs.hyprland já habilita o xdg.portal (+ portal-hyprland p/ screencast).
  # O portal-gtk é quem serve org.freedesktop.appearance (color-scheme) → é assim
  # que apps Electron/Chromium (vscode, chrome, spotify) escurecem junto do sistema.
  xdg.portal.extraPortals = [ pkgs.xdg-desktop-portal-gtk ];

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
