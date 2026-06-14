#!/usr/bin/env bash
# ============================================================================
#  Coletor de status do greeter (greetd) — roda como ROOT via systemd
# ----------------------------------------------------------------------------
#  Escreve /run/greeter-status/status.json (mundo-legível) + assets, num loop.
#  O greeter quickshell roda como o usuário `greeter` (sem docker, sem entrar em
#  /home que é 710), então TODA coleta privilegiada acontece aqui e o greeter só lê.
#
#  Campos do JSON:
#    containers[] {name,cpu,mem,up}  (ordenado por CPU desc)
#    up, total, cpu_temp, gpu_temp, ip, uptime, quote, author, gifs[], alerts[]
#
#  Por boot (1x): sorteia quote (lockscreen_quotes.tsv) e copia ~4 GIFs.
#  A cada ciclo (~3s): docker stats, temps, disco, ip, uptime, alertas.
#  Wallpaper borrado: só re-gera quando o wallpaper do desktop muda.
# ============================================================================
set -uo pipefail

OUT_DIR="/run/greeter-status"
JSON="${OUT_DIR}/status.json"
TMP="${JSON}.tmp"

USER_HOME="/home/v1cferr"
QUOTES_TSV="${USER_HOME}/dotfiles/hypr/.config/hypr/scripts/lockscreen_quotes.tsv"
GIF_SRC="${USER_HOME}/dotfiles/wallpapers/Pictures/Wallpapers/lockscreen-gifs"

TEMP_HI=85          # °C — alerta de temperatura
DISK_HI=90          # %  — alerta de disco cheio
GIF_COUNT=4         # quantos GIFs copiar pro greeter (tmpfs!)
INTERVAL=3          # segundos entre ciclos

mkdir -p "${OUT_DIR}"; chmod 755 "${OUT_DIR}"

# ---------------------------------------------------------------------------
#  Coisas por-boot (não mudam durante a vida do greeter)
# ---------------------------------------------------------------------------
QUOTE_PT=""; QUOTE_AUTHOR=""
if [[ -s "${QUOTES_TSV}" ]]; then
    line=$(shuf -n1 "${QUOTES_TSV}")
    QUOTE_PT=$(cut -f2 <<<"${line}")
    QUOTE_AUTHOR=$(cut -f3 <<<"${line}")
fi

# Copia um punhado de GIFs (nunca os 1.4G inteiros) pro tmpfs
rm -f "${OUT_DIR}"/gif-*.gif
if [[ -d "${GIF_SRC}" ]]; then
    i=0
    while IFS= read -r f; do
        cp -f "${f}" "${OUT_DIR}/gif-${i}.gif" 2>/dev/null && chmod 644 "${OUT_DIR}/gif-${i}.gif" && i=$((i+1))
    done < <(find "${GIF_SRC}" -maxdepth 1 -name '*.gif' | shuf -n "${GIF_COUNT}")
fi
GIFS_JSON=$(for g in "${OUT_DIR}"/gif-*.gif; do [[ -e "${g}" ]] && printf '%s\n' "${g}"; done | jq -R . | jq -s 'map(select(length>0))')

# ---------------------------------------------------------------------------
#  Helpers
# ---------------------------------------------------------------------------
cpu_temp() {  # imprime inteiro em °C, ou vazio
    local t
    if command -v sensors >/dev/null 2>&1; then
        t=$(sensors 2>/dev/null | awk '/Package id 0|Tctl|Tdie|Core 0/ {for(i=1;i<=NF;i++) if($i ~ /^\+[0-9]/){gsub(/[+°C]/,"",$i); print $i; exit}}' | cut -d. -f1)
        [[ "${t}" =~ ^[0-9]+$ ]] && { echo "${t}"; return; }
    fi
    for h in /sys/class/hwmon/hwmon*/temp1_input; do
        [[ -r "${h}" ]] || continue
        t=$(cat "${h}" 2>/dev/null); [[ "${t}" =~ ^[0-9]+$ ]] && { echo $((t/1000)); return; }
    done
}

