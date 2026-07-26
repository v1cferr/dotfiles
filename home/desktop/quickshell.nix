# QUICKSHELL — o shell/bar em QML (bar, OSD, mídia, notificações), substituindo a
# waybar. O binário vem do FLAKE oficial (inputs.quickshell → sempre a última;
# bump com `nix flake update quickshell`).
#
# HOT-RELOAD (o motivo de ser assim): a config QML mora no REPO
# (home/desktop/quickshell/) e é linkada por mkOutOfStoreSymlink — um symlink pro
# arquivo MUTÁVEL, não pra store read-only. Assim o Quickshell recarrega o QML AO
# VIVO ao salvar (sem rebuild), e os arquivos seguem versionados no git (portável:
# outra máquina clona o repo no mesmo caminho e funciona). É um desvio consciente
# da regra 3 (não é symlink puro da store), padrão da comunidade p/ ricing de QML.
{ pkgs, config, inputs, ... }:

{
  home.packages = [
    inputs.quickshell.packages.${pkgs.system}.default # `qs` / `quickshell`
    pkgs.lm_sensors # `sensors` — CPU temp lido pelo bar/Bar.qml
  ];

  # ~/.config/quickshell → arquivo real no repo (mutável) = hot-reload.
  xdg.configFile."quickshell".source =
    config.lib.file.mkOutOfStoreSymlink
      "${config.home.homeDirectory}/Projects/GitHub/v1cferr/dotfiles/home/desktop/quickshell";
}
