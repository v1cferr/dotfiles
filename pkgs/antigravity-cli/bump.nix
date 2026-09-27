# antigravity-cli-bump: Google's latest `agy` into source.json, without downloading it.
# Why the manifest's hash is enough: docs/notes/repo/version-bumps.md
{ mkVendoredBump }:

let
  base = "https://storage.googleapis.com/antigravity-public/antigravity-cli";
in
mkVendoredBump {
  pname = "antigravity-cli";

  # "Did it change?" costs 7 bytes: `latest` is a plain text file holding the version.
  latest = ''
    curl -fsSL ${base}/latest
  '';

  # The manifest carries the url (with its opaque build id) and the sha512 of every platform.
  resolve = ''
    m=$(curl -fsSL "${base}/$version/manifest.json" | jq -ec '.platforms."linux-x64"')
    jq -n --arg url "$(jq -er .url <<<"$m")" \
      --arg hash "$(sri sha512 "$(jq -er .sha512 <<<"$m")")" '{ $url, $hash }'
  '';
}
