#!/usr/bin/env bash

# Conecta à VPN da UFSCar via NetworkManager/OpenConnect.
# Requisito: networkmanager-vpn-plugin-openconnect

set -u

PROFILE_NAME="${PROFILE_NAME:-VPN_UFSCar_SCL}"

running_kernel="$(uname -r)"

print_tun_error_and_exit() {
  local installed_kernel=""

  if command -v pacman >/dev/null 2>&1; then
    installed_kernel="$(pacman -Q linux 2>/dev/null | awk '{print $2}')"
  fi

  echo "Erro: o suporte TUN do kernel nao esta disponivel para $running_kernel." >&2

  if [ -n "$installed_kernel" ]; then
    echo "Kernel instalado no sistema: $installed_kernel" >&2
  fi

  echo "A VPN da UFSCar via OpenConnect precisa de /dev/net/tun funcional." >&2
  echo "No seu caso, o NetworkManager ja indicou que o modulo tun nao existe para o kernel atual." >&2
  echo "Tente primeiro reiniciar a maquina para carregar o kernel/modulos mais recentes." >&2
  echo "Se continuar falhando apos reboot, reinstale o pacote linux e linux-headers." >&2
  exit 1
}

ensure_tun_ready() {
  if [ -e "/sys/class/misc/tun" ]; then
    return 0
  fi

  if [ -e "/usr/lib/modules/$running_kernel/kernel/drivers/net/tun.ko.zst" ] || \
     [ -e "/usr/lib/modules/$running_kernel/kernel/drivers/net/tun.ko" ]; then
    return 0
  fi

  print_tun_error_and_exit
}

if ! command -v nmcli >/dev/null 2>&1; then
  echo "Erro: nmcli nao encontrado. Instale/ative o NetworkManager." >&2
  exit 1
fi

if ! nmcli -t -f NAME connection show 2>/dev/null | grep -Fxq "$PROFILE_NAME"; then
  echo "Erro: perfil $PROFILE_NAME nao encontrado no NetworkManager." >&2
  echo "Publique o arquivo .nmconnection em /etc/NetworkManager/system-connections e rode 'sudo nmcli connection reload'." >&2
  exit 1
fi

ensure_tun_ready

echo "Conectando à VPN da UFSCar ($PROFILE_NAME)..."
echo "Se a senha nao estiver salva, o nmcli vai solicitar no terminal."

nmcli --ask connection up id "$PROFILE_NAME"
