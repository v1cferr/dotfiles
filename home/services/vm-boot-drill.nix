# THE WEEKLY DRILL: it rebuilds the VM boot test once a week and only speaks when it FAILS.
# Why it is user-level, and why a cache hit is the normal case: docs/notes/repo/vm-boot.md
{
  config,
  osConfig,
  pkgs,
  ...
}:

let
  # The repo path has ONE owner, `programs.nh.flake` on the system side (rule 11).
  flake = osConfig.programs.nh.flake;

  # `notify` by ABSOLUTE path: a systemd user unit does not inherit the login shell's PATH, the
  # same reason btrfs.nix spells libnotify out.
  notify = "${config.home.profileDirectory}/bin/notify";

  drill = pkgs.writeShellApplication {
    name = "vm-boot-drill";
    runtimeInputs = with pkgs; [
      coreutils
      nix
    ];
    text = ''
      log="$(mktemp)"
      trap 'rm -f "$log"' EXIT

      # A cache HIT is the NORMAL case: with nothing changed the derivation is already in the
      # store and this costs seconds. The VM only boots again when a rebuild changed the closure.
      if nix build --no-link --print-build-logs ${flake}#vm-boot >"$log" 2>&1; then
        echo "vm-boot drill: the config still boots"
        exit 0
      fi

      echo "vm-boot drill FAILED" >&2
      cat "$log" >&2
      ${notify} -p high -T warning "vm-boot drill failed" \
        "This config no longer boots in a VM. Read it with: journalctl --user -u vm-boot-drill" \
        || true
      exit 1
    '';
  };
in
{
  home.packages = [ drill ]; # runnable by hand, which is how you read a failure

  systemd.user.services.vm-boot-drill = {
    Unit.Description = "Weekly drill: does this config still boot in a VM?";
    Service = {
      Type = "oneshot";
      ExecStart = "${drill}/bin/vm-boot-drill";
      # A QEMU VM plus a build while the machine is in use: last in line for CPU and IO.
      Nice = 19;
      IOSchedulingClass = "idle";
    };
  };

  systemd.user.timers.vm-boot-drill = {
    Unit.Description = "Weekly VM boot drill";
    Timer = {
      OnCalendar = "Sun 11:00";
      Persistent = true; # machine off at the scheduled time means it runs on the next boot
      RandomizedDelaySec = "30m";
    };
    Install.WantedBy = [ "timers.target" ];
  };
}
