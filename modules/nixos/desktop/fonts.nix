# FONTS: the SSOT of the UI family and of the shell's text and icons (`my.fonts.*`), read by the
# modules/home/ side through osConfig. Why here, and the fallback coverage: docs/notes/hardware/fonts.md
{
  pkgs,
  lib,
  config,
  ...
}:

{
  options.my.fonts.ui = lib.mkOption {
    type = lib.types.str;
    default = "JetBrainsMono Nerd Font";
    description = "The UI font family (SSOT). Read by fontconfig and, through osConfig, by the modules/home/ modules.";
  };

  options.my.fonts.shell = lib.mkOption {
    type = lib.types.str;
    default = "Geist";
    description = "The Quickshell shell's text family: the bar, its panels, the band and the lock. A missing glyph falls back to the UI family's proportional cut.";
  };

  options.my.fonts.icons = lib.mkOption {
    type = lib.types.str;
    default = "Material Symbols Rounded";
    description = "The icon family the bar draws by ligature name.";
  };

  config.fonts = {
    packages = with pkgs; [
      nerd-fonts.jetbrains-mono
      # COVERAGE. The Nerd Font stops at Latin/Greek/Cyrillic; with nobody declared the fallback ends
      # at unifont's pixelated square. Declared even when free, so it is not a NixOS default.
      noto-fonts # proportional Sans/Serif plus Symbols/Symbols2: the broadest general coverage
      noto-fonts-color-emoji # COLOR emoji (CBDT); monochrome-emoji is the opposite of what we want
      noto-fonts-cjk-sans # Japanese/Chinese/Korean (a stream name, Twitch chat)
      # Microsoft's metrics, so OnlyOffice opens .docx/.xlsx without the pagination shifting.
      corefonts # Arial, Times New Roman, Courier New, Verdana… (Office 2003 and earlier)
      vista-fonts # Calibri, Cambria, Consolas… (the modern .docx uses Calibri by default)
      # The SHELL's type, never the system's UI default: Geist, and icons with a weight axis
      # (Material Symbols). docs/notes/hardware/fonts.md
      geist-font
      material-symbols
    ];
    fontconfig = {
      enable = true;
      # The SSOT stays FIRST in every list, so the look never changes; what follows is only reached
      # for a missing glyph, and emoji goes LAST so it never beats a text font.
      defaultFonts = {
        monospace = [
          config.my.fonts.ui
          "Noto Sans Mono"
          "Noto Color Emoji"
        ];
        sansSerif = [
          config.my.fonts.ui
          "Noto Sans"
          "Noto Color Emoji"
        ];
        serif = [
          config.my.fonts.ui
          "Noto Serif"
          "Noto Color Emoji"
        ];
        emoji = [ "Noto Color Emoji" ]; # explicit: it is NixOS' default, but a silent default is not something to inherit
      };
      # The shell's family has no icons: a Nerd Font glyph inside its text comes from the UI family's
      # PROPORTIONAL cut, whose advances fit a proportional text (the plain cut's glyphs overlap it).
      localConf = ''
        <?xml version="1.0"?>
        <!DOCTYPE fontconfig SYSTEM "urn:fontconfig:fonts.dtd">
        <fontconfig>
          <alias binding="same">
            <family>${config.my.fonts.shell}</family>
            <prefer>
              <family>${config.my.fonts.shell}</family>
              <family>${config.my.fonts.ui} Propo</family>
            </prefer>
          </alias>
        </fontconfig>
      '';
    };
  };
}
