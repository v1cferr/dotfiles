# /mnt/arch-antigo: the old Arch archive mounted PERMANENTLY (a restic mount, read-only).
# Why a user unit, why --no-lock and the readiness wait: docs/notes/boot-and-storage/arch-legacy.md
{
  osConfig,
  lib,
  pkgs,
  ...
}:

let
  cfg = osConfig.my.archAntigo;

  # READINESS: `restic mount` does not speak sd_notify, so Type=simple would call the unit ready
  # BEFORE the mountpoint exists and Dolphin would cache an empty folder. See the notes.
  waitMount = pkgs.writeShellApplication {
    name = "arch-antigo-wait-mount";
    runtimeInputs = with pkgs; [
      coreutils
      util-linux
    ];
    # 120 attempts of 1 s: a cold cache took ~20 s, and the ceiling lets Restart=on-failure retry.
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
      After = [ "network-online.target" ];
      Wants = [ "network-online.target" ];
      # At login the network takes a few seconds; without this systemd gives up after 5 quick tries.
      StartLimitIntervalSec = 0;
    };

    Service = {
      Type = "simple"; # sd_notify does not exist here; see `waitMount` above

      # Its OWN writable copy of rclone.conf: rclone rewrites the token, and two units sharing one
      # copy is the stomping that hit the backup on 07/08/2026. `%t` = XDG_RUNTIME_DIR, a tmpfs.
      ExecStartPre = "${pkgs.coreutils}/bin/install -m600 /run/secrets/rclone_gdrive_conf %t/rclone-arch-antigo.conf";

      # Only the rclone backend reads this, and it reads it from the environment. Safe here (the
      # unit's own); the warning in drive-mount.nix is about exporting it from the SESSION.
      Environment = [ "RCLONE_CONFIG=%t/rclone-arch-antigo.conf" ];

      ExecStart = lib.concatStringsSep " " [
        "${pkgs.restic}/bin/restic"
        "-r ${cfg.repo}"
        "--password-file /run/secrets/restic_password_arch_kingston"
        # The `rclone:` backend EXECUTES rclone, and a unit does not inherit the session's PATH: the
        # store path goes PINNED here. The same trap that once cost the whole backup service.
        "-o rclone.program=${pkgs.rclone}/bin/rclone"
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
