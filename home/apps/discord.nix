# ═══════════════════════════════════════════════════════════════════════════
# DISCORD (nível-usuário) — cliente oficial de voz/chat.
#
# Regra do home/ (ver home/default.nix): app de USUÁRIO fica aqui. Sem módulo
# programs.* próprio → entra em home.packages. É unfree, ok pelo allowUnfree
# (flake.nix + system/core.nix). O cliente oficial expõe o socket IPC local
# (discord-ipc-0 no $XDG_RUNTIME_DIR) — é o que o Rich Presence do Claude Code
# (home/claude-discord-rpc.nix) precisa pra pintar o card de atividade.
# ═══════════════════════════════════════════════════════════════════════════
{ pkgs, ... }:

{
  home.packages = [ pkgs.discord ];
}
