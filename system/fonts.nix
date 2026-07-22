# ═══════════════════════════════════════════════════════════════════════════
# FONTES E TIPOGRAFIA — JetBrainsMono Nerd Font (ícones do starship/eza/waybar)
# como fonte padrão de mono/sans/serif.
# ═══════════════════════════════════════════════════════════════════════════
{ pkgs, ... }:

{
  fonts = {
    packages = with pkgs; [ nerd-fonts.jetbrains-mono ];
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
