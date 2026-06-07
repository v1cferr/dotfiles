#!/usr/bin/env bash
# ============================================================================
#  Deploy do daemon.json do Docker (/etc/docker)
# ----------------------------------------------------------------------------
#  Instala o daemon.json e recarrega o Docker (SIGHUP). NÃO reinicia o serviço
#  — restart derrubaria todos os containers do homelab. Mudanças de runtime/
#  storage só valem após um restart manual, quando você puder.
#
#  Uso:  sudo ~/dotfiles/scripts/docker/deploy.sh
# ============================================================================
set -euo pipefail
if [[ ${EUID} -ne 0 ]]; then echo "Precisa de root. Rode: sudo $0" >&2; exit 1; fi

SCRIPT_DIR="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")" && pwd)"
DOTFILES_DIR="$(cd "${SCRIPT_DIR}/../.." && pwd)"
SRC="${DOTFILES_DIR}/docker/etc/docker/daemon.json"

# Valida o JSON antes de instalar (daemon.json quebrado impede o Docker de subir)
if command -v python >/dev/null 2>&1; then
    python -m json.tool "${SRC}" >/dev/null || { echo "ERRO: daemon.json inválido (JSON)." >&2; exit 1; }
fi

install -Dm0644 "${SRC}" /etc/docker/daemon.json
echo "[deploy] /etc/docker/daemon.json"

if systemctl reload docker 2>/dev/null; then
    echo "[deploy] docker recarregado (SIGHUP)"
else
    echo "[deploy] reload não aplicou; rode 'sudo systemctl restart docker' quando puder (derruba containers)."
fi
echo "[deploy] OBS: mudanças de runtime/storage só valem após restart do Docker."
