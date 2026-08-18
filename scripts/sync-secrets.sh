#!/usr/bin/env bash
# It syncs the secrets from Bitwarden into secrets/secrets.yaml (sops), with no --impure.
# Adding one: Bitwarden, then 1 line in bitwarden-secrets.json, then: docs/notes/repo/secrets.md
set -euo pipefail

repo="$(git rev-parse --show-toplevel)"
map="$repo/secrets/bitwarden-secrets.json"
yaml="$repo/secrets/secrets.yaml"

# --yes skips the overwrite prompt, for a non-interactive run that means to rotate.
assume_yes=0
for arg in "$@"; do
  case "$arg" in
    -y | --yes) assume_yes=1 ;;
    *) echo "usage: $(basename "$0") [--yes]" >&2; exit 2 ;;
  esac
done

# sops comes from the devShell (flake.nix), which direnv enters on a `cd` into the repo.
# Checked HERE because without it the failure landed on the first `sops set`, already past
# the vault read, reading as "line NN: command not found" with no hint of what to do.
if ! command -v sops >/dev/null 2>&1; then
  echo "sops is not on PATH. Enter the devShell (direnv allow, or nix develop) and rerun," >&2
  echo "or: nix shell nixpkgs#sops -c $0" >&2
  exit 1
fi

if ! bw status | jq -e '.status == "unlocked"' >/dev/null 2>&1; then
  echo "Bitwarden is locked or logged out. Run:" >&2
  echo "  bw login                            # if you have not logged in yet" >&2
  echo "  export BW_SESSION=\$(bw unlock --raw)" >&2
  exit 1
fi

# The age key (root's) is read ONLY into the process' memory, it does not go to disk.
SOPS_AGE_KEY="$(sudo cat /var/lib/sops-nix/key.txt)"
export SOPS_AGE_KEY

# The file is decrypted ONCE, into JSON, instead of once per key: it is the same age key
# either way, and the per-key loop below stays a plain lookup.
# An EMPTY (or absent) file legitimately means "every key is new". A decrypt that FAILS does
# not: swallowing it into {} classified everything as new and turned the gate below off,
# which is the one failure this script must never have.
if [ -s "$yaml" ]; then
  if ! cur_json="$(sops -d --output-type json "$yaml")"; then
    echo "Could not decrypt $yaml (see the sops error above). Refusing to continue: with no" >&2
    echo "current values to compare against, every secret would look new and be overwritten." >&2
    exit 1
  fi
else
  cur_json='{}'
fi

# ── Pass 1: read both sides and classify. It writes NOTHING, so the prompt below can
# still describe the whole change instead of reporting damage already done.
declare -A spec_of=() vault_of=()
declare -a fresh=() changed=()
same=0
missing=0

while IFS=$'\t' read -r key spec; do
  [ -z "$key" ] && continue
  # spec = "Item" (the default field: password) OR "Item:field" ("duolingo.com:username", say)
  item="${spec%%:*}"
  field="password"
  case "$spec" in *:*) field="${spec##*:}" ;; esac
  # An item that is not there names itself and the rest still syncs. `bw` says only
  # "Not found." and set -e used to abort on it, so the one line you needed -- WHICH
  # item -- was the one line you did not get. Its stderr is dropped rather than
  # folded into $val: a warning on the happy path would become part of a secret.
  if ! val="$(bw get "$field" "$item" 2>/dev/null)"; then
    echo "  MISSING  $key  <-  Bitwarden item \"$item\" ($field): create it there, or drop the line from $(basename "$map")" >&2
    missing=$((missing + 1))
    continue
  fi
  spec_of["$key"]="\"$item\" ($field)"
  vault_of["$key"]="$val"
  # A key the vault and the file already agree on is SKIPPED, not re-set: sops keeps the
  # ciphertext of an unchanged value, and re-setting it would churn the diff for nothing.
  if cur="$(jq -er --arg k "$key" '.[$k]' <<< "$cur_json")"; then
    if [ "$cur" = "${vault_of["$key"]}" ]; then
      same=$((same + 1))
    else
      changed+=("$key")
    fi
  else
    fresh+=("$key")
  fi
done < <(jq -r 'to_entries[] | "\(.key)\t\(.value)"' "$map")

# ── The gate. A value that DIFFERS is the dangerous case: on 17/08 a run meant to add
# one topic silently reverted the FAI VPN password, and the VPN only died at the reboot.
if [ "${#changed[@]}" -gt 0 ]; then
  echo "" >&2
  echo "These $((${#changed[@]})) secret(s) DIFFER between the vault and $(basename "$yaml"):" >&2
  for key in "${changed[@]}"; do
    echo "  ~  $key  <-  Bitwarden: ${spec_of["$key"]}" >&2
  done
  echo "" >&2
  echo "Bitwarden wins, so the file's value is LOST. That is right after a rotation you" >&2
  echo "did in the vault, and wrong if you edited sops directly and the vault is stale." >&2
  if [ "$assume_yes" = 1 ]; then
    echo "--yes given: overwriting." >&2
  elif [ -t 0 ]; then
    read -r -p "Overwrite with the vault's value? [y/N] " ans
    case "$ans" in
      y | Y | yes | YES) ;;
      *) echo "Aborted, nothing was written." >&2; exit 1 ;;
    esac
  else
    echo "Refusing to overwrite with no tty. Re-run with --yes if that is what you mean." >&2
    exit 1
  fi
fi

# ── Pass 2: write. Only what is new or was just confirmed reaches `sops set`.
n=0
for key in ${fresh[@]+"${fresh[@]}"} ${changed[@]+"${changed[@]}"}; do
  sops set "$yaml" "[\"$key\"]" "\"${vault_of["$key"]}\""
  echo "  ok  $key  <-  Bitwarden: ${spec_of["$key"]}"
  n=$((n + 1))
done
if [ "$same" -gt 0 ]; then
  echo "  --  $same already matched the vault, left alone"
fi

git -C "$repo" add secrets/secrets.yaml secrets/bitwarden-secrets.json
echo ""

# Non-zero on a partial sync, so a `sync-secrets && git commit && nixos-rebuild`
# chain stops here instead of committing a half-synced state.
if [ "$missing" -gt 0 ]; then
  echo "$n synced, $missing missing. Fix those before applying: a secret the index" >&2
  echo "declares and the vault does not have stays inert, so it would fail at use." >&2
  exit 1
fi

if [ "$n" -eq 0 ]; then
  echo "Nothing to do: all $same secret(s) already match the vault."
  exit 0
fi

echo "$n secret(s) synced. Apply them with:"
# $HOSTNAME is a BUILTIN, so it does not depend on the PATH (writeShellApplication's
# runtimeInputs is strict). It used to name a host that died in the cutover.
echo "  sudo nixos-rebuild switch --flake .#$HOSTNAME"
