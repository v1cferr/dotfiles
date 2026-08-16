# THEME / DARK MODE plus the UI font. GTK follows color-scheme, Qt is 100% Kvantum (Dolphin).
# The 2 vendored themes and the 3 build traps in the icons: docs/notes/theme.md
{
  pkgs,
  lib,
  config,
  osConfig,
  ...
}:

let
  # ONLY the Kvantum folder of Win11OS-kde, pinned by commit. The /share/Kvantum layout is what
  # qt.kvantum.themes expects. An exception to "home/ does not install": it is a theme asset.
  win11os-kvantum = pkgs.stdenvNoCC.mkDerivation {
    pname = "win11os-kvantum";
    version = "0-unstable-9f021c3";
    src = pkgs.fetchFromGitHub {
      owner = "yeyushengfan258";
      repo = "Win11OS-kde";
      rev = "9f021c3e71da7baf59a0614ab858d53b1e455fd5";
      hash = "sha256-R1l0YG+UEfFKPJd/pQJ3aJzWKg1ru0gWasW7zStK1Ig=";
    };
    # It only copies SVG/kvconfig, so there is nothing to configure or compile.
    dontConfigure = true;
    dontBuild = true;
    installPhase = ''
      runHook preInstall
      mkdir -p "$out/share/Kvantum"
      cp -r Kvantum/Win11OS-dark "$out/share/Kvantum/"
      runHook postInstall
    '';
  };

  # The Windows 11 ICONS, pinned by commit and vendored (not in nixpkgs). Chosen over
  # fluent-icon-theme on 07/08/2026; the reasons and the price: docs/notes/theme.md
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
    # gtk3 is ONLY for the binary: install.sh ends each variant with gtk-update-icon-cache, and
    # under `set -eo pipefail` the missing command killed it BEFORE Win11-dark existed.
    nativeBuildInputs = [ pkgs.gtk3 ];
    # It runs install.sh, not a hand copy: the script also builds the SYMLINK FARM that maps
    # hundreds of mime names onto one SVG. A hand copy delivers generic icons.
    installPhase = ''
      runHook preInstall
      mkdir -p "$out/share/icons"
      # `-t` stays OUT: an empty variant keeps src/places/scalable, which is the approved folder.
      bash ./install.sh -d "$out/share/icons" -n Win11

      # PRUNING the dead links (147/variant), which noBrokenSymlinks would fail on. They are COLOR
      # VARIANT links whose target never exists upstream; none is a name Dolphin looks up.
      find "$out" -xtype l -delete
      runHook postInstall
    '';
  };
in

{
  # The Bibata cursor is referenced by NAME, so the package has to be in the user's profile.
  home.packages = [ pkgs.bibata-cursors ];

  # GTK apps read the UI font FROM HERE, not from fontconfig. The suffix is the size in pt.
  dconf.settings."org/gnome/desktop/interface" = {
    color-scheme = "prefer-dark";
    gtk-theme = "Adwaita-dark";
    icon-theme = config.my.theme.iconTheme; # SSOT (the package in gtk below)
    font-name = "${osConfig.my.fonts.ui} 11";
    document-font-name = "${osConfig.my.fonts.ui} 11";
    monospace-font-name = "${osConfig.my.fonts.ui} 11";
    # The GTK apps' cursor (Hyprland reads it from hypr/lua/environment.lua).
    cursor-theme = config.my.theme.cursor.name;
    cursor-size = config.my.theme.cursor.size;
  };

  # It writes ~/.config/gtk-3.0 and gtk-4.0. The packages are declared HERE (rule 4); the font
  # comes from system/.
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

  # Qt does NOT follow GTK under Hyprland. It is 100% Kvantum now, which takes over the palette
  # AND the widgets, so the old gtk3-follow was dropped. GTK/Electron are unchanged.
  qt = {
    enable = true;
    platformTheme.name = "kvantum"; # QT_QPA_PLATFORMTHEME=kvantum -> Kvantum sets the palette
    style.name = "kvantum"; # QT_STYLE_OVERRIDE=kvantum -> Kvantum draws the widgets
  };

  # It selects Win11OS-dark and copies it into ~/.config/Kvantum.
  qt.kvantum = {
    enable = true;
    themes = [ win11os-kvantum ]; # copies into ~/.config/Kvantum/Win11OS-dark/
    settings.General.theme = "Win11OS-dark";
  };

  # Kvantum does NOT set icons: KDE reads kdeglobals [Icons] Theme, and it rewrites that file, so
  # only that key is forced (the same pattern as home/apps/dolphin.nix).
  home.activation.kdeIconTheme = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    kw="${pkgs.kdePackages.kconfig}/bin/kwriteconfig6"
    run "$kw" --file "$HOME/.config/kdeglobals" --group Icons --key Theme ${config.my.theme.iconTheme}
  '';
}
