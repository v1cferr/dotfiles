# ═══════════════════════════════════════════════════════════════════════════
# MONITORES = FONTE ÚNICA dos nomes de conector (regra 11). Era o pior caso de
# duplicação do repo: DP-2 em 8 arquivos e HDMI-A-3 em 7, entre Nix, Lua e QML —
# trocar de monitor (ou de cabo) obrigava a caçar string em tudo.
#
# Aqui ficam só os NOMES, que é o que se repetia. Modo/posição/refresh continuam
# em hypr/lua/monitors.lua: aparecem uma vez cada, não são SSOT de nada.
#
# Consumidores em Nix leem `config.my.monitors.<n>`. Os de HOT-RELOAD leem os
# arquivos de dados gerados abaixo, porque o Nix não escreve dentro das árvores
# symlinkadas do hypr/quickshell (mesma mecânica da paleta em palette.nix).
# ═══════════════════════════════════════════════════════════════════════════
{ config, lib, ... }:

let
  cfg = config.my.monitors;
in
{
  options.my.monitors = {
    primary = lib.mkOption {
      type = lib.types.str;
      default = "DP-2";
      description = "Conector do monitor PRINCIPAL (LG ULTRAGEAR) — origem 0x0, workspaces 1–4.";
    };
    secondary = lib.mkOption {
      type = lib.types.str;
      default = "HDMI-A-3";
      description = "Conector do monitor SECUNDÁRIO (TV LG) — à esquerda, workspaces 5–8.";
    };
  };

  config = {
    # Dados p/ o Hyprland: monitors/rules/keybinds.lua dão dofile e usam a tabela.
    home.file.".config/theme/monitors.lua".text = ''
      -- Gerado pelo Nix (my.monitors). NÃO editar à mão — fonte em home/desktop/monitors.nix.
      return {
        primary = "${cfg.primary}",
        secondary = "${cfg.secondary}",
      }
    '';

    # Dados p/ o Quickshell: Theme.qml lê via FileView + JsonAdapter.
    home.file.".config/theme/monitors.json".text = builtins.toJSON {
      inherit (cfg) primary secondary;
    };
  };
}
