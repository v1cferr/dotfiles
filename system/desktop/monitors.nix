# ═══════════════════════════════════════════════════════════════════════════
# MONITORES = FONTE ÚNICA dos nomes de conector (regra 11). Era o pior caso de
# duplicação do repo: DP-2 em 8 arquivos e HDMI-A-3 em 7, entre Nix, Lua e QML —
# trocar de monitor (ou de cabo) obrigava a caçar string em tudo.
#
# Aqui ficam só os NOMES, que é o que se repetia. Modo/posição/refresh continuam
# em hypr/lua/monitors.lua: aparecem uma vez cada, não são SSOT de nada.
#
# POR QUE EM system/ E NÃO EM home/ (mudou em 04/08/2026): conector é fato de
# HARDWARE, e quem precisa dele não é só o usuário — o Sunshine (serviço de
# sistema) escolhe QUAL monitor capturar por este nome. Módulo de sistema não
# consegue ler opção de home sem citar o nome do usuário e alcançar dentro do
# `home-manager.users.<x>`; o caminho contrário é limpo e idiomático, porque o
# home-manager roda como módulo NixOS e entrega o `osConfig` pronto pra cada
# módulo de home. Então a opção mora aqui e TODO MUNDO lê pra baixo.
#
# Consumidores em system/ leem `config.my.monitors.<n>`; os de home/ leem
# `osConfig.my.monitors.<n>` (mesma mecânica do my.fonts em hardware/fonts.nix).
# Os de HOT-RELOAD (Hyprland/Quickshell) leem os arquivos de dados gerados em
# home/desktop/monitors.nix, porque o Nix não escreve dentro das árvores
# symlinkadas (mesma mecânica da paleta em palette.nix).
# ═══════════════════════════════════════════════════════════════════════════
{ lib, ... }:

{
  options.my.monitors = {
    primary = lib.mkOption {
      type = lib.types.str;
      default = "DP-2";
      description = "Conector do monitor PRINCIPAL (LG ULTRAGEAR) — origem 0x0, workspaces 1–4.";
    };
    secondary = lib.mkOption {
      type = lib.types.str;
      default = "HDMI-A-3";
      description = "Conector do monitor SECUNDÁRIO (TV LG) — à esquerda, workspaces 5–8.";
    };
  };
}
