#!/usr/bin/env bash
# ============================================================================
#  Quote PT-BR da tela de bloqueio (hyprlock)
# ----------------------------------------------------------------------------
#  Chamado uma vez por lock pelo label `cmd[]` do hyprlock. Lê um banco local
#  versionado (lockscreen_quotes.tsv, ~1450 quotes traduzidas) e devolve uma
#  fila embaralhada: cada quote aparece UMA vez antes de qualquer repetição —
#  são meses de locks sem repetir. Totalmente offline, sem API no momento do
#  lock.
#
#  Para regenerar/ampliar o banco: rode gen-lockscreen-quotes.sh (ao lado
#  deste arquivo). Formato do TSV:  en<TAB>pt<TAB>autor.
# ============================================================================
set -u

SELF_DIR="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")" && pwd)"
DB="${SELF_DIR}/lockscreen_quotes.tsv"   # en<TAB>pt<TAB>autor
CACHE="${HOME}/.cache/hypr/quotes"
QUEUE="${CACHE}/queue"   # linhas pt<TAB>autor, embaralhadas, 1 consumida por lock
LAST="${CACHE}/last"
mkdir -p "${CACHE}"

if [[ ! -s ${DB} ]]; then
    # fallback se o banco sumir (TAB real entre frase e autor)
    line="$(printf 'A simplicidade é a sofisticação máxima.\tLeonardo da Vinci')"
else
    if [[ ! -s ${QUEUE} ]]; then
        # (re)embaralha o banco; evita abrir com a mesma quote que acabou de sair
        prev=""; [[ -f ${LAST} ]] && prev="$(<"${LAST}")"
        cut -f2,3 "${DB}" | shuf > "${QUEUE}.tmp"
        if [[ -n ${prev} && "$(head -n1 "${QUEUE}.tmp")" == "${prev}" ]]; then
            { tail -n +2 "${QUEUE}.tmp"; head -n1 "${QUEUE}.tmp"; } > "${QUEUE}"
            rm -f "${QUEUE}.tmp"
        else
            mv "${QUEUE}.tmp" "${QUEUE}"
        fi
    fi
    line="$(head -n1 "${QUEUE}")"
    sed -i '1d' "${QUEUE}"
    printf '%s\n' "${line}" > "${LAST}"
fi

IFS=$'\t' read -r pt author <<<"${line}"

# Escapa pango e quebra linhas longas (o label do hyprlock não faz wrap).
esc() { sed 's/&/\&amp;/g; s/</\&lt;/g; s/>/\&gt;/g'; }
pt="$(printf '%s' "${pt}" | esc | fold -s -w 70)"
author="$(printf '%s' "${author:-}" | esc)"

printf '<i>“%s”</i>\n<b>— %s</b>\n' "${pt}" "${author}"
