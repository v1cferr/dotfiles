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
    # The condition TEXT is pt-BR on purpose: it is the product, like the holidays' names, while
    # the chrome around it stays en-US (rule 2). The ICON is NOT here: only the bar draws one, so
    # the code -> glyph mapping lives in Bar.qml and is not duplicated.
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
    inherit (cfg) latitude longitude conditions;
  };
}
