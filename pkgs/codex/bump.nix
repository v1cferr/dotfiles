# codex-bump: OpenAI's latest codex release into source.json.
# Why the redirect answers "did it change?" for free: docs/notes/repo/version-bumps.md
{ mkVendoredBump }:

mkVendoredBump {
  pname = "codex";

  # /releases/latest REDIRECTS to the tag, so the question is one HEAD with no API token spent.
  # A tag that is not `rust-v<semver>` leaves the whole URL behind, and the skeleton rejects it.
  latest = ''
    tag=$(curl -fsSLI -o /dev/null -w '%{url_effective}' https://github.com/openai/codex/releases/latest)
    echo "''${tag##*/rust-v}"
  '';

  # The `-package-` asset (see pkgs/codex/package.nix); only a new tag pays its 93 MiB download.
  resolve = ''
    url="https://github.com/openai/codex/releases/download/rust-v$version/codex-package-x86_64-unknown-linux-musl.tar.gz"
    jq -n --arg url "$url" --arg hash "$(prefetch "$url")" '{ $url, $hash }'
  '';
}
