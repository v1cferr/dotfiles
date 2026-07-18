# TEMA / DARK MODE (declarado). Regra da pasta: aqui só se CONFIGURA — o pacote
# do tema (gnome-themes-extra, que traz o Adwaita-dark) e o portal GTK vivem no
# system/. Dark mode em Hyprland (sem DE) tem duas frentes:
#
#   1. color-scheme = "prefer-dark"  → sinal lido por apps GTK4/libadwaita E
#      repassado pelo xdg-desktop-portal-gtk aos apps Electron/Chromium
#      (VS Code, Chrome, Spotify, LibreWolf). É o que escurece a maioria.
#   2. gtk-theme = "Adwaita-dark"    → pros apps GTK3 antigos, que não seguem
#      o color-scheme sozinhos. O tema é achado via XDG_DATA_DIRS (system/).
{ ... }:

{
  # Preferência global de esquema de cor (dconf → gsettings).
  dconf.settings."org/gnome/desktop/interface" = {
    color-scheme = "prefer-dark";
    gtk-theme = "Adwaita-dark";
  };

  # Escreve ~/.config/gtk-3.0 e gtk-4.0 apontando pro tema escuro. Sem `package`
  # de propósito: o Adwaita-dark é instalado system-wide (gnome-themes-extra) e
  # achado via XDG_DATA_DIRS — mantém a regra "home/ não instala pacote".
  gtk = {
    enable = true;
    theme.name = "Adwaita-dark";
  };
}
