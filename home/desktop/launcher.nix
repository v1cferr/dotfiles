# LAUNCHER: rofi `drun` with icons and rofi's own recency history, themed from my.theme.
# rofi itself comes from clipboard.nix; the binds are in keybinds.lua (SUPER+Q / SUPER+R).
{ config, osConfig, ... }:

let
  palette = config.my.theme.palette; # the active theme's colors (home/desktop/palette.nix)
in
{
  # An explicit `font`, or rofi falls back to "mono 12". Do NOT comment inside a .rasi with '#':
  # there '#' opens a color literal and breaks the parse.
  xdg.configFile."rofi/launcher.rasi".text = ''
    configuration {
      show-icons: true;
      icon-theme: "${config.my.theme.iconTheme}";
      drun-display-format: "{name}";
      matching:   "fuzzy";
      font:       "${osConfig.my.fonts.ui} 12";
    }
    * {
      tn-bg:     #${palette.bg};
      tn-bg-alt: #${palette.surface};
      tn-fg:     #${palette.text};
      tn-muted:  #${palette.dim};
      tn-blue:   #${palette.blue};
      tn-border: #${palette.border};
      background-color: transparent;
      text-color:       @tn-fg;
    }
    window {
      width:            640px;
      background-color: @tn-bg;
      border:           2px;
      border-color:     @tn-blue;
      border-radius:    12px;
      padding:          14px;
    }
    mainbox { spacing: 12px; children: [ inputbar, listview ]; }
    inputbar {
      background-color: @tn-bg-alt;
      border-radius:    8px;
      padding:          10px 14px;
      spacing:          8px;
      children:         [ prompt, entry ];
    }
    prompt { text-color: @tn-blue; }
    entry  { placeholder: "Search apps…"; placeholder-color: @tn-muted; }
    listview { lines: 10; columns: 1; scrollbar: false; spacing: 4px; }
    element {
      padding:       8px 10px;
      spacing:       12px;
      border-radius: 8px;
      children:      [ element-icon, element-text ];
    }
    element normal.normal   { background-color: transparent; text-color: @tn-fg; }
    element selected.normal { background-color: @tn-blue;     text-color: @tn-bg; }
    element-icon { size: 1.8em; vertical-align: 0.5; }
    element-text { vertical-align: 0.5; }
  '';
}
