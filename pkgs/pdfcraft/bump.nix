# pdfcraft-bump: storytold's latest PdfCraft release into source.json, without downloading it.
# Same redirect trick as zapfast-bump: docs/notes/repo/version-bumps.md
{ mkVendoredBump }:

mkVendoredBump {
  pname = "pdfcraft";

  # /releases/latest REDIRECTS to the tag, so the question is one HEAD with no API token spent.
  latest = ''
    tag=$(curl -fsSLI -o /dev/null -w '%{url_effective}' https://github.com/storytold/pdfcraft/releases/latest)
    echo "''${tag##*/v}"
  '';

  # The sha256 from the release's (signed) SHA256SUMS.txt, so only a rebuild downloads the tarball.
  resolve = ''
    name="pdfcraft-$version-linux-x86_64.tar.gz"
    base="https://github.com/storytold/pdfcraft/releases/download/v$version"
    hex=$(curl -fsSL "$base/SHA256SUMS.txt" | awk -v n="$name" '$2 == n { print $1 }')
    [ -n "$hex" ] || { echo "pdfcraft-bump: SHA256SUMS.txt does not list $name" >&2; exit 1; }
    jq -n --arg url "$base/$name" --arg hash "$(sri sha256 "$hex")" '{ $url, $hash }'
  '';
}
