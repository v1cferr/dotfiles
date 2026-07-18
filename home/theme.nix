# TEMA / DARK MODE + FONTE DA UI (declarado). Regra da pasta: aqui só se CONFIGURA — o pacote
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
  # Preferência global de esquema de cor + fonte da UI (dconf → gsettings).
  # A fonte aqui é o que os apps GTK/GNOME usam na interface — o fontconfig
  # (system/default.nix) já cobre o resto (mono/sans/serif), mas apps GTK leem
  # a fonte da UI DAQUI, não do fontconfig. Sufixo numérico = tamanho em pt.
  dconf.settings."org/gnome/desktop/interface" = {
    color-scheme = "prefer-dark";
    gtk-theme = "Adwaita-dark";
    font-name = "JetBrainsMono Nerd Font 11";
    document-font-name = "JetBrainsMono Nerd Font 11";
    monospace-font-name = "JetBrainsMono Nerd Font 11";
  };

  # Escreve ~/.config/gtk-3.0 e gtk-4.0 apontando pro tema escuro + fonte. Sem
  # `package` no tema de propósito: o Adwaita-dark é instalado system-wide
  # (gnome-themes-extra) e achado via XDG_DATA_DIRS — mantém a regra "home/ não
  # instala pacote". A fonte também vem do system/ (fonts.packages).
  gtk = {
    enable = true;
    theme.name = "Adwaita-dark";
    font.name = "JetBrainsMono Nerd Font";
    font.size = 11;
  };
}
