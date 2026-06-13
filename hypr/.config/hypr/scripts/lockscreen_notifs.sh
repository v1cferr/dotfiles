#!/usr/bin/env bash
# ============================================================================
#  Contagem de notificações (swaync) para a tela de bloqueio (hyprlock)
# ----------------------------------------------------------------------------
#  O swaync só expõe a CONTAGEM (não o conteúdo), então mostramos só o número.
#  Sem expor o texto das notificações na tela bloqueada.
# ============================================================================
n=$(swaync-client -c 2>/dev/null || echo 0)
[[ ${n} =~ ^[0-9]+$ ]] || n=0

if (( n > 0 )); then
    s=""; (( n != 1 )) && s="s"
    printf '󰂚  %s não lida%s\n' "${n}" "${s}"
else
    printf '󰂜  sem notificações\n'
fi
