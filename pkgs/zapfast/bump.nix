# zapfast-bump: crmne's latest ZapFast release into source.json, without downloading it.
# Why the redirect answers "did it change?" for free: docs/notes/repo/version-bumps.md
{ mkVendoredBump }:

mkVendoredBump {
  pname = "zapfast";

  # /releases/latest REDIRECTS to the tag, so the question is one HEAD with no API token spent.
  latest = ''
    tag=$(curl -fsSLI -o /dev/null -w '%{url_effective}' https://github.com/crmne/zapfast/releases/latest)
    echo "''${tag##*/v}"
  '';

  # The sha256 from the release's (signed) checksums.txt, so only a rebuild downloads the 37 MiB.
  resolve = ''
    name="zapfast-v$version-x86_64-unknown-linux-gnu.tar.gz"
    base="https://github.com/crmne/zapfast/releases/download/v$version"
    hex=$(curl -fsSL "$base/checksums.txt" | awk -v n="$name" '$2 == n { print $1 }')
    [ -n "$hex" ] || { echo "zapfast-bump: checksums.txt does not list $name" >&2; exit 1; }
    jq -n --arg url "$base/$name" --arg hash "$(sri sha256 "$hex")" '{ $url, $hash }'
  '';
}
