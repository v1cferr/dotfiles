# ═══════════════════════════════════════════════════════════════════════════
# CLI MODERNO — toolkit de terminal (reescritas em Rust) + integração com o zsh.
#
# Mora no home/ DE PROPÓSITO: são ferramentas do USUÁRIO, e os módulos programs.*
# já escrevem a integração no zsh (keybinds, hooks, completions) de forma
# versionada — melhor que hooks à mão. (system/ segue dono do nível-sistema.)
# ═══════════════════════════════════════════════════════════════════════════
{ pkgs, ... }:

{
  programs.eza.enable = true; # ls moderno (ícones + git); aliases logo abaixo
  programs.eza.git = true; # coluna de status do git na listagem
  programs.bat.enable = true; # cat com syntax highlight + paginação
  programs.zoxide.enable = true; # `z <pasta>` pula por frequência (hook de cd no zsh)
  programs.fzf.enable = true; # fuzzy finder: Ctrl+R (histórico), Ctrl+T (arquivo), Alt+C (cd)
  programs.yazi.enable = true; # file manager TUI com preview (usa bat; `y` faz cd ao sair)
  programs.tealdeer = {
    enable = true; # `tldr <cmd>` = exemplos práticos (tldr em Rust)
    settings.updates.auto_update = true; # baixa/atualiza o cache do tldr sozinho
  };
  # direnv: ao entrar numa pasta com .envrc, ativa o ambiente (ex.: `use flake`).
  # nix-direnv = cache que deixa o `nix develop` por-pasta rápido (essencial p/ dev/IA).
  programs.direnv = {
    enable = true;
    nix-direnv.enable = true;
  };

  # Binários sem módulo programs.* dedicado (só o pacote no perfil do usuário):
  home.packages = with pkgs; [
    fd # find moderno (rápido, respeita .gitignore) — `fd nix`
    ripgrep # grep moderno (rg): busca de texto recursiva ultrarrápida
  ];

  # Aliases do toolkit (os de shell/sistema seguem em zsh.nix):
  programs.zsh.shellAliases = {
    ls = "eza --icons --group-directories-first"; # ls com ícones, pastas primeiro
    ll = "eza -lah --icons --git --group-directories-first"; # detalhado + ocultos + git
    la = "eza -a --icons --group-directories-first"; # tudo (menos . e ..)
    lt = "eza --tree --icons --level=2"; # árvore (2 níveis)
    cat = "bat --paging=never"; # cat com destaque (age como cat ao redirecionar)
  };
}
