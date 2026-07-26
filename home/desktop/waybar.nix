# WAYBAR — status bar (topo), portada dos meus dotfiles do Arch e adaptada pro
# NixOS. Design em "pílulas" (grupos arredondados, hover, Tokyo Night). Pacote +
# config no home (regra 4). Os scripts que a barra chama são CONSTRUÍDOS pelo Nix
# (regra 7: nada de .sh solto; paths absolutos = durável), e onde dá troco script
# por MÓDULO NATIVO (mpris no lugar do script de Spotify).
#
# Adaptações Arch → NixOS:
#   • workspaces DP-1/HDMI-A-1 → DP-2/HDMI-A-3 (conectores atuais)
#   • weather: wttr.in (sem chave/segredo) no lugar da weatherAPI
#   • notificações: swaync (home/desktop/notifications.nix)
#   • GPU: só TEMP (o driver xe do Arc B580 não expõe uso%); usage dropado
#   • VPN dropado (migração de VPN adiada — netExtender fora do nixpkgs)
{ pkgs, ... }:

let
  # Conectores (mesmos nomes do home/desktop/hypr.nix).
  primary = "DP-2"; # LG ULTRAGEAR
  secondary = "HDMI-A-3"; # TV

  # ── Weather: wttr.in (JSON j1) → {text,tooltip,class}, cache /tmp p/ offline ──
  weather = pkgs.writeShellApplication {
    name = "waybar-weather";
    runtimeInputs = with pkgs; [ curl jq coreutils ];
    text = ''
      cache=/tmp/waybar-weather.json
      coords="-21.9977,-47.8827" # São Carlos/SP
      resp=$(curl -s --max-time 8 "https://wttr.in/$coords?format=j1&lang=pt" || true)
      temp=$(printf '%s' "$resp" | jq -r '.current_condition[0].temp_C // empty' 2>/dev/null || true)
      if [ -n "$temp" ]; then
        cond=$(printf '%s' "$resp" | jq -r '.current_condition[0].lang_pt[0].value // .current_condition[0].weatherDesc[0].value')
        hum=$(printf '%s' "$resp" | jq -r '.current_condition[0].humidity')
        wind=$(printf '%s' "$resp" | jq -r '.current_condition[0].windspeedKmph')
        feels=$(printf '%s' "$resp" | jq -r '.current_condition[0].FeelsLikeC')
        lc=$(printf '%s' "$cond" | tr '[:upper:]' '[:lower:]')
        icon="󰖐"
        case "$lc" in
          *sol*|*limp*|*clear*|*sunny*) icon="󰖙" ;;
          *parcial*|*partly*) icon="󰖕" ;;
          *nublad*|*cloud*|*encobert*|*overcast*) icon="󰖐" ;;
          *nevoeiro*|*neblina*|*mist*|*fog*) icon="󰖑" ;;
          *chuva*|*rain*|*chuvisco*|*drizzle*|*pancada*) icon="󰖗" ;;
          *trovoada*|*thunder*|*tempestade*|*storm*) icon="󰖓" ;;
          *neve*|*snow*|*granizo*) icon="󰖘" ;;
        esac
        tooltip="<b>São Carlos/SP</b>\n$cond\nSensação: ''${feels}°C\nUmidade: ''${hum}%\nVento: ''${wind} km/h"
        printf '{"text":"%s %s°C","tooltip":"%s","class":"weather"}\n' "$icon" "$temp" "$tooltip" | tee "$cache"
      elif [ -f "$cache" ]; then
        cat "$cache"
      else
        printf '{"text":"󰖐 --°C","tooltip":"Sem dados de clima","class":"weather-error"}\n'
      fi
    '';
  };

  # ── CPU temp: coretemp "Package id 0" (scan por nome — o hwmonN embaralha) ──
  cpuTemp = pkgs.writeShellApplication {
    name = "waybar-cpu-temp";
    runtimeInputs = with pkgs; [ coreutils gnugrep ];
    text = ''
      for h in /sys/class/hwmon/hwmon*; do
        [ "$(cat "$h/name" 2>/dev/null)" = "coretemp" ] || continue
        for l in "$h"/temp*_label; do
          grep -q "Package id 0" "$l" 2>/dev/null || continue
          v=$(cat "''${l%_label}_input")
          printf '%d°C\n' "$((v / 1000))"
          exit 0
        done
      done
      echo "N/A"
    '';
  };

  # ── GPU temp: sensor xe do Arc B580 (/sys/class/drm/card*/device/hwmon) ──
  gpuTemp = pkgs.writeShellApplication {
    name = "waybar-gpu-temp";
    runtimeInputs = with pkgs; [ coreutils ];
    text = ''
      for t in /sys/class/drm/card*/device/hwmon/hwmon*/temp*_input; do
        [ -r "$t" ] || continue
        d=$(dirname "$t")
        [ "$(cat "$d/name" 2>/dev/null)" = "xe" ] || continue
        v=$(cat "$t")
        printf '%d°C\n' "$((v / 1000))"
        exit 0
      done
      echo "N/A"
    '';
  };

  # ── Toggle do hypridle (systemd --user, no lugar do killall do Arch) ──
  hypridleToggle = pkgs.writeShellApplication {
    name = "waybar-hypridle-toggle";
    runtimeInputs = with pkgs; [ systemd libnotify ];
    text = ''
      unit=hypridle.service
      if [ "''${1:-}" = "toggle" ]; then
        if systemctl --user is-active --quiet "$unit"; then
          systemctl --user stop "$unit"
          notify-send -u low -t 2000 "Hypridle" "Desativado 󰒲" || true
        else
          systemctl --user start "$unit"
          notify-send -u low -t 2000 "Hypridle" "Ativado 󰒳" || true
        fi
        exit 0
      fi
      if systemctl --user is-active --quiet "$unit"; then
        printf '{"text":"󰒳","tooltip":"Hypridle: ativo — clique p/ desativar","class":"enabled"}\n'
      else
        printf '{"text":"󰒲","tooltip":"Hypridle: inativo — clique p/ ativar","class":"disabled"}\n'
      fi
    '';
  };
