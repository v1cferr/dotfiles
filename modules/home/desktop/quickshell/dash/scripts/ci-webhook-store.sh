# shellcheck shell=bash
# ci-webhook-store: one GitLab "Pipeline Hook" payload ($1) -> one file per repo and ref under
# $STATE_DIRECTORY/gitlab, in the SAME run schema glance-feed's CI source writes, so the band reads the webhook
# copy exactly like the API one. Run by the webhook receiver (modules/nixos/services/ci-webhook.nix)
# only after it has checked X-Gitlab-Token. Why a webhook at all: docs/notes/desktop/dash.md
set -euo pipefail

payload="${1:-}"
[ -n "$payload" ] || exit 0
[ "$(jq -r '.object_kind // ""' <<<"$payload")" = pipeline ] || exit 0

dir="${STATE_DIRECTORY:?}/gitlab"
mkdir -p "$dir"

# GitLab's hook dates are "2026-10-06 20:01:38 UTC"; the API ones (and the band) are ISO 8601.
run="$(jq -c '
  def iso: if . == null then null else sub(" UTC$"; "Z") | sub(" "; "T") end;
  .object_attributes as $p
  | {id: $p.id, repo: .project.path_with_namespace, ref: $p.ref, event: $p.source,
     # A merge request pipeline is named like the API path names it: !N.
     name: (if .merge_request then "!" + (.merge_request.iid | tostring) else $p.ref end),
     created: ($p.created_at | iso),
     started: ([.builds[]?.started_at | select(. != null)] | min | iso) // ($p.created_at | iso),
     finished: ($p.finished_at | iso),
     url: (.project.web_url + "/-/pipelines/" + ($p.id | tostring)),
     title: (.commit.title // ""), actor: (.user.username // ""), attempt: null,
     failure: ([.builds[]? | select(.status == "failed")][0]
               | if . == null then null
                 else {job: .name, step: (.stage + (if .failure_reason then " · " + .failure_reason else "" end))} end),
     state: ($p.status
             | if . == "running" then "running"
               elif (. == "created" or . == "pending" or . == "preparing"
                     or . == "waiting_for_resource" or . == "scheduled") then "queued"
               elif . == "success" then "success"
               elif . == "failed" then "failure"
               elif . == "canceled" then "cancelled"
               else "skipped" end)}' <<<"$payload")"

key="$(jq -r '(.repo + "__" + .name) | gsub("[^A-Za-z0-9._-]"; "_")' <<<"$run")"
file="$dir/$key.json"

# Hooks can arrive out of order: an OLDER pipeline never overwrites a newer one on the same ref.
if [ -s "$file" ] && [ "$(jq -r .id "$file")" -gt "$(jq -r .id <<<"$run")" ]; then
  exit 0
fi
tmp="$(mktemp "$dir/.new.XXXXXX")"
printf '%s\n' "$run" >"$tmp"
chmod 0644 "$tmp"
mv "$tmp" "$file"
