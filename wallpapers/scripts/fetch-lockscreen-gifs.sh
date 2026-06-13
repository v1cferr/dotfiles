#!/usr/bin/env bash
# ============================================================================
#  Baixa os GIFs da tela de bloqueio a partir do manifesto
# ----------------------------------------------------------------------------
#  Os GIFs (~400 MB) não ficam no git — só o manifesto lockscreen-gifs.txt.
#  Este script lê o manifesto e baixa o que estiver faltando para
#  lockscreen-gifs/ (ao lado do manifesto). Idempotente: pula o que já existe.
#
#  Uso:
#    wallpapers/scripts/fetch-lockscreen-gifs.sh          # baixa o que falta
#    wallpapers/scripts/fetch-lockscreen-gifs.sh --force  # rebaixa tudo
#    wallpapers/scripts/fetch-lockscreen-gifs.sh --prune  # remove .gif órfãos
# ============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")" && pwd)"
WP_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)/Pictures/Wallpapers"
MANIFEST="${WP_DIR}/lockscreen-gifs.txt"
DEST="${WP_DIR}/lockscreen-gifs"

FORCE=0
PRUNE=0
for arg in "$@"; do
    case "${arg}" in
        --force) FORCE=1 ;;
        --prune) PRUNE=1 ;;
        *) echo "argumento desconhecido: ${arg}" >&2; exit 2 ;;
    esac
done

[[ -f ${MANIFEST} ]] || { echo "manifesto não encontrado: ${MANIFEST}" >&2; exit 1; }
mkdir -p "${DEST}"

declare -A wanted
ok=0 skip=0 fail=0

while read -r name url _; do
    [[ -z ${name} || ${name} == \#* ]] && continue
    wanted["${name}"]=1
    out="${DEST}/${name}"
    if [[ ${FORCE} -eq 0 && -s ${out} ]]; then
        skip=$((skip + 1)); continue
    fi
    printf '↓ %-22s %s\n' "${name}" "${url}"
    if curl -fsSL --max-time 300 -o "${out}.part" "${url}" && [[ -s ${out}.part ]]; then
        mv "${out}.part" "${out}"; ok=$((ok + 1))
    else
        rm -f "${out}.part"; echo "  ✗ falhou: ${name}" >&2; fail=$((fail + 1))
    fi
done < "${MANIFEST}"

if [[ ${PRUNE} -eq 1 ]]; then
    for f in "${DEST}"/*.gif; do
        [[ -e ${f} ]] || continue
        base="$(basename "${f}")"
        [[ -n ${wanted[${base}]:-} ]] || { echo "🗑  ${base} (fora do manifesto)"; rm -f "${f}"; }
    done
fi

echo "ok: ${ok}  já tinha: ${skip}  falhas: ${fail}  →  ${DEST}"
[[ ${fail} -eq 0 ]]
