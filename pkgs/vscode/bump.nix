# vscode-bump: the latest stable VS Code into source.json, without downloading it.
# Why a VERSIONED url and never /latest/: docs/notes/repo/flake.md
{ mkVendoredBump }:

mkVendoredBump {
  pname = "vscode";

  # The official update API, kept in $tmp so `resolve` reads the SAME answer. `productVersion` and
  # not `version`, which is the commit hash.
  latest = ''
    curl -fsSL https://update.code.visualstudio.com/api/update/linux-x64/stable/latest >"$tmp/api.json"
    jq -er .productVersion "$tmp/api.json"
  '';

  # The versioned url is immutable, and the API publishes its sha256 (measured identical, 26/09).
  resolve = ''
    jq -n --arg url "https://update.code.visualstudio.com/$version/linux-x64/stable" \
      --arg hash "$(sri sha256 "$(jq -er .sha256hash "$tmp/api.json")")" '{ $url, $hash }'
  '';
}
