#!/usr/bin/env bash
# ============================================================================
#  Deploy do greetd + greeter quickshell + coletor de status (/etc + /usr/local)
# ----------------------------------------------------------------------------
#  Instala configs/QML/coletor/units a partir dos dotfiles, cria o usuário
#  `greeter` se faltar, e sobe o coletor de status. NÃO troca o display manager
#  (isso é o switch-to-greetd.sh) — o SDDM continua ativo até você validar.
#
#  Pré-requisito:  sudo pacman -S greetd
#  Uso:            sudo ~/dotfiles/scripts/greetd/deploy.sh
# ============================================================================
set -euo pipefail

if [[ ${EUID} -ne 0 ]]; then
    echo "Este script precisa de root. Rode: sudo $0" >&2
    exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")" && pwd)"
DOTFILES_DIR="$(cd "${SCRIPT_DIR}/../.." && pwd)"
PKG="${DOTFILES_DIR}/greetd"

echo "[deploy] dotfiles: ${DOTFILES_DIR}"

# 0) greetd instalado?
if ! command -v greetd >/dev/null 2>&1; then
    echo "[deploy] AVISO: greetd não está instalado. Rode: sudo pacman -S greetd" >&2
fi

# 1) Usuário greeter (o pacote do greetd costuma criar; garante aqui)
if ! getent passwd greeter >/dev/null; then
    echo "[deploy] criando usuário greeter"
    useradd -r -M -G video,input -s /usr/bin/nologin greeter
fi

# 2) Config do greetd + Hyprland mínimo + QML do greeter
install -Dm0644 "${PKG}/etc/greetd/config.toml"           /etc/greetd/config.toml
install -Dm0644 "${PKG}/etc/greetd/hyprland-greeter.conf" /etc/greetd/hyprland-greeter.conf
# árvore quickshell (conteúdo por cima, sem aninhar)
mkdir -p /etc/greetd/quickshell
cp -rT "${PKG}/etc/greetd/quickshell" /etc/greetd/quickshell
# wallpaper FIXO do monitor primário (o greeter `greeter` não lê /home, que é 710).
# Já sai borrado + escurecido aqui (o compositor do greeter tem blur desligado),
# pra o login ganhar destaque. Ajuste o blur (0xN) / brilho (-N) a gosto.
magick "${DOTFILES_DIR}/wallpapers/Pictures/Wallpapers/arch_hero_flipped.png" \
       -blur 0x24 -brightness-contrast 18x-22 /etc/greetd/wallpaper.png
# o usuário `greeter` precisa LER tudo em /etc/greetd
chmod -R a+rX /etc/greetd
echo "[deploy] /etc/greetd atualizado (incl. wallpaper.png)"

# 3) Coletor root
install -Dm0755 "${SCRIPT_DIR}/collect-status.sh" /usr/local/lib/greetd/collect-status.sh
echo "[deploy] coletor instalado em /usr/local/lib/greetd/"

# 4) systemd unit + tmpfiles
install -Dm0644 "${PKG}/etc/systemd/system/greeter-status.service" \
                /etc/systemd/system/greeter-status.service
install -Dm0644 "${PKG}/etc/tmpfiles.d/greeter-status.conf" \
                /etc/tmpfiles.d/greeter-status.conf
systemd-tmpfiles --create /etc/tmpfiles.d/greeter-status.conf
systemctl daemon-reload
systemctl enable --now greeter-status.service
echo "[deploy] greeter-status.service ativo"

# 5) Sanidade
sleep 4
echo "[deploy] amostra do status.json:"
if [[ -f /run/greeter-status/status.json ]]; then
    jq '{up, total, ip, cpu_temp, gpu_temp, n_containers: (.containers|length), n_gifs: (.gifs|length), n_alerts: (.alerts|length)}' \
       /run/greeter-status/status.json 2>/dev/null || cat /run/greeter-status/status.json
else
    echo "  (status.json ainda não existe — veja: journalctl -u greeter-status -e)"
fi

cat <<'EOF'

[deploy] ok. Próximos passos (SDDM ainda é o DM ativo):
  1) Teste o compositor standalone numa VT livre:
       sudo -u greeter Hyprland --config /etc/greetd/hyprland-greeter.conf
  2) Dry-run do greetd sem desativar o SDDM:
       sudo systemctl start greetd   (depois: chvt 2 pra ver; senha real loga)
       sudo systemctl stop greetd
  3) Cutover definitivo:
       sudo ~/dotfiles/scripts/greetd/switch-to-greetd.sh
  Rollback a qualquer momento:
       sudo ~/dotfiles/scripts/greetd/rollback-to-sddm.sh
EOF
