# ═══════════════════════════════════════════════════════════════════════════
# CLAUDE CODE (CLI) — o pacote + as CONTAS SEPARADAS (`claude-fai`, `claude-pessoal`).
#
# O PROBLEMA: são DUAS assinaturas na mesma máquina (FAI/nonprofit e pessoal) e o Claude
# Code guarda LOGIN, MCP e settings num único diretório de config. Rodar as duas no mesmo
# diretório significaria relogar a cada troca. A saída é a variável CLAUDE_CONFIG_DIR: cada
# conta tem o seu diretório, e trocar de conta é trocar a variável.
#
#   ~/.claude-fai      -> FAI / nonprofit (victor.ferreira@fai.ufscar.br) — é o DEFAULT
#   ~/.claude-pessoal  -> pessoal         (dragons10021@outlook.com)
#   ~/.claude          -> NÃO é conta: é o ACERVO comum (projects/), ver abaixo
#
# SÃO DUAS CONTAS E NÃO TRÊS, e isso é uma correção de 11/08/2026: a primeira versão deste
# módulo criava um `~/.claude-fai` VAZIO ao lado do `~/.claude` — que já era a conta da FAI
# (`oauthAccount.emailAddress` = victor.ferreira@…, seat nonprofit premium). Seriam dois
# logins pra mesma assinatura, e a terceira "conta" existiria só por acidente de nomenclatura.
# Agora o `claude` puro CAI NA FAI, porque o CLAUDE_CONFIG_DIR é exportado na sessão (lá
# embaixo). Vale pra tudo que chama o binário sem passar pelos wrappers: extensão do VS Code,
# script, cron. Quem quer a outra conta chama `claude-pessoal`, que sobrepõe a variável.
#
# ⚠️ MAS O ACERVO CONTINUA NO ~/.claude, e essa separação é o miolo do desenho: o `projects/`
# (transcripts + memória, 200 MB e 13 projetos aqui) é da MÁQUINA, não de uma assinatura.
# Deixá-lo no caminho canônico significa que ferramenta de terceiro que procura o padrão
# (`ccusage` e afins) acha sozinha, e que aposentar uma conta um dia não órfã o acervo.
#
# ⚠️ E É POR ISSO QUE O ~/.claude NÃO PODE SER A PASTA DE CONFIG, por mais tentador que
# pareça agora que ele já é FAI: o `.claude.json` (config de projetos/MCP, distinta do
# settings.json) mora na RAIZ do CLAUDE_CONFIG_DIR. Sem a variável ele é o `~/.claude.json`
# do home; com ela apontada pro `~/.claude` viraria `~/.claude/.claude.json`, um SEGUNDO
# arquivo divergente do primeiro. Verificado no 2.1.222 — junto do teste do symlink, o
# `claude mcp add` gravou exatamente ali dentro do CLAUDE_CONFIG_DIR.
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
# O CONTEÚDO dos settings-*.json: o da PESSOAL veio do Arch inteiro; o da FAI é MERGE do
# Arch com o que o `~/.claude` (a mesma conta, viva nesta máquina) tinha em uso — os plugins
# `github`/`atlassian`/`frontend-design`. Pegar só a versão do Arch teria SILENCIOSAMENTE
# desligado três plugins que estavam ligados, que é o tipo de perda que ninguém liga à
# migração dois dias depois.
# Fora isso, morreu na travessia (regra 16): o `permissions.allow` com `mcp__pencil` e os
# dois MCP de usuário que estavam no .claude.json das duas contas — `pencil`
# (/opt/pencil-dev-bin/…, pacote do AUR que não existe aqui) e `atlassian` (por
# `npx mcp-remote`, hoje feito pelo PLUGIN atlassian@claude-plugins-official). Migrar
# permissão pra um MCP que não sobe seria declarar o inexistente.
# SEM comentário DENTRO do JSON, de propósito: o CC reescreve o arquivo inteiro ao salvar
# (não é JSONC como o do VS Code) e apagaria qualquer comentário — o porquê fica aqui.
# E `theme: dark-ansi` não é neutro, é o mais TokyoNight que dá: manda a TUI usar as 16
# cores ANSI do terminal, que no kitty deste repo JÁ são a paleta do my.theme (regra 9).
#
# MCP POR CONTA (14/08/2026) — o Azure MCP Server (`pkgs.azure-mcp`, empacotado em
# ./pkgs) entra SÓ na FAI, porque a nuvem é a do trabalho: a conta pessoal não tem o que
# fazer com ela, e 68 tools a mais custam contexto em toda sessão. Por isso `mcp` virou
# campo do `profiles`: a conta que não declara nada não ganha flag nenhuma.
#
# O ENTREGADOR é a flag `--mcp-config` do wrapper, e as três alternativas foram
# DESCARTADAS por motivo concreto:
#   • `.mcp.json` na raiz do repo (o que hoje serve os dois MCP da Cloudflare) — é escopo
#     de PROJETO: o Azure só existiria rodando `claude` dentro do dotfiles, que é onde a
#     gente NUNCA vai mexer no Azure.
#   • user scope no `.claude.json` — é estado do app, o CC reescreve o arquivo inteiro;
#     declarar ali é a receita de drift da regra 14.
#   • `/etc/claude-code/managed-mcp.json` — parece o lugar certo (é irmão do
#     managed-settings.json que já usamos pros hooks), e é ARMADILHA: quem deploya esse
#     arquivo passa a ter controle EXCLUSIVO, e o CC deixa de carregar TODO o resto —
#     inclusive os MCP dos plugins `github` e `atlassian`, que estão em uso. Ganharia o
#     Azure e perderia dois.
#
# ⚠️ E É POR ISSO QUE O `claude` PURO VIROU WRAPPER TAMBÉM (antes era o binário cru do
# pacote): `claude` puro É a conta da FAI (o CLAUDE_CONFIG_DIR aqui embaixo), então sem
# isso o MCP do Azure só apareceria em quem lembrasse de digitar `claude-fai` — e nunca
# na extensão do VS Code, que chama o binário do PATH. O pacote `claude` NÃO entra mais
# em `home.packages` (dois `bin/claude` colidiriam na ativação); ele só é referenciado
# pelo `lib.getExe` dentro dos wrappers.
#
# O QUE NÃO ENTRA AQUI:
#   • `.credentials.json` (token OAuth de cada conta) — segredo E estado: nunca versionado,
#     nunca declarado. Conta nova = um `/login` (regras 6 e 12).
#   • `.claude.json`, `history.jsonl`, `sessions/`, `plugins/`, `cache/` — estado do app,
#     escrito em runtime; vai pro restic, não pro git (regra 6).
#   • os HOOKS do ciclo de vida (Discord Rich Presence) — eles moram no
#     /etc/claude-code/managed-settings.json (system/services/claude-code.nix), porque
#     precisam ser IMPOSTOS e não sobrescrevíveis. O caminho é FIXO em /etc, fora do
#     CLAUDE_CONFIG_DIR, então valem nas duas contas de uma vez.
#   • o `projects/` do ~/.claude — é o ALVO dos symlinks, não um artefato declarado. O Nix é
#     dono dos links; o conteúdo é do app (regra 14).
#   • o RESTO do ~/.claude (history.jsonl, settings.json, sessions/, shell-snapshots/…) —
#     sobra de quando ele era conta, e sobra é LEGADO: o que valia a pena foi copiado pro
#     ~/.claude-fai na virada e o resto se poda depois que a conta nova provar que anda
#     (está anotado em docs/pendencias.md — regra 16).
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

  # Azure MCP Server: deixa o CC criar/ler/alterar recurso do Azure por tool em vez de a
  # gente clicar no portal. `--mode namespace` (o default do azmcp) expõe UMA tool por
  # serviço — 68 no total; `all` explodiria pra centenas e `single` deixaria uma só, com
  # um salto de roteamento a mais. Pra enxugar, `--namespace storage --namespace keyvault…`
  # limita aos serviços citados. Auth NÃO mora aqui (regra 12): é o device code do próprio
  # azmcp, guardado no keyring — ver o comentário do pkgs/azure-mcp.nix.
  azureMcp = pkgs.writeText "mcp-azure.json" (
    builtins.toJSON {
      mcpServers.azure = {
        type = "stdio";
        command = lib.getExe pkgs.azure-mcp;
        args = [
          "server"
          "start"
          "--mode"
          "namespace"
        ];
        # Telemetria da Microsoft desligada: é máquina pessoal, e o servidor roda local.
        env.AZURE_MCP_COLLECT_TELEMETRY = "false";
      };
    }
  );

  # SSOT das contas (regra 11): esta atriz gera os wrappers, o menu do claude-pick, os
  # symlinks de settings.json, os de projects/ e quais MCP cada conta enxerga. Conta nova =
  # uma entrada aqui + o settings-<nome>.json no ./claude — nada mais muda.
  profiles = {
    fai = {
      dir = ".claude-fai";
      label = "FAI      (victor.ferreira@fai.ufscar.br)";
      mcp = [ azureMcp ]; # a nuvem do trabalho é só desta conta
    };
    pessoal = {
      dir = ".claude-pessoal";
      label = "Pessoal  (dragons10021@outlook.com)";
      mcp = [ ];
    };
  };

  # Qual conta o `claude` PURO é. Sai daqui o CLAUDE_CONFIG_DIR da sessão E o wrapper
  # `claude` — antes o ".claude-fai" estava escrito duas vezes, agora sai do profiles.
  defaultProfile = "fai";
  defaultDir = "${config.home.homeDirectory}/${profiles.${defaultProfile}.dir}";

  # O mesmo binário com o CLAUDE_CONFIG_DIR trocado e os MCP da conta. `exec` = o wrapper
  # sai da árvore de processos e sobra o claude real (sinais e TTY da TUI chegam direto).
  # "$@" repassa argumentos, então `--resume`, `-p …` e `doctor` funcionam igual ao cru.
  #
  # ⚠️ O `--` NÃO É ENFEITE, e a regra de quando usá-lo é o oposto da intuição — MEDIDO no
  # 2.1.222: `--mcp-config` é VARIÁDICO (aceita N arquivos), então ele engole tudo que vier
  # depois enquanto não achar um token começando com "-". Sem terminador,
  # `claude-fai mcp list` morre com "MCP config file not found: …/mcp" (ele leu `mcp` e
  # `list` como mais dois arquivos de config). Mas o `--` resolve SÓ o caso do subcomando e
  # ESTRAGA o da flag: com ele, `claude-fai --version` abre uma SESSÃO com "--version" de
  # prompt, em vez de imprimir a versão. Daí o `case` — quem começa com "-" (ou nada, a TUI
  # interativa) vai sem terminador; palavra solta (subcomando ou prompt) vai com.
  mkLauncher =
    binName: p:
    pkgs.writeShellApplication {
      name = binName;
      text = ''
        export CLAUDE_CONFIG_DIR="$HOME/${p.dir}"
      ''
      + (
        if p.mcp == [ ] then
          ''
            exec ${lib.getExe claude} "$@"
          ''
        else
          let
            flags = lib.concatMapStringsSep " " (f: "--mcp-config ${f}") p.mcp;
          in
          ''
            case "''${1-}" in
              -* | "") exec ${lib.getExe claude} ${flags} "$@" ;;
              *)       exec ${lib.getExe claude} ${flags} -- "$@" ;;
            esac
          ''
      );
    };

  # `claude-fai` / `claude-pessoal`, e o `claude` puro apontando pra conta default.
  launchers = lib.mapAttrs (name: mkLauncher "claude-${name}") profiles;
  claudeDefault = mkLauncher "claude" profiles.${defaultProfile};

  # Linhas "<caminho do wrapper>\tlabel" pro fzf: ele FILTRA por tudo e MOSTRA só o campo
  # 2+ (--with-nth), então o caminho viaja junto sem aparecer na tela. Carregar o WRAPPER
  # (e não o diretório, como era antes) é o que faz o pick herdar de graça o
  # CLAUDE_CONFIG_DIR e os MCP da conta, em vez de repetir essa lógica aqui dentro.
  menu = lib.concatMapStringsSep "\n" (
    name: "${lib.getExe launchers.${name}}\t${profiles.${name}.label}"
  ) (lib.attrNames profiles);

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
      # Atribuição separada do exec: `X="$(cmd)"` na mesma linha mascara o exit code
      # (SC2155), e o shellcheck do writeShellApplication REPROVA o build por isso.
      bin=$(printf '%s' "$sel" | cut -f1)
      exec "$bin" "$@"
    '';
  };
