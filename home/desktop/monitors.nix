# Dados de MONITOR para quem faz HOT-RELOAD (Hyprland em Lua e Quickshell em QML):
# eles leem arquivo em runtime, e o Nix não escreve dentro das árvores symlinkadas
# do ~/.config/hypr e ~/.config/quickshell — então o valor sai da opção e vira
# arquivo aqui (mesma mecânica da paleta em home/desktop/palette.nix).
#
# A OPÇÃO em si NÃO mora mais aqui: `my.monitors` é de sistema desde 04/08/2026
# (system/desktop/monitors.nix), porque o Sunshine também precisa do conector p/
# escolher qual monitor capturar. Aqui só se lê, via `osConfig`.
{ osConfig, ... }:

let
  cfg = osConfig.my.monitors;
in
{
  # Dados p/ o Hyprland: monitors/rules/keybinds.lua dão dofile e usam a tabela.
  home.file.".config/theme/monitors.lua".text = ''
    -- Gerado pelo Nix (my.monitors). NÃO editar à mão — fonte em system/desktop/monitors.nix.
    return {
      primary = "${cfg.primary}",
      secondary = "${cfg.secondary}",
    }
  '';

  # Dados p/ o Quickshell: Theme.qml lê via FileView + JsonAdapter.
  home.file.".config/theme/monitors.json".text = builtins.toJSON {
    inherit (cfg) primary secondary;
  };
}
