# Stack Wallet: Cypher Stack's multichain self-custody wallet (GPL-3.0), the official AppImage.
# How the AppImage is pinned to the hash upstream publishes: docs/notes/repo/version-bumps.md
{
  lib,
  appimageTools,
  fetchurl,
  callPackage,
}:

let
  # version, url and hash: the ONLY file the bump writes. The hash is the one upstream publishes.
  source = lib.importJSON ./source.json;
  pname = "stack-wallet";
  inherit (source) version;

  src = fetchurl { inherit (source) url hash; };

  # extract + wrapAppImage, not wrapType2: extraInstallCommands has to READ the extracted tree.
  appimageContents = appimageTools.extract { inherit pname version src; };
in
appimageTools.wrapAppImage {
  inherit pname version;
  src = appimageContents;

  # The one library Flutter's GTK runner links that the AppImage FHS does not already carry.
  extraPkgs = pkgs: [ pkgs.libepoxy ];

  # Upstream's .desktop with only the binary swapped; the AppImage ships a single 512px icon.
  extraInstallCommands = ''
    install -Dm444 ${appimageContents}/stackwallet.desktop -t $out/share/applications
    substituteInPlace $out/share/applications/stackwallet.desktop \
      --replace-fail 'Exec=stack_wallet' 'Exec=${pname}'
    install -Dm444 ${appimageContents}/stackwallet.png \
      $out/share/icons/hicolor/512x512/apps/stackwallet.png
  '';

  # What vendored-bump runs on `update`.
  passthru.updateScript = callPackage ./bump.nix { };

  meta = {
    description = "Open-source multichain self-custody cryptocurrency wallet (official AppImage)";
    homepage = "https://github.com/cypherstack/stack_wallet";
    license = lib.licenses.gpl3Only;
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
    platforms = [ "x86_64-linux" ];
    mainProgram = pname;
  };
}
