# BACKUP (restic): the state Nix does not declare, encrypted and deduplicated onto a local USB disk.
# Why USB, what is in it and how it comes back: docs/notes/boot-and-storage/restic.md
{
  config,
  lib,
  pkgs,
  ...
}:

let
  # Rule 19: everything this module reaches for, named once.
  inherit (pkgs)
    coreutils
    docker
    writeShellApplication
    ;

  cfg = config.my.backup;
  home = config.users.users.v1cferr.home;

  # Each module's `prepare` plus one dump per container, in a checked script (rule 7). A dump
  # that fails fails the backup: a visible red unit beats a snapshot missing its database.
  prepare = writeShellApplication {
    name = "backup-prepare";
    runtimeInputs = [
      coreutils
      docker
    ];
    text = ''
      install -d -m 0700 ${cfg.dumpDir}/postgres
    ''
    + lib.concatStrings (
      lib.mapAttrsToList (name: container: ''
        # A host without the project's clone never started it, so there is nothing to lose.
        if docker container inspect ${container} >/dev/null 2>&1; then
          docker exec ${container} sh -c 'pg_dump -U "$POSTGRES_USER" -d "$POSTGRES_DB" -Fc' \
            > ${cfg.dumpDir}/postgres/${name}.dump.tmp
          mv ${cfg.dumpDir}/postgres/${name}.dump.tmp ${cfg.dumpDir}/postgres/${name}.dump
        else
          echo "backup: no container ${container}, skipping its dump" >&2
        fi
      '') cfg.postgres
    )
    + cfg.prepare;
  };
in
{
  options.my.backup = {
    device = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      example = "/dev/disk/by-uuid/0000-0000";
      description = "The USB disk holding the repo, by UUID. The host's fact; null keeps the module inert.";
    };

    mountPoint = lib.mkOption {
      type = lib.types.str;
      default = "/mnt/backup-usb";
      description = "Outside /home on purpose: a mount inside `paths` broke the old backup three times.";
    };

    repo = lib.mkOption {
      type = lib.types.str;
      readOnly = true;
      default = "${cfg.mountPoint}/restic";
      description = "The restic repo: read by the backup, the staleness check and the restore (rule 11).";
    };

    dumpDir = lib.mkOption {
      type = lib.types.str;
      readOnly = true;
      default = "/var/backup";
      description = "Where logical dumps land before each snapshot, and where the restore reads them.";
    };

    paths = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = "What goes in. Each module adds its OWN state under its own toggle, never a central list.";
    };

    exclude = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = "restic exclude patterns, contributed the same way as `paths`.";
    };

    prepare = lib.mkOption {
      type = lib.types.lines;
      default = "";
      description = "Bash run as root before each snapshot; a non-zero exit fails the backup.";
    };

    postgres = lib.mkOption {
      type = lib.types.attrsOf lib.types.str;
      default = { };
      example = {
        duo = "duo-db";
      };
      description = ''
        name = container: a Postgres container dumped with `pg_dump -Fc` into
        `<dumpDir>/postgres/<name>.dump`, using the container's own POSTGRES_USER and POSTGRES_DB.
      '';
    };
  };

  config = lib.mkIf config.my.services.restic {
    assertions = [
      {
        assertion = cfg.device != null;
        message = "my.services.restic needs my.backup.device (the USB disk's /dev/disk/by-uuid path).";
      }
    ];

    my.backup = {
      # IDENTITY: small, and each one costs a manual redo without it. /var/lib/nixos holds the
      # uid/gid map, so restored files keep the right owners.
      paths = [
        home
        "/var/lib/sbctl"
        "/var/lib/nixos"
        "/var/lib/bluetooth"
        "/etc/ssh/ssh_host_*"
        "/etc/NetworkManager/system-connections"
        cfg.dumpDir
      ];

      exclude = [
        # Somebody else's FUSE: root cannot lstat it, restic exits 3 and the prune never runs.
        "${home}/FAI-workstation"
        "${home}/Drive"

        "${home}/.cache"
        "${home}/.local/share/Trash"
        # Bulky and RE-OBTAINABLE: no sense in encrypting and keeping it.
        "${home}/Downloads"
        "${home}/Games"
        "${home}/.local/share/bottles" # Wine prefixes; the CS2 saves have their own mirror
        "${home}/.local/share/Steam"
        "**/node_modules"
        "**/.direnv"
        "**/target"
        "**/__pycache__"
        "**/.venv"
        "**/Cache"
        "**/Cache_Data"
        "**/CachedData"
        "**/Code Cache"
        "**/GPUCache"
        "**/ShaderCache"
        "**/cache2" # the Zen http cache; its `storage` (site data) stays
        "**/startupCache"
      ];
    };

    # noauto plus automount: the disk can be away, and only the backup's own access mounts it.
    fileSystems.${cfg.mountPoint} = {
      inherit (cfg) device;
      fsType = "btrfs";
      options = [
        "noauto"
        "nofail"
        "x-systemd.automount"
        "x-systemd.idle-timeout=10min"
        "x-systemd.device-timeout=5s"
        "compress=zstd:3"
        "noatime"
      ];
    };

    services.restic.backups.usb = {
      repository = cfg.repo;
      passwordFile = config.sops.secrets.restic_password.path;
      initialize = true;
      inherit (cfg) paths exclude;
      backupPrepareCommand = lib.getExe prepare;

      extraBackupArgs = [
        "--one-file-system" # never crosses into a mount that appears under a path
        "--exclude-caches" # skips directories with a CACHEDIR.TAG
      ];
      progressFps = 0.0167; # one progress line a minute, not thousands

      timerConfig = {
        OnCalendar = "03:00";
        Persistent = true; # the desktop is often off at 03:00, so it runs at the next boot
        RandomizedDelaySec = "30min";
      };

      pruneOpts = [
        "--keep-daily 7"
        "--keep-weekly 4"
        "--keep-monthly 6"
      ];
    };

    # The disk mounts on demand, so the unit has to ask for it explicitly.
    systemd.services.restic-backups-usb.unitConfig.RequiresMountsFor = cfg.mountPoint;
  };
}
