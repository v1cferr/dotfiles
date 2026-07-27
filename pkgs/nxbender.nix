# nxBender — cliente FOSS (Python) pra VPNs SSL da SonicWall/Dell (NetExtender).
# Substituto FOSS do netExtender proprietário (que não está no nixpkgs) p/ a VPN da
# FAI. Estabelece o túnel SSL e sobe o pppd (PPP-over-SSL, como o NetExtender faz).
# Uso: sudo nxBender --server HOST:PORT -u USER -p SENHA -d DOMINIO [--fingerprint ...].
# Repo: https://github.com/abrasive/nxBender (IPv4 only; sem 2FA/auto-reconnect).
{ lib, python3Packages, fetchFromGitHub, ppp, makeWrapper }:

python3Packages.buildPythonApplication {
  pname = "nxbender";
  version = "0.3.0-unstable-2021-06-02";
  format = "setuptools"; # tem setup.py (legado), não pyproject

  src = fetchFromGitHub {
    owner = "abrasive";
    repo = "nxBender";
    rev = "69fdaeffcf16e63a96009c662397269c10c9b4e9";
    hash = "sha256-PusyOqqSQaV63LITeOR/G2nkc1tuvlj8l8I8Hp0Ako0=";
  };

  propagatedBuildInputs = with python3Packages; [ configargparse pyroute2 requests colorlog ];
  nativeBuildInputs = [ makeWrapper ];

  doCheck = false; # o repo não tem testes

  # pppd no PATH: o nxBender chama o pppd pra levantar a interface do túnel.
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
