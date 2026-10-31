# fai-meet-bump: the FAI's latest FAI Meet AppImage into source.json.
# Why a HEAD answers "did it change?" for free: docs/notes/apps/fai-meet.md
{ mkVendoredBump, gnused }:

let
  url = "https://meetings.sup.fai.ufscar.br/download/linux/FAI-Meet.AppImage";
in
mkVendoredBump {
  pname = "fai-meet";
  runtimeInputs = [ gnused ];

  # The pointer url names the release in its Content-Disposition (`FAI-Meet-0.5.0.AppImage`).
  latest = ''
    curl -fsSI ${url} | sed -n 's|^content-disposition:.*filename="FAI-Meet-\(.*\)\.AppImage".*|\1|Ip'
  '';

  # A POINTER url, so the hash is the only anchor: only a new version pays the 84 MiB download.
  resolve = ''
    jq -n --arg url ${url} --arg hash "$(prefetch ${url})" '{ $url, $hash }'
  '';
}