in
{
  home.packages = [
    # O pacote mora AQUI e não no home/packages.nix: app com config própria é dono do seu
    # pacote (mesma regra do vscode.nix). `unstable` porque o CC evolui rápido — a stable
    # do NixOS congelaria meses de features. Ele entra EMBRULHADO (`claudeDefault`), nunca
    # cru: ver o ⚠️ do cabeçalho sobre o `claude` puro ter virado wrapper.
    claudeDefault
    # ccusage: tokens/custo do bloco de 5h e por sessão (os aliases claude-usage* abaixo).
    # Só existe no unstable. Lê o acervo ~/.claude/projects — que é o COMPARTILHADO, então
    # a conta some do relatório: o número é o da máquina, não o da assinatura.
    pkgs.unstable.ccusage
    pick
  ]
  ++ lib.attrValues launchers;

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

  # O `claude` PURO vira a FAI. Sem isto ele cairia no ~/.claude, que hoje é só o acervo —
  # e o CC criaria ali um `.claude.json` paralelo e pediria um terceiro login (ver o ⚠️ do
  # cabeçalho). Vale pra todo mundo que chama o binário sem passar pelos wrappers: extensão
  # do VS Code, script, cron.
  #
  # ⚠️ SÓ VALE DEPOIS DE RELOGAR NA SESSÃO GRÁFICA — terminal novo NÃO basta, e isso foi
  # MEDIDO em 11/08/2026, com o switch já aplicado e a variável ainda vazia num zsh
  # recém-aberto. O mecanismo: isto é gravado no `hm-session-vars.sh`, que o `~/.zshenv`
  # carrega, e o arquivo se autoprotege com `__HM_SESS_VARS_SOURCED=1` pra não recarregar em
  # subshell. A marca é EXPORTADA, então todo filho da sessão gráfica já nasce com ela e
  # pula o carregamento inteiro — variável nova não chega em terminal novo, só em sessão
  # nova. Provado com `env -u __HM_SESS_VARS_SOURCED zsh -i -c`: sem a marca, ela aparece.
  # Mesma família da pegadinha do NH_FLAKE (home/shell/zsh.nix, 03/08).
  #
  # TENTEI `programs.zsh.sessionVariables` como segunda camada e NÃO ADIANTA: cai no MESMO
  # ~/.zshenv e traz guard próprio (`__HM_ZSH_SESS_VARS_SOURCED`), que a sessão também já
  # exporta — mesmo o repo não usando a opção em canto nenhum, porque o home-manager emite o
  # bloco sempre, só vazio. Eram duas camadas com a mesma falha; ficou uma, honesta.
  #
  # ATÉ O RELOGIN quem entrega a conta certa é o WRAPPER (`claude-fai`), que exporta a
  # variável ele mesmo. É o argumento mais forte a favor de o wrapper existir: ele não
  # depende de o ambiente da sessão ter sido reconstruído.
  home.sessionVariables.CLAUDE_CONFIG_DIR = defaultDir;

  programs.zsh.shellAliases = {
    # Monitor ao vivo do bloco atual (tokens/custo), 1 refresh por segundo.
    claude-usage = "watch -n 1 -c ccusage blocks --active --color";
    # Tabela por sessão: quanto cada conversa consumiu.
    claude-usage-sessions = "ccusage session --color";
  };
}
