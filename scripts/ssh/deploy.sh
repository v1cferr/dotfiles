#!/usr/bin/env bash
# ============================================================================
#  Deploy do SSH server (drop-in /etc/ssh/sshd_config.d) para o sistema
# ----------------------------------------------------------------------------
#  Instala o 99-custom.conf (porta 2222 + hardening), VALIDA com `sshd -t`
#  ANTES de aplicar e faz RELOAD (não restart) — preserva sessões ativas e
#  evita lockout no SSH externo se a config estiver inválida.
#
#  Uso:  sudo ~/dotfiles/scripts/ssh/deploy.sh
# ============================================================================
set -euo pipefail
if [[ ${EUID} -ne 0 ]]; then echo "Precisa de root. Rode: sudo $0" >&2; exit 1; fi

SCRIPT_DIR="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")" && pwd)"
DOTFILES_DIR="$(cd "${SCRIPT_DIR}/../.." && pwd)"
PKG="${DOTFILES_DIR}/ssh"

install -Dm0644 "${PKG}/etc/ssh/sshd_config.d/99-custom.conf" \
                /etc/ssh/sshd_config.d/99-custom.conf
echo "[deploy] /etc/ssh/sshd_config.d/99-custom.conf"

# Valida ANTES de recarregar — config inválida = risco de lockout no SSH externo
if sshd -t; then
    systemctl reload sshd
    echo "[deploy] sshd recarregado (sessões ativas preservadas)"
else
    echo "ERRO: 'sshd -t' falhou — NÃO recarreguei. Corrija a config antes." >&2
    exit 1
fi
