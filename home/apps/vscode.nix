# VS Code — pacote (regra: app COM config própria é dono do seu pacote) + os TRÊS JSONs de
# config do usuário (settings/keybindings/mcp) versionados aqui e linkados pro
# ~/.config/Code/User. O resto daquele diretório (globalStorage, History, workspaceStorage,
# sync) é ESTADO e fica de fora de propósito: vai pro restic, não pro git.
#
# POR QUE mkOutOfStoreSymlink e NÃO `programs.vscode.profiles.default.userSettings`: o
# módulo do home-manager GERA o settings.json na store, e store é read-only — o app, que
# escreve nesse arquivo a cada toggle de UI e a cada pull do Settings Sync, passaria a
# falhar em "Unable to write into user settings", e cada ajuste custaria um rebuild. Aqui
# o alvo é o arquivo REAL do repo, mutável: editar aplica NA HORA (o VS Code observa o
# arquivo, sem reload de janela) e um toggle na UI cai como `git diff`. Mesmo contrato do
# hyprland.lua e do quickshell (home/desktop/), pelo mesmo motivo. Sai de graça um terceiro
# ganho: o formato aqui é JSONC, então os COMENTÁRIOS do settings.json sobrevivem — um
# userSettings gerado por Nix seria JSON puro e apagaria todos (o "por que" do
# nix.enableLanguageServer, do modernUI, do externalUriOpeners…).
#
# ⚠️ O QUE FAZ ISSO SER SEGURO, e é o detalhe que decide o desenho: o VS Code escreve o
# settings.json de forma ATÔMICA (grava um .vsctmp e dá rename em cima), e um rename
# TROCARIA o symlink por um arquivo comum — silenciosamente desligando o repo. Mas ele
# checa o alvo antes: `canWriteFileAtomic` faz stat e, se for symbolic link, retorna false
# e cai no write direto, ATRAVÉS do link. VERIFICADO no 1.132.0 desta máquina
# (resources/app/out/vs/code/electron-utility/sharedProcess/sharedProcessMain.js — o
# shared process é justamente onde o Settings Sync roda). Se um dia o VS Code perder essa
# guarda, o sintoma é o symlink virar arquivo comum e o repo parar de receber as mudanças.
#
# O SETTINGS SYNC FICA LIGADO, de propósito: a mesma conta serve a máquina Windows da FAI
# (o settings.json tem `terminal.integrated.profiles.windows` e o UNC host FAIADM6246), e
# desligar o recurso "Settings" congelaria ela pra sempre. Consequência a aceitar: este
# arquivo é um MIRROR versionado, não fonte imutável — mudança feita em outra máquina
# chega aqui como diff, e extensão que escreve na config (o `"//": "Last update at …"` do
# fileNesting é o pior caso) aparece no `git status` — e isso é a FUNÇÃO, não o preço: o
# repo tem que espelhar o que o sistema É, e como o arquivo linkado é o VIVO, `git status`
# virou detector de drift da config do editor. Quem quiser Nix ENFORCING troca os
# `xdg.configFile` abaixo por `programs.vscode.profiles.default.userSettings` e desliga
# "Settings"/"Keybindings" no Sync — é a decisão inversa, não uma correção.
#
# EXTENSÕES continuam sendo INSTALADAS pelo Sync (conta), não declaradas aqui: declará-las
# exigiria o input nix-vscode-extensions (o set do nixpkgs atrasa) e
# `mutableExtensionsDir = false`, que quebra o botão de instalar da UI e o auto-update.
# Mas o repo REGISTRA quais estão instaladas em ./vscode/extensions.txt — espelhar sem
# governar (ver o `extensionsDump` no let). Sem isso, extensão era o único canto do VS Code
# invisível pro git.
#
# NB: a config do nixd que carrega CAMINHO (nixd.options/nixpkgs) mora no
# .vscode/settings.json da raiz deste repo — ela só vale com este flake como workspace.
{ config, pkgs, ... }:

