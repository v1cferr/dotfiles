# stack-wallet-bump: Cypher Stack's latest Stack Wallet AppImage into source.json, without downloading it.
# Why the API and not /releases/latest, and the two hashes it compares: docs/notes/repo/version-bumps.md
{ mkVendoredBump }:

mkVendoredBump {
  pname = "stack-wallet";

  # The repo also releases `mwebd-*` binaries, so the newest release is not always the wallet's.
  # Kept in $tmp, so `resolve` reads the SAME answer and cannot pair a version with another's hash.
  latest = ''
    curl -fsSL 'https://api.github.com/repos/cypherstack/stack_wallet/releases?per_page=20' |
      jq -e '[.[] | select((.tag_name | startswith("build_")) and (.prerelease | not) and (.draft | not))][0]' \
        >"$tmp/release.json"
    jq -er '.assets[].name | capture("^sw-v(?<v>.+)-linux\\.AppImage$").v' "$tmp/release.json"
  '';

  # GitHub's asset digest, cross-checked against the sha256 the release notes publish: two
  # statements that disagree stop the bump instead of pinning either.
  resolve = ''
    name="sw-v$version-linux.AppImage"
    asset=$(jq -ec --arg n "$name" '.assets[] | select(.name == $n)' "$tmp/release.json")
    hex=$(jq -er '.digest | ltrimstr("sha256:")' <<<"$asset")
    body=$(jq -er .body "$tmp/release.json")
    case "$body" in
      *"$name $hex"*) ;;
      *) echo "stack-wallet-bump: the release notes do not publish $hex for $name" >&2; exit 1 ;;
    esac
    jq -n --arg url "$(jq -er .browser_download_url <<<"$asset")" \
      --arg hash "$(sri sha256 "$hex")" '{ $url, $hash }'
  '';
}
