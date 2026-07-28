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

  # ── Autologin ──────────────────────────────────────────────────────────────
  # A máquina loga sozinha no Hyprland no boot. MOTIVO: o Sunshine (acesso remoto)
  # captura uma sessão gráfica VIVA — sem alguém logado não há compositor pra
  # streamar. Com autologin a sessão sobe no boot → o graphical-session.target ativa
  # → o Sunshine (autoStart) sobe junto, e dá pra conectar do Moonlight sem ninguém
  # tocar na máquina. Bônus: se o Hyprland cair, o LightDM re-loga sozinho (resiliência).
  # defaultSession é OBRIGATÓRIO (assertion do lightdm) e define a sessão do autologin.
  # SEGURANÇA: o boot cai numa sessão DESTRANCADA. Mitigação: o hypridle tranca aos
  # 5min (home/desktop/lockscreen.nix) e o acesso remoto é só pela tailnet. Se quiser
  # trancar já no boot, dá p/ um exec-once do hyprlock no autostart.
  services.displayManager.autoLogin = {
    enable = true;
    user = "v1cferr";
  };
  services.displayManager.defaultSession = "hyprland";
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
  # Provê o org.freedesktop.secrets — onde apps guardam segredos (git via libsecret,
  # NetworkManager, Chrome/Spotify/Dropbox, etc.). ATENÇÃO ao AUTOLOGIN: o PAM do
  # lightdm-autologin NÃO digita senha, então o pam_gnome_keyring NUNCA recebe authtok
  # → o auto-unlock NÃO vem do PAM. Aqui o keyring "Login" tem senha VAZIA (estado, não
  # declarável — regra 6): o gnome-keyring-daemon o destrava sozinho no startup, sem
  # prompt, pra TODOS os apps. Trade-off aceito: sessão já é autologin/destrancada e o
  # acesso remoto é só tailnet. Ver memória [[keyring-apos-restore]].
  services.gnome.gnome-keyring.enable = true;
  # Só serve ao login INTERATIVO (resgate, se o autologin for desligado); inerte no autologin.
  security.pam.services.lightdm.enableGnomeKeyring = true;
  programs.seahorse.enable = true; # GUI "Senhas e Chaves" pra gerenciar/trocar senha do keyring

  # ── Lockscreen (hyprlock) ──────────────────────────────────────────────────
  # PAM p/ o hyprlock autenticar a senha do usuário. SEM isto ele não desbloqueia
  # e TRANCA você pra fora. O pacote/config são do usuário (home/lockscreen.nix);
  # aqui é só o serviço PAM (nível-sistema). {} = herda a stack de login padrão.
  security.pam.services.hyprlock = { };
}
