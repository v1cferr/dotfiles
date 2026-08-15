# ═══════════════════════════════════════════════════════════════════════════
# /mnt/arch-antigo: the old Arch archive mounted PERMANENTLY (a restic mount).
#
# It used to be the `arch-browse` alias, run by hand and alive only as long as the terminal
# stayed open. The symptom that killed the alias (11/08/2026): opening the Dolphin bookmark and
# seeing an EMPTY folder. There was no defect at all: the secrets were readable, the repo was
# answering, the mount came up in ~20 s when asked. The defect was the DESIGN: automation with no
# declared owner (rule 15) that depended on me remembering the command and never closing that
# terminal.
#
# ── WHY A USER UNIT, AND NOT A SYSTEM ONE ───────────────────────────────────
# A FUSE mount is private to whoever mounted it: `sudo restic mount` produces a folder Dolphin
# cannot open (that was the defect of the alias' 1st version). The mountpoint itself is created
# by root through tmpfiles, in system/services/arch-legacy.nix, which also holds the path's SSOT.
#
# ── THE PRICE OF LEAVING IT UP (measured on 11/08/2026) ─────────────────────
# ~195 MiB of resident RSS: 115 MiB from restic (the repo index in memory, a 44.6 GiB snapshot)
# plus 79 MiB from `rclone serve restic`. On the NETWORK, while idle, it is ZERO: restic does not
# poll, it only reads when somebody reads. The bookmark's comment in home/apps/dolphin.nix used
# to say a permanent mount would be "an open connection and a lock on the repo for nothing". The
# first half was true and became a conscious choice; the second one `--no-lock` solves (below).
#
# WARNING: IF THE NETWORK DROPS, a read hangs until rclone's timeout and the mount can go zombie
# ("Transport endpoint is not connected"). The remedy is `systemctl --user restart
# arch-antigo-mount`; the ExecStopPost force-unmounts the leftovers before coming back up. The
# same exposure as ~/Drive, which has run this way since 05/08/2026 with no incident.
# ═══════════════════════════════════════════════════════════════════════════
{
  osConfig,
  lib,
  pkgs,
  ...
}:

let
  cfg = osConfig.my.archAntigo;

  # READINESS. `restic mount` does NOT speak sd_notify (checked: no "notify" in 0.18.1's
  # `restic mount --help`), so there is no copying the `Type = "notify"` that ~/Drive uses, and
  # with Type=simple systemd would call the unit ready the instant the process is born, which is
  # to say BEFORE the mountpoint exists. Then Dolphin would open the empty folder and cache that:
  # exactly the symptom this module came to solve. ExecStartPost blocks the "started" until the
  # mount actually shows up.
  #
  # writeShellApplication and not a loose `.sh` nor a two-line `sh -c` (rule 7): the logic lives
  # in the build, and that way it goes through shellcheck.
  waitMount = pkgs.writeShellApplication {
    name = "arch-antigo-wait-mount";
    runtimeInputs = with pkgs; [
      coreutils
      util-linux
    ];
    # 120 attempts of 1 s. A cold cache (the index not yet downloaded from the Drive) took ~20 s
    # in the measurement; the slack is for a bad network, and the ceiling exists so
    # `Restart=on-failure` can try again instead of leaving the unit "activating" forever.
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
      # At login the network usually takes a few seconds. Without this systemd would give up
      # after 5 quick failures (StartLimit) and the folder would stay empty until a manual start.
      StartLimitIntervalSec = 0;
    };

    Service = {
      Type = "simple"; # sd_notify does not exist here; see `waitMount` above

      # A WRITABLE COPY of rclone.conf, the same pattern as ~/Drive and the backup service.
      # rclone renews the OAuth token and tries to persist the new one OVER the config file;
      # against the sops secret (0400, in a non-writable directory) that becomes
      # `Failed to save config … permission denied`. It is not fatal, but in a 24/7 service it
      # would be a recurring ERROR in the journal hiding a real error.
      # Its OWN file (`-arch-antigo`) and not ~/Drive's `%t/rclone-gdrive.conf`: two units
      # rewriting the same copy is the same stomping the backup did on the secret (07/08/2026,
      # see restic.nix). `%t` = XDG_RUNTIME_DIR (/run/user/1000), a tmpfs.
      ExecStartPre = "${pkgs.coreutils}/bin/install -m600 /run/secrets/rclone_gdrive_conf %t/rclone-arch-antigo.conf";

      # restic has no flag for pointing at rclone.conf: only the backend reads it, and it reads
      # it from the ENVIRONMENT. Here that is safe (the unit's own, not the session's); the
      # warning in drive-mount.nix is about exporting RCLONE_CONFIG from outside and making the
      # FAI mount look for the `faiws` remote in the wrong file.
      Environment = [ "RCLONE_CONFIG=%t/rclone-arch-antigo.conf" ];

      ExecStart = lib.concatStringsSep " " [
        "${pkgs.restic}/bin/restic"
        "-r ${cfg.repo}"
        "--password-file /run/secrets/restic_password_arch_kingston"
        # A TRAP that already cost the whole backup service: the `rclone:` backend EXECUTES the
        # rclone binary, and a systemd unit does not inherit the session's PATH. There the remedy
        # was `path = [ pkgs.rclone ]`; here the store path goes PINNED in the `-o`, which depends
        # on no PATH at all. The default args (`serve restic --stdio`) still hold.
        "-o rclone.program=${pkgs.rclone}/bin/rclone"
        "mount ${cfg.local}"
        # NO LOCK, and this is a measured decision, not thrift. Every `restic mount` creates a
        # non-exclusive lock and renews it every ~5 min; a mount that dies without exiting cleanly
        # leaves it STUCK. On 11/08/2026 the repo had 3 locks: one from the live mount and two
        # leftovers from `arch-browse` on 05/08 and 08/08. A permanent mount was only going to
        # make that worse, and it would also write to the offsite repo every 5 min forever.
        # What the lock protects is a read concurrent with a prune; this repo is STATIC and NO
        # routine prunes it (the automatic `forget --prune` only looks at the HOME repo). If
        # something ever starts writing here, this line is the first one to go.
        "--no-lock"
      ];

      ExecStartPost = lib.getExe waitMount;

      # 120 s of waiting plus restic's startup do not fit in the default 90 s, and blowing past
      # TimeoutStartSec KILLS the unit in the middle of the wait.
      TimeoutStartSec = 180;

      # A safety net for a hung mount (the `-` ignores a failure when it is already unmounted):
      # without this the "Transport endpoint is not connected" is left behind, and then the next
      # mount does not come up because the mountpoint is occupied by a corpse. It has to be
      # NixOS' setuid WRAPPER, since the package's fusermount3 has no privilege.
      ExecStopPost = "-/run/wrappers/bin/fusermount3 -uz ${cfg.local}";

      Restart = "on-failure";
      RestartSec = 10;
    };

    Install.WantedBy = [ "default.target" ];
  };
}
