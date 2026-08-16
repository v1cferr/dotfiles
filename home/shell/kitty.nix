# kitty, Hyprland's default terminal. The prompt is starship, the shell is zsh.
# The color scheme follows my.theme.name through the table below.
{ config, osConfig, ... }:

let
  # kitty-themes has names of its own, so the preset needs translating. A new preset with no
  # entry here BREAKS the eval on purpose: fail loudly, not silently.
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

    # It follows my.theme.name; it used to be pinned and the terminal was the one thing that
    # did not recolor.
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
