# Soloist: Spotify's OFFICIAL headless Connect receiver, the local speaker spotifast hands playback to.
# Why it exists here (librespot's refused audio keys) and the 90-day expiry: docs/notes/apps/spotifast.md
{
  lib,
  stdenv,
  fetchurl,
  autoPatchelfHook,
  makeBinaryWrapper,
  libpulseaudio,
  callPackage,
}:

let
  # version, url and hash: the ONLY file the bump writes. The URL never changes, so the version is
  # the build's Last-Modified date, the same date `soloist --version` prints.
  source = lib.importJSON ./source.json;
in
stdenv.mkDerivation {
  pname = "soloist";
  inherit (source) version;

  src = fetchurl {
    inherit (source) url hash;
    name = "soloist-${source.version}.tar.gz"; # the URL is unversioned, the store path is not
  };
  sourceRoot = ".";

  nativeBuildInputs = [
    autoPatchelfHook
    makeBinaryWrapper
  ];

  # What the binary links (NEEDED): libatomic, beside glibc.
  buildInputs = [ stdenv.cc.cc.lib ];

  # A released artifact: keep it byte-identical to what upstream published.
  dontStrip = true;

  installPhase = ''
    runHook preInstall
    install -Dm755 soloist -t $out/bin
    install -Dm644 CHANGELOG.md THIRD_PARTY_LICENSES.txt -t $out/share/doc/soloist
    runHook postInstall
  '';

  # libpulse is dlopened (PipeWire answers it through pipewire-pulse), so autoPatchelf never sees it.
  postFixup = ''
    wrapProgram $out/bin/soloist --prefix LD_LIBRARY_PATH : ${lib.makeLibraryPath [ libpulseaudio ]}
  '';

  # What vendored-bump runs on `update`.
  passthru.updateScript = callPackage ./bump.nix { };

  meta = {
    description = "Spotify's headless Spotify Connect receiver (official release binary)";
    homepage = "https://github.com/spotify/soloist";
    license = lib.licenses.unfree;
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
    platforms = [ "x86_64-linux" ];
    mainProgram = "soloist";
  };
}
