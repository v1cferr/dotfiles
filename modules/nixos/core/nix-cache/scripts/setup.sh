# shellcheck shell=bash
# nix-cache-setup: every key of the R2 binary cache in one run. The R2 tokens are created through
# the API, and no secret reaches the screen, argv, a file in git or the store.
# What it creates and where each piece lives: docs/notes/repo/nix-cache.md
shopt -s inherit_errexit # a failure inside $(...) stops the run too
repo="${1:?usage: nix-cache-setup <path-to-the-flake-repo>}"
dir="$repo/modules/nixos/core/nix-cache"
gh_repo="v1cferr/dotfiles"
account=$(jq -er .account "$dir/cache.json")
bucket=$(jq -er .bucket "$dir/cache.json")
key_name=$(jq -er .keyName "$dir/cache.json")
bootstrap_item="Cloudflare API Token Creator"

if ! bw status | jq -e '.status == "unlocked"' >/dev/null 2>&1; then
  echo "nix-cache-setup: Bitwarden is locked. Run: export BW_SESSION=\$(bw unlock --raw)" >&2
  exit 1
fi
gh auth status >/dev/null # fails loud when logged out
bw sync >/dev/null

# A Bitwarden login item. The values go through the environment, not argv, where `ps` shows them.
bw_login() {
  bw get template item |
    N="$1" U="$2" P="$3" jq '.type = 1 | .name = env.N | .notes = null
      | .login = { username: env.U, password: env.P, uris: [] }' |
    bw encode | bw create item >/dev/null
  echo "nix-cache-setup: Bitwarden item \"$1\" created."
}

# The Cloudflare API with the bootstrap token: the header comes through a /dev/fd path, so argv
# shows the path and never the token.
cf() { # method, path, [json body]
  curl -fsS -X "$1" "https://api.cloudflare.com/client/v4$2" \
    -H @<(printf 'Authorization: Bearer %s\nContent-Type: application/json\n' "$cf_token") \
    ${3:+--data-binary "$3"}
}

# 1. The signing key. The public half goes into git, the private one into GitHub and Bitwarden.
if [ -e "$dir/nix-cache.pub" ]; then
  echo "nix-cache-setup: nix-cache.pub exists, keeping the current signing key."
else
  secret=$(nix key generate-secret --key-name "$key_name")
  nix key convert-secret-to-public <<<"$secret" >"$dir/nix-cache.pub"
  gh secret set NIX_CACHE_SIGNING_KEY --repo "$gh_repo" <<<"$secret"
  bw_login "Nix Cache Signing Key" "$key_name" "$secret"
  unset secret
fi

# 2. The two R2 tokens, unless both already exist: replacing one is a decision, not a rerun.
# Captured first: `gh | grep -q` under pipefail fails when grep closes the pipe early.
gh_secrets=$(gh secret list --repo "$gh_repo" --json name --jq '.[].name')
if bw get item "Nix Cache R2 Read" >/dev/null 2>&1 && grep -qx R2_ACCESS_KEY_ID <<<"$gh_secrets"; then
  echo "nix-cache-setup: the R2 tokens exist, left alone."
else
  # The ONE thing made by hand, once: a token that may create tokens. Kept in Bitwarden after.
  if ! cf_token=$(bw get password "$bootstrap_item" 2>/dev/null); then
    echo "Once: dash.cloudflare.com, My Profile, API Tokens, Create Token, template"
    echo "\"Create Additional Tokens\". Paste it here (not shown):"
    read -rsp "  token: " cf_token
    echo
    bw_login "$bootstrap_item" "api.cloudflare.com" "$cf_token"
  fi

  groups=$(cf GET /user/tokens/permission_groups)
  group() { jq -er --arg n "$1" '.result[] | select(.name == $n) | .id' <<<"$groups"; }

  # A token scoped to the ONE bucket. Its id IS the S3 access key, sha256(value) the secret.
  mint() { # token name, permission group name -> "id secret" on stdout
    local body
    body=$(jq -n --arg n "$1" --arg g "$(group "$2")" \
      --arg r "com.cloudflare.edge.r2.bucket.${account}_default_${bucket}" \
      '{ name: $n, policies: [{ effect: "allow", resources: { ($r): "*" },
         permission_groups: [{ id: $g }] }] }')
    local resp id secret
    resp=$(cf POST /user/tokens "$body")
    id=$(jq -er .result.id <<<"$resp")
    secret=$(jq -er .result.value <<<"$resp" | tr -d '\n' | sha256sum | cut -d' ' -f1)
    printf '%s %s' "$id" "$secret"
  }

  creds=$(mint "nix-cache CI (read and write)" "Workers R2 Storage Bucket Item Write")
  read -r rw_id rw_secret <<<"$creds"
  gh secret set R2_ACCESS_KEY_ID --repo "$gh_repo" <<<"$rw_id"
  gh secret set R2_SECRET_ACCESS_KEY --repo "$gh_repo" <<<"$rw_secret"
  unset rw_id rw_secret

  creds=$(mint "nix-cache host (read only)" "Workers R2 Storage Bucket Item Read")
  read -r ro_id ro_secret <<<"$creds"
  bw_login "Nix Cache R2 Read" "$ro_id" "$ro_secret"
  unset ro_id ro_secret creds cf_token
  bw sync >/dev/null
fi

# 3. The read key into sops, and the public key staged: what is left is a commit and a rebuild.
(cd "$repo" && sync-secrets) # it finds the repo by the working directory
git -C "$repo" add "$dir/nix-cache.pub" "$repo/secrets/bitwarden-secrets.json" "$repo/secrets/secrets.yaml"
echo "nix-cache-setup: done. Staged: nix-cache.pub, the index and secrets.yaml. Next: rebuild."