in
{
  # Binário + ferramentas que a barra invoca nos on-click (mpris/rede/áudio/notif).
  home.packages = with pkgs; [
    waybar
    playerctl # módulo mpris + play-pause/next/previous
    networkmanagerapplet # nm-connection-editor (network on-click)
    pulseaudio # pactl (pulseaudio on-click/scroll; cliente, não o daemon)
    xdg-utils # xdg-open (weather on-click)
  ];

  # ── config.jsonc (portada do Arch; scripts via ${...} do /nix/store) ──────────
  xdg.configFile."waybar/config.jsonc".text = ''
    {
      "layer": "top",
      "position": "top",
      "height": 30,
      "spacing": 4,
      "margin": "4 4 1 4",
      "reload_style_on_change": true,

      "modules-left": ["group/workspaces-window-spotify"],
      "modules-center": ["group/info-center"],
      "modules-right": ["group/system-tray"],

      "hyprland/workspaces": {
        "format": "{icon}",
        "on-click": "activate",
        "on-scroll-up": "hyprctl dispatch workspace e+1",
        "on-scroll-down": "hyprctl dispatch workspace e-1",
        "all-outputs": false,
        "active-only": false,
        "format-icons": {
          "1": "󰲠", "2": "󰲢", "3": "󰲤", "4": "󰲦",
          "5": "󰲨", "6": "󰲪", "7": "󰲬", "8": "󰲮",
          "active": "󰮯", "default": "󰊠", "empty": "󰧵", "urgent": "󰀪"
        },
        "persistent-workspaces": {
          "${primary}": [1, 2, 3, 4],
          "${secondary}": [5, 6, 7, 8]
        },
        "sort-by": "number"
      },
      "hyprland/window": {
        "format": "{title}",
        "format-empty": "",
        "max-length": 35,
        "separate-outputs": true,
        "rewrite": {
          "(.*) — Zen Browser": "󰺕 $1",
          "(.*) - zsh": "󰆍 [$1]",
          "(.*) - Spotify": "󰝚 $1",
          "(.*) - Code": "󰨞 $1",
          "(.*) - Visual Studio Code": "󰨞 $1"
        }
      },
      "mpris": {
        "format": "󰝚 {title} - {artist}",
        "format-paused": "󰏤 {title} - {artist}",
        "format-stopped": "",
        "interval": 2,
        "max-length": 30,
        "ellipsis": "…",
        "player-icons": { "spotify": "󰝚", "default": "󰎈" },
        "on-click": "playerctl play-pause",
        "on-scroll-up": "playerctl next",
        "on-scroll-down": "playerctl previous",
        "tooltip-format": "{player}: {status}\n{title}\n{artist} — {album}"
      },

      "custom/weather": {
        "format": "{}",
        "tooltip": true,
        "interval": 900,
        "exec": "${weather}/bin/waybar-weather",
        "return-type": "json",
        "on-click": "xdg-open 'https://wttr.in/S%C3%A3o+Carlos'"
      },
      "clock": {
        "interval": 1,
        "format": "󰥔 {:%H:%M:%S}",
        "format-alt": "󰃭 {:%d/%m/%Y}",
        "tooltip-format": "<big>{:%Y %B}</big>\n<tt><small>{calendar}</small></tt>",
        "calendar": {
          "mode": "year",
          "mode-mon-col": 3,
          "weeks-pos": "right",
          "on-scroll": 1,
          "format": {
            "months": "<span color='#ffead3'><b>{}</b></span>",
            "days": "<span color='#ecc6d9'>{}</span>",
            "weeks": "<span color='#99ffdd'><b>W{}</b></span>",
            "weekdays": "<span color='#ffcc66'><b>{}</b></span>",
            "today": "<span color='#ff6699'><b><u>{}</u></b></span>"
          }
        },
        "actions": {
          "on-click-right": "mode",
          "on-scroll-up": "shift_up",
          "on-scroll-down": "shift_down"
        }
      },
      "custom/notification": {
        "tooltip": true,
        "format": "{icon}",
        "format-icons": {
          "notification": "󰂚", "none": "󰂜",
          "dnd-notification": "󰂛", "dnd-none": "󰪑",
          "inhibited-notification": "󰂚", "inhibited-none": "󰂜",
          "dnd-inhibited-notification": "󰂛", "dnd-inhibited-none": "󰪑"
        },
        "return-type": "json",
        "exec-if": "which swaync-client",
        "exec": "swaync-client -swb",
        "on-click": "swaync-client -t -sw",
        "on-click-right": "swaync-client -d -sw",
        "escape": true
      },

      "pulseaudio": {
        "format": "{icon} {volume}%",
        "format-muted": "󰝟 {volume}%",
        "format-icons": {
          "headphone": "󰋋", "hands-free": "󰋎", "headset": "󰋎",
          "phone": "󰏲", "portable": "󰏲", "car": "󰄋",
          "default": ["󰕿", "󰖀", "󰕾"]
        },
        "scroll-step": 5,
        "on-click": "pactl set-sink-mute @DEFAULT_SINK@ toggle",
        "on-click-right": "pavucontrol",
        "on-scroll-up": "pactl set-sink-volume @DEFAULT_SINK@ +5%",
        "on-scroll-down": "pactl set-sink-volume @DEFAULT_SINK@ -5%",
        "tooltip-format": "Volume: {volume}%\nDispositivo: {desc}"
      },
      "network": {
        "format-wifi": "󰤨 {signalStrength}%",
        "format-ethernet": "󰈀",
        "format-disconnected": "󰤯",
        "format-alt": "{ifname}: {ipaddr}/{cidr}",
        "tooltip-format-wifi": "WiFi: {essid} ({signalStrength}%)\nIP: {ipaddr}\nVelocidade: {bandwidthDownBits} ⬇ {bandwidthUpBits} ⬆",
        "tooltip-format-ethernet": "Ethernet: {ifname}\nIP: {ipaddr}\nVelocidade: {bandwidthDownBits} ⬇ {bandwidthUpBits} ⬆",
        "tooltip-format-disconnected": "Rede desconectada",
        "on-click": "nm-connection-editor",
        "on-click-right": "nmcli device wifi rescan",
        "interval": 5
      },
      "cpu": {
        "interval": 2,
        "format": " {usage}%",
        "max-length": 10,
        "states": { "warning": 70, "critical": 90 },
        "tooltip-format": "CPU: {usage}%\nFrequência: {avg_frequency} GHz\nLoad: {load}"
      },
      "custom/cpu-temp": {
        "format": " {}",
        "interval": 3,
        "exec": "${cpuTemp}/bin/waybar-cpu-temp",
        "tooltip": true,
        "tooltip-format": "Temperatura da CPU: {}"
      },
      "custom/gpu-temp": {
        "format": "󰢮 {}",
        "interval": 3,
        "exec": "${gpuTemp}/bin/waybar-gpu-temp",
        "tooltip": true,
        "tooltip-format": "Temperatura da GPU (Arc B580): {}"
      },
      "memory": {
        "interval": 5,
        "format": " {percentage}%",
        "max-length": 10,
        "states": { "warning": 70, "critical": 90 },
        "tooltip-format": "RAM: {used:0.1f}GB / {total:0.1f}GB ({percentage}%)\nSwap: {swapUsed:0.1f}GB / {swapTotal:0.1f}GB\nDisponível: {avail:0.1f}GB"
      },
      "disk": {
        "interval": 30,
        "format": "󰋊 {percentage_used}%",
        "path": "/",
        "states": { "warning": 70, "critical": 90 },
        "tooltip-format": "Disco: {used} / {total} ({percentage_used}%)\nLivre: {free}",
        "unit": "GB"
      },
      "custom/hypridle": {
        "format": "{}",
        "exec": "${hypridleToggle}/bin/waybar-hypridle-toggle",
        "return-type": "json",
        "interval": 5,
        "on-click": "${hypridleToggle}/bin/waybar-hypridle-toggle toggle",
        "tooltip": true
      },
      "tray": {
        "icon-size": 18,
        "spacing": 8,
        "show-passive-items": true
      },

      "group/workspaces-window-spotify": {
        "orientation": "horizontal",
        "modules": ["hyprland/workspaces", "hyprland/window", "mpris"]
      },
      "group/info-center": {
        "orientation": "horizontal",
        "modules": ["custom/weather", "clock", "custom/notification"]
      },
      "group/system-tray": {
        "orientation": "horizontal",
        "modules": [
          "cpu", "custom/cpu-temp", "custom/gpu-temp", "memory", "disk",
          "network", "pulseaudio", "custom/hypridle", "tray"
        ]
      }
    }
  '';

  # ── style.css (portada; #custom-spotify → #mpris; gpu-usage/vpn removidos) ─────
  xdg.configFile."waybar/style.css".text = ''
    * {
      border: none;
      border-radius: 0;
      font-family: "JetBrainsMono Nerd Font", "JetBrainsMono NFP", sans-serif;
      font-size: 11px;
      font-weight: 400;
      min-height: 0;
      margin: 0;
      padding: 0;
    }

    window#waybar { background: transparent; color: #cdd6f4; }

    tooltip {
      background: rgba(26, 27, 38, 0.95);
      border: 1px solid #414868;
      border-radius: 8px;
      color: #c0caf5;
    }
    tooltip label { color: #c0caf5; padding: 4px 8px; }

    /* Containers dos grupos (pílulas) */
    #group-workspaces-window-spotify,
    #group-info-center,
    #group-system-tray {
      background: rgba(26, 27, 38, 0.35);
      border: 1px solid rgba(65, 72, 104, 0.18);
      border-radius: 12px;
      padding: 4px;
      box-shadow: 0 2px 8px rgba(0, 0, 0, 0.15);
    }
    #group-workspaces-window-spotify { margin: 0 20px 0 0; }
    #group-info-center { margin: 0 8px; }
    #group-system-tray { margin: 0 0 0 8px; }

    /* Mini-pílulas (todos os módulos) */
    #window, #mpris, #custom-weather, #clock, #custom-notification,
    #cpu, #custom-cpu-temp, #custom-gpu-temp, #memory, #disk,
    #network, #pulseaudio, #custom-hypridle, #tray {
      background: rgba(26, 27, 38, 0.86);
      border: 1px solid rgba(65, 72, 104, 0.35);
      border-radius: 8px;
      margin: 0 3px;
      padding: 4px 10px;
      color: #c0caf5;
      box-shadow: 0 1px 3px rgba(0, 0, 0, 0.3);
      transition: all 0.3s ease-in-out;
    }

    /* Hover das mini-pílulas */
    #window:hover, #mpris:hover, #custom-weather:hover, #clock:hover,
    #custom-notification:hover, #cpu:hover, #custom-cpu-temp:hover,
    #custom-gpu-temp:hover, #memory:hover, #disk:hover, #network:hover,
    #pulseaudio:hover, #custom-hypridle:hover, #tray:hover {
      background: rgba(26, 27, 38, 0.98);
      border-color: rgba(122, 162, 247, 0.5);
    }
    #group-workspaces-window-spotify:hover,
    #group-info-center:hover,
    #group-system-tray:hover {
      background: rgba(26, 27, 38, 0.5);
      border-color: rgba(122, 162, 247, 0.3);
    }

    /* Workspaces: botões como mini-pílulas */
    #workspaces button {
      background: rgba(26, 27, 38, 0.86);
      border: 1px solid rgba(65, 72, 104, 0.35);
      border-radius: 8px;
      color: #a9b1d6;
      margin: 0 3px;
      padding: 4px 10px;
      min-width: 24px;
      font-size: 13px;
      transition: all 0.3s ease;
    }
    #workspaces button:hover { border-color: rgba(122, 162, 247, 0.5); }
    #workspaces button.active, #workspaces button.focused {
      background: rgba(122, 162, 247, 0.85);
      border-color: rgba(122, 162, 247, 0.9);
      color: #1a1b26;
      font-weight: 600;
    }
    #workspaces button.urgent {
      background: rgba(247, 118, 142, 0.85);
      color: #1a1b26;
    }

    /* Cores por módulo (Tokyo Night) */
    #window { color: #89dceb; font-style: italic; }
    #mpris { color: #a6e3a1; }
    #mpris.paused { color: #f9e2af; }
    #mpris.stopped { color: #6c7086; }
    #custom-weather { color: #74c7ec; }
    #custom-weather.weather-error { color: #f38ba8; }
    #clock { color: #cba6f7; font-weight: 500; font-size: 12px; }
    #custom-notification { color: #fab387; }
    #pulseaudio { color: #89b4fa; }
    #pulseaudio.muted { color: #6c7086; }
    #network { color: #a6e3a1; }
    #network.disconnected { color: #f38ba8; }
    #network.ethernet { color: #94e2d5; }
    #cpu { color: #f9e2af; }
    #cpu.warning { color: #fab387; }
    #cpu.critical { color: #f38ba8; }
    #custom-cpu-temp { color: #fab387; }
    #custom-gpu-temp { color: #b4befe; }
    #memory { color: #f5c2e7; }
    #memory.warning { color: #fab387; }
    #memory.critical { color: #f38ba8; }
    #disk { color: #94e2d5; }
    #disk.warning { color: #fab387; }
    #disk.critical { color: #f38ba8; }
    #custom-hypridle.enabled { color: #a6e3a1; }
    #custom-hypridle.disabled { color: #f38ba8; }
    #tray { padding: 2px 6px; }
    #tray > .needs-attention { color: #fab387; }

    window#waybar.empty #window {
      background: transparent;
      border: none;
      margin: 0;
      padding: 0;
      box-shadow: none;
    }

    .modules-left > widget:first-child > #workspaces { margin-left: 0; }
    .modules-right > widget:last-child > #tray { margin-right: 0; }
  '';
}
