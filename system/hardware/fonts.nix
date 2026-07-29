# ═══════════════════════════════════════════════════════════════════════════
# FONTES E TIPOGRAFIA — FONTE ÚNICA (SSOT) da família de UI: `my.fonts.ui`.
#
# Mora aqui, e não no my.theme (home/desktop/palette.nix, que cuida das CORES),
# por dois motivos: o PACOTE da fonte é nível-sistema (regra 4) → nome e pacote
# ficam juntos; e o fontconfig abaixo também precisa do nome, e módulo de sistema
# não lê opção do home-manager. Os consumidores de USUÁRIO leem via `osConfig`
# (mesmo padrão do my.services em system/services/toggles.nix): GTK+Qt
# (home/desktop/theme.nix), kitty, hyprlock, rofi e o JSON do Quickshell.
#
# Trocar de fonte = 1 linha (`my.fonts.ui`) + o pacote correspondente na lista.
# O TAMANHO fica em cada consumidor: 11pt no GTK, 12pt no kitty/rofi, e o lockscreen
# varia por widget — é contexto, não tema.
# ═══════════════════════════════════════════════════════════════════════════
{ pkgs, lib, config, ... }:

{
  options.my.fonts.ui = lib.mkOption {
    type = lib.types.str;
    default = "JetBrainsMono Nerd Font";
    description = "Família da fonte de UI (SSOT). Lida pelo fontconfig e, via osConfig, pelos módulos do home/.";
  };

  config.fonts = {
    packages = with pkgs; [
      nerd-fonts.jetbrains-mono
      # Métricas da Microsoft p/ o OnlyOffice (home/apps/office.nix) abrir .docx/.xlsx
      # com o layout certo — sem elas o fontconfig substitui e a paginação anda.
      corefonts # Arial, Times New Roman, Courier New, Verdana… (Office ≤2003)
      vista-fonts # Calibri, Cambria, Consolas… (o .docx moderno usa Calibri por padrão)
    ];
    fontconfig = {
      enable = true;
      # Estética "laboratório": a fonte de UI também em menus/navegador. É o que
      # responde quando um documento pede fonte que não está instalada (ver acima).
      defaultFonts = {
        monospace = [ config.my.fonts.ui ];
        sansSerif = [ config.my.fonts.ui ];
        serif = [ config.my.fonts.ui ];
      };
    };
  };
}