gpu_temp() {  # NVIDIA
    nvidia-smi --query-gpu=temperature.gpu --format=csv,noheader,nounits 2>/dev/null | head -n1 | tr -dc '0-9'
}

# ---------------------------------------------------------------------------
#  Loop principal
# ---------------------------------------------------------------------------
while true; do
    # --- docker ---
    stats_raw=$(docker stats --no-stream --format '{{json .}}' 2>/dev/null)
    ps_raw=$(docker ps -a --format '{{json .}}' 2>/dev/null)
    stats_json=$(printf '%s' "${stats_raw}" | jq -s '.' 2>/dev/null); [[ -z "${stats_json}" ]] && stats_json='[]'
    ps_json=$(printf '%s' "${ps_raw}" | jq -s '.' 2>/dev/null);       [[ -z "${ps_json}" ]] && ps_json='[]'

    # nome -> "running"? (do ps), e métricas (do stats), ordenado por CPU desc
    containers=$(jq -n --argjson stats "${stats_json}" --argjson ps "${ps_json}" '
        ($ps | map({(.Names): (.State // "")}) | add // {}) as $state
        | [ $stats[]
            | { name: .Name,
                cpu:  ((.CPUPerc // "0%") | rtrimstr("%") | tonumber? // 0),
                mem:  (.MemPerc // "0%"),
                up:   (($state[.Name] // "running") == "running") } ]
        | sort_by(-.cpu)')

    total=$(jq -n --argjson ps "${ps_json}" '$ps | length')
    up=$(jq -n --argjson ps "${ps_json}" '[$ps[] | select(.State=="running")] | length')

    ct=$(cpu_temp); gt=$(gpu_temp)
    ip=$(ip -4 -o addr show scope global 2>/dev/null | awk '{print $4}' | cut -d/ -f1 | head -n1)
    up_pretty=$(uptime -p 2>/dev/null)

    # --- alertas ---
    alert_arr=()
    while IFS= read -r n; do
        [[ -n "${n}" ]] && alert_arr+=("Container caído: ${n}")
    done < <(jq -r --argjson ps "${ps_json}" '$ps[] | select(.State!="running") | .Names' 2>/dev/null)
    [[ "${ct}" =~ ^[0-9]+$ && "${ct}" -ge "${TEMP_HI}" ]] && alert_arr+=("CPU quente: ${ct}°C")
    [[ "${gt}" =~ ^[0-9]+$ && "${gt}" -ge "${TEMP_HI}" ]] && alert_arr+=("GPU quente: ${gt}°C")
    while read -r tgt pct; do
        p=${pct%\%}
        [[ "${p}" =~ ^[0-9]+$ && "${p}" -ge "${DISK_HI}" ]] && alert_arr+=("Disco cheio: ${tgt} ${pct}")
    done < <(df -P --output=target,pcent / /home 2>/dev/null | tail -n +2)
    alerts=$(printf '%s\n' "${alert_arr[@]}" | jq -R . | jq -s 'map(select(length>0))')

    # --- monta JSON (atômico) ---
    jq -n \
        --argjson containers "${containers:-[]}" \
        --argjson up "${up:-0}" --argjson total "${total:-0}" \
        --arg cpu_temp "${ct}" --arg gpu_temp "${gt}" \
        --arg ip "${ip}" --arg uptime "${up_pretty}" \
        --arg quote "${QUOTE_PT}" --arg author "${QUOTE_AUTHOR}" \
        --argjson gifs "${GIFS_JSON:-[]}" \
        --argjson alerts "${alerts:-[]}" \
        '{containers:$containers, up:$up, total:$total,
          cpu_temp:$cpu_temp, gpu_temp:$gpu_temp, ip:$ip, uptime:$uptime,
          quote:$quote, author:$author, gifs:$gifs, alerts:$alerts}' \
        > "${TMP}" 2>/dev/null && mv "${TMP}" "${JSON}" && chmod 644 "${JSON}"

    sleep "${INTERVAL}"
done
