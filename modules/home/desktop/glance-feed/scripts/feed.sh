# shellcheck shell=bash
# glance-feed: every network source of the desktop's glance surfaces, fetched ONLY when it can have
# changed, into one SQLite cache (schema.sql). `glance-feed` (the timer, every minute) runs what is
# due; `glance-feed read <name>` prints a source's document for the UI. Why: docs/notes/desktop/glance-feed.md
# GLANCE_LAT, GLANCE_LON, GLANCE_MODEL, GLANCE_IBGE, GLANCE_SCHEMA, the GLANCE_GITLAB_* /
# GLANCE_WEBHOOK_DIR of the CI source, GLANCE_ROUTER_UCI of the network source and GLANCE_ROUTER_LOG
# of the threats source come from runtimeEnv (default.nix).
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

sql() { sqlite3 -batch -cmd '.timeout 5000' "$db" "$@" </dev/null; }
q() { printf '%s' "${1//\'/\'\'}"; } # a value inside single quotes

sqlite3 "$db" <"$GLANCE_SCHEMA" >/dev/null # idempotent: a new table arrives with the next run

# ── read: the UI's only way in ──
glance-feed-read() { # the stored document alone, "{}" when there is none yet
  sqlite3 -readonly -cmd '.timeout 3000' "$db" "SELECT json FROM feed WHERE name = '$(q "$1")'" | jq -c '. // {}' 2>/dev/null || echo '{}'
}
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

# get_once SOURCE URL OUT [curl args...]: for what never changes once it exists (a commit by its
# SHA, the jobs of a finished run): served from http_cache with no request at all after the first.
get_once() {
  local url="$2" out="$3"
  if [ "$(sql "SELECT count(*) FROM http_cache WHERE url = '$(q "$url")'")" = 1 ]; then
    sql "SELECT body FROM http_cache WHERE url = '$(q "$url")'" >"$out"
    return 0
  fi
  get "$@"
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

# ── CI: GitHub Actions and the FAI GitLab, every 2 min (1 min while something runs) ──
# The document keeps the band's schema (dash/Ci.qml, docs/notes/desktop/dash.md): per source
# {ok, error, via, stale, staleSince, runs}, a run being {repo, name, ref, state, event, created,
# started, finished, url, title, actor, attempt, failure}. It holds NO per-run timestamp of its own,
# so it changes, and the UI wakes, only when a run does.
ci_since="$(date -u -d '7 days ago' +%Y-%m-%dT%H:%M:%SZ)"

ci_github() {
  local token
  if ! token="$(gh auth token 2>/dev/null)" || [ -z "$token" ]; then
    jq -n '{ok: false, error: "gh is not logged in", runs: []}'
    return
  fi
  local auth=(-H "Authorization: Bearer $token" -H "Accept: application/vnd.github+json" -H "X-GitHub-Api-Version: 2022-11-28")
  local api="https://api.github.com"
  # pushed_at only narrows the candidates; the run filter below decides. ETag: unchanged is a 304.
  if ! get github "$api/user/repos?per_page=100&affiliation=owner,collaborator,organization_member&sort=pushed" "$work/repos" "${auth[@]}"; then
    jq -n '{ok: false, error: "unreachable", runs: []}'
    return
  fi
  local r runs=()
  while read -r r; do
    [ -n "$r" ] || continue
    if get github "$api/repos/$r/actions/runs?per_page=30&created=>=${ci_since%T*}" "$work/runs" "${auth[@]}"; then
      # Dependabot's update jobs (event "dynamic") are bookkeeping, not CI.
      jq -c --arg r "$r" '[.workflow_runs[] | select(.event != "dynamic")] | group_by(.workflow_id) | map(max_by(.created_at)) | .[]
        | {repo: $r, id: .id, name: .name, ref: .head_branch, event: .event,
           created: .created_at, started: .run_started_at, finished: .updated_at, url: .html_url,
           title: .display_title, actor: .actor.login, attempt: .run_attempt, status: .status, conclusion: .conclusion}' \
        "$work/runs" >>"$work/gh.runs"
    fi
  done < <(jq -r --arg s "$ci_since" '.[] | select(.archived | not) | select(.pushed_at >= $s) | .full_name' "$work/repos")
  touch "$work/gh.runs"
  local run failure
  while read -r run; do
    failure=null
    if [ "$(jq -r '.status == "completed" and (.conclusion | IN("failure", "timed_out", "startup_failure"))' <<<"$run")" = true ]; then
      # A finished run's jobs never change: fetched once, then served from the cache forever.
      if get_once github "$api/repos/$(jq -r .repo <<<"$run")/actions/runs/$(jq -r .id <<<"$run")/jobs?filter=latest" "$work/jobs" "${auth[@]}"; then
        failure="$(jq -c '[.jobs[] | select(.conclusion == "failure")][0]
          | if . == null then null else {job: .name, step: ([.steps[]? | select(.conclusion == "failure") | .name][0])} end' "$work/jobs" 2>/dev/null || echo null)"
      fi
    fi
    runs+=("$(jq -c --argjson f "${failure:-null}" '. + {failure: $f}' <<<"$run")")
  done <"$work/gh.runs"
  printf '%s\n' "${runs[@]}" | jq -s '{ok: true, error: "", via: "api", runs: (map(select(. != null)) | map(. + {state: (
      if .status == "in_progress" then "running"
      elif .status != "completed" then "queued"
      elif .conclusion == "success" then "success"
      elif (.conclusion | IN("failure", "timed_out", "startup_failure")) then "failure"
      elif .conclusion == "cancelled" then "cancelled"
      else "skipped" end)}) | map(del(.status, .conclusion, .id)) | sort_by(.created) | reverse)}'
}

