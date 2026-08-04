# fastfetch — resumo do sistema (`programs.fastfetch` instala o pacote E escreve
# ~/.config/fastfetch/config.jsonc; app+config no home, regra 4).
#
# Por que existe config em vez de só o pacote: no terminal integrado do VS Code a
# linha "Terminal:" vinha com a linha de comando INTEIRA do Electron (~1.5 KB de
# `--standard-schemes=...`, `--field-trial-handle=...`), estourando o layout. Causa:
# o fastfetch monta o nome do terminal a partir do basename do /proc/<pid>/cmdline
# COMPLETO do processo pai — e o pty host do VS Code tem `--user-data-dir=.../Code`
# no meio, então o basename pega tudo depois da última "/" ("Code --standard-schemes…").
# Fix: formatar o módulo terminal com {process-name} (vem do comm, sempre limpo)
# em vez do {pretty-name} default. Dá "code 1.131.0", "kitty 0.44.1" etc.
#
# A lista de módulos é a ESTRUTURA DEFAULT do fastfetch (`fastfetch --print-structure`,
# minúscula) repetida na íntegra: só assim se troca o formato de UM módulo — não existe
# override pontual, quem declara `modules` declara todos. Módulos que não se aplicam a
# esta máquina (battery/poweradapter/host/de) somem sozinhos, ficam aqui p/ portabilidade.
{ pkgs, ... }:

{
  programs.fastfetch = {
    enable = true;
    package = pkgs.unstable.fastfetch; # bleeding-edge: hardware/versões novas

    settings.modules = [
      "title"
      "separator"
      "os"
      "host"
      "kernel"
      "uptime"
      "packages"
      "shell"
      "display"
      "de"
      "wm"
      "wmtheme"
      "theme"
      "icons"
      "font"
      "cursor"
      {
        # {?version}…{?} = bloco condicional: sem versão detectada, não sobra espaço solto.
        type = "terminal";
        format = "{process-name}{?version} {version}{?}";
      }
      "terminalfont"
      "cpu"
      "gpu"
      "memory"
      "swap"
      "disk"
      "localip"
      "battery"
      "poweradapter"
      "locale"
      "break"
      "colors"
    ];
  };
}
