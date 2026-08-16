# FONTS AND TYPOGRAPHY: the SINGLE SOURCE (SSOT) of the UI family, `my.fonts.ui`.
#
# It lives here, and not in my.theme (home/desktop/palette.nix, which handles the COLORS), for two
# reasons: the font's PACKAGE is system level (rule 4), so name and package stay together; and the
# fontconfig below also needs the name, and a system module does not read a home-manager option.
# The USER consumers read it through `osConfig` (the same pattern as my.services in
# system/services/toggles.nix): GTK+Qt (home/desktop/theme.nix), kitty, hyprlock, rofi and
# Quickshell's JSON.
#
# Switching fonts = 1 line (`my.fonts.ui`) plus the corresponding package in the list.
# The SIZE stays with each consumer: 11pt in GTK, 12pt in kitty/rofi, and the lockscreen varies
# per widget. That is context, not theme.
# ═══════════════════════════════════════════════════════════════════════════
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
      # ── COVERAGE (the rest of Unicode the Nerd Font does not have) ──────────
      # JetBrainsMono NF covers Latin/Greek/Cyrillic plus the patched symbols, and THAT IS ALL.
      # Emoji, CJK, math, arrows and dingbats come out through FALLBACK, and with nobody declared
      # fontconfig resolves in an order of its own, ending at `unifont` (a 16px bitmap that comes
      # from enableDefaultPackages and is the only one covering ranges like U+0870/U+2FFC): it is
      # the pixelated little square that showed up in a stream title and in a spreadsheet. These
      # three go in so the fallback is a CHOICE and not an accident, and they stay DECLARED even
      # the ones that already came for free through enableDefaultPackages, otherwise the rendering
      # depends on a NixOS default nobody here asked for.
      noto-fonts # proportional Sans/Serif plus Symbols/Symbols2: the broadest general coverage
      noto-fonts-color-emoji # COLOR emoji (CBDT); monochrome-emoji is the opposite of what we want
      noto-fonts-cjk-sans # Japanese/Chinese/Korean (a stream name, Twitch chat)
      # Microsoft's metrics so OnlyOffice (home/apps/office.nix) opens .docx/.xlsx with the right
      # layout; without them fontconfig substitutes and the pagination shifts.
      corefonts # Arial, Times New Roman, Courier New, Verdana… (Office 2003 and earlier)
      vista-fonts # Calibri, Cambria, Consolas… (the modern .docx uses Calibri by default)
    ];
    fontconfig = {
      enable = true;
      # A "laboratory" aesthetic: the UI font in menus and the browser too. It is what answers
      # when a document asks for a font that is not installed (see above).
      # The SSOT stays FIRST in every list, and what comes after it is only consulted for a glyph
      # it does not have, so the appearance does not change, things merely stop being missing.
      # Emoji goes at the END of each generic on purpose: at the end it never beats a text font,
      # but it is reached directly instead of by luck in the queue.
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
