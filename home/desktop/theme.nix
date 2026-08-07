# TEMA / DARK MODE + FONTE DA UI (declarado). Regra da pasta: aqui só se CONFIGURA — o pacote
# do tema (gnome-themes-extra, que traz o Adwaita-dark) e o portal GTK vivem no
# system/. Dark mode em Hyprland (sem DE) tem duas frentes:
#
#   1. color-scheme = "prefer-dark"  → sinal lido por apps GTK4/libadwaita E
#      repassado pelo xdg-desktop-portal-gtk aos apps Electron/Chromium
#      (VS Code, Chrome, Spotify, LibreWolf). É o que escurece a maioria.
#   2. gtk-theme = "Adwaita-dark"    → pros apps GTK3 antigos, que não seguem
#      o color-scheme sozinhos. O tema é achado via XDG_DATA_DIRS (system/).
{
  pkgs,
  lib,
  config,
  osConfig,
  ...
}:

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

  # ÍCONES Windows 11 (yeyushengfan258/Win11-icon-theme), pinado por commit. Vendorizado
  # porque NÃO está no nixpkgs — mesma exceção do win11os-kvantum acima.
  #
  # Escolhido em 07/08/2026 sobre o `pkgs.fluent-icon-theme`, que era o tema daqui e TAMBÉM
  # é Windows 11. Dois motivos, nesta ordem: (1) é redesenho dos ícones da Microsoft, e não
  # a interpretação autoral do Fluent Design — comparado ícone a ícone antes de trocar;
  # (2) é do MESMO autor do Kvantum acima, então widget e ícone combinam de fábrica.
  # PREÇO ACEITO: sai do canal do nixpkgs, então o bump aqui virou manual (regra da
  # estratégia de versões — upstream direto só quando o ganho justifica).
  #
  # `-t` fica FORA de propósito: com a variante vazia o script pula o `cp colors/color<X>`,
  # e é justamente `src/places/scalable` (pasta azul-clara da MS) que foi aprovado. Passar
  # `-t blue` etc. RECOLORIRIA as pastas por cima e entregaria outra coisa.
  win11-icons = pkgs.stdenvNoCC.mkDerivation {
    pname = "win11-icon-theme";
    version = "0-unstable-a5b460a";
    src = pkgs.fetchFromGitHub {
      owner = "yeyushengfan258";
      repo = "Win11-icon-theme";
      rev = "a5b460a407da143b32f19a503d7fcebb3edf2371";
      hash = "sha256-+GtOkOVSWlNTdKSs0R86LhnpbBZ21Y0ML3V8pwDUUSc=";
    };
    dontConfigure = true;
    dontBuild = true;
    # SÓ pelo binário: o install.sh termina cada variante com `gtk-update-icon-cache`
    # (linha 202) e o `set -eo pipefail` transforma o "command not found" em erro fatal.
    # O estrago era pior que falhar: ele morria DEPOIS de instalar a 1ª variante, então
    # sem isto o `Win11-dark` — justamente o que usamos — nem chegava a existir.
    # Não é pelo cache: conferido que nenhum icon-theme.cache sobra no output.
    nativeBuildInputs = [ pkgs.gtk3 ];
    # Roda o install.sh em vez de copiar `src/` na mão: além de copiar, ele renomeia o
    # index.theme, aplica a troca da variante dark e recria a FAZENDA DE SYMLINKS do
    # `links/` — é ela que faz centenas de nomes de mime caírem no mesmo SVG. Copiar à
    # mão entregaria um tema cheio de ícone genérico.
    installPhase = ''
      runHook preInstall
      mkdir -p "$out/share/icons"
      bash ./install.sh -d "$out/share/icons" -n Win11

      # PODA de symlink morto, senão o `noBrokenSymlinks` do nixpkgs reprova o build
      # (147 por variante). Não é workaround: são links de VARIANTE DE COR
      # (`folder-green.svg`, `green-folder-video.svg`, `folder_color_yellow_wine.svg`)
      # cujo alvo não existe em instalação nenhuma — nem num Arch — porque
      # `colors/color-<X>/` usa nomes `folder-*.svg` pra SOBRESCREVER, e nunca cria os
      # nomes prefixados. Bug cosmético do upstream; o nixpkgs só é mais rigoroso.
      # Conferido que nenhum deles é nome freedesktop que o Dolphin procure — os que
      # importam (folder, folder-documents, user-home, mimes) seguem intactos.
      find "$out" -xtype l -delete
      runHook postInstall
    '';
  };
in

{
  # Cursor Bibata: referenciado por NOME (dconf cursor-theme + envs XCURSOR no
  # home/desktop/hypr.nix), então o pacote precisa estar no perfil do usuário.
  home.packages = [ pkgs.bibata-cursors ];

  # Preferência global de esquema de cor + fonte da UI (dconf → gsettings).
  # A fonte aqui é o que os apps GTK/GNOME usam na interface — o fontconfig
  # (system/default.nix) já cobre o resto (mono/sans/serif), mas apps GTK leem
  # a fonte da UI DAQUI, não do fontconfig. Sufixo numérico = tamanho em pt.
  dconf.settings."org/gnome/desktop/interface" = {
    color-scheme = "prefer-dark";
    gtk-theme = "Adwaita-dark";
    icon-theme = config.my.theme.iconTheme; # SSOT (pacote no gtk abaixo)
    font-name = "${osConfig.my.fonts.ui} 11";
    document-font-name = "${osConfig.my.fonts.ui} 11";
    monospace-font-name = "${osConfig.my.fonts.ui} 11";
    # Cursor dos apps GTK (o Hyprland pega pelas envs em hypr/lua/environment.lua).
    cursor-theme = config.my.theme.cursor.name;
    cursor-size = config.my.theme.cursor.size;
  };

  # Escreve ~/.config/gtk-3.0 e gtk-4.0 apontando pro tema escuro + fonte. Os
  # pacotes do tema e dos ícones são declarados AQUI (regra 4): o home-manager os
  # põe no perfil do usuário e referencia. A fonte vem do system/ (fonts.packages).
  gtk = {
    enable = true;
    theme = {
      name = "Adwaita-dark";
      package = pkgs.gnome-themes-extra; # traz o Adwaita-dark
    };
    iconTheme = {
      name = config.my.theme.iconTheme; # SSOT: my.theme.iconTheme
      package = win11-icons; # ícones do Windows 11 (Win11-dark) — ver a derivação no let
    };
    font.name = osConfig.my.fonts.ui; # SSOT: system/hardware/fonts.nix
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
    run "$kw" --file "$HOME/.config/kdeglobals" --group Icons --key Theme ${config.my.theme.iconTheme}
  '';
}
