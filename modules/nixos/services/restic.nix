# BACKUP (restic): the state Nix does not declare, encrypted and deduplicated onto a local backup disk.
# Why that disk, what is in it and how it comes back: docs/notes/boot-and-storage/restic.md
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
    diffutils
    docker
    findutils
    jq
    restic
    sops
    util-linux
    writeShellApplication
    ;

  cfg = config.my.backup;
  home = config.users.users.v1cferr.home;

  # IDENTITY: small, and each one costs a manual redo without it. /var/lib/nixos holds the
  # uid/gid map, so restored files keep the right owners. `restore-state --verify` diffs these.
  identity = [
    "/var/lib/sbctl"
    "/var/lib/nixos"
    "/var/lib/bluetooth"
    "/etc/ssh/ssh_host_*"
    "/etc/NetworkManager/system-connections"
  ];

  # Each module's `prepare` plus one dump per container, in a checked script (rule 7). A dump
  # that fails fails the backup: a visible red unit beats a snapshot missing its database.
  prepare = writeShellApplication {
    name = "backup-prepare";
    runtimeInputs = [
      coreutils
      docker
      findutils
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

  # THE STALENESS WATCH: catches what onFailure cannot, a backup that simply stopped running
  # (the disk unplugged, the timer gone). September 2026 went 8 silent days that way.
  staleness = writeShellApplication {
    name = "backup-staleness";
    runtimeInputs = [
      coreutils
      jq
      restic
    ];
    text = ''
      latest="$(restic -r ${cfg.repo} --password-file ${config.sops.secrets.restic_password.path} \
        --no-lock snapshots --latest 1 --host ${config.networking.hostName} --json | jq -r '.[-1].time // empty')"
      [ -n "$latest" ] || { echo "backup: the repo holds no snapshot of this host" >&2; exit 1; }
      age=$(( ($(date +%s) - $(date -d "$latest" +%s)) / 86400 ))
      echo "backup: the newest snapshot is $age day(s) old ($latest)"
      [ "$age" -le ${toString cfg.maxAgeDays} ]
    '';
  };

  # THE WAY BACK, run from the installer against /mnt: the age key already in place decrypts the
  # repo password, so a reinstall needs no typing. --verify is drill D4 against the live system.
  restoreState = writeShellApplication {
    name = "restore-state";
    runtimeInputs = [
      coreutils
      diffutils
      restic
      sops
      util-linux
    ];
    text = ''
      target=/mnt
      verify=0
      while [ $# -gt 0 ]; do
        case "$1" in
          --target) target="$2"; shift 2 ;;
          --verify) verify=1; target="$(mktemp -d)"; shift ;;
          *) echo "usage: restore-state [--target DIR] [--verify]" >&2; exit 2 ;;
        esac
      done

      work="$(mktemp -d)"
      trap 'umount "$work/disk" 2>/dev/null || true; rm -rf "$work"' EXIT
      repo=${cfg.repo}
      if [ ! -d "$repo" ]; then
        mkdir "$work/disk"
        mount -o ro /dev/disk/by-label/${cfg.label} "$work/disk"
        repo="$work/disk/${lib.removePrefix "${cfg.mountPoint}/" cfg.repo}"
      fi

      # The key the installer step put in /mnt, or the live one; failing both, restic prompts.
      for key in "$target${config.sops.age.keyFile}" ${config.sops.age.keyFile}; do
        if [ -z "''${RESTIC_PASSWORD_FILE:-}" ] && [ -r "$key" ]; then
          (umask 077; SOPS_AGE_KEY_FILE="$key" sops -d --extract '["restic_password"]' \
            ${config.sops.defaultSopsFile} > "$work/pw") && export RESTIC_PASSWORD_FILE="$work/pw"
        fi
      done

      if [ "$verify" = 1 ]; then
        includes=( ${lib.escapeShellArgs identity} )
      else
        includes=( ${lib.escapeShellArgs cfg.paths} )
      fi
      args=()
      for p in "''${includes[@]}"; do args+=(--include "$p"); done
      restic -r "$repo" restore latest --host ${config.networking.hostName} --target "$target" "''${args[@]}"

      if [ "$verify" = 1 ]; then
        status=0
        for p in "''${includes[@]}"; do
          # An array, so a glob like ssh_host_* expands against the restored tree.
          for restored in "$target"$p; do
            diff -rq "$restored" "''${restored#"$target"}" || status=1
          done
        done
        rm -rf "$target"
        [ "$status" = 0 ] && echo "restore-state: the identity in the backup matches this machine"
        exit "$status"
      fi
      echo "restore-state: done. After the first boot: restore-dbs, then Immich's own restore."
    '';
  };

  # AFTER the first boot, with the stacks up: each dump back into its container. --clean replaces
  # whatever the fresh container created, so it asks first.
  restoreDbs = writeShellApplication {
    name = "restore-dbs";
    runtimeInputs = [ docker ];
    text = ''
      read -r -p "restore-dbs: REPLACE ${lib.concatStringsSep ", " (lib.attrNames cfg.postgres)} with the dumps in ${cfg.dumpDir}? [y/N] " ok
      [ "$ok" = y ] || exit 1
    ''
    + lib.concatStrings (
      lib.mapAttrsToList (name: container: ''
        echo "restore-dbs: ${name} -> ${container}"
        docker exec -i ${container} sh -c \
          'pg_restore -U "$POSTGRES_USER" -d "$POSTGRES_DB" --clean --if-exists --no-owner' \
          < ${cfg.dumpDir}/postgres/${name}.dump
      '') cfg.postgres
    )
    + ''
      echo "restore-dbs: Immich restores itself: its welcome screen offers 'Restore from backup'."
    '';
  };

  alertUnit = title: body: {
    description = "Alarm: ${title}";
    serviceConfig = {
      Type = "oneshot";
      # Double quotes, never escapeShellArgs: systemd does not parse the shell's '\'' splice.
      ExecStart = ''${lib.getExe config.my.alert} backup drive-removable-media "${title}" "${body}"'';
    };
  };
