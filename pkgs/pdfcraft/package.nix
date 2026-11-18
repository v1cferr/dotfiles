# PdfCraft: a PDF reader and editor in pure Rust (egui), the OFFICIAL release binary instead of a Rust build.
# Same layout as pkgs/zapfast; why it replaced Papers: docs/notes/apps/pdfcraft.md
{
  lib,
  stdenv,
  fetchurl,
  autoPatchelfHook,
  makeBinaryWrapper,
  dbus,
  libGL,
  wayland,
  libxkbcommon,
  libx11,
  libxcursor,
  libxi,
  libxrender,
  callPackage,
}:

let
  # version, url and hash: the ONLY file the bump writes. The hash is the one upstream publishes.
  source = lib.importJSON ./source.json;

  # dlopened at run time, so autoPatchelf never sees them: the sonames the binary itself names.
  runtimeLibs = lib.makeLibraryPath [
    dbus
    libGL # libEGL plus libGL (glvnd)
    wayland # libwayland-client plus libwayland-egl
    libxkbcommon
    libx11
    libxcursor
    libxi
    libxrender
  ];
in
stdenv.mkDerivation {
  pname = "pdfcraft";
  inherit (source) version;

  src = fetchurl { inherit (source) url hash; };

  nativeBuildInputs = [
    autoPatchelfHook
    makeBinaryWrapper
  ];

  # What the binaries link (NEEDED): glibc plus libgcc_s.
  buildInputs = [ stdenv.cc.cc.lib ];

  # A released artifact: keep it byte-identical to what upstream published.
  dontStrip = true;

  # The tarball is already an FHS prefix. share/pdfcraft/models (the OCR) is found as
  # ../share/pdfcraft/models from the binary, which the wrapper keeps in $out/bin.
  installPhase = ''
    runHook preInstall
    mkdir -p $out
    cp -r bin share $out/
    runHook postInstall
  '';

  postFixup = ''
    wrapProgram $out/bin/pdfcraft --prefix LD_LIBRARY_PATH : ${runtimeLibs}
  '';

  # What vendored-bump runs on `update`.
  passthru.updateScript = callPackage ./bump.nix { };

  meta = {
    description = "PDF reader and editor written from scratch in pure Rust (official release binary)";
    homepage = "https://github.com/storytold/pdfcraft";
    license = with lib.licenses; [
      mit
      asl20
    ];
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
    platforms = [ "x86_64-linux" ];
    mainProgram = "pdfcraft";
  };
}
