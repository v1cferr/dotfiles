# Sparks (After the Flood, OFL): sparkline fonts. Their `calt` turns `{30,60,90}` into a chart, so the
# lock draws charts as TEXT (no image reloads while locked). docs/notes/desktop/lockscreen.md
{
  lib,
  stdenvNoCC,
  fetchzip,
}:

stdenvNoCC.mkDerivation (finalAttrs: {
  pname = "sparks-font";
  version = "2.0";

  src = fetchzip {
    url = "https://github.com/aftertheflood/sparks/releases/download/v${finalAttrs.version}/Sparks-font-complete.zip";
    hash = "sha256-xp/rCZpitX2IZO1Tvl3Me1WSPsxy55BDDuoQzQGBlII=";
    stripRoot = false;
  };

  installPhase = ''
    runHook preInstall
    install -Dm444 -t $out/share/fonts/opentype Sparks/*.otf
    runHook postInstall
  '';

  meta = {
    description = "Typefaces that draw sparklines from numbers in text";
    homepage = "https://github.com/aftertheflood/sparks";
    license = lib.licenses.ofl;
    platforms = lib.platforms.all;
  };
})
