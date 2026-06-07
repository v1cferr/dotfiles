#!/usr/bin/env bash
# ============================================================================
#  Regenera as listas de pacotes versionadas (pacman + AUR)
# ----------------------------------------------------------------------------
#  Escreve, ao lado deste script, os arquivos:
#    - pacman-explicit.txt : explícitos dos repos oficiais (nome + versão)
#    - aur.txt             : explícitos foreign/AUR        (nome + versão)
#    - orphans.txt         : deps órfãs (candidatas a remoção; pode ser vazio)
#
#  NÃO faz git (commit/push) — só atualiza os arquivos. O versionamento é
#  manual (você revisa o diff e commita quando quiser). Roda como usuário,
#  acionado pelo timer de usuário dotfiles-pkgsync.timer (a cada 5min).
# ============================================================================
set -euo pipefail

OUT="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")" && pwd)"

# Explícitos nativos (repos oficiais), com versão, ordenados p/ diff estável
{ pacman -Qen 2>/dev/null || true; } | sort > "${OUT}/pacman-explicit.txt"

# Explícitos foreign / AUR, com versão
{ pacman -Qem 2>/dev/null || true; } | sort > "${OUT}/aur.txt"

# Órfãos: dependências que nada mais requer (lixo candidato a 'pacman -Rns')
{ pacman -Qdtq 2>/dev/null || true; } | sort > "${OUT}/orphans.txt"
