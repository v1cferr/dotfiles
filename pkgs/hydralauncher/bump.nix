# hydralauncher-bump: Hydra's latest AppImage into source.json, without downloading it.
# Why the redirect plus latest-linux.yml cost two small requests: docs/notes/apps/hydralauncher.md
{ mkVendoredBump, gnused }:

mkVendoredBump {
  pname = "hydralauncher";
  runtimeInputs = [ gnused ];

  # /releases/latest REDIRECTS to the tag, so the question is one HEAD with no API token spent.
  latest = ''
    tag=$(curl -fsSLI -o /dev/null -w '%{url_effective}' https://github.com/hydralauncher/hydra/releases/latest)
    echo "''${tag##*/v}"
  '';

  # electron-builder's latest-linux.yml carries the AppImage's sha512 already in base64, which IS
  # the SRI body, so only a rebuild downloads the 269 MiB.
  resolve = ''
    name="hydralauncher-$version.AppImage"
    base="https://github.com/hydralauncher/hydra/releases/download/v$version"
    b64=$(curl -fsSL "$base/latest-linux.yml" |
      sed -n "/url: $name\$/{n;s|^ *sha512: ||p;q}")
    [ -n "$b64" ] || { echo "hydralauncher-bump: latest-linux.yml does not list $name" >&2; exit 1; }
    jq -n --arg url "$base/$name" --arg hash "sha512-$b64" '{ $url, $hash }'
  '';
}
