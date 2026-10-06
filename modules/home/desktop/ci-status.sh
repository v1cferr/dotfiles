# shellcheck shell=bash
# ci-status-json: the latest run of every workflow (GitHub) and pipeline ref (the FAI GitLab) that
# moved in the last DAYS, as ONE JSON document for the glance band (quickshell/Ci.qml).
# Both sources share a schema, so the QML never learns two vocabularies:
#   {repo, name, ref, state, event, created, url}, state = running|queued|success|failure|cancelled|skipped
# A source that fails reports {ok:false, error} and never takes the other one down with it.
# GITLAB_URL and GITLAB_TOKEN_FILE come from runtimeEnv (quickshell.nix).
set -uo pipefail

days="${1:-7}"
since="$(date -u -d "$days days ago" +%Y-%m-%dT%H:%M:%SZ)"

# ===== GitHub: gh's own login, so no second token =====
github() {
  local repos
  # pushed_at only narrows the candidates; the run filter below is what decides.
  if ! repos="$(gh api 'user/repos?per_page=100&affiliation=owner,collaborator,organization_member&sort=pushed' \
    --jq ".[] | select(.archived | not) | select(.pushed_at >= \"$since\") | .full_name" 2>/dev/null)"; then
    jq -n '{ok: false, error: "auth", runs: []}'
    return
  fi
  local r
  for r in $repos; do
    # Dependabot's update jobs (event "dynamic") are bookkeeping, not CI.
    gh api "repos/$r/actions/runs?per_page=30&created=>=${since%T*}" --jq "
      [.workflow_runs[] | select(.event != \"dynamic\")]
      | group_by(.workflow_id) | map(max_by(.created_at))
      | map({repo: \"$r\", name: .name, ref: .head_branch, event: .event, created: .created_at,
             url: .html_url, status: .status, conclusion: .conclusion})" 2>/dev/null || echo '[]'
  done | jq -s '{ok: true, error: "", runs: (add // [] | map(. + {state: (
      if .status == "in_progress" then "running"
      elif .status != "completed" then "queued"
      elif .conclusion == "success" then "success"
      elif (.conclusion == "failure" or .conclusion == "timed_out" or .conclusion == "startup_failure") then "failure"
      elif .conclusion == "cancelled" then "cancelled"
      else "skipped" end)}) | map(del(.status, .conclusion)) | sort_by(.created) | reverse)}'
}

# ===== GitLab (git.sup): only behind the FAI VPN, read_api token from sops =====
gitlab() {
  if [ ! -r "$GITLAB_TOKEN_FILE" ]; then
    jq -n '{ok: false, error: "no-token", runs: [], runners: null}'
    return
  fi
  local token projects
  token="$(<"$GITLAB_TOKEN_FILE")"
  api() { curl -sS -m 8 --fail -H "PRIVATE-TOKEN: $token" "$GITLAB_URL/api/v4/$1"; }
  # Off the VPN the name still resolves but nothing answers: one short probe, not a timeout per project.
  if ! curl -s -m 4 -o /dev/null "$GITLAB_URL/api/v4/version"; then
    jq -n '{ok: false, error: "unreachable", runs: [], runners: null}'
    return
  fi
  if ! projects="$(api "projects?membership=true&simple=true&per_page=100&last_activity_after=$since" 2>/dev/null)"; then
    jq -n '{ok: false, error: "auth", runs: [], runners: null}'
    return
  fi
  local runs runners id path
  runs="$(jq -r '.[] | "\(.id) \(.path_with_namespace)"' <<<"$projects" | while read -r id path; do
    api "projects/$id/pipelines?per_page=30&updated_after=$since" 2>/dev/null |
      jq --arg repo "$path" 'group_by(.ref) | map(max_by(.created_at))
        | map({repo: $repo, name: "pipeline", ref: .ref, event: .source, created: .created_at,
               url: .web_url, status: .status})' || echo '[]'
  done | jq -s 'add // [] | map(. + {state: (
      if .status == "running" then "running"
      elif (.status == "created" or .status == "pending" or .status == "preparing"
            or .status == "waiting_for_resource" or .status == "scheduled") then "queued"
      elif .status == "success" then "success"
      elif .status == "failed" then "failure"
      elif .status == "canceled" then "cancelled"
      else "skipped" end)}) | map(del(.status)) | sort_by(.created) | reverse')"
  # The runners this token can see; null when the API refuses, which is not the same as "0 online".
  runners="$(api 'runners?per_page=100' 2>/dev/null |
    jq '{online: map(select(.status == "online")) | length, total: length}' 2>/dev/null || echo null)"
  jq -n --argjson runs "$runs" --argjson runners "${runners:-null}" \
    '{ok: true, error: "", runs: $runs, runners: $runners}'
}

jq -n --arg now "$(date -u +%FT%TZ)" --argjson gh "$(github)" --argjson gl "$(gitlab)" \
  '{fetched: $now, github: $gh, gitlab: $gl}'
