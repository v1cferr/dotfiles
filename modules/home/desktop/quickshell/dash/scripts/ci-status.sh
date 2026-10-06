# shellcheck shell=bash
# ci-status-json: the latest run of every workflow (GitHub) and pipeline ref (the FAI GitLab) that
# moved in the last DAYS, as ONE JSON document for the glance band (dash/Ci.qml).
# Both sources share a schema, so the QML never learns two vocabularies:
#   {repo, name, ref, state, event, created, started, finished, url, title, actor, attempt, failure}
#   state = running|queued|success|failure|cancelled|skipped, failure = {job, step} or null
# A source that fails reports {ok:false, error} and never takes the other one down with it; when it
# has answered before, its last good picture is served instead, marked stale (docs: dash.md).
# GITLAB_URL, GITLAB_TOKEN_FILE and WEBHOOK_DIR come from runtimeEnv (quickshell.nix).
set -uo pipefail

days="${1:-7}"
since="$(date -u -d "$days days ago" +%Y-%m-%dT%H:%M:%SZ)"
now="$(date -u +%FT%TZ)"
cache="${XDG_CACHE_HOME:-$HOME/.cache}/ci-status"
mkdir -p "$cache"

# ===== GitHub: gh's own login, so no second token =====
github() {
  local repos
  # pushed_at only narrows the candidates; the run filter below is what decides.
  if ! repos="$(gh api 'user/repos?per_page=100&affiliation=owner,collaborator,organization_member&sort=pushed' \
    --jq ".[] | select(.archived | not) | select(.pushed_at >= \"$since\") | .full_name" 2>/dev/null)"; then
    jq -n '{ok: false, error: "unreachable", runs: []}'
    return
  fi
  local r runs
  runs="$(for r in $repos; do
    # Dependabot's update jobs (event "dynamic") are bookkeeping, not CI.
    gh api "repos/$r/actions/runs?per_page=30&created=>=${since%T*}" --jq "
      [.workflow_runs[] | select(.event != \"dynamic\")]
      | group_by(.workflow_id) | map(max_by(.created_at))
      | map({repo: \"$r\", id: .id, name: .name, ref: .head_branch, event: .event,
             created: .created_at, started: .run_started_at, finished: .updated_at, url: .html_url,
             title: .display_title, actor: .actor.login, attempt: .run_attempt,
             status: .status, conclusion: .conclusion})" 2>/dev/null || echo '[]'
  done | jq -s 'add // [] | map(. + {state: (
      if .status == "in_progress" then "running"
      elif .status != "completed" then "queued"
      elif .conclusion == "success" then "success"
      elif (.conclusion == "failure" or .conclusion == "timed_out" or .conclusion == "startup_failure") then "failure"
      elif .conclusion == "cancelled" then "cancelled"
      else "skipped" end)}) | map(del(.status, .conclusion)) | sort_by(.created) | reverse')"
  # What broke, for the failures only: one extra call each, the first failed job and its failed step.
  local run failure
  runs="$(jq -c '.[]' <<<"$runs" | while read -r run; do
    failure=null
    if [ "$(jq -r .state <<<"$run")" = failure ]; then
      failure="$(gh api "repos/$(jq -r .repo <<<"$run")/actions/runs/$(jq -r .id <<<"$run")/jobs?filter=latest" \
        --jq '[.jobs[] | select(.conclusion == "failure")][0]
              | if . == null then null
                else {job: .name, step: ([.steps[]? | select(.conclusion == "failure") | .name][0])} end' \
        2>/dev/null || echo null)"
    fi
    jq -c --argjson f "${failure:-null}" '. + {failure: $f} | del(.id)' <<<"$run"
  done | jq -s '.')"
  jq -n --argjson runs "$runs" '{ok: true, error: "", runs: $runs}'
}

