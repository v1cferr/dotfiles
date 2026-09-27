# curseforge-bump: Overwolf's latest AppImage into source.json.
# Why the .deb answers "did it change?" for 256 KiB: docs/notes/repo/version-bumps.md
{
  mkVendoredBump,
  gnused,
  gnutar,
  xz,
  binutils,
}:

let
  base = "https://curseforge.overwolf.com/downloads";
in
mkVendoredBump {
  pname = "curseforge";
  runtimeInputs = [
    gnused
    gnutar
    xz # the .deb's control.tar.xz: GNU tar autodetects it, but needs the binary
    binutils # `ar`, since a .deb is an ar archive
  ];

  # ONLY the start of the .deb, where `control` sits. Through a FILE: tar autodetects only when it
  # can seek. `1.316.0~37372-37372` becomes `1.316.0-37372`, the AppImage's own spelling.
  latest = ''
    curl -fsSL -r 0-262143 -o "$tmp/head.deb" ${base}/curseforge-latest-linux.deb
    ar p "$tmp/head.deb" "$(ar t "$tmp/head.deb" | sed -n '/^control\.tar/p' | head -1)" >"$tmp/control.tar"
    tar -xOf "$tmp/control.tar" ./control | sed -n 's|^Version: \(.*\)$|\1|p' | sed 's|~|-|; s|-[0-9]*$||'
  '';

  # A POINTER url, so the hash is the only anchor: only a new version pays the 139 MiB download.
  resolve = ''
    url=${base}/curseforge-latest-linux.AppImage
    jq -n --arg url "$url" --arg hash "$(prefetch "$url")" '{ $url, $hash }'
  '';
}
