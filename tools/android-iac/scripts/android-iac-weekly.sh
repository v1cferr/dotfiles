#!/usr/bin/env bash
# The weekly unattended audit: a push to the phone (notify, ntfy) on drift or missing evidence,
# and after two weeks in a row the phone could not be reached: docs/notes/hardware/android-iac.md
set -euo pipefail # writeShellApplication sets it anyway; every expected failure is caught below

state="${XDG_STATE_HOME:-$HOME/.local/state}/android-iac"
misses="$state/weekly-misses"
mkdir -p "$state"

code=0
out="$(android-iac audit </dev/null 2>&1)" || code=$? # 1 and 3 are answers, not crashes
printf '%s\n' "$out" # the journal keeps the whole run: journalctl --user -u android-iac-weekly

# The rows a person should read: what drifted, and what could not be proven.
rows="$(grep -E '^(drift|unknown) ' <<<"$out" | sed -E 's/ {2,}/ /g' | head -n 8 || true)"

case "$code" in
  0 | 3)
    rm -f "$misses"
    if [[ -n $rows ]]; then
      notify -p default -T iphone "Edge 70 Fusion: evidence missing" "$rows"
    fi
    ;;
  1)
    rm -f "$misses"
    notify -p high -T warning "Edge 70 Fusion drifted" "$rows"
    ;;
  *)
    # Away from home, or wireless debugging off: one miss is normal, two in a row is a pattern.
    count=$(($(cat "$misses" 2>/dev/null || echo 0) + 1))
    echo "$count" >"$misses"
    if ((count >= 2)); then
      reason="$(grep -m1 '^android-iac:' <<<"$out" || echo "exit $code")"
      notify -p low -T iphone "Edge 70 Fusion: no audit for $count weeks" \
        "$reason. Turn wireless debugging back on at home, then: android-iac audit"
    fi
    ;;
esac
exit 0 # an unreachable phone is not a failed unit: the push is the signal
