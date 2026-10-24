# soloist-bump: Spotify's latest Soloist build into source.json. A build EXPIRES 90 days after it is
# made (exit 10), so this is what keeps the receiver alive: docs/notes/repo/version-bumps.md
{ mkVendoredBump }:

mkVendoredBump {
  pname = "soloist";

  # One unversioned URL, so the question is its Last-Modified, as a date: one HEAD, no download.
  latest = ''
    lm=$(curl -fsSLI https://soloist-builds.spotifycdn.com/soloist_release_x86_64.tar.gz |
      awk 'tolower($1) == "last-modified:" { $1 = ""; print }' | tail -1)
    date -ud "$lm" +%F
  '';

  # Nothing published to trust, so the hash comes from downloading the 13 MiB.
  resolve = ''
    url=https://soloist-builds.spotifycdn.com/soloist_release_x86_64.tar.gz
    jq -n --arg url "$url" --arg hash "$(prefetch "$url")" '{ $url, $hash }'
  '';
}
