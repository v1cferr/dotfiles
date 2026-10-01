# /mnt/arch-antigo: the old Arch archive mounted PERMANENTLY (a restic mount, read-only).
# Why a user unit, why --no-lock and the readiness wait: docs/notes/boot-and-storage/arch-legacy.md
{
  osConfig,
  lib,
  pkgs,
  ...
}:

let
  # Rule 19: everything this module reaches for, named once. deadnix fails the build on an
  # entry that stops being used, so the list cannot rot into a lie (rule 16).
  inherit (pkgs)
    coreutils
    restic
    util-linux
    writeShellApplication
    ;

  cfg = osConfig.my.archAntigo;

  # READINESS: `restic mount` does not speak sd_notify, so Type=simple would call the unit ready
  # BEFORE the mountpoint exists and Dolphin would cache an empty folder. See the notes.
  waitMount = writeShellApplication {
    name = "arch-antigo-wait-mount";
    runtimeInputs = [
      coreutils
      util-linux
    ];
    # 120 attempts of 1 s: a cold cache took ~20 s over the Drive and is far quicker off the
    # local disk. The ceiling stays so Restart=on-failure can retry instead of hanging.
    text = ''
      for _ in $(seq 1 120); do
        mountpoint -q ${cfg.local} && exit 0
        sleep 1
      done
      echo "the mountpoint ${cfg.local} did not show up in 120 s" >&2
      exit 1
    '';
  };
in
lib.mkIf osConfig.my.services.arch-antigo-mount {
  systemd.user.services.arch-antigo-mount = {
    Unit = {
      Description = "The old Arch archive mounted at ${cfg.local} (restic mount, read-only)";
      # NO network dependency since 24/09/2026: the repo is a local path. What this needs is
      # /mnt/seagate-old, a SYSTEM mount ordered before local-fs.target and therefore up long
      # before this session. It is `nofail` though, so a slow HDD can still lose the race, and
      # without this systemd would give up after 5 quick tries and leave the folder empty.
      StartLimitIntervalSec = 0;
    };

    Service = {
      Type = "simple"; # sd_notify does not exist here; see `waitMount` above

      ExecStart = lib.concatStringsSep " " [
        "${restic}/bin/restic"
        "-r ${cfg.repo}"
        "--password-file /run/secrets/restic_password_arch_kingston"
        "mount ${cfg.local}"
        # NO LOCK, and it is measured: a mount that dies unclean leaves the lock STUCK (3 of them on
        # 11/08/2026). The premise is that this repo is STATIC; see the notes before removing it.
        "--no-lock"
      ];

      ExecStartPost = lib.getExe waitMount;

      # 120 s of waiting plus restic's startup do not fit in the default 90 s, and blowing past
      # TimeoutStartSec KILLS the unit mid-wait.
      TimeoutStartSec = 180;

      # A safety net for a hung mount (the `-` ignores an already-unmounted one). It has to be
      # NixOS' setuid WRAPPER, since the package's fusermount3 has no privilege.
      ExecStopPost = "-/run/wrappers/bin/fusermount3 -uz ${cfg.local}";

      Restart = "on-failure";
      RestartSec = 10;
    };

    Install.WantedBy = [ "default.target" ];
  };
}
