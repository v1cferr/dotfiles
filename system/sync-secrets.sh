#!/usr/bin/env bash
# Sincroniza segredos do Bitwarden -> secrets/secrets.yaml (sops), sem --impure.
# Fonte da verdade: secrets/bitwarden-secrets.json (nome-no-sops -> item-no-Bitwarden).
# Fluxo pra adicionar segredo: cadastra no Bitwarden -> +1 linha no JSON -> sync-secrets
# -> nixos-rebuild (puro). O nix gera os sops.secrets a partir do JSON automaticamente.
set -euo pipefail

repo="$(git rev-parse --show-toplevel)"
map="$repo/secrets/bitwarden-secrets.json"
yaml="$repo/secrets/secrets.yaml"

if ! bw status | jq -e '.status == "unlocked"' >/dev/null 2>&1; then
  echo "Bitwarden travado ou deslogado. Rode:" >&2
  echo "  bw login                            # se ainda nao logou" >&2
  echo "  export BW_SESSION=\$(bw unlock --raw)" >&2
  exit 1
fi

# Chave age (root) lida SO pra memoria do processo — nao vai a disco.
SOPS_AGE_KEY="$(sudo cat /var/lib/sops-nix/key.txt)"
export SOPS_AGE_KEY

n=0
while IFS=$'\t' read -r key item; do
  [ -z "$key" ] && continue
  val="$(bw get password "$item")"
  sops set "$yaml" "[\"$key\"]" "\"$val\""
  echo "  ok  $key  <-  Bitwarden: \"$item\""
  n=$((n + 1))
done < <(jq -r 'to_entries[] | "\(.key)\t\(.value)"' "$map")

git -C "$repo" add secrets/secrets.yaml secrets/bitwarden-secrets.json
echo ""
echo "$n segredo(s) sincronizado(s). Aplique com:"
echo "  sudo nixos-rebuild switch --flake .#nixos-seagate"