in
{
  options.my.backup = {
    device = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      example = "/dev/disk/by-uuid/0000-0000";
      description = "The disk holding the repo, by UUID. The host's fact; null keeps the module inert.";
    };

    label = lib.mkOption {
      type = lib.types.str;
      default = "BACKUP";
      description = "The filesystem label: how the installer finds the disk with no config yet.";
    };

    restoreState = lib.mkOption {
      type = lib.types.package;
      readOnly = true;
      default = restoreState;
      description = "`restore-state`: the flake's `nix run .#restore-state`, for the installer.";
    };

    mountPoint = lib.mkOption {
      type = lib.types.str;
      default = "/mnt/backup";
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

    maxAgeDays = lib.mkOption {
      type = lib.types.ints.positive;
      default = 3;
      description = "The staleness watch alarms when the newest snapshot is older than this.";
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

  config = lib.mkMerge [
    # WHAT goes in is a fact even with the toggle off: restore-state reads it from the flake.
    {
      my.backup = {
        paths = [
          home
          cfg.dumpDir
        ]
        ++ identity;

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
          "${home}/.config/Claude/vm_bundles" # Claude Desktop's VM image (14 GiB), downloaded again
          "${home}/.vscode/extensions" # Settings Sync puts them back
          "${home}/.vscode-server"
          "${home}/.config/Code/CachedExtensionVSIXs"
          "${home}/.npm"
          "${home}/.local/share/pnpm" # the pnpm store
          "${home}/.nuget/packages"
          "**/OptGuideOnDeviceModel" # Chrome's on-device model (4 GiB)
          "**/Service Worker" # site caches, rebuilt on the next visit
          "**/.next" # Next.js build output and cache
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
    }

    (lib.mkIf config.my.services.restic {
      assertions = [
        {
          assertion = cfg.device != null;
          message = "my.services.restic needs my.backup.device (the backup disk's /dev/disk/by-uuid path).";
        }
      ];

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

      services.restic.backups.local = {
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
          "--keep-tag archive" # an archive copied in (the old Arch) is never pruned by age
        ];

        # A local disk makes rereading cheap, so every run proves a random slice of the packs.
        checkOpts = [ "--read-data-subset=2%" ];
      };

      environment.systemPackages = [
        restoreState
        restoreDbs
      ];

      systemd.services = {
        restic-backups-local = {
          # The disk mounts on demand, so the unit has to ask for it explicitly.
          unitConfig.RequiresMountsFor = cfg.mountPoint;
          onFailure = [ "backup-alert-failed.service" ];
        };

        backup-staleness = {
          description = "Checks that the newest backup snapshot is recent";
          unitConfig.RequiresMountsFor = cfg.mountPoint;
          onFailure = [ "backup-alert-stale.service" ];
          serviceConfig = {
            Type = "oneshot";
            ExecStart = lib.getExe staleness;
          };
        };

        backup-alert-failed = alertUnit "backup: the daily restic run failed" "See 'journalctl -u restic-backups-local -b'. Until it is fixed, nothing new reaches the backup disk.";
        backup-alert-stale = alertUnit "backup: no recent snapshot on the backup disk" "The newest snapshot is older than ${toString cfg.maxAgeDays} days, or the disk is unreachable. Plug it in and run 'sudo systemctl start restic-backups-local'.";
      };

      systemd.timers.backup-staleness = {
        description = "Daily check that the backup is still running";
        wantedBy = [ "timers.target" ];
        timerConfig = {
          OnCalendar = "12:00";
          Persistent = true;
          RandomizedDelaySec = "30min";
        };
      };
    })
  ];
}
