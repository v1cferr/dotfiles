#!/usr/bin/env bash
# ============================================================================
#  Quote PT-BR da tela de bloqueio (hyprlock)
# ----------------------------------------------------------------------------
#  Lê um banco local versionado (lockscreen_quotes.tsv, ~1450 quotes
#  traduzidas) numa fila embaralhada: cada quote aparece UMA vez antes de
#  qualquer repetição (meses sem repetir). Offline, sem API no lock.
#
#  Troca de quote a cada lock novo E a cada 2.5 min dentro do mesmo lock
#  (ROTATE), igual ao GIF — chamado pelo label cmd[update:...] do hyprlock.
#
#  Para regenerar/ampliar o banco: rode gen-lockscreen-quotes.sh (ao lado
#  deste arquivo). Formato do TSV:  en<TAB>pt<TAB>autor.
# ============================================================================
set -u

SELF_DIR="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")" && pwd)"
DB="${SELF_DIR}/lockscreen_quotes.tsv"   # en<TAB>pt<TAB>autor
CACHE="${HOME}/.cache/hypr/quotes"
QUEUE="${CACHE}/queue"          # linhas pt<TAB>autor, embaralhadas
CURRENT="${CACHE}/current"      # quote atual: pt<TAB>autor
SESSION="${CACHE}/session"      # sid do hyprlock (pid:starttime)
PICKED="${CACHE}/picked_at"     # epoch de quando a quote atual foi escolhida
ROTATE=150                      # troca de quote a cada 2.5 min no mesmo lock
mkdir -p "${CACHE}"

emit() {  # formata e imprime "pt" + autor (escapa pango, quebra linhas longas)
    local pt author
    IFS=$'\t' read -r pt author <<<"$1"
    esc() { sed 's/&/\&amp;/g; s/</\&lt;/g; s/>/\&gt;/g'; }
    pt="$(printf '%s' "${pt}" | esc | fold -s -w 70)"
    author="$(printf '%s' "${author:-}" | esc)"
    printf '<i>“%s”</i>\n<b>— %s</b>\n' "${pt}" "${author}"
}

# Banco ausente -> fallback fixo (TAB real entre frase e autor)
if [[ ! -s ${DB} ]]; then
    emit "$(printf 'A simplicidade é a sofisticação máxima.\tLeonardo da Vinci')"
    exit 0
fi

# Sessão de lock = pid+starttime do hyprlock.
pid="$(pgrep -o -x hyprlock 2>/dev/null || true)"
sid="none"
[[ -n ${pid} ]] && sid="${pid}:$(awk '{print $22}' "/proc/${pid}/stat" 2>/dev/null)"

# Avança a fila sob flock (o label pode disparar mais de uma vez no startup):
# (a) lock novo, (b) sem estado, ou (c) passaram ROTATE segundos.
exec 9>"${CACHE}/.advance.lock"
if flock -w 2 9; then
    advance=0
    if [[ ! -f ${SESSION} || "$(<"${SESSION}")" != "${sid}" ]]; then
        advance=1
    elif [[ ! -f ${PICKED} || ! -f ${CURRENT} ]]; then
        advance=1
    elif (( $(date +%s) - $(<"${PICKED}") >= ROTATE )); then
        advance=1
    fi

    if (( advance )); then
        prev=""; [[ -f ${CURRENT} ]] && prev="$(<"${CURRENT}")"
        if [[ ! -s ${QUEUE} ]]; then
            # (re)embaralha; evita abrir com a mesma quote que acabou de sair
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
        printf '%s\n' "${line}" > "${CURRENT}"
        echo "${sid}" > "${SESSION}"
        date +%s > "${PICKED}"
    fi
    flock -u 9
fi

emit "$(<"${CURRENT}")"