ci_gitlab() {
  if [ ! -r "$GLANCE_GITLAB_TOKEN_FILE" ]; then
    jq -n '{ok: false, error: "no-token", runs: []}'
    return
  fi
  local token api="$GLANCE_GITLAB_URL/api/v4"
  token="$(<"$GLANCE_GITLAB_TOKEN_FILE")"
  local auth=(-H "PRIVATE-TOKEN: $token")
  # Off the VPN the name resolves but nothing answers: one short probe, then the pipeline hook's
  # copy (ci-webhook-store) is the source, pushed instead of pulled.
  if ! curl -s -m 4 -o /dev/null "$api/version"; then
    local hooked=("$GLANCE_WEBHOOK_DIR"/*.json) # stays the literal pattern when the folder is empty
    if [ -e "${hooked[0]}" ]; then
      jq -s --arg s "$ci_since" '{ok: true, error: "", via: "webhook",
        runs: (map(select(.created >= $s)) | map(del(.id)) | sort_by(.created) | reverse)}' "${hooked[@]}"
    else
      jq -n '{ok: false, error: "unreachable", runs: []}'
    fi
    return
  fi
  if ! get gitlab "$api/projects?membership=true&simple=true&per_page=100&last_activity_after=$ci_since" "$work/projects" "${auth[@]}"; then
    jq -n '{ok: false, error: "auth", runs: []}'
    return
  fi
  local id path pipe pid detail title failure out=()
  while read -r id path; do
    get gitlab "$api/projects/$id/pipelines?per_page=30&updated_after=$ci_since" "$work/pipes" "${auth[@]}" || continue
    while read -r pipe; do
      pid="$(jq -r .id <<<"$pipe")"
      # The list has no author, timing or title: the pipeline (ETag), and the commit by SHA, once.
      get gitlab "$api/projects/$id/pipelines/$pid" "$work/detail" "${auth[@]}" || echo '{}' >"$work/detail"
      detail="$(jq -c . "$work/detail" 2>/dev/null || echo '{}')"
      title=""
      if get_once gitlab "$api/projects/$id/repository/commits/$(jq -r .sha <<<"$pipe")" "$work/commit" "${auth[@]}"; then
        title="$(jq -r '.title // ""' "$work/commit" 2>/dev/null || true)"
      fi
      failure=null
      if [ "$(jq -r .status <<<"$pipe")" = failed ] && get_once gitlab "$api/projects/$id/pipelines/$pid/jobs?scope%5B%5D=failed" "$work/fjobs" "${auth[@]}"; then
        failure="$(jq -c '.[0] | if . == null then null else {job: .name, step: (.stage + (if .failure_reason then " · " + .failure_reason else "" end))} end' "$work/fjobs" 2>/dev/null || echo null)"
      fi
      out+=("$(jq -c --arg repo "$path" --arg title "$title" --argjson d "$detail" --argjson f "${failure:-null}" '
        {repo: $repo, ref: .ref, event: .source, created: .created_at,
         started: ($d.started_at // .created_at), finished: ($d.finished_at // .updated_at),
         name: (.ref | if test("^refs/merge-requests/[0-9]+/head$") then "!" + split("/")[2] else . end),
         url: .web_url, title: $title, actor: ($d.user.username // ""), attempt: null,
         failure: $f, status: .status}' <<<"$pipe")")
    done < <(jq -c 'group_by(.ref) | map(max_by(.created_at)) | .[]' "$work/pipes")
  done < <(jq -r '.[] | "\(.id) \(.path_with_namespace)"' "$work/projects")
  printf '%s\n' "${out[@]}" | jq -s '{ok: true, error: "", via: "api", runs: (map(select(. != null)) | map(. + {state: (
      if .status == "running" then "running"
      elif (.status | IN("created", "pending", "preparing", "waiting_for_resource", "scheduled")) then "queued"
      elif .status == "success" then "success"
      elif .status == "failed" then "failure"
      elif .status == "canceled" then "cancelled"
      else "skipped" end)}) | map(del(.status)) | sort_by(.created) | reverse)}'
}

# A source that fails keeps its last good picture, marked stale since the FIRST failure (so the
# document does not change on every failing run); "no-token" is a setup problem, shown as is.
ci_served() { # ci_served KEY FRESH_JSON_FILE PREVIOUS_JSON_FILE
  jq -n --slurpfile fresh "$2" --slurpfile prev "$3" --arg k "$1" --argjson now "$now" '
    $fresh[0] as $f | ($prev[0][$k] // null) as $p
    | if $f.ok then $f + {stale: false, staleSince: null}
      elif ($f.error != "no-token") and $p != null and ($p.runs | length) > 0 then
        $p + {ok: true, stale: true, error: $f.error, staleSince: ($p.staleSince // $now)}
      else $f + {stale: false, staleSince: null} end'
}

ci() {
  due ci || return 0
  ci_github >"$work/ci.gh"
  ci_gitlab >"$work/ci.gl"
  glance-feed-read ci >"$work/ci.prev" 2>/dev/null || echo '{}' >"$work/ci.prev"
  jq -n --slurpfile gh <(ci_served github "$work/ci.gh" "$work/ci.prev") \
    --slurpfile gl <(ci_served gitlab "$work/ci.gl" "$work/ci.prev") \
    '{github: $gh[0], gitlab: $gl[0]}' >"$work/ci.doc"
  put ci "github+gitlab" "$work/ci.doc"
  # A minute while something runs or waits, two otherwise.
  if jq -e '[.github.runs[], .gitlab.runs[]] | any(.state == "running" or .state == "queued")' "$work/ci.doc" >/dev/null; then
    again ci 60
  else
    again ci 120
  fi
}

# ── network: the house as the router sees it, over the LAN only (no internet), every 2 min ──
# Names come from the router's mirror in the repo (static DHCP hosts, WireGuard descriptions),
# which also defines what is KNOWN. Attacks on the exposed ports come from this machine's journal.
network() {
  due network || return 0
  again network 120
  local raw="$work/router"
  # ONE ssh round; nothing here needs root except wg-status, which sudoers allows without a
  # password. logread is NOT used: unprivileged, it hangs instead of failing.
  if ! timeout 20 ssh -o BatchMode=yes -o ConnectTimeout=6 router \
    'cat /tmp/dhcp.leases; echo @@; ip -4 neigh show dev br-lan; echo @@; cat /proc/sys/net/netfilter/nf_conntrack_count; echo @@; sudo -n /usr/bin/wg-status; echo @@; ip -6 neigh show dev br-lan' \
    >"$raw" 2>/dev/null; then
    fail network "router unreachable over ssh"
    return 0
  fi
  local leases neigh conntrack wg neigh6
  leases="$(awk 'BEGIN{RS="@@\n"} NR==1' "$raw")"
  neigh="$(awk 'BEGIN{RS="@@\n"} NR==2' "$raw")"
  conntrack="$(awk 'BEGIN{RS="@@\n"} NR==3' "$raw" | tr -dc 0-9)"
  wg="$(awk 'BEGIN{RS="@@\n"} NR==4' "$raw")"
  neigh6="$(awk 'BEGIN{RS="@@\n"} NR==5' "$raw")"

  # Known names: the static DHCP hosts and the WireGuard peers, from the mirror (one owner).
  local known="$work/known.tsv" peers="$work/peers.tsv"
  awk -F"'" '/^dhcp\.[^.]*\.name=/{split($0,a,"[.=]"); n[a[2]]=$2} /^dhcp\.[^.]*\.mac=/{split($0,a,"[.=]"); m[a[2]]=tolower($2)}
             END{for (k in m) if (k in n) print m[k] "\t" n[k]}' "$GLANCE_ROUTER_UCI/dhcp.conf" >"$known"
  awk -F"'" '/\.description=/{split($0,a,"[]\\[]"); d[a[2]]=$2} /\.public_key=/{split($0,a,"[]\\[]"); k[a[2]]=$2} /\.allowed_ips=/{split($0,a,"[]\\[]"); ip[a[2]]=$2}
             END{for (i in k) print k[i] "\t" d[i] "\t" ip[i]}' "$GLANCE_ROUTER_UCI/network.conf" >"$peers"

  # Devices: the neighbour table (who answers now) joined with the leases (names, IPs).
  # "192.168.1.111 lladdr a0:92:08:db:cf:d3 STALE" (no "dev" field once filtered by interface).
  printf '%s\n' "$neigh" | awk '$2 == "lladdr" && $4 != "FAILED" {print tolower($3) "\t" $1 "\t" $4}' >"$work/neigh.tsv"
  printf '%s\n' "$leases" | awk 'NF>=4 {print tolower($2) "\t" $3 "\t" $4}' >"$work/leases.tsv"
  # The inventory: a MAC never seen gets first_seen = now, except on the very first run, where
  # everything present is the baseline (first_seen = 0) and not "new".
  local baseline=0 mac ip name
  [ "$(sql "SELECT count(*) FROM devices")" = 0 ] && baseline=1
  while IFS=$'\t' read -r mac ip _; do
    name="$(awk -F'\t' -v m="$mac" '$1==m{print $2}' "$known")"
    [ -n "$name" ] || name="$(awk -F'\t' -v m="$mac" '$1==m && $3!="*"{print $3}' "$work/leases.tsv")"
    sql "INSERT INTO devices(mac, name, first_seen, last_seen, last_ip)
         VALUES ('$(q "$mac")', '$(q "$name")', $([ $baseline = 1 ] && echo 0 || echo "$now"), $now, '$(q "$ip")')
         ON CONFLICT(mac) DO UPDATE SET last_seen = excluded.last_seen, last_ip = excluded.last_ip,
           name = CASE WHEN excluded.name <> '' THEN excluded.name ELSE devices.name END"
  done <"$work/neigh.tsv"
  # Every address a device answers on, v4 and v6, so the threats source can name a log line's client.
  { cut -f1,2 "$work/neigh.tsv"; printf '%s\n' "$neigh6" | awk '$2 == "lladdr" && $4 != "FAILED" {print tolower($3) "\t" $1}'; } |
    awk -F'\t' -v now="$now" '$1 != "" && $2 != "" {gsub(/\x27/, "", $2); printf "INSERT INTO addresses(ip, mac, last_seen) VALUES (\x27%s\x27, \x27%s\x27, %d) ON CONFLICT(ip) DO UPDATE SET mac = excluded.mac, last_seen = excluded.last_seen;\n", $2, $1, now}' |
    sqlite3 -batch -cmd '.timeout 5000' "$db" >/dev/null
  local day_ago=$((now - 86400))
  sqlite3 -batch -json "$db" "SELECT mac, name, last_ip AS ip, first_seen, last_seen FROM devices WHERE last_seen >= $((now - 300)) ORDER BY name" </dev/null >"$work/online.json"
  [ -s "$work/online.json" ] || echo '[]' >"$work/online.json"
  cut -f1 "$known" | jq -R . | jq -s . >"$work/known.json"

  # WireGuard: the router's `wg-status` is a FIXED `wg show` (no arguments pass through sudo), so
  # its human output is parsed: per peer the key, "latest handshake: 35 minutes, 9 seconds ago" as
  # an absolute time, and "transfer: 274.99 MiB received, 1.43 GiB sent" in bytes. Peers are named
  # from the mirror; the endpoint is NOT kept, where someone connects from is not for a glance.
  printf '%s\n' "$wg" | awk -v now="$now" '
    function bytes(v, u) { return v * (u=="KiB"?1024:u=="MiB"?1048576:u=="GiB"?1073741824:u=="TiB"?1099511627776:1) }
    function flush() { if (key != "") print key "\t" hs "\t" rx "\t" tx; key=""; hs=0; rx=0; tx=0 }
    /^peer: / { flush(); key=$2 }
    /latest handshake:/ { s=0; for (i=3; i<=NF; i++) { n=$i+0; u=$(i+1);
        if (u ~ /^day/) s+=n*86400; else if (u ~ /^hour/) s+=n*3600; else if (u ~ /^minute/) s+=n*60; else if (u ~ /^second/) s+=n }
      hs = now - s }
    /transfer:/ { rx=bytes($2, $3); tx=bytes($5, $6) }
    END { flush() }' >"$work/wg.tsv"
  jq -Rn --rawfile peers "$peers" '
    ($peers | split("\n") | map(select(length>0) | split("\t") | {key: .[0], value: {name: .[1], ip: .[2]}}) | from_entries) as $p
    | [inputs | split("\t") | select(length >= 4)
       | {name: ($p[.[0]].name // "unknown peer"), ip: ($p[.[0]].ip // ""), handshake: (.[1] | tonumber), rx: (.[2] | tonumber), tx: (.[3] | tonumber)}]
    | sort_by(-.handshake)' <"$work/wg.tsv" >"$work/wg.json" 2>/dev/null || echo '[]' >"$work/wg.json"

  # Attacks on the exposed ports, last 24 h, from this machine's own journal (no network).
  journalctl -u sshd --since "@$day_ago" -o cat -q 2>/dev/null |
    grep -oE '(Failed (password|publickey)|Invalid user|authentication failure).* from ([0-9]{1,3}\.){3}[0-9]{1,3}' |
    grep -oE '([0-9]{1,3}\.){3}[0-9]{1,3}$' >"$work/ssh.ips" || true
  journalctl -u fail2ban --since "@$day_ago" -o cat -q 2>/dev/null | grep -cE '\] Ban ' >"$work/bans" || echo 0 >"$work/bans"

  if jq -n --slurpfile online "$work/online.json" --slurpfile known "$work/known.json" --slurpfile wg "$work/wg.json" \
    --rawfile ips "$work/ssh.ips" --arg bans "$(head -1 "$work/bans")" --arg conntrack "${conntrack:-0}" \
    --argjson now "$now" --argjson dayago "$day_ago" '
    ($known[0]) as $k
    | {devices: ($online[0] | map(. + {known: (.mac as $m | $k | index($m) != null),
                                        new: (.first_seen > $dayago)})
                 | sort_by((if .new then 0 elif (.known | not) then 1 else 2 end), ((.name // "") | ascii_downcase))),
       remote: ($wg[0] | map(. + {active: (.handshake > 0 and ($now - .handshake) < 180)})),
       connections: ($conntrack | tonumber),
       attacks: (($ips | split("\n") | map(select(length > 0))) as $l
                 | {sshFails: ($l | length), sshIps: ($l | unique | length),
                    top: ($l | group_by(.) | map({ip: .[0], n: length}) | sort_by(-.n) | .[0:3]),
                    bans: ($bans | tonumber? // 0)}),
       feeds: {dns: true, banip: true}}' >"$work/net.doc"; then
    put network "router+journal" "$work/net.doc"
  else
    fail network "network document unreadable"
  fi
}

# ── threats: the router's syslog (router-log.nix) read from where the last run stopped, LOCAL only ──
# The TIF and DoH lists are the ones adblock-fast blocks with (their URLs come from the router's
# mirror), refreshed every 12 h with an ETag, so a block can be told apart as threat, DoH or ad.
list_url() { # list_url NAME_PATTERN: the URL of the adblock-fast list whose name matches it
  local i
  i="$(grep -E "\.name='[^']*$1" "$GLANCE_ROUTER_UCI/adblock-fast.conf" | head -1 | grep -oE 'file_url\[[0-9]+\]')"
  [ -n "$i" ] && grep -F "@$i.url=" "$GLANCE_ROUTER_UCI/adblock-fast.conf" | cut -d"'" -f2
}
threats() {
  due threats || return 0
  again threats 60
  local log="$GLANCE_ROUTER_LOG" chunk="$work/chunk" lists="$dir/lists"
  [ -r "$log" ] || {
    fail threats "router log unreadable: $log"
    return 0
  }
  mkdir -p "$lists"
  if due threat_lists; then
    again threat_lists 43200
    local kind url
    for kind in tif doh; do
      url="$(list_url "$([ "$kind" = tif ] && echo 'Threat Intelligence' || echo 'DoH servers')")"
      if [ -n "$url" ] && get threats "$url" "$work/list"; then
        grep -vE '^(#|$)' "$work/list" >"$lists/$kind.txt"
      else
        again threat_lists 1800 # keep the copy we have, try sooner
      fi
    done
  fi

  # The new bytes only. After a rotation the rest of the old file (`.1`, compressed only a day
  # later) is read first; a line still being written is left for the next run.
  local inode size off prev partial=0
  inode="$(stat -c %i "$log")"
  size="$(stat -c %s "$log")"
  prev="$(state threats:inode)"
  off="$(state threats:offset)"
  off="${off:-0}"
  : >"$chunk"
  if [ "$prev" != "$inode" ]; then
    [ -n "$prev" ] && [ -r "$log.1" ] && [ "$(stat -c %i "$log.1")" = "$prev" ] && tail -c +"$((off + 1))" "$log.1" >>"$chunk"
    off=0
  elif [ "$size" -lt "$off" ]; then
    off=0
  fi
  tail -c +"$((off + 1))" "$log" | head -c "$((size - off))" >>"$chunk"
  if [ -s "$chunk" ] && [ "$(tail -c 1 "$chunk" | wc -l)" = 0 ]; then
    partial="$(tail -n 1 "$chunk" | wc -c)"
    head -c "-$partial" "$chunk" >"$chunk.whole" && mv "$chunk.whole" "$chunk"
  fi

  # One line per fact. Q: a query (day, client). B: a block by any list (time, client, name).
  # I/O: a banIP drop inbound or outbound (time, feed, source, destination:port).
  awk '
    function epoch(ts, d) { d = substr(ts, 1, 19); gsub(/[-T:]/, " ", d); return mktime(d) }
    $3 ~ /^dnsmasq\[/ && $5 ~ /\// {
      c = $5; sub(/\/[0-9]+$/, "", c)
      if ($6 ~ /^query\[/) print "Q\t" substr($1, 1, 10) "\t" c
      else if ($6 == "config" && $9 == "NXDOMAIN" && $7 !~ /\.lan$/) print "B\t" epoch($1) "\t" c "\t" tolower($7)
      next
    }
    /banIP\/(inbound|outbound)\// {
      dir = ""; feed = ""; src = ""; dst = ""; dpt = ""
      for (i = 1; i <= NF; i++) {
        if ($i ~ /^banIP\//) { split($i, p, "/"); dir = p[2]; feed = p[4]; sub(/:$/, "", feed); sub(/\.v[46]$/, "", feed) }
        else if ($i ~ /^SRC=/) src = substr($i, 5)
        else if ($i ~ /^DST=/) dst = substr($i, 5)
        else if ($i ~ /^DPT=/) dpt = substr($i, 5)
      }
      if (dir == "outbound") print "O\t" epoch($1) "\t" feed "\t" src "\t" dst (dpt ? ":" dpt : "")
      else if (dir == "inbound") print "I\t" epoch($1) "\t" feed "\t" src "\t" (dpt ? dpt : "-")
    }' "$chunk" >"$work/facts.tsv"

  # Which blocks were threats: every suffix of a blocked name against the wildcard lists.
  awk -F'\t' '$1 == "B" {print $4}' "$work/facts.tsv" | sort -u |
    awk '{n = split($0, l, "."); s = l[n]; print $0 "\t" s; for (i = n - 1; i >= 1; i--) { s = l[i] "." s; print $0 "\t" s }}' >"$work/suffixes.tsv"
  local kind
  for kind in tif doh; do
    if [ -s "$lists/$kind.txt" ] && [ -s "$work/suffixes.tsv" ]; then
      cut -f2 "$work/suffixes.tsv" | sort -u | grep -Fxf - "$lists/$kind.txt" >"$work/$kind.hit" || true
      awk -F'\t' 'NR == FNR {h[$0]; next} $2 in h {print $1}' "$work/$kind.hit" "$work/suffixes.tsv" | sort -u >"$work/$kind.names"
    else
      : >"$work/$kind.names"
    fi
  done

  {
    echo "BEGIN;"
    awk -F'\t' -v doh="$work/doh.names" -v tif="$work/tif.names" '
      BEGIN { while ((getline l < tif) > 0) t[l]; while ((getline l < doh) > 0) d[l] }
      function esc(v) { gsub(/\x27/, "", v); return "\x27" v "\x27" }
      function ev(ts, kind, client, target, feed) {
        printf "INSERT INTO threat_events(hour, kind, client, target, feed, n, first, last) VALUES (%d, %s, %s, %s, %s, 1, %d, %d) ON CONFLICT(hour, kind, client, target, feed) DO UPDATE SET n = n + 1, last = max(last, excluded.last);\n", int(ts / 3600) * 3600, esc(kind), esc(client), esc(target), esc(feed), ts, ts
      }
      $1 == "Q" { q[$2 "\t" $3]++ }
      $1 == "B" { b[strftime("%Y-%m-%d", $2) "\t" $3]++
                  if ($4 in t) ev($2, "dns-threat", $3, $4, "tif"); else if ($4 in d) ev($2, "dns-doh", $3, $4, "doh") }
      $1 == "O" { ev($2, "ip-out", $4, $5, $3) }
      $1 == "I" { ev($2, "ip-in", $4, $5, $3) }
      END {
        for (k in q) { split(k, x, "\t"); printf "INSERT INTO dns_daily(day, client, queries) VALUES (%s, %s, %d) ON CONFLICT(day, client) DO UPDATE SET queries = queries + excluded.queries;\n", esc(x[1]), esc(x[2]), q[k] }
        for (k in b) { split(k, x, "\t"); printf "INSERT INTO dns_daily(day, client, blocked) VALUES (%s, %s, %d) ON CONFLICT(day, client) DO UPDATE SET blocked = blocked + excluded.blocked;\n", esc(x[1]), esc(x[2]), b[k] }
      }' "$work/facts.tsv"
    # The position moves in the SAME transaction as the facts, so a crash never counts a line twice.
    echo "INSERT INTO state(key, value) VALUES ('threats:inode', '$inode'), ('threats:offset', '$((size - partial))') ON CONFLICT(key) DO UPDATE SET value = excluded.value;"
    # 30 days, the retention the owner chose, like the raw log's.
    echo "DELETE FROM threat_events WHERE hour < $((now - 30 * 86400));"
    echo "DELETE FROM dns_daily WHERE day < '$(date -d @$((now - 30 * 86400)) +%F)';"
    echo "COMMIT;"
  } | sqlite3 -batch -cmd '.timeout 5000' "$db" >/dev/null || {
    fail threats "could not store the router log's facts"
    return 0
  }

  # The document: the last 24 h, clients named through addresses -> devices.
  local since=$((now - 86400)) yday
  yday="$(date -d @"$since" +%F)"
  sqlite3 -batch -json -cmd '.timeout 5000' "$db" "
    WITH named AS (SELECT a.ip, coalesce(nullif(d.name, ''), a.mac) AS name FROM addresses a LEFT JOIN devices d ON d.mac = a.mac)
    SELECT e.kind, e.client, coalesce(n.name, CASE WHEN e.client IN ('127.0.0.1', '::1') THEN 'router' END) AS name,
           e.target, e.feed, sum(e.n) AS n, max(e.last) AS last
    FROM threat_events e LEFT JOIN named n ON n.ip = e.client
    WHERE e.last >= $since AND e.kind <> 'ip-in'
    GROUP BY e.kind, e.client, e.target, e.feed ORDER BY last DESC LIMIT 30" </dev/null >"$work/hits.json"
  sqlite3 -batch -json -cmd '.timeout 5000' "$db" "
    SELECT feed, sum(n) AS n, count(DISTINCT client) AS sources FROM threat_events
    WHERE kind = 'ip-in' AND last >= $since GROUP BY feed ORDER BY n DESC" </dev/null >"$work/inbound.json"
  sqlite3 -batch -json -cmd '.timeout 5000' "$db" "
    SELECT coalesce(sum(queries), 0) AS queries, coalesce(sum(blocked), 0) AS blocked, count(DISTINCT client) AS clients
    FROM dns_daily WHERE day >= '$yday'" </dev/null >"$work/dns.json"
  local f
  for f in hits inbound dns; do [ -s "$work/$f.json" ] || echo '[]' >"$work/$f.json"; done
  if jq -n --slurpfile hits "$work/hits.json" --slurpfile inbound "$work/inbound.json" --slurpfile dns "$work/dns.json" \
    --arg tif "$(wc -l <"$lists/tif.txt" 2>/dev/null || echo 0)" --arg doh "$(wc -l <"$lists/doh.txt" 2>/dev/null || echo 0)" '
    {dns: ($dns[0][0] // {queries: 0, blocked: 0, clients: 0}),
     hits: $hits[0],
     inbound: {drops: ($inbound[0] | map(.n) | add // 0), sources: ($inbound[0] | map(.sources) | add // 0), byFeed: $inbound[0]},
     lists: {tif: ($tif | tonumber), doh: ($doh | tonumber)}}' >"$work/threats.doc"; then
    put threats "router log" "$work/threats.doc"
  else
    fail threats "threats document unreadable"
  fi
}

weather
inmet_forecast
inmet_alerts
ci
network
threats
