# THEME / DARK MODE plus the UI FONT (declared). The folder's rule: here we only CONFIGURE, and
# the theme package (gnome-themes-extra, which brings Adwaita-dark) and the GTK portal live in
# system/. Dark mode on Hyprland (with no DE) has two fronts:
#
#   1. color-scheme = "prefer-dark"  -> the signal read by GTK4/libadwaita apps AND
#      forwarded by xdg-desktop-portal-gtk to the Electron/Chromium apps
#      (VS Code, Chrome, Spotify, LibreWolf). It is what darkens most of them.
#   2. gtk-theme = "Adwaita-dark"    -> for the old GTK3 apps, which do not follow
#      the color-scheme on their own. The theme is found through XDG_DATA_DIRS (system/).
{
  pkgs,
  lib,
  config,
  osConfig,
  ...
}:

let
  # It vendors ONLY the Kvantum folder of the Win11OS theme (yeyushengfan258/Win11OS-kde),
  # pinned by commit for reproducibility. The /share/Kvantum/<Theme> layout is what
  # qt.kvantum.themes expects (it does stripPrefix "/share/Kvantum"). An exception to the
  # "home/ does not install a package" rule: it is a theme asset consumed only by home-manager's
  # qt module (the same case as adwaita-qt, which already comes through the module).
  win11os-kvantum = pkgs.stdenvNoCC.mkDerivation {
    pname = "win11os-kvantum";
    version = "0-unstable-9f021c3";
    src = pkgs.fetchFromGitHub {
      owner = "yeyushengfan258";
      repo = "Win11OS-kde";
      rev = "9f021c3e71da7baf59a0614ab858d53b1e455fd5";
      hash = "sha256-R1l0YG+UEfFKPJd/pQJ3aJzWKg1ru0gWasW7zStK1Ig=";
    };
    # It only copies SVG/kvconfig files, so there is nothing to configure or compile.
    dontConfigure = true;
    dontBuild = true;
    installPhase = ''
      runHook preInstall
      mkdir -p "$out/share/Kvantum"
      cp -r Kvantum/Win11OS-dark "$out/share/Kvantum/"
      runHook postInstall
    '';
  };

  # The Windows 11 ICONS (yeyushengfan258/Win11-icon-theme), pinned by commit. Vendored because
  # it is NOT in nixpkgs, the same exception as win11os-kvantum above.
  #
  # Chosen on 07/08/2026 over `pkgs.fluent-icon-theme`, which was the theme here and is ALSO
  # Windows 11. Two reasons, in this order: (1) it is a redraw of Microsoft's icons, and not an
  # author's own take on Fluent Design, compared icon by icon before switching; (2) it is by the
  # SAME author as the Kvantum above, so widget and icon match out of the box.
  # THE PRICE, ACCEPTED: it leaves the nixpkgs channel, so bumping it here became manual (the
  # version strategy rule: upstream directly only when the gain justifies it).
  #
  # `-t` stays OUT on purpose: with an empty variant the script skips the `cp colors/color<X>`,
  # and it is precisely `src/places/scalable` (Microsoft's light blue folder) that was approved.
  # Passing `-t blue` and so on would RECOLOR the folders on top and deliver something else.
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
    # ONLY for the binary: install.sh ends every variant with `gtk-update-icon-cache` (line 202)
    # and the `set -eo pipefail` turns the "command not found" into a fatal error. The damage was
    # worse than just failing: it died AFTER installing the 1st variant, so without this
    # `Win11-dark`, which is exactly what we use, never even came to exist.
    # It is not for the cache: checked that no icon-theme.cache is left in the output.
    nativeBuildInputs = [ pkgs.gtk3 ];
    # It runs install.sh instead of copying `src/` by hand: besides copying, it renames the
    # index.theme, applies the dark variant swap and recreates the SYMLINK FARM in `links/`,
    # which is what makes hundreds of mime names land on the same SVG. Copying by hand would
    # deliver a theme full of generic icons.
    installPhase = ''
      runHook preInstall
      mkdir -p "$out/share/icons"
      bash ./install.sh -d "$out/share/icons" -n Win11

      # PRUNING dead symlinks, otherwise nixpkgs' `noBrokenSymlinks` fails the build (147 per
      # variant). It is not a workaround: they are COLOR VARIANT links (`folder-green.svg`,
      # `green-folder-video.svg`, `folder_color_yellow_wine.svg`) whose target does not exist in
      # any installation, not even on an Arch, because `colors/color-<X>/` uses `folder-*.svg`
      # names to OVERWRITE and never creates the prefixed names. A cosmetic upstream bug;
      # nixpkgs is just stricter. Checked that none of them is a freedesktop name Dolphin looks
      # up: the ones that matter (folder, folder-documents, user-home, mimes) stay intact.
      find "$out" -xtype l -delete
      runHook postInstall
    '';
  };
