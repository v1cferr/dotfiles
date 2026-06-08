#!/usr/bin/env bash
# ============================================================================
#  Backup CRIPTOGRAFADO dos segredos (NÃO versionado) — arquivo ÚNICO
# ----------------------------------------------------------------------------
#  Empacota o que NÃO vai pro repo (chaves SSH/GPG, .env, tokens) num tarball
#  GPG simétrico. Sempre o MESMO arquivo (sobrescreve):
#  secrets-backup.tar.gz.gpg na raiz do dotfiles (gitignored).
#  Sincronize/mova pro Dropbox/HDD.
#
#  Passphrase:
#   - interativo: o GPG pergunta.
#   - automático (timer): lê de ~/.config/secrets-backup.passphrase (chmod 600).
#
#  Restaurar:  gpg -d secrets-backup.tar.gz.gpg | tar -xzf - -C ~
#
#  Uso:  ~/dotfiles/scripts/secrets/backup.sh
# ============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")" && pwd)"
DOTFILES_DIR="$(cd "${SCRIPT_DIR}/../.." && pwd)"
OUT="${SECRETS_BACKUP_OUT:-${DOTFILES_DIR}/secrets-backup.tar.gz.gpg}"
PASS_FILE="${SECRETS_BACKUP_PASSFILE:-${HOME}/.config/secrets-backup.passphrase}"

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

exist=()
for s in "${SECRETS[@]}"; do [[ -e "${HOME}/${s}" ]] && exist+=("${s}"); done
[[ ${#exist[@]} -eq 0 ]] && { echo "Nenhum segredo encontrado." >&2; exit 1; }

# Args do GPG: passphrase-file se existir (automático); senão interativo.
gpg_args=(--symmetric --cipher-algo AES256 --yes --output "${OUT}")
if [[ -f "${PASS_FILE}" ]]; then
    gpg_args=(--batch --pinentry-mode loopback --passphrase-file "${PASS_FILE}" "${gpg_args[@]}")
elif [[ ! -t 0 ]]; then
    echo "ERRO: execução automática sem TTY e sem ${PASS_FILE}." >&2
    echo "      Rode scripts/secrets/install.sh para configurar a passphrase." >&2
    exit 1
else
    echo "Itens no backup:"; printf '  • %s\n' "${exist[@]}"
    echo "Defina a PASSPHRASE (guarde no gerenciador de senhas!)."
fi

tar -czf - -C "${HOME}" --exclude='.gnupg/S.*' --exclude='.gnupg/*.lock' "${exist[@]}" \
    | gpg "${gpg_args[@]}"
chmod 600 "${OUT}"
echo "✓ ${OUT} (gitignored). Sincronize pro Dropbox/HDD."