let
  # Caminho do repo CLONADO — não dá pra derivar de dentro da avaliação (o flake é
  # copiado pra store; o que precisamos é o diretório de trabalho). Mesmo literal do
  # home/desktop/hypr.nix. Se o repo não estiver aqui, o symlink fica pendurado e o VS
  # Code não consegue salvar settings — idêntico ao que já acontece com o hyprland.lua.
  repo = "${config.home.homeDirectory}/Projects/GitHub/v1cferr/dotfiles/home/apps/vscode";

  code = pkgs.unstable.vscode.override {
    commandLineArgs = "--password-store=gnome-libsecret";
  };

  # vscode-extensions-dump <repo>: regrava o extensions.txt com o que ESTÁ instalado.
  #
  # POR QUE existe: as extensões continuam sendo instaladas/atualizadas pelo Settings Sync,
  # e sem este arquivo o repo não teria REGISTRO nenhum delas — era o último lugar onde a
  # realidade do VS Code era invisível pro git. Aqui o repo ESPELHA sem GOVERNAR: mesmo
  # contrato que o settings.json, um nível acima. Declará-las (nix-vscode-extensions +
  # mutableExtensionsDir = false) governaria, mas quebra o botão de instalar da UI.
  #
  # O arquivo é só IDs, um por linha, ordenado: `sort` porque a ordem da CLI é arbitrária e
  # sem isso o diff seria embaralhamento em vez de informação. IDs e NÃO `--show-versions`
  # de propósito — versão é decisão do marketplace (auto-update), então churnaria todo dia
  # sem carregar nenhuma decisão minha. Formato puro, sem cabeçalho, pra continuar servindo
  # de entrada: `xargs -n1 code --install-extension < extensions.txt` numa máquina nova.
  extensionsDump = pkgs.writeShellApplication {
    name = "vscode-extensions-dump";
    runtimeInputs = [
      code
      pkgs.coreutils
    ];
    text = ''
      repo="''${1:?uso: vscode-extensions-dump <caminho-do-repo>}"
      out="$repo/home/apps/vscode/extensions.txt"
      if [ ! -d "$(dirname "$out")" ]; then
        echo "vscode-extensions-dump: $(dirname "$out") não existe — caminho de repo errado?" >&2
        exit 1
      fi

      # `|| true` é obrigatório: writeShellApplication roda com `set -euo pipefail`, então
      # um `code` que falhe mataria o script ANTES da guarda abaixo poder explicar por quê.
      list="$(code --list-extensions 2>/dev/null | sort -u || true)"

      # GUARDA: lista vazia é a falha REAL desta CLI (não acha o diretório de extensões), e
      # gravá-la escreveria a mentira "desinstalei tudo" no diff — exatamente o oposto de
      # espelhar. Avisa e sai 0: o `update` que chama isto não deve morrer porque o espelho
      # falhou, mas também não deve mentir em silêncio.
      if [ -z "$list" ]; then
        echo "vscode-extensions-dump: 'code --list-extensions' não devolveu nada — $out NÃO foi reescrito" >&2
        exit 0
      fi

      printf '%s\n' "$list" > "$out"
      echo "vscode-extensions-dump: $(printf '%s\n' "$list" | wc -l) extensões → $out"
    '';
  };
in
{
  home.packages = [
    # Receita do unstable com o SRC trocado pelo tarball oficial (input vscode-tarball +
    # overlayVscodeTarball no flake.nix) — adiante do que o nixpkgs bumpou. A URL do input
    # é versionada, e quem sobe o número é o vscode-bump abaixo, chamado pelo
    # `update`/`upgrade`: na prática, SEMPRE a última stable. Override
    # --password-store=gnome-libsecret: no Hyprland o Electron não autodetecta o backend de
    # secret e mostra "couldn't identify OS keyring".
    code
    # Sobe o input vscode-tarball p/ a última stable (./pkgs). No PATH porque é o alias
    # `update` (home/shell/zsh.nix) que o chama por nome, e não um serviço.
    pkgs.vscode-bump
    # Espelho das extensões instaladas (ver o let). No PATH pelo mesmo motivo do
    # vscode-bump: quem o chama por nome é o alias `update`.
    extensionsDump
  ];

  xdg.configFile."Code/User/settings.json".source =
    config.lib.file.mkOutOfStoreSymlink "${repo}/settings.json";
  xdg.configFile."Code/User/keybindings.json".source =
    config.lib.file.mkOutOfStoreSymlink "${repo}/keybindings.json";
  # mcp.json: quais MCP servers o chat do VS Code enxerga (context7, playwright, markitdown).
  # Entra aqui pelo MESMO motivo dos dois de cima — é config que o app REESCREVE (adicionar
  # server pela galeria grava neste arquivo), então symlink e não `programs.vscode.userMcp`,
  # que existe mas geraria na store.
  #
  # SEGREDO NENHUM aqui, e é isso que torna versionar seguro: a API key do context7 não está
  # no arquivo, e sim como ${input:context7_api_key} — a indireção NATIVA do VS Code, que
  # pergunta o valor em runtime e o guarda no globalStorage (estado → restic). VERIFICAR ISSO
  # DE NOVO ao adicionar server novo: no dia em que um pedir token INLINE, este arquivo deixa
  # de poder ser versionado em claro e o caminho passa a ser sops, não commit.
  xdg.configFile."Code/User/mcp.json".source = config.lib.file.mkOutOfStoreSymlink "${repo}/mcp.json";
}
