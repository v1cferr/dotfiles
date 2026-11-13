# soloist-bump: Spotify's latest Soloist build into source.json. A build EXPIRES 90 days after it is
# made (exit 10), so this is what keeps the receiver alive: docs/notes/repo/version-bumps.md
{ mkVendoredBump }:

mkVendoredBump {
  pname = "soloist";

  # One unversioned URL, so the question is its Last-Modified: one HEAD, no download. Date AND time,
  # since Spotify republishes the same day (05/11/2026), and a bare date kept the stale hash.
  latest = ''
    lm=$(curl -fsSLI https://soloist-builds.spotifycdn.com/soloist_release_x86_64.tar.gz |
      awk 'tolower($1) == "last-modified:" { $1 = ""; print }' | tail -1)
    date -ud "$lm" +%F.%H%M%S
  '';

  # Nothing published to trust, so the hash comes from downloading the 13 MiB. Under package.nix's
  # store name: the URL is republished in place, and a second download hit a new hash (11/11/2026).
  resolve = ''
    url=https://soloist-builds.spotifycdn.com/soloist_release_x86_64.tar.gz
    jq -n --arg url "$url" --arg hash "$(prefetch "$url" "soloist-$version.tar.gz")" '{ $url, $hash }'
  '';
}
