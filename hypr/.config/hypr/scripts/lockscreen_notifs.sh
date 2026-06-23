#!/usr/bin/env bash
# ============================================================================
#  Contagem de notificações para a tela de bloqueio (hyprlock)
# ----------------------------------------------------------------------------
#  Fonte: serviço de notificações do Quickshell (Notifs.qml), via IPC.
#  Mostramos só o NÚMERO — sem expor o conteúdo na tela bloqueada.
# ============================================================================
n=$(qs ipc call notif count 2>/dev/null || echo 0)
[[ ${n} =~ ^[0-9]+$ ]] || n=0

if (( n > 0 )); then
    s=""; (( n != 1 )) && s="s"
    printf '󰂚  %s não lida%s\n' "${n}" "${s}"
else
    printf '󰂜  sem notificações\n'
fi
