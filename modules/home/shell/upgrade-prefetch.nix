# UPGRADE-PREFETCH: the system at origin/main, downloaded ahead of time, so `upgrade` only switches.
# Why and how it relates to the nightly: docs/notes/repo/shell.md
{
  config,
  osConfig,
  pkgs,
  ...
}:

let
  # Rule 19: everything this module reaches for, named once.
  inherit (pkgs)
    git
    writeShellApplication
    ;

  flake = osConfig.programs.nh.flake; # SSOT of the repo path (rule 11)
  host = osConfig.networking.hostName; # what `rebuild` matches, with no #host
  state = "${config.xdg.stateHome}/upgrade-prefetch";

  # Builds the COMMIT, not the checkout: the working tree, its dirt and other sessions' edits stay
  # untouched. The out-link is the GC root that keeps the download until the next one replaces it.
  prefetch = writeShellApplication {
    name = "upgrade-prefetch";
    runtimeInputs = [
      git
      osConfig.nix.package
    ];
    text = ''
      mkdir -p "${state}"
      git -C "${flake}" fetch -q origin main
      rev=$(git -C "${flake}" rev-parse origin/main)
      if [ "$(cat "${state}/rev" 2>/dev/null)" = "$rev" ]; then
        echo "upgrade-prefetch: ''${rev:0:8} is already in the store."
        exit 0
      fi
      nix build --out-link "${state}/system" \
        "git+file://${flake}?rev=$rev#nixosConfigurations.${host}.config.system.build.toplevel"
      echo "$rev" >"${state}/rev"
      echo "upgrade-prefetch: ''${rev:0:8} is in the store, so the next upgrade only switches."
    '';
  };
in
{
  home.packages = [ prefetch ]; # also by hand, to warm the store before an upgrade

  systemd.user.services.upgrade-prefetch = {
    Unit.Description = "Download the system at origin/main ahead of the next upgrade";
    Service = {
      Type = "oneshot";
      ExecStart = "${prefetch}/bin/upgrade-prefetch";
      # Background work: the evaluation (~35 s of CPU) yields to anything interactive.
      Nice = 19;
      IOSchedulingClass = "idle";
    };
  };
  systemd.user.timers.upgrade-prefetch = {
    Unit.Description = "Prefetch the system once the nightly CI has committed";
    Timer = {
      # The nightly starts 02:37 here and commits within ~2 h; 13:00 catches a slow or manual one.
      # Persistent: a machine that was off at 06:00 catches up at the next login.
      OnCalendar = [
        "*-*-* 06:00"
        "*-*-* 13:00"
      ];
      Persistent = true;
    };
    Install.WantedBy = [ "timers.target" ];
  };
}
