# shellcheck shell=bash
# dash-services-meta: the slow half of the services carousel (every 30 s). It resolves the catalog
# (~/.config/theme/dash-services.json, from dash/services.nix) into live state: per systemd unit its
# state, since when, restarts and cgroup; per compose project its containers, health and cgroups.
# Compose projects missing from the catalog are added as found. The fast half (CPU, RAM, I/O,
# tasks every 3 s) is the QML reading those cgroups directly: docs/notes/desktop/dash.md
set -uo pipefail

catalog="$(cat "${CATALOG:-$HOME/.config/theme/dash-services.json}" 2>/dev/null || echo '[]')"

# `systemctl show` on many units at once prints one key=value block per unit, blank-line separated.
show() {
  local scope="$1"
  shift
  [ "$#" -gt 0 ] || { echo '[]'; return; }
  systemctl "$scope" show --timestamp=unix \
    -p Id,ActiveState,SubState,ActiveEnterTimestamp,NRestarts,ControlGroup,MainPID "$@" 2>/dev/null |
    jq -R -s --arg scope "${scope#--}" '
      split("\n\n") | map(select(length > 0)
        | split("\n") | map(select(test("=")) | capture("^(?<key>[^=]+)=(?<value>.*)$")) | from_entries
        | {id: .Id, scope: $scope, state: .ActiveState, sub: .SubState,
           since: ((.ActiveEnterTimestamp // "") | ltrimstr("@") | tonumber? // null),
           restarts: ((.NRestarts // "0") | tonumber? // 0), cgroup: .ControlGroup})'
}

mapfile -t sys_units < <(jq -r '.[].system[]' <<<"$catalog")
mapfile -t usr_units < <(jq -r '.[].user[]' <<<"$catalog")
system_json="$(show --system "${sys_units[@]}")"
user_json="$(show --user "${usr_units[@]}")"

# Docker: one inspect of every compose container; nothing (not an error) when the daemon is away.
containers='[]'
if ids="$(docker ps -q --filter label=com.docker.compose.project 2>/dev/null)" && [ -n "$ids" ]; then
  # shellcheck disable=SC2086 # the ids are meant to split
  containers="$(docker inspect $ids 2>/dev/null | jq '[.[] | {
      project: .Config.Labels["com.docker.compose.project"], name: (.Name | ltrimstr("/")),
      state: .State.Status, health: (.State.Health.Status // null), restarts: .RestartCount,
      since: (.State.StartedAt | sub("\\.[0-9]+"; "") | fromdateiso8601? // null),
      cgroup: ("/system.slice/docker-" + .Id + ".scope")}]' || echo '[]')"
fi

jq -n --argjson cat "$catalog" --argjson sys "$system_json" --argjson usr "$user_json" \
  --argjson ctr "$containers" --arg now "$(date +%s)" '
  ($sys + $usr) as $units
  | ($cat | map(.compose // empty)) as $known
  | ($cat + ($ctr | map(.project) | unique | map(select(. as $p | $known | index($p) | not))
       | map({key: ., label: ., system: [], user: [], compose: ., url: null})))
  | map(. as $s
      | ($units | map(select(.id as $i | ($s.system + $s.user) | index($i)))) as $u
      | ($ctr | map(select(.project == $s.compose))) as $c
      | {key, label, url,
         kind: (if $s.compose then "compose" elif ($s.user | length) > 0 then "user" else "system" end),
         logs: (if $s.compose then {compose: $s.compose}
                else {unit: ((($s.system + $s.user)[0]) // null), user: (($s.user | length) > 0)} end),
         parts: (if $s.compose then ($c | map({name, state, health, restarts, since, cgroup}))
                 else ($u | map({name: (.id | sub("\\.service$"; "")), state, sub, restarts, since, cgroup})) end)}
      | . + {
          expected: (if .kind == "compose" then ([.parts[]] | length) else ($s.system + $s.user | length) end),
          running: ([.parts[] | select(.state == "active" or .state == "running")] | length),
          restarts: ([.parts[].restarts] | add // 0),
          since: ([.parts[].since | select(. != null and . > 0)] | min // null),
          unhealthy: ([.parts[] | select(.health == "unhealthy")] | length)})
  | map(. + {state: (if .running == 0 then "down"
                     elif .running < .expected or .unhealthy > 0 then "degraded"
                     else "up" end)})
  | {fetched: ($now | tonumber), services: .}'
