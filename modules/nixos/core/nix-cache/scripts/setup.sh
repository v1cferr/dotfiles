# shellcheck shell=bash
# nix-cache-setup: the one-time keys of the R2 binary cache. Every secret is READ without echo
# and goes straight to GitHub or Bitwarden, so none reaches the screen, a file in git or the store.
# The steps around it (the dashboard tokens, then sync-secrets): docs/notes/repo/nix-cache.md
repo="${1:?usage: nix-cache-setup <path-to-the-flake-repo>}"
dir="$repo/modules/nixos/core/nix-cache"
gh_repo="v1cferr/dotfiles"
key_name=$(jq -er .keyName "$dir/cache.json")

if ! bw status | jq -e '.status == "unlocked"' >/dev/null 2>&1; then
  echo "nix-cache-setup: Bitwarden is locked. Run: export BW_SESSION=\$(bw unlock --raw)" >&2
  exit 1
fi
gh auth status >/dev/null # fails loud when logged out

# A Bitwarden login item, refusing to overwrite: replacing a key is a decision, not a rerun.
bw_login() {
  if bw get item "$1" >/dev/null 2>&1; then
    echo "nix-cache-setup: Bitwarden already has \"$1\", left alone." >&2
    return 0
  fi
  # The values through the environment, not argv, where `ps` would show them.
  bw get template item |
    N="$1" U="$2" P="$3" jq '.type = 1 | .name = env.N | .notes = null
      | .login = { username: env.U, password: env.P, uris: [] }' |
    bw encode | bw create item >/dev/null
  echo "nix-cache-setup: Bitwarden item \"$1\" created."
}

# Reads without echo and prints the value; `read -p` prompts on stderr, so $(ask ...) works.
ask() {
  local value
  read -rsp "$1: " value
  echo >&2
  [ -n "$value" ] || { echo "nix-cache-setup: empty, stopping." >&2; exit 1; }
  printf '%s' "$value"
}

# 1. The signing key. The public half goes into git, the private one into GitHub and Bitwarden.
if [ -e "$dir/nix-cache.pub" ]; then
  echo "nix-cache-setup: $dir/nix-cache.pub exists, keeping the current signing key."
else
  secret=$(nix key generate-secret --key-name "$key_name")
  nix key convert-secret-to-public <<<"$secret" >"$dir/nix-cache.pub"
  gh secret set NIX_CACHE_SIGNING_KEY --repo "$gh_repo" <<<"$secret"
  bw_login "Nix Cache Signing Key" "$key_name" "$secret"
  unset secret
  echo "nix-cache-setup: signing key created; git add $dir/nix-cache.pub"
fi

# 2. The READ AND WRITE token, for CI only.
echo "R2 token with Object Read & Write on the bucket (CI):"
rw_id=$(ask "  Access Key ID")
rw_secret=$(ask "  Secret Access Key")
gh secret set R2_ACCESS_KEY_ID --repo "$gh_repo" <<<"$rw_id"
gh secret set R2_SECRET_ACCESS_KEY --repo "$gh_repo" <<<"$rw_secret"
unset rw_id rw_secret

# 3. The READ-ONLY token, for this machine, through Bitwarden -> sync-secrets -> sops.
echo "R2 token with Object Read only on the bucket (this machine):"
ro_id=$(ask "  Access Key ID")
ro_secret=$(ask "  Secret Access Key")
bw_login "Nix Cache R2 Read" "$ro_id" "$ro_secret"
unset ro_id ro_secret

bw sync >/dev/null
echo "nix-cache-setup: done. Next: sync-secrets, then rebuild."
