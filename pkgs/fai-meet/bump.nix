# fai-meet-bump: the FAI's latest FAI Meet AppImage into source.json.
# Why a HEAD answers "did it change?" for free: docs/notes/apps/fai-meet.md
{
  mkVendoredBump,
  gnused,
  iproute2,
}:

let
  url = "https://meetings.sup.fai.ufscar.br/download/linux/FAI-Meet.AppImage";
in
mkVendoredBump {
  pname = "fai-meet";
  runtimeInputs = [
    gnused
    iproute2
  ];

  # The host only answers through the FAI VPN, so without ppp0 the bump skips at once instead of
  # spending a connect timeout. The pointer url names the release in its Content-Disposition.
  latest = ''
    if ! ip -o link show ppp0 >/dev/null 2>&1; then
      echo "fai-meet-bump: FAI VPN down, not asking." >&2
      touch "$tmp/unreachable"
      exit 1
    fi
    curl -fsSI ${url} | sed -n 's|^content-disposition:.*filename="FAI-Meet-\(.*\)\.AppImage".*|\1|Ip'
  '';

  # A POINTER url, so the hash is the only anchor: only a new version pays the 84 MiB download.
  resolve = ''
    jq -n --arg url ${url} --arg hash "$(prefetch ${url})" '{ $url, $hash }'
  '';
}
