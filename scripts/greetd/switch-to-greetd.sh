#!/usr/bin/env bash
# ============================================================================
#  Cutover: SDDM -> greetd
# ----------------------------------------------------------------------------
#  Desabilita o SDDM e habilita o greetd. NÃO remove o SDDM (rede de segurança).
#  Mantenha uma sessão SSH aberta antes de rodar. Aplica no próximo boot.
#
#  Uso:  sudo ~/dotfiles/scripts/greetd/switch-to-greetd.sh
# ============================================================================
set -euo pipefail

if [[ ${EUID} -ne 0 ]]; then
    echo "Precisa de root. Rode: sudo $0" >&2
    exit 1
fi

if ! command -v greetd >/dev/null 2>&1; then
    echo "greetd não instalado. Rode: sudo pacman -S greetd" >&2
    exit 1
fi
if [[ ! -f /run/greeter-status/status.json ]]; then
    echo "AVISO: greeter-status.service não parece estar rodando (sem status.json)." >&2
    echo "       Rode o deploy.sh antes. Continuar mesmo assim? [y/N]"
    read -r ans; [[ "${ans}" == "y" || "${ans}" == "Y" ]] || exit 1
fi

echo "[switch] desabilitando sddm e habilitando greetd…"
systemctl disable sddm.service
systemctl enable greetd.service

echo "[switch] display-manager.service ->"
readlink -f /etc/systemd/system/display-manager.service 2>/dev/null || true

cat <<'EOF'

[switch] feito. Reinicie pra aplicar:  sudo reboot
  Se o greeter não subir, recupere via SSH/console (chvt 3) e rode:
      sudo ~/dotfiles/scripts/greetd/rollback-to-sddm.sh && sudo reboot
EOF
