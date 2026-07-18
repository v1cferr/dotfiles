# ═══════════════════════════════════════════════════════════════════════════
# USUÁRIO (home-manager) — os MEUS DOTFILES, declarados.
#
# Regra desta pasta: aqui NÃO se instala pacote (isso é no system/, lista única).
# Aqui só se CONFIGURA — settings de programa, arquivos de ~/.config, dconf.
# É o que o environment.systemPackages não sabe fazer e o que torna o repo de
# dotfiles do Arch "imortal" e reprodutível.
#
# Cresce por app: home/kitty.nix, home/zsh.nix, home/hypr.nix… e adiciona no
# imports abaixo.
# ═══════════════════════════════════════════════════════════════════════════
{ ... }:

{
  imports = [
    ./git.nix # programs.git → ~/.gitconfig
    ./hypr.nix # ~/.config/hypr/hyprland.conf (ABNT2 + monitores + keybinds)
    ./theme.nix # dark mode (color-scheme prefer-dark + GTK Adwaita-dark)
  ];

  home.username = "v1cferr";
  home.homeDirectory = "/home/v1cferr";

  programs.home-manager.enable = true;

  # Fixado no 1º switch — NUNCA mudar depois.
  home.stateVersion = "26.05";
}
