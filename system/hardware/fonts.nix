# ═══════════════════════════════════════════════════════════════════════════
# FONTES E TIPOGRAFIA — JetBrainsMono Nerd Font (ícones do starship/eza/waybar)
# como fonte padrão de mono/sans/serif.
# ═══════════════════════════════════════════════════════════════════════════
{ pkgs, ... }:

{
  fonts = {
    packages = with pkgs; [
      nerd-fonts.jetbrains-mono
      # Métricas da Microsoft p/ o OnlyOffice (home/apps/office.nix) abrir .docx/.xlsx
      # com o layout certo — sem elas o fontconfig substitui e a paginação anda.
      corefonts # Arial, Times New Roman, Courier New, Verdana… (Office ≤2003)
      vista-fonts # Calibri, Cambria, Consolas… (o .docx moderno usa Calibri por padrão)
    ];
    fontconfig = {
      enable = true;
      # Estética "laboratório": JetBrains Mono também em menus/navegador.
      defaultFonts = {
        monospace = [ "JetBrainsMono Nerd Font" ];
        sansSerif = [ "JetBrainsMono Nerd Font" ];
        serif = [ "JetBrainsMono Nerd Font" ];
      };
    };
  };
}
