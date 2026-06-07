#!/usr/bin/env bash
# ============================================================================
#  Deploy do swap (zram + swapfile) para o sistema
# ----------------------------------------------------------------------------
#  Reproduz o esquema de swap em camadas desta máquina:
#    - zram0     : zram-size = ram (~16G), zstd, prioridade 100  -> tier rápido
#    - /swapfile : 16G no disco (NVMe), prioridade 10            -> overflow/OOM
#  Com prioridades diferentes o kernel enche o zram (rápido) primeiro e só cai
#  pro disco quando ele lota — rede de segurança contra OOM.
#
#  O que este script faz (idempotente):
#    1. Copia zram-generator.conf para /etc/systemd/
#    2. Cria o /swapfile (só se não existir) e o formata como swap
#    3. Garante a linha do /swapfile no /etc/fstab — SEM reescrever o fstab,
#       que é machine-specific por causa dos UUIDs de /, /boot, etc.
#    4. Ativa o swapfile e (re)aplica o zram
#
#  Por que um script (e não stow): o stow-sync aponta pro $HOME e não cobre
#  /etc. Os caminhos são resolvidos pela LOCALIZAÇÃO do script, então rodar
#  com sudo NÃO cai na pegadinha do ~ -> /root.
#
#  Pré-requisito: pacote 'zram-generator' instalado (pacman -S zram-generator).
#
#  Uso:  sudo ~/dotfiles/scripts/swap/deploy.sh
# ============================================================================
set -euo pipefail

if [[ ${EUID} -ne 0 ]]; then
    echo "Este script precisa de root. Rode: sudo $0" >&2
    exit 1
fi

# Parâmetros do swapfile (devem casar com a FSTAB_LINE abaixo)
SWAPFILE="/swapfile"
SWAPFILE_SIZE="16G"
SWAPFILE_PRIO=10
FSTAB_LINE="${SWAPFILE} none swap defaults,pri=${SWAPFILE_PRIO} 0 0"

# Raiz do repo: este arquivo fica em <repo>/scripts/swap/deploy.sh
SCRIPT_DIR="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")" && pwd)"
DOTFILES_DIR="$(cd "${SCRIPT_DIR}/../.." && pwd)"
PKG="${DOTFILES_DIR}/swap"

echo "[deploy] dotfiles: ${DOTFILES_DIR}"

# 1) Config do zram-generator
install -Dm0644 "${PKG}/etc/systemd/zram-generator.conf" \
                /etc/systemd/zram-generator.conf
echo "[deploy] /etc/systemd/zram-generator.conf"

# 2) Swapfile no disco (só cria se ainda não existir)
if [[ ! -f "${SWAPFILE}" ]]; then
    echo "[deploy] criando ${SWAPFILE} (${SWAPFILE_SIZE})..."
    # fallocate funciona em ext4. Se o swapon reclamar 'Invalid argument'
    # (FS que não suporta), troque por: dd if=/dev/zero of=${SWAPFILE} bs=1M count=16384
    fallocate -l "${SWAPFILE_SIZE}" "${SWAPFILE}"
    chmod 600 "${SWAPFILE}"
    mkswap "${SWAPFILE}" >/dev/null
    echo "[deploy] ${SWAPFILE} criado e formatado"
else
    echo "[deploy] ${SWAPFILE} já existe — mantendo"
fi

# 3) Linha no /etc/fstab (idempotente; NÃO reescreve o fstab inteiro)
if ! grep -qE "^[[:space:]]*${SWAPFILE}[[:space:]]" /etc/fstab; then
    echo "${FSTAB_LINE}" >> /etc/fstab
    echo "[deploy] entrada do swapfile adicionada ao /etc/fstab"
else
    echo "[deploy] /etc/fstab já tem a entrada do swapfile"
fi

# 4) Ativa o swapfile (se ainda não estiver ativo)
systemctl daemon-reload
if ! swapon --show=NAME --noheadings | grep -qx "${SWAPFILE}"; then
    swapon --priority "${SWAPFILE_PRIO}" "${SWAPFILE}"
    echo "[deploy] swapfile ativado"
else
    echo "[deploy] swapfile já ativo"
fi

# 5) (Re)aplica o zram. O swapoff antes permite o resize; o swapfile acima
#    serve de colchão caso o zram esteja cheio na hora da troca.
if systemctl cat systemd-zram-setup@zram0.service &>/dev/null; then
    swapoff /dev/zram0 2>/dev/null || true
    systemctl restart systemd-zram-setup@zram0.service
    echo "[deploy] zram (re)aplicado"
else
    echo "[deploy] AVISO: serviço systemd-zram-setup@ não encontrado."
    echo "          Instale o pacote e rode de novo (ou reboote): pacman -S zram-generator"
fi

echo "[deploy] ok — swaps ativos:"
swapon --show
echo
free -h
