# antigravity-ide-bump: the latest stable Antigravity IDE into source.json, without downloading it.
# Why the version is parsed from the url: docs/notes/apps/antigravity-ide.md
{ mkVendoredBump }:

mkVendoredBump {
  pname = "antigravity-ide";

  # The IDE's own update API, kept in $tmp so `resolve` reads the SAME answer. Its `version` is a
  # commit hash and `productVersion` is the VS Code base, so the release lives only in the url.
  latest = ''
    curl -fsSL https://antigravity-ide-auto-updater-974169037036.us-central1.run.app/api/update/linux-x64/stable/latest \
      >"$tmp/api.json"
    jq -er '.url | capture("/antigravity/stable/(?<v>[0-9.]+)-[0-9]+/").v' "$tmp/api.json"
  '';

  # The url is versioned (release plus build id), and the API publishes its sha256.
  resolve = ''
    jq -n --arg url "$(jq -er '.url | gsub(" "; "%20")' "$tmp/api.json")" \
      --arg hash "$(sri sha256 "$(jq -er .sha256hash "$tmp/api.json")")" '{ $url, $hash }'
  '';
}
