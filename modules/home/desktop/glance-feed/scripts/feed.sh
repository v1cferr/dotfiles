# shellcheck shell=bash
# glance-feed: every network source of the desktop's glance surfaces, fetched ONLY when it can have
# changed, into one SQLite cache (schema.sql). `glance-feed` (the timer, every minute) runs what is
# due; `glance-feed read <name>` prints a source's document for the UI. Why: docs/notes/desktop/glance-feed.md
# GLANCE_LAT, GLANCE_LON, GLANCE_MODEL, GLANCE_IBGE and GLANCE_SCHEMA come from runtimeEnv.
set -uo pipefail

dir="${XDG_CACHE_HOME:-$HOME/.cache}/glance"
db="$dir/glance.db"
stamps="$dir/stamps" # one file per source, rewritten ONLY when its document changes
mkdir -p "$stamps"
now="$(date +%s)"
today="$(date +%F)"
work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT
# INMET drops clients that do not look like a browser.
ua="Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/130 Safari/537.36"

sql() { sqlite3 -batch -cmd '.timeout 5000' "$db" "$@"; }
q() { printf '%s' "${1//\'/\'\'}"; } # a value inside single quotes

[ -s "$db" ] || sqlite3 "$db" <"$GLANCE_SCHEMA" >/dev/null

# ── read: the UI's only way in ──
if [ "${1:-}" = read ]; then
  sqlite3 -readonly -json -cmd '.timeout 3000' "$db" \
    "SELECT name, json, source, updated_at, checked_at, error FROM feed WHERE name = '$(q "${2:-}")'" |
    jq -c '.[0] // {} | if .json then .json |= fromjson else . end'
  exit 0
fi

# ── scheduling ──
state() { sql "SELECT value FROM state WHERE key = '$(q "$1")'"; }
state_set() { sql "INSERT INTO state(key, value) VALUES ('$(q "$1")', '$(q "$2")') ON CONFLICT(key) DO UPDATE SET value = excluded.value"; }
due() { # due NAME -> true when its next run has come (or never ran)
  local next
  next="$(state "next:$1")"
  [ -z "$next" ] || [ "$now" -ge "$next" ]
}
again() { state_set "next:$1" "$((now + $2))"; } # again NAME SECONDS

count() { # count SOURCE BYTES NOT_MODIFIED(0|1)
  sql "INSERT INTO traffic(day, source, bytes, requests, not_modified) VALUES ('$today', '$(q "$1")', $2, 1, $3)
       ON CONFLICT(day, source) DO UPDATE SET bytes = bytes + $2, requests = requests + 1, not_modified = not_modified + $3"
}

# get SOURCE URL OUT [curl args...]: a conditional GET through http_cache. Writes the body (fresh or
# cached) to OUT; returns 0 with a body, 1 on failure. An ETag, when the server sends one, makes an
# unchanged resource a 304 with no body.
get() {
  local source="$1" url="$2" out="$3"
  shift 3
  local etag code size hdr="$work/hdr" body="$work/body"
  etag="$(sql "SELECT etag FROM http_cache WHERE url = '$(q "$url")'")"
  read -r code size < <(curl -sS -m 30 --compressed -A "$ua" -D "$hdr" -o "$body" -w '%{http_code} %{size_download}\n' \
    ${etag:+-H "If-None-Match: $etag"} "$@" "$url" 2>/dev/null || echo "000 0")
  case "$code" in
    304)
      count "$source" "${size:-0}" 1
      sql "UPDATE http_cache SET checked_at = $now WHERE url = '$(q "$url")'"
      sql "SELECT body FROM http_cache WHERE url = '$(q "$url")'" >"$out"
      ;;
    200)
      count "$source" "${size:-0}" 0
      etag="$(grep -i '^etag:' "$hdr" | tail -1 | cut -d' ' -f2- | tr -d '\r')"
      sql "INSERT INTO http_cache(url, etag, body, fetched_at, checked_at)
           VALUES ('$(q "$url")', '$(q "$etag")', CAST(readfile('$body') AS TEXT), $now, $now)
           ON CONFLICT(url) DO UPDATE SET etag = excluded.etag, body = excluded.body,
             fetched_at = excluded.fetched_at, checked_at = excluded.checked_at"
      cp "$body" "$out"
      ;;
    *) return 1 ;;
  esac
}

# put NAME SOURCE FILE: store a document; updated_at and the stamp move only if it CHANGED.
put() {
  local name="$1" source="$2" file="$3" same
  jq -e . "$file" >/dev/null 2>&1 || return 1
  jq -c . "$file" >"$work/doc"
  same="$(sql "SELECT json = CAST(readfile('$work/doc') AS TEXT) FROM feed WHERE name = '$(q "$name")'")"
  if [ "$same" = 1 ]; then
    sql "UPDATE feed SET checked_at = $now, error = NULL WHERE name = '$(q "$name")'"
  else
    sql "INSERT INTO feed(name, json, source, updated_at, checked_at, error)
         VALUES ('$(q "$name")', CAST(readfile('$work/doc') AS TEXT), '$(q "$source")', $now, $now, NULL)
         ON CONFLICT(name) DO UPDATE SET json = excluded.json, source = excluded.source,
           updated_at = excluded.updated_at, checked_at = excluded.checked_at, error = NULL"
    printf '%s\n' "$now" >"$stamps/$name"
  fi
}
fail() { # fail NAME MESSAGE: keep the last document, say why, and try again in 5 minutes
  sql "UPDATE feed SET error = '$(q "$2")' WHERE name = '$(q "$1")'"
  again "$1" 300
}

