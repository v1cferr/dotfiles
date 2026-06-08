#!/usr/bin/env bash
# ============================================================================
#  Backup CRIPTOGRAFADO dos segredos (NÃO versionado no git)
# ----------------------------------------------------------------------------
#  Empacota o que NÃO vai pro repo (chaves SSH/GPG, .env, tokens) num tarball
#  criptografado com GPG simétrico (passphrase). A saída fica na raiz do
#  dotfiles e é gitignorada — depois mova pro Dropbox / HDD de Backup.
#
#  ⚠️ Guarde a PASSPHRASE no seu gerenciador de senhas. Sem ela, o backup é
#     inútil. E mantenha pelo menos uma cópia FORA deste disco (a graça é DR).
#
#  Restaurar:  gpg -d secrets-backup-XXXX.tar.gz.gpg | tar -xzf - -C ~
#
#  Uso:  ~/dotfiles/scripts/backup-secrets.sh
# ============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")" && pwd)"
DOTFILES_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
OUT="${DOTFILES_DIR}/secrets-backup-$(date +%Y%m%d-%H%M%S).tar.gz.gpg"

# Segredos a incluir (caminhos relativos a $HOME). Edite à vontade.
SECRETS=(
    .ssh
    .gnupg
    .config/gh/hosts.yml
    .config/rustdesk
    .local/share/atuin/key
    dotfiles/.env
    Projects/Local/jellyfin/.env
)

# Mantém só os que existem
exist=()
for s in "${SECRETS[@]}"; do [[ -e "${HOME}/${s}" ]] && exist+=("${s}"); done
if [[ ${#exist[@]} -eq 0 ]]; then echo "Nenhum segredo encontrado para backup." >&2; exit 1; fi

echo "Itens que vão no backup:"; printf '  • %s\n' "${exist[@]}"
echo
echo "Defina uma PASSPHRASE (o GPG vai pedir). GUARDE-A no gerenciador de senhas!"

tar -czf - -C "${HOME}" --exclude='.gnupg/S.*' --exclude='.gnupg/*.lock' "${exist[@]}" \
    | gpg --symmetric --cipher-algo AES256 --output "${OUT}"

chmod 600 "${OUT}"
echo
echo "✓ Backup criptografado gerado: ${OUT}"
echo "  → MOVA pra fora deste disco (Dropbox / HDD de Backup). É gitignored, não vai pro repo."
echo "  → Restaurar:  gpg -d '${OUT}' | tar -xzf - -C ~"
