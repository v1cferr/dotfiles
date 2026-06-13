#!/usr/bin/env bash
# ============================================================================
#  Quote da tela de bloqueio (EN + tradução PT-BR)
# ----------------------------------------------------------------------------
#  Chamado uma vez a cada lock pelo label do hyprlock (cmd[] roda só na
#  inicialização), então cada lock mostra uma quote nova.
#
#  Mantém um pool local em ~/.cache/hypr/quotes/: lote vem da ZenQuotes
#  (50 por chamada, respeita o rate limit) e a tradução do endpoint gtx do
#  Google Translate. Cada quote é consumida uma única vez — sem repetição
#  até o pool circular. Offline: cai para o histórico ou para o seed.
# ============================================================================
set -u

QDIR="${HOME}/.cache/hypr/quotes"
POOL="${QDIR}/pool.tsv"   # EN<TAB>PT<TAB>autor
USED="${QDIR}/used.tsv"
MIN_POOL=5

mkdir -p "${QDIR}"

seed() {
    cat <<'EOF'
The only way to do great work is to love what you do.	A única forma de fazer um grande trabalho é amar o que você faz.	Steve Jobs
Simplicity is the ultimate sophistication.	A simplicidade é a sofisticação máxima.	Leonardo da Vinci
It always seems impossible until it is done.	Sempre parece impossível até que seja feito.	Nelson Mandela
What we know is a drop, what we don't know is an ocean.	O que sabemos é uma gota; o que não sabemos é um oceano.	Isaac Newton
Make it work, make it right, make it fast.	Faça funcionar, faça direito, faça rápido.	Kent Beck
EOF
}

refill() {
    local batch q a pt
    batch="$(curl -s --max-time 10 'https://zenquotes.io/api/quotes')" || return 1
    jq -r '.[] | select(.q and .a) | [.q, .a] | @tsv' <<<"${batch}" 2>/dev/null |
    while IFS=$'\t' read -r q a; do
        grep -qsF "${q}" "${POOL}" "${USED}" && continue
        pt="$(curl -sG --max-time 8 'https://translate.googleapis.com/translate_a/single' \
            --data-urlencode 'client=gtx' --data-urlencode 'sl=en' \
            --data-urlencode 'tl=pt' --data-urlencode 'dt=t' \
            --data-urlencode "q=${q}" | jq -r '.[0] | map(.[0]) | join("")' 2>/dev/null)"
        [[ -z ${pt} || ${pt} == "null" ]] && pt="${q}"
        printf '%s\t%s\t%s\n' "${q}" "${pt}" "${a}" >>"${POOL}"
        sleep 0.4   # gentileza com o rate limit do tradutor
    done
}

# Consome a próxima quote do pool; sem pool, recicla o histórico ou o seed.
line=""
if [[ -s ${POOL} ]]; then
    line="$(head -n1 "${POOL}")"
    sed -i '1d' "${POOL}"
    printf '%s\n' "${line}" >>"${USED}"
elif [[ -s ${USED} ]]; then
    line="$(shuf -n1 "${USED}")"
else
    line="$(seed | shuf -n1)"
fi

# Reabastece em segundo plano quando o pool encurta (mkdir = lock atômico).
pool_count=0
[[ -f ${POOL} ]] && pool_count="$(wc -l <"${POOL}")"
if (( pool_count < MIN_POOL )); then
    if mkdir "${QDIR}/.refilling" 2>/dev/null; then
        ( refill; rmdir "${QDIR}/.refilling" ) >/dev/null 2>&1 &
        disown
    fi
fi

IFS=$'\t' read -r en pt author <<<"${line}"

# Escapa pango e quebra linhas longas (o label do hyprlock não faz wrap).
# Só a tradução PT-BR é exibida; o EN fica no pool para dedup.
esc() { sed 's/&/\&amp;/g; s/</\&lt;/g; s/>/\&gt;/g'; }
pt="$(printf '%s' "${pt}" | esc | fold -s -w 70)"
author="$(printf '%s' "${author}" | esc)"

printf '<i>“%s”</i>\n<b>— %s</b>\n' "${pt}" "${author}"
