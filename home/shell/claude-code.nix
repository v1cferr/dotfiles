# ═══════════════════════════════════════════════════════════════════════════
# CLAUDE CODE (CLI) — o pacote + as CONTAS SEPARADAS (`claude-fai`, `claude-pessoal`).
#
# O PROBLEMA: são três assinaturas na mesma máquina (a default + FAI/nonprofit + pessoal)
# e o Claude Code guarda LOGIN, MCP e settings num único diretório de config. Rodar as três
# no mesmo diretório significaria relogar a cada troca de conta. A saída é a variável
# CLAUDE_CONFIG_DIR: cada conta tem o seu diretório, e trocar de conta é trocar a variável.
#
#   ~/.claude          -> default (a que o `claude` puro usa; NÃO é gerenciada aqui, ver abaixo)
#   ~/.claude-fai      -> FAI / nonprofit (victor.ferreira@fai.ufscar.br)
#   ~/.claude-pessoal  -> pessoal         (dragons10021@outlook.com)
#
# ⚠️ NÃO apontar CLAUDE_CONFIG_DIR pro ~/.claude pra "reaproveitar" a conta default: o
# `.claude.json` (a config de projetos/MCP, distinta do settings.json) mora na RAIZ do
# CLAUDE_CONFIG_DIR — no default ele é o ~/.claude.json do home, e com a variável apontada
# pro ~/.claude ele viraria ~/.claude/.claude.json, um SEGUNDO arquivo divergente. Por isso
# cada conta extra tem pasta própria e a default fica intocada. (Verificado no 2.1.222.)
#
# WRAPPER e não ALIAS (era alias no Arch, home/.zshrc): alias só existe em zsh INTERATIVO —
# `claude-fai` não funcionava por SSH não-interativo, dentro de script, em task do VS Code
# nem em keybind do Hyprland. O wrapper é um binário no PATH e a regra 7 pede a lógica no
# build. Sai de graça a versão do claude ficar FIXA no wrapper (mesmo store path do pacote),
# em vez de depender de qual `claude` o PATH resolve primeiro — o que importa aqui porque
# esta máquina tem uma instalação nativa órfã em ~/.local/bin (o `claude doctor` reclama dela).
#
# HISTÓRICO E MEMÓRIA SÃO COMPARTILHADOS, de propósito: o `projects/` de cada conta é
# symlink pro acervo canônico ~/.claude/projects, que é onde ficam os transcripts E a
# memória por projeto (…/projects/<slug>/memory/). Assim qualquer conta resume as mesmas
# conversas e lê as mesmas memórias. No Arch isso era a função `_claude_share_projects` do
# .zshrc, imperativa e rodando a cada abertura de shell; aqui é o symlink declarado abaixo
# (regra 3). Preço a saber: `ccusage` não separa custo por conta, porque lê o acervo comum.
#
# SETTINGS.JSON VERSIONADO NO REPO (mkOutOfStoreSymlink), mesmo contrato do VS Code
# (home/apps/vscode.nix) e do hyprland.lua: o alvo é o arquivo REAL do repo, mutável, então
# o `/config` da TUI continua funcionando e cada ajuste cai como `git diff` em vez de drift
# invisível (regra 16). Um `programs.*` gerando na store NÃO serve — store é read-only e o CC
# escreve nesse arquivo.
#
# ⚠️ O QUE FAZ ISSO SER SEGURO — MEDIDO em 11/08/2026 no 2.1.222, e é o detalhe que decide o
# desenho: o CC escreve o settings.json de forma ATÔMICA (tmp + rename), e rename em cima de
# um symlink TROCARIA o link por arquivo comum, desligando o repo em silêncio. Mas ele
# resolve o realpath ANTES: o link sobreviveu intacto e quem trocou de inode foi o arquivo
# ALVO (593793 → 593844, via `claude auto-mode reset`) — ou seja, a escrita chega no repo.
# Se um dia o CC perder essa guarda, o sintoma é ~/.claude-fai/settings.json deixar de ser
# symlink e o repo parar de receber as mudanças.
#
# O CONTEÚDO dos dois settings-*.json veio do Arch (…/.claude-{fai,pessoal}/settings.json),
# menos o que morreu na travessia (regra 16): o `permissions.allow` com `mcp__pencil` e os
# dois MCP de usuário que estavam no .claude.json das duas contas — `pencil`
# (/opt/pencil-dev-bin/…, pacote do AUR que não existe aqui) e `atlassian` (por
# `npx mcp-remote`, hoje feito pelo PLUGIN atlassian@claude-plugins-official). Migrar
# permissão pra um MCP que não sobe seria declarar o inexistente.
# SEM comentário DENTRO do JSON, de propósito: o CC reescreve o arquivo inteiro ao salvar
# (não é JSONC como o do VS Code) e apagaria qualquer comentário — o porquê fica aqui.
# E `theme: dark-ansi` não é neutro, é o mais TokyoNight que dá: manda a TUI usar as 16
# cores ANSI do terminal, que no kitty deste repo JÁ são a paleta do my.theme (regra 9).
#
# O QUE NÃO ENTRA AQUI:
#   • `.credentials.json` (token OAuth de cada conta) — segredo E estado: nunca versionado,
#     nunca declarado. Conta nova = um `/login` (regras 6 e 12).
#   • `.claude.json`, `history.jsonl`, `sessions/`, `plugins/`, `cache/` — estado do app,
#     escrito em runtime; vai pro restic, não pro git (regra 6).
#   • os HOOKS do ciclo de vida (Discord Rich Presence) — eles moram no
#     /etc/claude-code/managed-settings.json (system/services/claude-code.nix), porque
#     precisam ser IMPOSTOS e não sobrescrevíveis. O caminho é FIXO em /etc, fora do
#     CLAUDE_CONFIG_DIR, então valem nas três contas de uma vez.
#   • o ~/.claude (conta default) — segue sem gerência do Nix, do jeito que estava. Não é
#     esquecimento: linkar o settings.json DELE pro repo é a mesma decisão de cima aplicada
#     à conta que este repo usa no dia a dia, e vale fazer — só não foi feito junto pra não
#     misturar com a entrada das duas contas novas.
# ═══════════════════════════════════════════════════════════════════════════
{
  config,
  lib,
  pkgs,
  ...
}:

