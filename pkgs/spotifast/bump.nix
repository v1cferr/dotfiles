# spotifast-bump: crmne's latest Spotifast release into source.json, without downloading it.
# Why the redirect answers "did it change?" for free: docs/notes/repo/version-bumps.md
{ mkVendoredBump }:

mkVendoredBump {
  pname = "spotifast";

  # /releases/latest REDIRECTS to the tag, so the question is one HEAD with no API token spent.
  latest = ''
    tag=$(curl -fsSLI -o /dev/null -w '%{url_effective}' https://github.com/crmne/spotifast/releases/latest)
    echo "''${tag##*/v}"
  '';

  # The sha256 from the release's (signed) checksums.txt, so only a rebuild downloads the 19 MiB.
  resolve = ''
    name="spotifast-v$version-x86_64-unknown-linux-gnu.tar.gz"
    base="https://github.com/crmne/spotifast/releases/download/v$version"
    hex=$(curl -fsSL "$base/checksums.txt" | awk -v n="$name" '$2 == n { print $1 }')
    [ -n "$hex" ] || { echo "spotifast-bump: checksums.txt does not list $name" >&2; exit 1; }
    jq -n --arg url "$base/$name" --arg hash "$(sri sha256 "$hex")" '{ $url, $hash }'
  '';
}
