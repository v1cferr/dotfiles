# HYDRA LAUNCHER, the user side (the package is pkgs/hydralauncher/package.nix, always upstream's latest):
# the download sources DECLARED, synced into its LevelDB at each launch. Why: docs/notes/apps/hydralauncher.md
{
  config,
  lib,
  pkgs,
  ...
}:

let
  # Rule 19: everything this module reaches for, named once.
  inherit (pkgs)
    hydralauncher
    libnotify
    makeWrapper
    python3Packages
    symlinkJoin
    writeShellApplication
    writers
    ;

  # The sources: the library.hydra.wiki catalog query (NSFW always dropped) plus loose URLs. A
  # source the catalog stops listing as Trusted leaves on the next launch, like one removed here.
  sources = writers.writeJSON "hydralauncher-sources.json" {
    catalog = "https://api.hydralibrary.com/sources?limit=100&status=Trusted";
    extra = [ ];
  };

  syncPy = writers.writePython3Bin "hydralauncher-sources-sync" {
    libraries = [ python3Packages.plyvel ];
    flakeIgnore = [ "E501" ]; # the repo's line length is 100, not flake8's 79
  } (builtins.readFile ./hydralauncher/sources-sync.py);

  # The same sync with its two arguments baked in, so a hand run (app closed) shows what failed.
  sync = writeShellApplication {
    name = "hydralauncher-sources";
    text = ''
      exec ${lib.getExe syncPy} "${config.xdg.configHome}/hydralauncher/hydra-db" ${sources}
    '';
  };

  # The desktop entry's `Exec=hydralauncher` is PATH-relative, so wrapping the binary covers the
  # launcher and the hydralauncher:// callback alike. A failed sync warns and never blocks the app.
  hydra = symlinkJoin {
    name = "hydralauncher-with-sources";
    paths = [ hydralauncher ];
    nativeBuildInputs = [ makeWrapper ];
    postBuild = ''
      wrapProgram $out/bin/hydralauncher --run '${lib.getExe sync} ||
        ${libnotify}/bin/notify-send -a Hydra Hydra "Download sources not synced: run hydralauncher-sources"'
    '';
  };
in
{
  home.packages = [
    hydra # ./pkgs: the official AppImage, pinned to the sha512 upstream publishes, plus the sync
    sync # `hydralauncher-sources`: the same sync by hand, with the app closed
  ];

  # The games churn and weigh tens of GiB, so neither the hourly @home snapshots nor the backup keep
  # them: the per-game Wine prefixes (the installed games) and the downloads folder set in the app.
  my.disk.subvolumes = [
    ".config/hydralauncher/wine-prefixes"
    "Games/Hydra"
  ];

  # Merges with the associations from xdg.nix and media.nix. The login comes back through it.
  xdg.mimeApps.defaultApplications."x-scheme-handler/hydralauncher" = "hydralauncher.desktop";
}
