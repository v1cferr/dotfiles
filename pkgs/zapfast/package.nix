# ZapFast: a native WhatsApp client (Rust/egui), the OFFICIAL release binary instead of an 8-minute build.
# Why the binary, and what is dropped from the tarball: docs/notes/apps/zapfast.md
{
  lib,
  stdenv,
  fetchurl,
  autoPatchelfHook,
  makeBinaryWrapper,
  alsa-lib,
  pipewire,
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
  pname = "zapfast";
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

  # `zapfast-portable.txt` stays behind: it turns on the in-app updater, which would try to
  # rewrite the store. The omarchy hook is for another distro's theming, so it goes too.
  installPhase = ''
    runHook preInstall
    install -Dm755 zapfast -t $out/bin
    install -Dm644 packaging/applications/zapfast.desktop -t $out/share/applications
    install -Dm644 packaging/icons/zapfast.svg -t $out/share/icons/hicolor/scalable/apps
    runHook postInstall
  '';

  postFixup = ''
    wrapProgram $out/bin/zapfast --prefix LD_LIBRARY_PATH : ${runtimeLibs}
  '';

  # What vendored-bump runs on `update`.
  passthru.updateScript = callPackage ./bump.nix { };

  meta = {
    description = "Fast native WhatsApp client (official release binary)";
    homepage = "https://zapfast.rocks";
    license = with lib.licenses; [
      mit
      gpl2Only
    ];
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
    platforms = [ "x86_64-linux" ];
    mainProgram = "zapfast";
  };
}
