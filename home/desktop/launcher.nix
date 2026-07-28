# Launcher de apps — rofi `drun` com ÍCONES (Fluent-dark) + ordena pelos mais/recém usados
# (histórico do rofi, ligado por padrão: na abertura mostra os recentes; ao digitar, filtra
# fuzzy) + tema Tokyo Night vindo da paleta ÚNICA (my.theme → recolore junto ao trocar preset).
# Binds SUPER+Q (apps) / SUPER+R (binários) em home/desktop/hypr/lua/keybinds.lua.
# O pacote rofi já vem de clipboard.nix (não redeclara — mesmo tool p/ launcher + clipboard).
{ config, ... }:

let
  palette = config.my.theme.palette; # cores do tema ativo (home/desktop/palette.nix)
in
{
  xdg.configFile."rofi/launcher.rasi".text = ''
    configuration {
      show-icons: true;
      icon-theme: "Fluent-dark";
      drun-display-format: "{name}";
      matching:   "fuzzy";
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
