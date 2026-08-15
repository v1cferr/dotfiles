# kitty: Hyprland's default terminal (SUPER+Q, the keybind is in home/desktop/hypr.nix).
# `programs.kitty` INSTALLS the package AND writes ~/.config/kitty/kitty.conf (app plus config in
# home, rule 4). The prompt is starship (home/shell/starship.nix) and the shell is zsh
# (home/shell/zsh.nix).
{ config, osConfig, ... }:

let
  # kitty-themes has file names OF ITS OWN, so my.theme's preset needs a translation (rule 11: the
  # consumer adapts, but it does not hold the value). A new preset in palette.nix with no entry
  # here BREAKS the eval, on purpose: it fails loudly, not in silence.
  kittyThemes = {
    tokyo-night = "tokyo_night_night";
    catppuccin-mocha = "Catppuccin-Mocha";
    gruvbox-dark = "gruvbox-dark";
  };
in
{
  programs.kitty = {
    enable = true;

    # The same font as the rest of the system (SSOT: my.fonts.ui, hence starship's icons).
    font = {
      name = osConfig.my.fonts.ui;
      size = 12;
    };

    # The color scheme FOLLOWS my.theme.name (it used to be pinned to tokyo_night: switching
    # presets recolored everything but the terminal). A kitty-themes file, without the .conf
    # suffix.
    themeFile = kittyThemes.${config.my.theme.name};

    # kitty injects helpers into the shell (jumping between prompts, opening output in the pager
    # and so on).
    shellIntegration.mode = "enabled";

    settings = {
      background_opacity = "0.95"; # a light transparency (Hyprland's compositor)
      scrollback_lines = 10000; # a generous scrollback history
      enable_audio_bell = false; # no beep; it uses a visual flash instead
      confirm_os_window_close = 0; # it closes the window without asking for confirmation
      window_padding_width = 8; # breathing room between the text and the border
      cursor_blink_interval = 0; # a steady cursor (it does not blink)
      copy_on_select = "clipboard"; # selecting already copies to the clipboard
    };

    keybindings = {
      "ctrl+shift+enter" = "new_window"; # a new kitty window (a split)
      "ctrl+shift+t" = "new_tab"; # a new tab
      "ctrl+equal" = "change_font_size all +1.0"; # it increases the font
      "ctrl+minus" = "change_font_size all -1.0"; # it decreases the font
      "ctrl+0" = "change_font_size all 0"; # it resets the font size
    };
  };
}
