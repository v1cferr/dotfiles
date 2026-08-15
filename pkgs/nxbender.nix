# nxBender: a FOSS client (Python) for SonicWall/Dell SSL VPNs (NetExtender).
# A FOSS replacement for the proprietary netExtender (which is not in nixpkgs) for the FAI VPN. It
# establishes the SSL tunnel and brings up pppd (PPP-over-SSL, the way NetExtender does).
# Usage: sudo nxBender --server HOST:PORT -u USER -p PASSWORD -d DOMAIN [--fingerprint ...].
# Repo: https://github.com/abrasive/nxBender (IPv4 only; no 2FA, no auto-reconnect).
{
  lib,
  python3Packages,
  fetchFromGitHub,
  ppp,
  makeWrapper,
}:

python3Packages.buildPythonApplication {
  pname = "nxbender";
  version = "0.3.0-unstable-2021-06-02";
  format = "setuptools"; # it has a setup.py (legacy), not a pyproject

  src = fetchFromGitHub {
    owner = "abrasive";
    repo = "nxBender";
    rev = "69fdaeffcf16e63a96009c662397269c10c9b4e9";
    hash = "sha256-PusyOqqSQaV63LITeOR/G2nkc1tuvlj8l8I8Hp0Ako0=";
  };

  propagatedBuildInputs = with python3Packages; [
    configargparse
    pyroute2
    requests
    colorlog
  ];
  nativeBuildInputs = [ makeWrapper ];

  # Python 3.12+ REMOVED ssl.wrap_socket, so nxBender's tunnel broke (AttributeError). Swapped for
  # the modern API: an unverified context (CERT_NONE), which is wrap_socket's original behavior
  # with no args (nxBender validates the server through its own fingerprint, not through the
  # certificate chain).
  postPatch = ''
    substituteInPlace nxbender/sslconn.py \
      --replace-fail "self.s = ssl.wrap_socket(sock)" \
                     "self.s = ssl._create_unverified_context().wrap_socket(sock)"
    # pppd 2.5+ (nixpkgs) does not have the 'nomp' option (which turns multilink off), so it gives
    # "unrecognized option". Multilink already comes OFF by default on a single link, so the
    # option is redundant.
    substituteInPlace nxbender/ppp.py \
      --replace-fail "'nomp'," "# 'nomp' removed: pppd 2.5+ has no multilink (the option does not exist)"
    # SPLIT-TUNNEL: FAI pushes a default route (0.0.0.0/0) that would throw ALL of the internet
    # through the tunnel. It filters the /0 out in setup_routes, so only FAI's internal subnets go
    # through the VPN and the user's internet keeps going over the LAN. (On teardown ppp0 goes
    # down and the kernel cleans up.)
    substituteInPlace nxbender/nx.py \
      --replace-fail "for route in set(self.routes):" \
                     "for route in [r for r in set(self.routes) if ipaddress.IPv4Network(unicode(r)).prefixlen != 0]:"
  '';

  doCheck = false; # the repo has no tests

  # pppd on the PATH: nxBender calls pppd to bring the tunnel's interface up.
  postFixup = ''
    wrapProgram $out/bin/nxBender --prefix PATH : ${lib.makeBinPath [ ppp ]}
  '';

  meta = {
    description = "FOSS client for SonicWall/Dell NetExtender SSL VPNs";
    homepage = "https://github.com/abrasive/nxBender";
    license = lib.licenses.gpl3Only;
    mainProgram = "nxBender";
  };
}
