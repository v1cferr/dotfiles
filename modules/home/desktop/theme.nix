# THEME / DARK MODE plus the UI font. GTK follows color-scheme; Qt is qt6ct + Kvantum, KDE apps a color scheme.
# The 2 vendored themes and the 3 build traps in the icons: docs/notes/desktop/theme.md
{
  pkgs,
  lib,
  config,
  osConfig,
  ...
}:

let
  # Rule 19: everything this module reaches for, named once. deadnix fails the build on an
  # entry that stops being used, so the list cannot rot into a lie (rule 16).
  inherit (pkgs)
    bibata-cursors
    fetchFromGitHub
    gtk3
    stdenvNoCC
    ;
  inherit (pkgs.kdePackages) kconfig; # kwriteconfig6, which the activation writes with

  p = config.my.theme.palette; # SSOT: modules/home/desktop/palette.nix (rule 11, decision 0001)

  # The theme is the Win11OS GEOMETRY recolored by the palette, so the name carries both.
  kvantumTheme = "Win11OS-${config.my.theme.slug}";

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

  # The KDE COLOR SCHEME from the palette. KDE apps paint their views from KColorScheme and NOT
  # from the Qt style, so under Kvantum alone Dolphin drew dark names on white rows. Outside
  # Plasma only the app's own choice loads it (kdeglobals' is ignored): dolphin.nix selects it.
  kdeColors =
    let
      rgb =
        key:
        lib.concatMapStringsSep "," (i: toString (lib.fromHexString (lib.substring i 2 p.${key}))) [
          0
          2
          4
        ];
      base = {
        BackgroundNormal = rgb "bg";
        BackgroundAlternate = rgb "surface"; # the alternating row
        DecorationFocus = rgb "accent";
        DecorationHover = rgb "accent";
        ForegroundNormal = rgb "text";
        ForegroundActive = rgb "text";
        ForegroundInactive = rgb "dim";
        ForegroundLink = rgb "accent";
        ForegroundVisited = rgb "magenta";
        ForegroundNegative = rgb "red";
        ForegroundNeutral = rgb "yellow";
        ForegroundPositive = rgb "green";
      };
    in
    lib.generators.toINI { } (
      {
        General.Name = config.my.theme.slug;
      }
      // lib.mapAttrs' (group: overrides: lib.nameValuePair "Colors:${group}" (base // overrides)) {
        Window = { };
        View = { };
        Complementary = { };
        Button.BackgroundNormal = rgb "track";
        Header.BackgroundNormal = rgb "surface";
        Tooltip.BackgroundNormal = rgb "surface";
        # The same three steps as Zen's tabs: hover on surface, selected on track.
        Selection = {
          BackgroundNormal = rgb "track";
          BackgroundAlternate = rgb "track";
          ForegroundInactive = rgb "subtext";
        };
      }
    );

  # ONLY the Kvantum folder of Win11OS-kde, pinned by commit. The /share/Kvantum layout is what
  # qt.kvantum.themes expects. An exception to "modules/home/ does not install": it is a theme asset.
  win11os-kvantum = stdenvNoCC.mkDerivation {
    pname = "win11os-kvantum";
    version = "0-unstable-9f021c3";
    src = fetchFromGitHub {
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

      # OPAQUE, like every GTK app here: Win11OS draws the window translucent, which put the
      # wallpaper behind Dolphin's file names (measured on screen, 13/10/2026).
      sed -i \
        -e 's/^translucent_windows=true$/translucent_windows=false/' \
        -e 's/^blurring=true$/blurring=false/' \
        "$dir/${kvantumTheme}.kvconfig"

      # A tool button with NO vertical padding. Dolphin sizes its free-space button to the font
      # height, and Win11OS' 5+6 px frame plus 4 px text margin cut the text in half (measured).
      sed -i \
        -e '/^\[PanelButtonTool\]$/a text.margin=0\nframe.top=0\nframe.bottom=0' \
        "$dir/${kvantumTheme}.kvconfig"

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
  win11-icons = stdenvNoCC.mkDerivation {
    pname = "win11-icon-theme";
    version = "0-unstable-a5b460a";
    src = fetchFromGitHub {
      owner = "yeyushengfan258";
      repo = "Win11-icon-theme";
      rev = "a5b460a407da143b32f19a503d7fcebb3edf2371";
      hash = "sha256-+GtOkOVSWlNTdKSs0R86LhnpbBZ21Y0ML3V8pwDUUSc=";
    };
    dontConfigure = true;
    dontBuild = true;
    # gtk3 is ONLY for the binary: install.sh ends each variant with gtk-update-icon-cache, and
    # under `set -eo pipefail` the missing command killed it BEFORE Win11-dark existed.
    nativeBuildInputs = [ gtk3 ];
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
  home.packages = [ bibata-cursors ];

  # GTK apps read the UI font FROM HERE, not from fontconfig. The suffix is the size in pt.
  dconf.settings."org/gnome/desktop/interface" = {
    color-scheme = "prefer-dark";
    # GTK on Wayland reads the theme HERE, through the settings portal, not from settings.ini, and a
    # key dropped from Nix stays in dconf. So it names Stylix's theme instead of going away.
    gtk-theme = config.gtk.theme.name;
    icon-theme = config.my.theme.iconTheme; # SSOT (the package in gtk below)
    font-name = "${osConfig.my.fonts.ui} 11";
    document-font-name = "${osConfig.my.fonts.ui} 11";
    monospace-font-name = "${osConfig.my.fonts.ui} 11";
    # The GTK apps' cursor (Hyprland reads it from hypr/lua/environment.lua).
    cursor-theme = config.my.theme.cursor.name;
    cursor-size = config.my.theme.cursor.size;
  };

  # It writes ~/.config/gtk-3.0 and gtk-4.0. The packages are declared HERE (rule 4); the font
  # comes from modules/nixos/.
  # The THEME and the font are Stylix's now (adw-gtk3 recolored by the palette, stylix.nix).
  gtk = {
    enable = true;
    iconTheme = {
      name = config.my.theme.iconTheme; # SSOT: my.theme.iconTheme
      package = win11-icons; # the Windows 11 icons (Win11-dark); see the derivation in the let
    };
  };

  # Qt: qt6ct as the platform theme and Kvantum as the style, the pairing Kvantum documents. With
  # no platform theme Qt keeps its LIGHT default palette under the style. Measured: docs/notes/desktop/theme.md
  qt = {
    enable = true;
    platformTheme.name = "qtct"; # QT_QPA_PLATFORMTHEME=qt5ct, a key qt6ct answers to as well
    style.name = "kvantum"; # QT_STYLE_OVERRIDE=kvantum -> Kvantum draws the widgets
  };

  # The palette comes from the Kvantum theme (custom_palette off), and the font from fontconfig
  # (decision 0002). One text for both: Qt 5 and Qt 6 apps read their own file.
  xdg.configFile = lib.genAttrs [ "qt5ct/qt5ct.conf" "qt6ct/qt6ct.conf" ] (_: {
    text = lib.generators.toINI { } {
      Appearance = {
        custom_palette = false;
        icon_theme = config.my.theme.iconTheme;
        standard_dialogs = "default";
        style = config.qt.style.name;
      };
    };
  });

  xdg.dataFile."color-schemes/${config.my.theme.slug}.colors".text = kdeColors;

  # It selects the recolored theme and copies it into ~/.config/Kvantum.
  qt.kvantum = {
    enable = true;
    themes = [ win11os-kvantum ]; # copies into ~/.config/Kvantum/<theme>/
    settings.General.theme = kvantumTheme; # SSOT: it follows my.theme.name
  };

  # Kvantum does NOT set icons: KDE reads kdeglobals [Icons] Theme, and it rewrites that file, so
  # only that key is forced (the same pattern as modules/home/apps/dolphin.nix).
  home.activation.kdeIconTheme = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    kw="${kconfig}/bin/kwriteconfig6"
    run "$kw" --file "$HOME/.config/kdeglobals" --group Icons --key Theme ${config.my.theme.iconTheme}
  '';
}
