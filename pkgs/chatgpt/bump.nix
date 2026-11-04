# chatgpt-bump: the newest build in OpenAI's apt repo into source.json, without downloading it.
# Why the apt index and not the channel: docs/notes/apps/chatgpt.md
{ mkVendoredBump, gzip }:

mkVendoredBump {
  pname = "chatgpt";
  runtimeInputs = [ gzip ];

  # The repo's Packages index, kept in $tmp so `resolve` reads the SAME answer. One package, one
  # stanza: the apt repo carries only the newest build.
  latest = ''
    curl -fsSL https://persistent.oaistatic.com/codex-app-prod/linux/deb/dists/stable/main/binary-amd64/Packages.gz \
      | gzip -dc >"$tmp/Packages"
    sed -n 's/^Version: //p' "$tmp/Packages" | head -n 1
  '';

  # The pool url is versioned (immutable), and the index publishes its sha256.
  resolve = ''
    file=$(sed -n 's/^Filename: //p' "$tmp/Packages" | head -n 1)
    hex=$(sed -n 's/^SHA256: //p' "$tmp/Packages" | head -n 1)
    jq -n --arg url "https://persistent.oaistatic.com/codex-app-prod/linux/deb/$file" \
      --arg hash "$(sri sha256 "$hex")" '{ $url, $hash }'
  '';
}
