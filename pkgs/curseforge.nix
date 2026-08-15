# CurseForge: the OFFICIAL Minecraft modpack app (Electron, by Overwolf).
# It replaced prismlauncher on 14/08/2026: Prism installs a CurseForge modpack by importing a
# .zip, without the library and pack updating that are the whole reason the app exists.
#
# It is NOT in nixpkgs (unfree and binary-only), so the repo repackages the official AppImage,
# the same vendored-binary pattern as claude-desktop.
#
# DO NOT ADD JAVA HERE. It has been tried, and it is DEAD CONFIG (measured on 15/08/2026).
# The app DOWNLOADS and manages its own JRE in `~/Documents/curseforge/minecraft/Install/java/`,
# and that is the only one it consults: with `java` in the FHS PATH and three JREs in
# /usr/lib/jvm, the agent log went on citing ITS java 18 times and ours ZERO times. All three
# went out in the same commit that brought them in. The "Java Runtime Environment is missing"
# error is NOT fixed from here: the cause is PERMISSIONS, see `curseforge-fix-perms`
# (pkgs/curseforge-fix-perms.nix).
#
# WHY AppImage and NOT the .deb (both sources exist and are the SAME release): everything that
# matters here is a binary the app DOWNLOADS at runtime (the JRE, the Forge installer, Minecraft
# itself), and none of that goes through `autoPatchelfHook`, which only reaches what is in the
# store. This system's `programs.nix-ld` does cover the loader (the /lib64/ld-linux here points
# at it), but not each one's libraries; the `buildFHSEnv` from appimageTools solves both at once
# and also puts /run/opengl-driver/lib in the ld.so.conf (through `container-init.cc`), so
# Minecraft inherits the FHS **and** the Arc B580 driver. It is the FHS that holds this package
# up, not patchelf.
#
# POINTER URL: Overwolf only publishes `curseforge-latest-linux.AppImage`; there is no
# versioned URL (the patterns `-1.316.0-`, `~37372` and `latest.yml` were all tested, all 404).
# The `hash` below PINS the content, so the build is reproducible, but the day Overwolf
# publishes the next version the fetch starts failing with a hash mismatch on a cold store
# (which is exactly what VS Code's `/latest/` caused in the CI). Who pays that price is
# `curseforge-bump` (pkgs/curseforge-bump.nix), which runs on the `update` alias and rewrites
# version+hash here. Do NOT swap it for `lib.fakeHash` or for a fetch with no hash (rule 13).
#
# The app's internal auto-updater (`resources/app-update.yml`, gitlab provider) does NOT
# work: the store is read-only. Updating is `update`/`upgrade`, like everything else.
{
  lib,
  appimageTools,
  fetchurl,
}:

let
  pname = "curseforge";
  # From the `X-AppImage-Version` of the .desktop inside the AppImage (the control file of the
  # .deb from the same release says `1.316.0~37372-37372`). The repeated `.37372` is
  # electron-builder noise.
  version = "1.316.0-37372";

  src = fetchurl {
    url = "https://curseforge.overwolf.com/downloads/curseforge-latest-linux.AppImage";
    hash = "sha256-ZH4ZkFSoT8bQgcQPkszcux4gds4DHwrD7Vyub+13mgQ=";
  };

  # extract + wrapAppImage instead of wrapType2 (which does both at once): extraInstallCommands
  # needs to READ the extracted tree to pick up the .desktop and the icons, and wrapType2 does
  # not expose it.
  appimageContents = appimageTools.extract { inherit pname version src; };
in
appimageTools.wrapAppImage {
  inherit pname version;
  src = appimageContents;

  # The upstream `.desktop` ships `Exec=AppRun --no-sandbox %U`; here only the AppRun becomes
  # the name of the FHS wrapper, the rest stays as upstream wrote it.
  # About `--no-sandbox`: it is NOT needed here. Measured on 14/08/2026 running `bin/curseforge`
  # (which passes no flags at all): the app opens and loads the library normally, without the
  # "SUID sandbox helper" this flag usually works around, because the bwrap from buildFHSEnv
  # already gives Chromium the namespace it wants. It stays because it came from upstream and
  # costs nothing; diverging from their `.desktop` would need a reason, and there is none.
  # `%U` plus the `x-scheme-handler/curseforge...` MimeType entries are what make the "Install"
  # button on the site open the app (a deep link). Declaring the scheme here is not enough: what
  # says THIS .desktop is the default is home/apps/curseforge.nix, and without that the LOGIN
  # does not come back (the whole trap, measured, is documented there).
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
