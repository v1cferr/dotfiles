#!/usr/bin/env bash
# ============================================================================
#  (Re)gera o banco de quotes da tela de bloqueio: lockscreen_quotes.tsv
# ----------------------------------------------------------------------------
#  Baixa ~1450 quotes em inglês (dummyjson), traduz para PT-BR em lote pelo
#  endpoint gtx do Google Translate, dedup pela tradução e grava o TSV
#  (en<TAB>pt<TAB>autor) ao lado deste script.
#
#  Só precisa rodar para ampliar/atualizar o banco — no dia a dia o
#  lockscreen_quote.sh lê o TSV versionado, sem rede.
#
#  Uso:  hypr/.config/hypr/scripts/gen-lockscreen-quotes.sh
# ============================================================================
set -euo pipefail

SELF_DIR="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")" && pwd)"
OUT="${SELF_DIR}/lockscreen_quotes.tsv"
TMP="$(mktemp -d)"
trap 'rm -rf "${TMP}"' EXIT
BATCH=25

echo "[gen] baixando quotes em inglês (dummyjson)…"
curl -s --max-time 30 'https://dummyjson.com/quotes?limit=0' \
    | jq -r '.quotes[] | [.quote, .author] | @tsv' > "${TMP}/en.tsv"
total=$(wc -l < "${TMP}/en.tsv")
echo "[gen] ${total} quotes; traduzindo em lotes de ${BATCH}…"

gtx() {
    curl -sG --max-time 25 'https://translate.googleapis.com/translate_a/single' \
        --data-urlencode 'client=gtx' --data-urlencode 'sl=en' \
        --data-urlencode 'tl=pt' --data-urlencode 'dt=t' --data-urlencode "q=$1" \
        | jq -r '.[0] | map(.[0]) | join("")'
}

mapfile -t lines < "${TMP}/en.tsv"
: > "${TMP}/out.tsv"
i=0
while (( i < total )); do
    ens=(); authors=()
    for ((j=0; j<BATCH && i<total; j++, i++)); do
        ens+=("$(cut -f1 <<<"${lines[i]}")")
        authors+=("$(cut -f2 <<<"${lines[i]}")")
    done
    n=${#ens[@]}
    mapfile -t pts < <(gtx "$(printf '%s\n' "${ens[@]}")")
    if (( ${#pts[@]} != n )); then           # fallback: uma a uma
        pts=()
        for ((k=0; k<n; k++)); do
            pt="$(gtx "${ens[k]}")"; [[ -z ${pt} ]] && pt="${ens[k]}"
            pts+=("${pt}"); sleep 0.2
        done
    fi
    for ((k=0; k<n; k++)); do
        printf '%s\t%s\t%s\n' "${ens[k]}" "${pts[k]:-${ens[k]}}" "${authors[k]}" >> "${TMP}/out.tsv"
    done
    printf '\r[gen] %d/%d' "$i" "$total"
    sleep 0.3
done
echo

# dedup pela tradução (mantém 1ª ocorrência, preserva ordem)
awk -F'\t' '!seen[$2]++' "${TMP}/out.tsv" > "${OUT}"
echo "[gen] ok — ${OUT} ($(wc -l < "${OUT}") quotes únicas)"