# ── weather: Open-Meteo, only when the model has a NEW RUN (ECMWF IFS: every 6 h) ──
weather() {
  due weather || return 0
  again weather 1800 # ask about a new run every 30 min; the answer is 658 bytes
  local run
  if ! get open-meteo "https://api.open-meteo.com/data/$GLANCE_MODEL/static/meta.json" "$work/meta"; then
    fail weather "open-meteo unreachable"
    return 0
  fi
  run="$(jq -r '.last_run_availability_time // empty' "$work/meta")"
  # Same run as last time, and the document still covers the next day: nothing to download.
  if [ -n "$run" ] && [ "$run" = "$(state weather:run)" ] && [ "$(sql "SELECT $now - updated_at < 43200 FROM feed WHERE name = 'weather'")" = 1 ]; then
    sql "UPDATE feed SET checked_at = $now, error = NULL WHERE name = 'weather'"
    return 0
  fi
  # The hours carry everything "now" needs (temperature, feels like, humidity, wind), so the UI
  # derives the current conditions from the run it has instead of asking every 15 minutes.
  local url="https://api.open-meteo.com/v1/forecast?latitude=$GLANCE_LAT&longitude=$GLANCE_LON&models=$GLANCE_MODEL&timezone=auto"
  url+="&hourly=temperature_2m,apparent_temperature,relative_humidity_2m,wind_speed_10m,wind_direction_10m,precipitation_probability,weather_code,is_day"
  url+="&daily=weather_code,temperature_2m_max,temperature_2m_min,precipitation_probability_max,sunrise,sunset"
  url+="&past_hours=3&forecast_hours=48&forecast_days=8"
  if get open-meteo "$url" "$work/forecast" && put weather "open-meteo:$GLANCE_MODEL" "$work/forecast"; then
    state_set weather:run "$run"
  else
    fail weather "forecast download failed"
  fi
}

# ── INMET forecast text: the forecasters update it a few times a day ──
inmet_forecast() {
  due inmet_forecast || return 0
  again inmet_forecast 14400 # every 4 hours
  if ! get inmet "https://apiprevmet3.inmet.gov.br/previsao/$GLANCE_IBGE" "$work/prev"; then
    fail inmet_forecast "inmet unreachable"
    return 0
  fi
  # 244 KB of which most is base64 icons: keep only what is shown.
  if jq --arg ibge "$GLANCE_IBGE" '.[$ibge] // {} | with_entries(.value |= (
      if (.manha or .tarde or .noite) then
        {periods: (with_entries(select(.key | IN("manha", "tarde", "noite"))) | map_values({resumo, temp_max, temp_min}))}
      else {resumo, temp_max, temp_min} end))' "$work/prev" >"$work/prev.min"; then
    put inmet_forecast inmet "$work/prev.min"
  else
    fail inmet_forecast "inmet forecast unreadable"
  fi
}

# ── INMET alerts: the 196 KB RSS says WHETHER the set changed; the 775 KB list only then ──
inmet_alerts() {
  due inmet_alerts || return 0
  again inmet_alerts 1800 # every 30 min
  if ! get inmet "https://apiprevmet3.inmet.gov.br/avisos/rss" "$work/rss"; then
    fail inmet_alerts "inmet unreachable"
    return 0
  fi
  local digest
  digest="$(grep -o '<guid[^>]*>[^<]*</guid>' "$work/rss" | sort | sha256sum | cut -c1-16)"
  # Unchanged set and refreshed in the last 6 h (the "until" of an alert moves with the clock): done.
  if [ "$digest" = "$(state inmet_alerts:digest)" ] && [ "$(sql "SELECT $now - updated_at < 21600 FROM feed WHERE name = 'inmet_alerts'")" = 1 ]; then
    sql "UPDATE feed SET checked_at = $now, error = NULL WHERE name = 'inmet_alerts'"
    return 0
  fi
  if ! get inmet "https://apiprevmet3.inmet.gov.br/avisos/ativos" "$work/avisos"; then
    fail inmet_alerts "inmet alerts unreachable"
    return 0
  fi
  # Ours only, by IBGE code; the polygons (most of the 775 KB) are dropped here.
  if jq --arg ibge "$GLANCE_IBGE" '[(.hoje // []) + (.futuro // []) | .[]
      | select((.geocodes // "" | tostring | split(",")) | index($ibge))
      | {id: .id_aviso, event: .descricao, severity: .severidade,
         start: ((.data_inicio // "")[:10] + "T" + (.hora_inicio // "00:00")),
         end: ((.data_fim // "")[:10] + "T" + (.hora_fim // "23:59")),
         until: .hora_fim,
         risk: ((.riscos | if type == "string" then (fromjson? // .) else . end) | if type == "array" then .[0] else . end // "")}]
      | sort_by(.start)' "$work/avisos" >"$work/avisos.min" && put inmet_alerts inmet "$work/avisos.min"; then
    state_set inmet_alerts:digest "$digest"
  else
    fail inmet_alerts "inmet alerts unreadable"
  fi
}

weather
inmet_forecast
inmet_alerts
