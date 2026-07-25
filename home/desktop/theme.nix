# TEMA / DARK MODE + FONTE DA UI (declarado). Regra da pasta: aqui só se CONFIGURA — o pacote
# do tema (gnome-themes-extra, que traz o Adwaita-dark) e o portal GTK vivem no
# system/. Dark mode em Hyprland (sem DE) tem duas frentes:
#
#   1. color-scheme = "prefer-dark"  → sinal lido por apps GTK4/libadwaita E
#      repassado pelo xdg-desktop-portal-gtk aos apps Electron/Chromium
#      (VS Code, Chrome, Spotify, LibreWolf). É o que escurece a maioria.
#   2. gtk-theme = "Adwaita-dark"    → pros apps GTK3 antigos, que não seguem
#      o color-scheme sozinhos. O tema é achado via XDG_DATA_DIRS (system/).
{ pkgs, lib, ... }:

let
  # Vendoriza SÓ a pasta Kvantum do tema Win11OS (yeyushengfan258/Win11OS-kde),
  # pinada por commit p/ reprodutibilidade. Layout /share/Kvantum/<Tema> = o que
  # qt.kvantum.themes espera (ele faz stripPrefix "/share/Kvantum"). Exceção à
  # regra "home/ não instala pacote": é asset de tema consumido só pelo módulo qt
  # do home-manager (mesmo caso do adwaita-qt, que já vem pelo módulo).
  win11os-kvantum = pkgs.stdenvNoCC.mkDerivation {
    pname = "win11os-kvantum";
    version = "0-unstable-9f021c3";
    src = pkgs.fetchFromGitHub {
      owner = "yeyushengfan258";
      repo = "Win11OS-kde";
      rev = "9f021c3e71da7baf59a0614ab858d53b1e455fd5";
      hash = "sha256-R1l0YG+UEfFKPJd/pQJ3aJzWKg1ru0gWasW7zStK1Ig=";
    };
    # Só copia arquivos SVG/kvconfig — nada pra configurar/compilar.
    dontConfigure = true;
    dontBuild = true;
    installPhase = ''
      runHook preInstall
      mkdir -p "$out/share/Kvantum"
      cp -r Kvantum/Win11OS-dark "$out/share/Kvantum/"
      runHook postInstall
    '';
  };
in

{
  # Preferência global de esquema de cor + fonte da UI (dconf → gsettings).
  # A fonte aqui é o que os apps GTK/GNOME usam na interface — o fontconfig
  # (system/default.nix) já cobre o resto (mono/sans/serif), mas apps GTK leem
  # a fonte da UI DAQUI, não do fontconfig. Sufixo numérico = tamanho em pt.
  dconf.settings."org/gnome/desktop/interface" = {
    color-scheme = "prefer-dark";
    gtk-theme = "Adwaita-dark";
    icon-theme = "Fluent-dark"; # ícones Windows 11 (fluent-icon-theme, no system/)
    font-name = "JetBrainsMono Nerd Font 11";
    document-font-name = "JetBrainsMono Nerd Font 11";
    monospace-font-name = "JetBrainsMono Nerd Font 11";
    # Cursor dos apps GTK (o Hyprland/XWayland pega pelas envs em home/hypr.nix).
    cursor-theme = "Bibata-Modern-Ice";
    cursor-size = 24;
  };

  # Escreve ~/.config/gtk-3.0 e gtk-4.0 apontando pro tema escuro + fonte. Sem
  # `package` no tema de propósito: o Adwaita-dark é instalado system-wide
  # (gnome-themes-extra) e achado via XDG_DATA_DIRS — mantém a regra "home/ não
  # instala pacote". A fonte também vem do system/ (fonts.packages).
  gtk = {
    enable = true;
    theme.name = "Adwaita-dark";
    iconTheme.name = "Fluent-dark"; # ícones Windows 11 nos apps GTK (pacote no system/)
    font.name = "JetBrainsMono Nerd Font";
    font.size = 11;
  };

  # Apps Qt/KDE (Dolphin) NÃO seguem o GTK sozinhos em Hyprland. Antes seguíamos o
  # GTK (platformTheme gtk3 + adwaita-dark); agora o Qt é 100% Kvantum p/ o tema
  # Windows 11 no Dolphin. O Kvantum passa a mandar em TUDO no Qt (paleta + widgets),
  # então largamos o gtk3-follow aqui — os apps GTK/Electron seguem inalterados
  # (color-scheme prefer-dark acima). O plugin da engine (qtstyleplugin-kvantum)
  # vem pelo próprio módulo qt (via platformTheme/style) — mesma exceção do adwaita-qt.
  qt = {
    enable = true;
    platformTheme.name = "kvantum"; # QT_QPA_PLATFORMTHEME=kvantum → Kvantum define a paleta
    style.name = "kvantum"; # QT_STYLE_OVERRIDE=kvantum → Kvantum desenha os widgets
  };

  # Seleciona o tema Windows 11 (dark) e o instala em ~/.config/Kvantum. O módulo
  # escreve ~/.config/Kvantum/kvantum.kvconfig apontando pro Win11OS-dark.
  qt.kvantum = {
    enable = true;
    themes = [ win11os-kvantum ]; # copia p/ ~/.config/Kvantum/Win11OS-dark/
    settings.General.theme = "Win11OS-dark";
  };

  # Ícones do Dolphin (e demais apps KDE): o Kvantum NÃO define ícones — os apps
  # KDE leem o tema do kdeglobals [Icons] Theme. Como o KDE reescreve esse arquivo
  # em runtime, forço SÓ essa chave (idempotente), como no home/dolphin.nix.
  home.activation.kdeIconTheme = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    kw="${pkgs.kdePackages.kconfig}/bin/kwriteconfig6"
    run "$kw" --file "$HOME/.config/kdeglobals" --group Icons --key Theme Fluent-dark
  '';
}
