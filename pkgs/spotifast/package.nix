# Spotifast: a native Spotify client (Rust/egui + librespot), the OFFICIAL release binary instead of a Rust build.
# Same layout and reasons as pkgs/zapfast (its sibling); what is dropped from the tarball: docs/notes/apps/spotifast.md
{
  lib,
  stdenv,
  fetchurl,
  autoPatchelfHook,
  makeBinaryWrapper,
  alsa-lib,
  pipewire,
  dbus,
  libxkbcommon,
  wayland,
  libGL,
  libx11,
  libxcursor,
  libxi,
  libxrandr,
  callPackage,
}:

let
  # version, url and hash: the ONLY file the bump writes. The hash is the one upstream publishes.
  source = lib.importJSON ./source.json;

  # dlopened at run time, so autoPatchelf never sees them: the same list upstream's flake wraps.
  runtimeLibs = lib.makeLibraryPath [
    dbus
    libxkbcommon
    wayland
    libGL
    libx11
    libxcursor
    libxi
    libxrandr
  ];
in
stdenv.mkDerivation {
  pname = "spotifast";
  inherit (source) version;

  src = fetchurl { inherit (source) url hash; };

  nativeBuildInputs = [
    autoPatchelfHook
    makeBinaryWrapper
  ];

  # What the binary links (NEEDED): libstdc++/libgcc_s plus the two audio backends.
  buildInputs = [
    stdenv.cc.cc.lib
    alsa-lib
    pipewire
  ];

  # A released artifact: keep it byte-identical to what upstream published.
  dontStrip = true;

  # `spotifast-portable.txt` stays behind: it turns on the in-app updater, which would try to
  # rewrite the store. The omarchy hook is for another distro's theming, so it goes too.
  installPhase = ''
    runHook preInstall
    install -Dm755 spotifast -t $out/bin
    install -Dm644 packaging/applications/spotifast.desktop -t $out/share/applications
    install -Dm644 packaging/icons/spotifast.svg -t $out/share/icons/hicolor/scalable/apps
    runHook postInstall
  '';

  postFixup = ''
    wrapProgram $out/bin/spotifast --prefix LD_LIBRARY_PATH : ${runtimeLibs}
  '';

  # What vendored-bump runs on `update`.
  passthru.updateScript = callPackage ./bump.nix { };

  meta = {
    description = "Fast native Spotify client (official release binary)";
    homepage = "https://spotifast.rocks";
    license = lib.licenses.mit;
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
    platforms = [ "x86_64-linux" ];
    mainProgram = "spotifast";
  };
}
