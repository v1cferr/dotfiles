# HYDRA LAUNCHER, the user side (the package is pkgs/hydralauncher/package.nix, always upstream's latest):
# the download sources and folder DECLARED, synced into its LevelDB at each launch. Why: docs/notes/apps/hydralauncher.md
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

  # Where the repacks land, relative to $HOME: a subvolume below, and the app's download folder.
  downloads = "Games/Hydra";

  # The sources: the library.hydra.wiki catalog query (NSFW always dropped) plus loose URLs. A
  # source the catalog stops listing as Trusted leaves on the next launch, like one removed here.
  # The download folder is pinned too: one changed in the app would land outside the subvolume.
  declared = writers.writeJSON "hydralauncher-declared.json" {
    catalog = "https://api.hydralibrary.com/sources?limit=100&status=Trusted";
    extra = [ ];
    downloadsPath = "${config.home.homeDirectory}/${downloads}";
  };

  syncPy = writers.writePython3Bin "hydralauncher-sync" {
    libraries = [ python3Packages.plyvel ];
    flakeIgnore = [ "E501" ]; # the repo's line length is 100, not flake8's 79
  } (builtins.readFile ./hydralauncher/sync.py);

  # The same sync with its two arguments baked in, so a hand run (app closed) shows what failed.
  sync = writeShellApplication {
    name = "hydralauncher-sync";
    text = ''
      exec ${lib.getExe syncPy} "${config.xdg.configHome}/hydralauncher/hydra-db" ${declared}
    '';
  };

  # The desktop entry's `Exec=hydralauncher` is PATH-relative, so wrapping the binary covers the
  # launcher and the hydralauncher:// callback alike. A failed sync warns and never blocks the app.
  hydra = symlinkJoin {
    name = "hydralauncher-synced";
    paths = [ hydralauncher ];
    nativeBuildInputs = [ makeWrapper ];
    # The app hard-codes PROTON_LOG=1 on every game, which turns on Wine's +unwind trace: 26 MiB/s
    # into ~/steam-<id>.log under Cyberpunk. Proton only `setdefault`s the channels, so these win.
    postBuild = ''
      wrapProgram $out/bin/hydralauncher \
        --set-default WINEDEBUG -all \
        --set-default DXVK_LOG_LEVEL none \
        --set-default VKD3D_DEBUG none \
        --set-default PROTON_LOG_DIR "${config.xdg.configHome}/hydralauncher/logs" \
        --run '${lib.getExe sync} ||
        ${libnotify}/bin/notify-send -a Hydra Hydra "Settings not synced: run hydralauncher-sync"'
    '';
  };
in
{
  home.packages = [
    hydra # ./pkgs: the official AppImage, pinned to the sha512 upstream publishes, plus the sync
    sync # `hydralauncher-sync`: the same sync by hand, with the app closed
  ];

  # The games churn and weigh tens of GiB, so neither the hourly @home snapshots nor the backup keep
  # them: the per-game Wine prefixes (the installed games) and the downloads folder set in the app.
  my.disk.subvolumes = [
    ".config/hydralauncher/wine-prefixes"
    downloads
  ];

  # Merges with the associations from xdg.nix and media.nix. The login comes back through it.
  xdg.mimeApps.defaultApplications."x-scheme-handler/hydralauncher" = "hydralauncher.desktop";
}
