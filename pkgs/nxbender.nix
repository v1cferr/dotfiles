# nxBender: FOSS client for the SonicWall SSL VPN (FAI), replacing the proprietary netExtender.
# What its 3 patches fix: docs/notes/repo/version-bumps.md
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

  # Three upstream fixes; each one is explained in the note.
  postPatch = ''
    substituteInPlace nxbender/sslconn.py \
      --replace-fail "self.s = ssl.wrap_socket(sock)" \
                     "self.s = ssl._create_unverified_context().wrap_socket(sock)"
    # pppd 2.5+ has no 'nomp' (it answers "unrecognized option"), and it was redundant anyway.
    substituteInPlace nxbender/ppp.py \
      --replace-fail "'nomp'," "# 'nomp' removed: pppd 2.5+ has no multilink (the option does not exist)"
    # SPLIT-TUNNEL: drops FAI's 0.0.0.0/0 so only their subnets go through the tunnel.
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
