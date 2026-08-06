# VS Code — pacote (regra: app COM config própria é dono do seu pacote) + os DOIS JSONs
# do usuário (settings/keybindings) versionados aqui e linkados pro ~/.config/Code/User.
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
# fileNesting é o pior caso) gera ruído no `git status`. Quem quiser Nix ENFORCING troca
# estas duas linhas por `programs.vscode.profiles.default.userSettings` e desliga
# "Settings"/"Keybindings" no Sync — é a decisão inversa, não uma correção.
#
# EXTENSÕES continuam 100% no Sync (conta), NÃO aqui: declará-las exigiria o input
# nix-vscode-extensions (o set do nixpkgs atrasa) e `mutableExtensionsDir = false`, que
# quebra o botão de instalar da UI e o auto-update. Custo alto, ganho zero com um host.
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
in
{
  home.packages = [
    # Receita do unstable com o SRC trocado pelo tarball oficial (input vscode-tarball +
    # overlayVscodeTarball no flake.nix) — adiante do que o nixpkgs bumpou. A URL do input
    # é versionada, e quem sobe o número é o vscode-bump abaixo, chamado pelo
    # `update`/`upgrade`: na prática, SEMPRE a última stable. Override
    # --password-store=gnome-libsecret: no Hyprland o Electron não autodetecta o backend de
    # secret e mostra "couldn't identify OS keyring".
    (pkgs.unstable.vscode.override { commandLineArgs = "--password-store=gnome-libsecret"; })
    # Sobe o input vscode-tarball p/ a última stable (./pkgs). No PATH porque é o alias
    # `update` (home/shell/zsh.nix) que o chama por nome, e não um serviço.
    pkgs.vscode-bump
  ];

  xdg.configFile."Code/User/settings.json".source =
    config.lib.file.mkOutOfStoreSymlink "${repo}/settings.json";
  xdg.configFile."Code/User/keybindings.json".source =
    config.lib.file.mkOutOfStoreSymlink "${repo}/keybindings.json";
}
