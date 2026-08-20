# THEME / DARK MODE plus the UI font. GTK follows color-scheme, Qt is 100% Kvantum (Dolphin).
# The 2 vendored themes and the 3 build traps in the icons: docs/notes/desktop/theme.md
{
  pkgs,
  lib,
  config,
  osConfig,
  ...
}:

let
  p = config.my.theme.palette; # SSOT: home/desktop/palette.nix (rule 9)

  # The theme is the Win11OS GEOMETRY recolored by the palette, so the name carries both.
  kvantumTheme = "Win11OS-${config.my.theme.name}";

  # The Win11OS hex -> palette key map: ONLY surfaces, text and the accent. The white and black
  # overlays stay untouched because they already adapt by OPACITY: docs/notes/desktop/theme.md
  kvantumRecolor = {
    "4bc8ff" = "accent"; # THE accent: focus frame, pressed, progress, slider
    "0057ae" = "blue"; # link.color, the one uppercase pair in the kvconfig
    "e040fb" = "magenta"; # link.visited.color
    "315bef" = "blue"; # the disabled progress pattern
    "4e9ff2" = "blue";
    "5887b6" = "blue";
    "69b2fd" = "sky";
    "f04a50" = "red";
    "242932" = "bg"; # window.color and base.color: the sidebar and the file view
    "1e1e1e" = "bg"; # window-normal, the whole window
    "23272f" = "bg"; # dark.color
    "141414" = "shadow";
    "191919" = "bg"; # menubar/toolbar and the tab strip, FLAT like Explorer's
    "2d2d2d" = "surface"; # the menu and tooltip interiors
    "212327" = "surface"; # the column header strip
    "26272a" = "surface";
    "272c35" = "surface"; # alt.base.color, the alternating row
    "2b303b" = "surface"; # mid.color
    "333333" = "surface"; # titlebar and dock
    "313338" = "track"; # lineedit and combo
    "343031" = "track"; # the window edges
    "36383e" = "track"; # header-normal
    "3c3c46" = "track";
    "3c4352" = "track"; # mid.light.color
    "414958" = "track"; # button.color
    "475061" = "border"; # light.color
    "586379" = "dim"; # disabled.text.color
    "a6abae" = "subtext";
    "b4b4b4" = "subtext"; # the button overlay, at 0.25 opacity
    "b6b6b6" = "subtext";
    "d9dce3" = "text"; # text.color and every text.*.color in the kvconfig
    "dfdfdf" = "text"; # the indicator artwork (arrows, checks, marks)
    "eaeaea" = "text";
    "edeff3" = "text"; # tooltip.text.color
  };

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
    # ONE sed over BOTH files, so [GeneralColors] and the SVG surfaces cannot drift apart. The
    # `I` flag is not decoration: link.color is the uppercase `#0057AE`.
    installPhase = ''
      runHook preInstall
      dir="$out/share/Kvantum/${kvantumTheme}"
      mkdir -p "$dir"
      cp Kvantum/Win11OS-dark/Win11OS-dark.kvconfig "$dir/${kvantumTheme}.kvconfig"
      cp Kvantum/Win11OS-dark/Win11OS-dark.svg "$dir/${kvantumTheme}.svg"
      sed -i \
        ${
          lib.concatStringsSep " \\\n        " (
            lib.mapAttrsToList (hex: key: "-e 's/#${hex}/#${p.${key}}/Ig'") kvantumRecolor
          )
        } \
        "$dir/${kvantumTheme}.kvconfig" "$dir/${kvantumTheme}.svg"

      # The 2 keys Win11OS never sets. Unset does NOT mean unused: Kvantum takes them from Qt's
      # palette, which is the LIGHT default.
      sed -i \
        -e '/^\[GeneralColors\]$/a tooltip.base.color=#${p.surface}' \
        -e '/^\[GeneralColors\]$/a shadow.color=#${p.shadow}' \
        "$dir/${kvantumTheme}.kvconfig"
      runHook postInstall
    '';
  };

  # The Windows 11 ICONS, pinned by commit and vendored (not in nixpkgs). Chosen over
  # fluent-icon-theme on 07/08/2026; the reasons and the price: docs/notes/desktop/theme.md
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

  # It selects the recolored theme and copies it into ~/.config/Kvantum.
  qt.kvantum = {
    enable = true;
    themes = [ win11os-kvantum ]; # copies into ~/.config/Kvantum/<theme>/
    settings.General.theme = kvantumTheme; # SSOT: it follows my.theme.name
  };

  # Kvantum does NOT set icons: KDE reads kdeglobals [Icons] Theme, and it rewrites that file, so
  # only that key is forced (the same pattern as home/apps/dolphin.nix).
  home.activation.kdeIconTheme = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    kw="${pkgs.kdePackages.kconfig}/bin/kwriteconfig6"
    run "$kw" --file "$HOME/.config/kdeglobals" --group Icons --key Theme ${config.my.theme.iconTheme}
  '';
}
