# FAI Meet: the FAI's meeting recorder (transcript, summary and minutes), the official AppImage.
# The pointer URL, the deep link and the self-updater that cannot run: docs/notes/apps/fai-meet.md
{
  lib,
  appimageTools,
  fetchurl,
  callPackage,
}:

let
  # version, url and hash: the ONLY file the bump writes. The url is a POINTER, see the note.
  source = lib.importJSON ./source.json;
  pname = "fai-meet";
  inherit (source) version;

  src = fetchurl { inherit (source) url hash; };

  # extract + wrapAppImage, not wrapType2: extraInstallCommands has to READ the extracted tree.
  appimageContents = appimageTools.extract { inherit pname version src; };
in
appimageTools.wrapAppImage {
  inherit pname version;
  src = appimageContents;

  # Upstream's .desktop with only the binary swapped; %u hands the fai-meet:// login callback over.
  extraInstallCommands = ''
    install -Dm444 "${appimageContents}/FAI Meet.desktop" $out/share/applications/fai-meet.desktop
    substituteInPlace $out/share/applications/fai-meet.desktop \
      --replace-fail 'Exec=fai-meetings-desktop' 'Exec=${pname} %u'
    cp -r ${appimageContents}/usr/share/icons $out/share/
  '';

  # What vendored-bump runs on `update`.
  passthru.updateScript = callPackage ./bump.nix { };

  meta = {
    description = "FAI.UFSCar meeting recorder: transcript, summary and minutes (official AppImage)";
    homepage = "https://meetings.sup.fai.ufscar.br/download/nixos";
    license = lib.licenses.unfree;
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
    platforms = [ "x86_64-linux" ];
    mainProgram = pname;
  };
}
