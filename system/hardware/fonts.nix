# FONTS: the SSOT of the UI family, `my.fonts.ui`. The home/ side reads it through osConfig.
# Why it lives here, and the fallback coverage that is a CHOICE: docs/notes/fonts.md
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
    description = "The UI font family (SSOT). Read by fontconfig and, through osConfig, by the home/ modules.";
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
    };
  };
}