let
  claude = pkgs.unstable.claude-code;

  # Caminho do repo CLONADO — mesmo literal (e mesmo motivo) do home/apps/vscode.nix: não
  # dá pra derivar da avaliação, o flake é copiado pra store. Repo fora daqui = symlink
  # pendurado e o CC sem conseguir salvar settings.
  repo = "${config.home.homeDirectory}/Projects/GitHub/v1cferr/dotfiles/home/shell/claude";

  # SSOT das contas extras (regra 11): esta atriz gera os wrappers, o menu do claude-pick,
  # os symlinks de settings.json e os de projects/. Conta nova = uma entrada aqui + o
  # settings-<nome>.json no ./claude — nada mais muda.
  profiles = {
    fai = {
      dir = ".claude-fai";
      label = "FAI      (victor.ferreira@fai.ufscar.br)";
    };
    pessoal = {
      dir = ".claude-pessoal";
      label = "Pessoal  (dragons10021@outlook.com)";
    };
  };

  # `claude-fai` / `claude-pessoal`: o mesmo binário com o CLAUDE_CONFIG_DIR trocado.
  # `exec` = o wrapper sai da árvore de processos e sobra o claude real (sinais e TTY da TUI
  # chegam direto). "$@" repassa argumentos, então `claude-fai --resume`, `claude-fai -p …`
  # e `claude-fai doctor` funcionam igual ao `claude`.
  launcher =
    name: p:
    pkgs.writeShellApplication {
      name = "claude-${name}";
      text = ''
        export CLAUDE_CONFIG_DIR="$HOME/${p.dir}"
        exec ${lib.getExe claude} "$@"
      '';
    };

  # Linhas "<dir>\tlabel" pro fzf: ele FILTRA por tudo e MOSTRA só o campo 2+ (--with-nth),
  # então o diretório viaja junto sem aparecer na tela — evita ter que traduzir o rótulo
  # escolhido de volta pra caminho com um `case` duplicando o que já está no `profiles`.
  menu = lib.concatMapStringsSep "\n" (p: "${p.dir}\t${p.label}") (lib.attrValues profiles);

  # Seletor interativo: escolhe a conta na hora. `claude-pick [args…]`.
  pick = pkgs.writeShellApplication {
    name = "claude-pick";
    runtimeInputs = [
      pkgs.fzf
      pkgs.coreutils
    ];
    text = ''
      # `|| exit 0`: Esc/Ctrl-C no fzf sai com 130 e o `set -e` mataria o script com erro —
      # cancelar o menu é uso normal, não falha.
      sel=$(printf '%s\n' ${lib.escapeShellArg menu} \
        | fzf --prompt='Conta Claude > ' --height=25% --reverse \
              --delimiter='\t' --with-nth=2..) || exit 0
      # Atribuição separada do export: `export X="$(cmd)"` mascara o exit code do comando
      # (SC2155), e o shellcheck do writeShellApplication REPROVA o build por isso.
      dir=$(printf '%s' "$sel" | cut -f1)
      export CLAUDE_CONFIG_DIR="$HOME/$dir"
      exec ${lib.getExe claude} "$@"
    '';
  };
in
{
  home.packages = [
    # O pacote mora AQUI e não no home/packages.nix: app com config própria é dono do seu
    # pacote (mesma regra do vscode.nix). `unstable` porque o CC evolui rápido — a stable
    # do NixOS congelaria meses de features.
    claude
    # ccusage: tokens/custo do bloco de 5h e por sessão (os aliases claude-usage* abaixo).
    # Só existe no unstable. Lê o acervo ~/.claude/projects — que é o COMPARTILHADO, então
    # a conta some do relatório: o número é o da máquina, não o da assinatura.
    pkgs.unstable.ccusage
    pick
  ]
  ++ lib.mapAttrsToList launcher profiles;

  # Por conta: o settings.json linkado pro repo (config, versionada) e o projects/ apontado
  # pro acervo comum (estado, compartilhado). O `home.file` é o DONO dos dois symlinks; quem
  # escreve DENTRO deles é o app — regra 14 satisfeita, porque os alvos não são da store.
  #
  # ⚠️ A ativação FALHA se ~/.claude-<conta>/projects já existir como diretório de verdade
  # ("existing file would be clobbered"): ao restaurar backup de conta, restaurar o
  # CONTEÚDO pra ~/.claude/projects, nunca a pasta da conta.
  home.file = lib.mkMerge (
    lib.mapAttrsToList (name: p: {
      "${p.dir}/settings.json".source =
        config.lib.file.mkOutOfStoreSymlink "${repo}/settings-${name}.json";
      "${p.dir}/projects".source =
        config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/.claude/projects";
    }) profiles
  );

  programs.zsh.shellAliases = {
    # Monitor ao vivo do bloco atual (tokens/custo), 1 refresh por segundo.
    claude-usage = "watch -n 1 -c ccusage blocks --active --color";
    # Tabela por sessão: quanto cada conversa consumiu.
    claude-usage-sessions = "ccusage session --color";
  };
}