in

{
  # The Bibata cursor: referenced by NAME (the dconf cursor-theme plus the XCURSOR envs in
  # home/desktop/hypr.nix), so the package has to be in the user's profile.
  home.packages = [ pkgs.bibata-cursors ];

  # The global color scheme preference plus the UI font (dconf through gsettings).
  # The font here is what GTK/GNOME apps use in the interface. fontconfig
  # (system/default.nix) already covers the rest (mono/sans/serif), but GTK apps read the UI
  # font FROM HERE, not from fontconfig. The numeric suffix is the size in pt.
  dconf.settings."org/gnome/desktop/interface" = {
    color-scheme = "prefer-dark";
    gtk-theme = "Adwaita-dark";
    icon-theme = config.my.theme.iconTheme; # SSOT (the package in gtk below)
    font-name = "${osConfig.my.fonts.ui} 11";
    document-font-name = "${osConfig.my.fonts.ui} 11";
    monospace-font-name = "${osConfig.my.fonts.ui} 11";
    # The GTK apps' cursor (Hyprland picks it up from the envs in hypr/lua/environment.lua).
    cursor-theme = config.my.theme.cursor.name;
    cursor-size = config.my.theme.cursor.size;
  };

  # It writes ~/.config/gtk-3.0 and gtk-4.0 pointing at the dark theme plus the font. The theme
  # and icon packages are declared HERE (rule 4): home-manager puts them in the user's profile
  # and references them. The font comes from system/ (fonts.packages).
  gtk = {
    enable = true;
    theme = {
      name = "Adwaita-dark";
      package = pkgs.gnome-themes-extra; # it brings Adwaita-dark
    };
    iconTheme = {
      name = config.my.theme.iconTheme; # SSOT: my.theme.iconTheme
      package = win11-icons; # the Windows 11 icons (Win11-dark); see the derivation in the let
    };
    font.name = osConfig.my.fonts.ui; # SSOT: system/hardware/fonts.nix
    font.size = 11;
  };

  # Qt/KDE apps (Dolphin) do NOT follow GTK on their own under Hyprland. We used to follow GTK
  # (platformTheme gtk3 plus adwaita-dark); now Qt is 100% Kvantum for the Windows 11 theme in
  # Dolphin. Kvantum takes over EVERYTHING in Qt (palette plus widgets), so we dropped the
  # gtk3-follow here. The GTK/Electron apps are unchanged (the prefer-dark color-scheme above).
  # The engine's plugin (qtstyleplugin-kvantum) comes through the qt module itself (through
  # platformTheme/style), the same exception as adwaita-qt.
  qt = {
    enable = true;
    platformTheme.name = "kvantum"; # QT_QPA_PLATFORMTHEME=kvantum -> Kvantum sets the palette
    style.name = "kvantum"; # QT_STYLE_OVERRIDE=kvantum -> Kvantum draws the widgets
  };

  # It selects the Windows 11 theme (dark) and installs it into ~/.config/Kvantum. The module
  # writes ~/.config/Kvantum/kvantum.kvconfig pointing at Win11OS-dark.
  qt.kvantum = {
    enable = true;
    themes = [ win11os-kvantum ]; # copies into ~/.config/Kvantum/Win11OS-dark/
    settings.General.theme = "Win11OS-dark";
  };

  # Dolphin's icons (and the other KDE apps'): Kvantum does NOT set icons, KDE apps read the
  # theme from kdeglobals [Icons] Theme. Since KDE rewrites that file at runtime, I force ONLY
  # that key (idempotently), as in home/dolphin.nix.
  home.activation.kdeIconTheme = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    kw="${pkgs.kdePackages.kconfig}/bin/kwriteconfig6"
    run "$kw" --file "$HOME/.config/kdeglobals" --group Icons --key Theme ${config.my.theme.iconTheme}
  '';
}
