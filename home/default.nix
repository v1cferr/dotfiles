# ═══════════════════════════════════════════════════════════════════════════
# USUÁRIO (home-manager) — os MEUS DOTFILES, declarados.
#
# Regra desta pasta: o home-manager é dono dos PACOTES E CONFIG DO USUÁRIO. O jeito
# idiomático é `programs.<tool>` (instala + integra shell/config, versionado);
# pacotes sem módulo próprio vão em `home.packages`. O system/ fica só com o
# nível-sistema (serviços, drivers, pacotes de root). Separação de privilégio:
# quebrar o home NÃO derruba o boot — é o que torna estes dotfiles reprodutíveis.
#
# Cresce por app: home/kitty.nix, home/zsh.nix, home/hypr.nix… e adiciona no
# imports abaixo.
# ═══════════════════════════════════════════════════════════════════════════
{ ... }:

{
  imports = [
    ./git.nix # programs.git → ~/.gitconfig
    ./zsh.nix # ~/.zshrc (histórico + autosuggest + syntax highlight + aliases)
    ./cli.nix # toolkit CLI moderno (eza/bat/fzf/zoxide/direnv/yazi/tealdeer) + integração zsh
    ./starship.nix # ~/.config/starship.toml (prompt do zsh)
    ./kitty.nix # ~/.config/kitty/kitty.conf (terminal default do Hyprland)
    ./hypr.nix # ~/.config/hypr/hyprland.conf (ABNT2 + monitores + keybinds)
    ./hyprsunset.nix # filtro de luz azul (serviço systemd + perfis por horário)
    ./waybar.nix # ~/.config/waybar/* (barra básica: workspaces + relógio)
    ./theme.nix # dark mode (color-scheme prefer-dark + GTK Adwaita-dark)
    ./xdg.nix # browser default (Zen) via xdg.mimeApps + $BROWSER
    ./dropbox.nix # serviço de sync do usuário (~/Dropbox: Obsidian + docs)
    ./dolphin.nix # Dolphin: view mode sempre "Detalhes" (via activation)
    ./flameshot.nix # ~/.config/flameshot/flameshot.ini (screenshot; keybind em hypr.nix)
    ./media.nix # visualizadores (Gwenview/Okular) + players (VLC/mpv) + apps padrão
  ];

  home.username = "v1cferr";
  home.homeDirectory = "/home/v1cferr";

  programs.home-manager.enable = true;

  # Fixado no 1º switch — NUNCA mudar depois.
  home.stateVersion = "26.05";
}
