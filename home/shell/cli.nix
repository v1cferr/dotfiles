# ═══════════════════════════════════════════════════════════════════════════
# CLI MODERNO — toolkit de terminal (reescritas em Rust) + integração com o zsh.
#
# Mora no home/ DE PROPÓSITO: são ferramentas do USUÁRIO, e os módulos programs.*
# já escrevem a integração no zsh (keybinds, hooks, completions) de forma
# versionada — melhor que hooks à mão. (system/ segue dono do nível-sistema.)
# ═══════════════════════════════════════════════════════════════════════════
{ pkgs, lib, ... }:

{
  programs.eza.enable = true; # ls moderno (ícones + git); aliases logo abaixo
  programs.eza.git = true; # coluna de status do git na listagem
  programs.bat.enable = true; # cat com syntax highlight + paginação
  # delta: o "bat do git diff". Realce de sintaxe, número de linha e navegação POR
  # ARQUIVO dentro do pager, em `git diff`/`show`/`log -p`/`blame`. É o de maior impacto
  # desta lista pelo mesmo motivo que o bat: ler diff é a operação mais repetida aqui, e
  # o diff cru do git é monocromático.
  #
  # Preterido o difftastic (diff ESTRUTURAL, compara árvore sintática em vez de linha):
  # ele resolve outro problema — "renomeei/reindentei e o diff explodiu" — e a própria
  # comunidade usa os dois juntos, delta como pager do dia a dia. Entra depois se a
  # necessidade aparecer; instalar os dois agora seria escolher sem ter o problema.
  programs.delta = {
    enable = true;
    enableGitIntegration = true; # NÃO é o default: sem isto o delta fica instalado e ocioso
    options = {
      navigate = true; # `n`/`N` salta entre arquivos dentro do pager (diff grande fica navegável)
      line-numbers = true; # coluna de linha nos dois lados — some a contagem manual no hunk
      # side-by-side DESLIGADO de propósito: os .nix daqui têm bloco de comentário por
      # config (regra 2) e linhas de ~90 colunas. Em 1920x1080, duas colunas quebram
      # tudo e o diff fica PIOR que o de uma coluna. Quando quiser, por invocação:
      # `git diff --side-by-side` (o delta aceita as flags dele no git).
    };
  };
  # zoxide: `cd nome-parcial` salta pra pasta mais usada (aprende ao navegar); `cd` normal
  # (path/../-) segue OK; `cdi` = picker fzf. Fim de digitar o dir inteiro.
  programs.zoxide.enable = true; # instala o binário (o init do zsh vai no fim, abaixo)
  # O HM injeta o init do zoxide-zsh cedo (mkOrder 851) → dispara o falso-positivo do doctor
  # ("initialize at the end"). Fix correto (home-manager#9349): desligar a integração
  # automática e reinjetar o init no FIM do .zshrc (mkOrder 2000, depois de todo mkAfter) —
  # o doctor fica satisfeito de verdade, sem silenciar nada. --cmd cd = o `cd` vira o zoxide.
  programs.zoxide.enableZshIntegration = false;
  programs.zsh.initContent = lib.mkOrder 2000 ''
    eval "$(${pkgs.zoxide}/bin/zoxide init zsh --cmd cd)"
  '';
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

  # Binários sem módulo programs.* dedicado (só o pacote no perfil do usuário).
  # Todos escolhidos por LACUNA REAL, não por lista de "awesome": cada um abaixo é uma
  # ferramenta que faltou num debug concreto desta máquina.
  home.packages = with pkgs; [
    fd # find moderno (rápido, respeita .gitignore) — `fd nix`
    ripgrep # grep moderno (rg): busca de texto recursiva ultrarrápida
    # dust: `du` em árvore, ordenado por tamanho e com barra. Complementa o filelight
    # (GUI, mostra PASTAS) e o czkawka (acha DESCARTÁVEL) no terceiro caso: "o que está
    # ocupando espaço AQUI", por SSH, sem sessão gráfica. Nesta máquina isso importa: a
    # partição é compartilhada com jogos e mídia (506 GiB medidos contra 58 GiB de store).
    dust
    # doggo: `dig` moderno (saída colorida e legível, fala DoH/DoT). Entra porque a
    # ausência DOEU: em 03/08, depurando o DNS dinâmico e o SSH externo, `dig` não
    # existia nesta máquina e a consulta teve de sair por `curl` na API DoH da Cloudflare.
    # Vem junto o `dnsutils` — o `dig` clássico é a língua franca de toda doc e script
    # de rede, e não quero traduzir comando de troubleshooting alheio na hora do aperto.
    doggo
    dnsutils
    # procs: `ps` moderno — colorido, com árvore, e busca por nome sem pipe pro grep.
    # Passei o dia inteiro em `pgrep -a` / `ps -o` caçando Hyprland, hyprlock e sunshine;
    # é exatamente o caso de uso dele.
    procs
    # hyperfine: benchmark de linha de comando com estatística (média, desvio, warmup).
    # Entra porque combina com a cultura deste repo: quase todo comentário aqui começa
    # com "MEDIDO em…". Era o que faltava pra medir CORRETAMENTE em vez de cronometrar
    # uma execução só — `time` mede uma amostra, o hyperfine mede a distribuição.
    hyperfine
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
