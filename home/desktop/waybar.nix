# Waybar — pacote + config (~/.config/waybar/*) no home (regra 4). Barra BÁSICA e
# temporária — só workspaces + relógio (+ bandeja) — até você trazer a sua barra
# do Quickshell. Uma barra por monitor (Waybar faz isso sozinho); cada uma mostra
# as workspaces do SEU monitor (all-outputs=false): o LG mostra 1–4 e a TV 5–8.
# (Config raw via xdg.configFile em vez de programs.waybar.settings — é jsonc/css
# à mão; programs.waybar espera dados estruturados e traz um serviço systemd próprio.)
{ pkgs, ... }:

{
  home.packages = [ pkgs.waybar ]; # o binário (config raw logo abaixo)

  xdg.configFile."waybar/config.jsonc".text = ''
    {
      "layer": "top",
      "position": "top",
      "height": 32,
      "spacing": 6,

      "modules-left": ["hyprland/workspaces"],
      "modules-center": ["clock"],
      "modules-right": ["tray"],

      "hyprland/workspaces": {
        "all-outputs": false,
        "sort-by-number": true,
        "on-click": "activate",
        "persistent-workspaces": {
          "1": ["DP-2"], "2": ["DP-2"], "3": ["DP-2"], "4": ["DP-2"],
          "5": ["HDMI-A-3"], "6": ["HDMI-A-3"], "7": ["HDMI-A-3"], "8": ["HDMI-A-3"]
        }
      },

      "clock": {
        "format": "{:%H:%M  ·  %a %d/%m}",
        "tooltip-format": "<big>{:%Y %B}</big>\n<tt><small>{calendar}</small></tt>"
      },

      "tray": { "spacing": 8 }
    }
  '';

  xdg.configFile."waybar/style.css".text = ''
    * {
      font-family: "JetBrainsMono Nerd Font";
      font-size: 13px;
      min-height: 0;
    }
    window#waybar {
      background: rgba(20, 20, 20, 0.85);
      color: #e0e0e0;
    }
    #workspaces button {
      padding: 0 8px;
      color: #888888;
      background: transparent;
    }
    #workspaces button.active {
      color: #ffffff;
      background: rgba(255, 255, 255, 0.12);
    }
    #workspaces button:hover {
      background: rgba(255, 255, 255, 0.06);
    }
    #clock { padding: 0 12px; }
    #tray  { padding: 0 8px; }
  '';
}
