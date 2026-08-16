# CurseForge: the official Minecraft modpack app (AppImage, unfree), replacing prismlauncher.
# Why AppImage, the pointer URL, and why Java does NOT go here: docs/notes/apps/curseforge.md
{
  lib,
  appimageTools,
  fetchurl,
}:

let
  pname = "curseforge";
  # From the AppImage's `X-AppImage-Version`; curseforge-bump rewrites it.
  version = "1.316.0-37372";

  src = fetchurl {
    url = "https://curseforge.overwolf.com/downloads/curseforge-latest-linux.AppImage";
    hash = "sha256-ZH4ZkFSoT8bQgcQPkszcux4gds4DHwrD7Vyub+13mgQ=";
  };

  # extract + wrapAppImage, not wrapType2: extraInstallCommands has to READ the extracted tree.
  appimageContents = appimageTools.extract { inherit pname version src; };
in
appimageTools.wrapAppImage {
  inherit pname version;
  src = appimageContents;

  # Shaders abort the game on Mesa's iris; zink (GL over Vulkan/ANV) is the measured fix.
  # The six coredumps and why it lives in `profile`: docs/notes/apps/curseforge.md
  profile = "export MESA_LOADER_DRIVER_OVERRIDE=zink";

  # Upstream's .desktop with only AppRun swapped. The %U and the scheme handler are what make
  # the site's "Install" button work; the default is claimed in home/apps/curseforge.nix.
  extraInstallCommands = ''
    install -Dm444 ${appimageContents}/curseforge.desktop \
      -t $out/share/applications
    substituteInPlace $out/share/applications/curseforge.desktop \
      --replace-fail 'Exec=AppRun' 'Exec=${pname}'
    # The AppImage already ships the full hicolor tree (16 to 1024), and copying it is better
    # than electing a single size: the icon comes out sharp both in the bar and in the menu.
    cp -r ${appimageContents}/usr/share/icons $out/share/
  '';

  meta = {
    description = "Official CurseForge app: modpack library and updates (Minecraft/WoW)";
    homepage = "https://www.curseforge.com/download/app";
    license = lib.licenses.unfree;
    platforms = [ "x86_64-linux" ];
    mainProgram = pname;
  };
}
