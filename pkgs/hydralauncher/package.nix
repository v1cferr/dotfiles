# Hydra Launcher: the game launcher with its own torrent client (MIT), the official AppImage.
# Why not nixpkgs' hydralauncher, and the scheme the login comes back on: docs/notes/apps/hydralauncher.md
{
  lib,
  appimageTools,
  fetchurl,
  callPackage,
}:

let
  # version, url and hash: the ONLY file the bump writes. The hash is the sha512 upstream publishes.
  source = lib.importJSON ./source.json;
  pname = "hydralauncher";
  inherit (source) version;

  src = fetchurl { inherit (source) url hash; };

  # extract + wrapAppImage, not wrapType2: extraInstallCommands has to READ the extracted tree.
  appimageContents = appimageTools.extract { inherit pname version src; };
in
appimageTools.wrapAppImage {
  inherit pname version;
  src = appimageContents;

  # The bundled umu-run (Proton for Windows games) is a `#!/usr/bin/env python3` zipapp, and the
  # AppImage FHS carries no Python: without this, launching any .exe fails before Proton starts.
  extraPkgs = pkgs: [ pkgs.python3 ];

  # Upstream's .desktop with only AppRun swapped; its MimeType is what claims hydralauncher://.
  extraInstallCommands = ''
    install -Dm444 ${appimageContents}/hydralauncher.desktop -t $out/share/applications
    substituteInPlace $out/share/applications/hydralauncher.desktop \
      --replace-fail 'Exec=AppRun' 'Exec=${pname}'
    cp -r ${appimageContents}/usr/share/icons $out/share/ # a single 512px size, upstream's only one
  '';

  # What vendored-bump runs on `update`.
  passthru.updateScript = callPackage ./bump.nix { };

  meta = {
    description = "Game launcher with its own embedded BitTorrent client (official AppImage)";
    homepage = "https://github.com/hydralauncher/hydra";
    changelog = "https://github.com/hydralauncher/hydra/releases/tag/v${version}";
    license = lib.licenses.mit;
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
    platforms = [ "x86_64-linux" ];
    mainProgram = pname;
  };
}
