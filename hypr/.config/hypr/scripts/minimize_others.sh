#!/usr/bin/env bash
set -euo pipefail

active_json="$(hyprctl -j activewindow)"
active_addr="$(jq -r '.address // empty' <<< "$active_json")"
current_ws_id="$(jq -r '.workspace.id // empty' <<< "$active_json")"
state_file="/tmp/hypr-minimized-ws-${current_ws_id}.list"
clients_json="$(hyprctl -j clients)"

# No focused window or invalid workspace.
if [[ -z "$active_addr" || -z "$current_ws_id" || "$current_ws_id" == "-1" ]]; then
  exit 0
fi

# Toggle restore: if we already have minimized windows tracked for this workspace,
# move them back and clear the state.
if [[ -s "$state_file" ]]; then
  while IFS= read -r addr; do
    [[ -n "$addr" ]] || continue
    hyprctl dispatch movetoworkspacesilent "${current_ws_id},address:${addr}" >/dev/null || true
  done < "$state_file"

  rm -f "$state_file"
  exit 0
fi

mapfile -t ws_other_addrs < <(
  jq -r --arg active_addr "$active_addr" --argjson ws "$current_ws_id" '
    .[]
    | select(.workspace.id == $ws)
    | select(.address != $active_addr)
    | .address
  ' <<< "$clients_json"
)

# If there are other windows in the current workspace, minimize them.
if (( ${#ws_other_addrs[@]} > 0 )); then
  printf '%s\n' "${ws_other_addrs[@]}" > "$state_file"

  for addr in "${ws_other_addrs[@]}"; do
    [[ -n "$addr" ]] || continue
    hyprctl dispatch movetoworkspacesilent "special:minimized,address:$addr" >/dev/null || true
  done

  # Do not keep empty state files (e.g., workspace had only one window).
  [[ -s "$state_file" ]] || rm -f "$state_file"
  exit 0
fi

# Fallback restore: if state file was lost but minimized windows still exist,
# bring them back to the current workspace.
mapfile -t minimized_addrs < <(
  jq -r '
    .[]
    | select(.workspace.id == -98)
    | .address
  ' <<< "$clients_json"
)

if (( ${#minimized_addrs[@]} > 0 )); then
  for addr in "${minimized_addrs[@]}"; do
    [[ -n "$addr" ]] || continue
    hyprctl dispatch movetoworkspacesilent "${current_ws_id},address:${addr}" >/dev/null || true
  done
fi