# ===== GitLab (git.sup): only behind the FAI VPN, read_api token from sops =====
gitlab() {
  if [ ! -r "$GITLAB_TOKEN_FILE" ]; then
    jq -n '{ok: false, error: "no-token", runs: []}'
    return
  fi
  local token projects
  token="$(<"$GITLAB_TOKEN_FILE")"
  api() { curl -sS -m 8 --fail -H "PRIVATE-TOKEN: $token" "$GITLAB_URL/api/v4/$1"; }
  # Off the VPN the name still resolves but nothing answers: one short probe, not a timeout per project.
  # Then the pipeline hook's copy (ci-webhook-store) is the source: live, just pushed instead of pulled.
  if ! curl -s -m 4 -o /dev/null "$GITLAB_URL/api/v4/version"; then
    local hooked=("$WEBHOOK_DIR"/*.json) # stays the literal pattern when the folder is empty
    if [ -e "${hooked[0]}" ]; then
      jq -s --arg since "$since" '{ok: true, error: "", via: "webhook",
        runs: (map(select(.created >= $since)) | map(del(.id)) | sort_by(.created) | reverse)}' "${hooked[@]}"
    else
      jq -n '{ok: false, error: "unreachable", runs: []}'
    fi
    return
  fi
  if ! projects="$(api "projects?membership=true&simple=true&per_page=100&last_activity_after=$since" 2>/dev/null)"; then
    jq -n '{ok: false, error: "auth", runs: []}'
    return
  fi
  local runs id path pipe detail title failure
  runs="$(jq -r '.[] | "\(.id) \(.path_with_namespace)"' <<<"$projects" | while read -r id path; do
    api "projects/$id/pipelines?per_page=30&updated_after=$since" 2>/dev/null |
      jq -c 'group_by(.ref) | map(max_by(.created_at)) | .[]' |
      while read -r pipe; do
        # The list carries no author, duration or commit title: one call for the pipeline, one for
        # the commit, and one more for the failed jobs when it failed.
        detail="$(api "projects/$id/pipelines/$(jq -r .id <<<"$pipe")" 2>/dev/null || echo '{}')"
        title="$(api "projects/$id/repository/commits/$(jq -r .sha <<<"$pipe")" 2>/dev/null | jq -r '.title // ""' || true)"
        failure=null
        if [ "$(jq -r .status <<<"$pipe")" = failed ]; then
          failure="$(api "projects/$id/pipelines/$(jq -r .id <<<"$pipe")/jobs?scope%5B%5D=failed" 2>/dev/null |
            jq '.[0] | if . == null then null else {job: .name, step: (.stage + (if .failure_reason then " · " + .failure_reason else "" end))} end' ||
            echo null)"
        fi
        jq -c --arg repo "$path" --arg title "$title" --argjson d "$detail" --argjson f "${failure:-null}" '
          {repo: $repo, ref: .ref, event: .source, created: .created_at,
           started: ($d.started_at // .created_at), finished: ($d.finished_at // .updated_at),
           # A merge request pipeline runs on refs/merge-requests/N/head: GitLab calls it !N.
           name: (.ref | if test("^refs/merge-requests/[0-9]+/head$") then "!" + split("/")[2] else . end),
           url: .web_url, title: $title, actor: ($d.user.username // ""), attempt: null,
           failure: $f, status: .status}' <<<"$pipe"
      done
  done | jq -s 'map(. + {state: (
      if .status == "running" then "running"
      elif (.status == "created" or .status == "pending" or .status == "preparing"
            or .status == "waiting_for_resource" or .status == "scheduled") then "queued"
      elif .status == "success" then "success"
      elif .status == "failed" then "failure"
      elif .status == "canceled" then "cancelled"
      else "skipped" end)}) | map(del(.status)) | sort_by(.created) | reverse')"
  # No runner health here: the FAI runner is instance-wide, and a read_api token only sees its own.
  jq -n --argjson runs "$runs" '{ok: true, error: "", via: "api", runs: $runs}'
}

# A good answer is stamped and kept; a failed one falls back to the last kept one, marked stale.
# "no-token" never does: it is a setup problem to show, not an outage to paper over.
served() {
  local name="$1" json="$2"
  if [ "$(jq -r .ok <<<"$json")" = true ]; then
    jq --arg t "$now" '. + {asOf: $t, stale: false}' <<<"$json" | tee "$cache/$name.json"
  elif [ "$(jq -r .error <<<"$json")" != no-token ] && [ -s "$cache/$name.json" ]; then
    jq --arg e "$(jq -r .error <<<"$json")" '. + {stale: true, error: $e}' "$cache/$name.json"
  else
    jq '. + {asOf: null, stale: false}' <<<"$json"
  fi
}

jq -n --arg now "$now" --argjson gh "$(served github "$(github)")" --argjson gl "$(served gitlab "$(gitlab)")" \
  '{fetched: $now, github: $gh, gitlab: $gl}'
