# ═══════════════════════════════════════════════════════════════════════════
# USUÁRIO (home-manager) — os MEUS DOTFILES, declarados.
#
# Regra desta pasta: o home-manager é dono dos PACOTES E CONFIG DO USUÁRIO. O jeito
# idiomático é `programs.<tool>` (instala + integra shell/config, versionado);
# pacotes sem módulo próprio vão em `home.packages`. O system/ fica só com o
# nível-sistema (serviços, drivers, pacotes de root). Separação de privilégio:
# quebrar o home NÃO derruba o boot — é o que torna estes dotfiles reprodutíveis.
#
# Organizado por CATEGORIA (subpasta com seu próprio default.nix que importa os
# módulos dela) — assim o topo não vira um monte de arquivos soltos. Novo módulo?
# cria home/<categoria>/<app>.nix e adiciona 1 linha no default.nix da categoria.
# ═══════════════════════════════════════════════════════════════════════════
{ ... }:

{
  imports = [
    ./shell # terminal, shell e dev-cli (zsh/starship/cli/kitty/git)
    ./desktop # Hyprland + Wayland + aparência (hypr/waybar/lockscreen/theme/xdg…)
    ./apps # apps GUI de usuário (discord/dropbox/media/dolphin/flameshot/mangohud)
    ./services # serviços/timers do usuário (cs2-saves-backup, claude-discord-rpc)
  ];

  home.username = "v1cferr";
  home.homeDirectory = "/home/v1cferr";

  programs.home-manager.enable = true;

  # Fixado no 1º switch — NUNCA mudar depois.
  home.stateVersion = "26.05";
}
