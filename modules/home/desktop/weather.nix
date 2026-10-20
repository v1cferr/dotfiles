# WEATHER SSOT (rule 11): the coordinates and the WMO code -> pt-BR table, shared by the bar and
# the lock screen. Reasoning and the source's history: docs/notes/desktop/weather.md
{ config, lib, ... }:

let
  cfg = config.my.weather;
in
{
  options.my.weather = {
    latitude = lib.mkOption {
      type = lib.types.str;
      default = "-22.0087";
      description = "The latitude read by the bar and by the lock screen's fetch (São Carlos/SP).";
    };
    longitude = lib.mkOption {
      type = lib.types.str;
      default = "-47.8909";
      description = "The longitude read by the bar and by the lock screen's fetch (São Carlos/SP).";
    };
    place = lib.mkOption {
      type = lib.types.str;
      default = "São Carlos, SP";
      description = "The coordinates' name as the lock screen's weather card shows it.";
    };
    # INMET keys its forecasts and its alerts' municipality lists by the IBGE code, not by name:
    # "São Carlos" alone also matches São Carlos/SC (4216008).
    ibge = lib.mkOption {
      type = lib.types.str;
      default = "3548906";
      description = "The IBGE municipality code INMET's forecast and alerts are matched against (São Carlos/SP).";
    };
    # Pinned, not `best_match`: measured on 07/10/2026, best_match for São Carlos WAS ECMWF IFS (9 km)
    # hour for hour; pinning keeps it so if Open-Meteo's choice changes, and names the source on screen.
    model = lib.mkOption {
      type = lib.types.str;
      default = "ecmwf_ifs";
      description = "The Open-Meteo model both the bar and the lock screen ask for (https://open-meteo.com/en/docs).";
    };
    # The condition TEXT is pt-BR on purpose: it is the product, like the holidays' names, while
    # the chrome around it stays en-US (rule 2). The ICON is NOT here: only the bar draws one, so
    # the code -> glyph mapping lives in Bar.qml and is not duplicated.
    # The glyph per WMO code, day and night, for the bar AND the lock screen (it lived in Bar.qml
    # until 20/10/2026, when the lock needed it too: rule 11).
    icons = lib.mkOption {
      type = lib.types.attrsOf (lib.types.attrsOf lib.types.str);
      description = "Open-Meteo's WMO weather code -> { day, night } Nerd Font glyph.";
      default =
        let
          same = g: {
            day = g;
            night = g;
          };
          codes = list: g: lib.genAttrs (map toString list) (_: g);
        in
        {
          "0" = {
            day = "󰖙";
            night = "󰖔";
          };
          "1" = {
            day = "󰖙";
            night = "󰖔";
          };
          "2" = {
            day = "󰖕";
            night = "󰼶";
          };
          "3" = same "󰖐";
          "45" = same "󰖑";
          "48" = same "󰖑";
        }
        // codes [
          51
          53
          55
          56
          57
          61
          63
          65
          66
          67
          80
          81
          82
        ] (same "󰖗")
        // codes [ 71 73 75 77 85 86 ] (same "󰖘")
        // codes [ 95 96 99 ] (same "󰖓");
    };
    conditions = lib.mkOption {
      type = lib.types.attrsOf lib.types.str;
      description = "Open-Meteo's WMO weather code -> the pt-BR status shown on screen.";
      default = {
        "0" = "Céu limpo";
        "1" = "Predominantemente limpo";
        "2" = "Parcialmente nublado";
        "3" = "Nublado";
        "45" = "Neblina";
        "48" = "Neblina congelante";
        "51" = "Garoa fraca";
        "53" = "Garoa";
        "55" = "Garoa forte";
        "56" = "Garoa congelante fraca";
        "57" = "Garoa congelante";
        "61" = "Chuva fraca";
        "63" = "Chovendo";
        "65" = "Chuva forte";
        "66" = "Chuva congelante fraca";
        "67" = "Chuva congelante";
        "71" = "Neve fraca";
        "73" = "Nevando";
        "75" = "Neve forte";
        "77" = "Grãos de neve";
        "80" = "Pancadas de chuva";
        "81" = "Pancadas de chuva fortes";
        "82" = "Pancadas de chuva violentas";
        "85" = "Pancadas de neve";
        "86" = "Pancadas de neve fortes";
        "95" = "Tempestade";
        "96" = "Tempestade com granizo";
        "99" = "Tempestade com granizo forte";
      };
    };
  };

  # Data for Quickshell (Bar.qml reads it through FileView), the same path and the same reason as
  # the palette's JSON: this is the ONLY way into a hot-reload tree that Nix cannot template.
  config.home.file.".config/theme/weather.json".text = builtins.toJSON {
    inherit (cfg)
      latitude
      longitude
      ibge
      model
      conditions
      icons
      ;
  };
}
