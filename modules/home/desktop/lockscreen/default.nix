# LOCK SCREEN plus IDLE: the QML lock (Quickshell, quickshell/lock.qml), hyprlock as its fallback,
# and hypridle. The design, the lessons NOT to undo and the rollback: docs/notes/desktop/lockscreen.md
{
  config,
  lib,
  pkgs,
  osConfig,
  inputs,
  ...
}:

let
  # Rule 19: everything this module reaches for, named once. deadnix fails the build on an
  # entry that stops being used, so the list cannot rot into a lie (rule 16).
  inherit (pkgs)
    bash
    coreutils
    findutils
    gnugrep
    hyprlock
    jq
    notify
    procps
    systemd
    writeShellApplication
    ;
  hyprland = osConfig.programs.hyprland.package; # hyprctl from the RUNNING compositor
  qsPkg = inputs.quickshell.packages.${pkgs.stdenv.hostPlatform.system}.default;

  # Colors from my.theme (palette.nix), for the fallback hyprlock.
  p = config.my.theme.palette;

  # MY OWN art, as STATE and not config (rule 6): Japanese prints and photos, landscape for the
  # main monitor in `wide/`, portrait for the standing one at the top. Never the desktop's astronomy.
  wallDir = "${config.home.homeDirectory}/Pictures/lockscreen";

  # The Quickshell tree as a STORE snapshot: the lock never hot-reloads from the repo mid-lock, and
  # a change to it takes a rebuild. The live shell keeps the mutable link (quickshell.nix).
  qsTree = builtins.path {
    path = ../quickshell;
    name = "quickshell-tree";
  };

  # The lock on the SESSION's compositor, even when the manager's WAYLAND_DISPLAY went stale
  # (every idle lock failed that way on 18/10/2026), falling back to hyprlock when it cannot lock.
  lockLaunch = writeShellApplication {
    name = "lockscreen-launch";
    runtimeInputs = [
      hyprland
      hyprlock
      jq
      coreutils
      qsPkg
      # What the QML lock's own commands use: the pools, /proc, the Caps Lock LED, the weather cache.
      bash
      findutils
      gnugrep
      config.my.glance.feed
    ];
    runtimeEnv = {
      LOCK_QML = "${qsTree}/lock.qml";
      LOCK_PAM_CONFIG = "quickshell-lock"; # modules/nixos/desktop/desktop.nix
      LOCK_POOL_PRIMARY = "${wallDir}/wide";
      LOCK_POOL_SECONDARY = wallDir;
      # The quotes are CONTENT in the repo (curated, sourced); what was shown is STATE.
      LOCK_QUOTES = builtins.path {
        path = ./quotes.json;
        name = "lockscreen-quotes.json";
      };
      LOCK_STATE = "${config.xdg.stateHome}/lockscreen";
      # The ASUS signature and logo: who I am from git's identity and the account, the logo as state.
      LOCK_NAME = config.programs.git.settings.user.name;
      LOCK_USER = config.home.username;
      LOCK_LOGO = config.my.lockscreen.logo;
    };
    text = builtins.readFile ./scripts/lock-launch.sh;
  };

  # The idle lock, held back ONLY by fullscreen video and never past a cap; audio no longer
  # holds it. It WAITS instead of skipping, since hypridle fires each timeout ONCE. See the notes.
  idleGate = writeShellApplication {
    name = "lockscreen-idle-gate";
    runtimeInputs = [
      hyprland
      jq
      systemd # busctl and loginctl
      coreutils
      gnugrep
    ];
    runtimeEnv = {
      LOCKGATE_MAX_HOLD = toString (3 * 3600); # 3 h: a long film, never a looping video forever
      LOCKGATE_POLL = "30";
    };
    text = builtins.readFile ./scripts/idle-gate.sh;
  };

  # Binaries at absolute paths, so nothing depends on the PATH (rule 7).
  pidof = "${procps}/bin/pidof"; # the unit's ExecCondition: no second lock beside a TTY rescue
  loginctlBin = "${systemd}/bin/loginctl";
  systemctlBin = "${systemd}/bin/systemctl";

  # hyprlock colors: "rgba(rrggbbaa)" from a palette key and an alpha byte.
  c = key: a: "rgba(${p.${key}}${a})";
in
{
  options.my.lockscreen.logo = lib.mkOption {
    type = lib.types.str;
    default = "${config.home.homeDirectory}/.dropbox-hm/Dropbox/Obsidian/v1cferr/5-Planning/5.7-@v1cferr/5.7.1-Logo/As Profile Pic/SVG/1018x1018.svg";
    description = "My logo's SVG, as STATE: the lock's signature draws it at lock time, never copied into git. Missing means no logo, never no lock.";
  };

  config = {
    # hyprlock: ONLY the fallback, plain on purpose (no labels, no images, nothing to fail): the
    # palette, the time and the field on every output, so it unlocks even with a monitor gone.
    programs.hyprlock = {
      enable = true;
      settings = {
        general.hide_cursor = true;
        animations.enabled = false;
        background = [
          {
            monitor = "";
            color = c "bg" "ff";
          }
        ];
        label = [
          {
            monitor = "";
            text = "$TIME";
            color = c "text" "ff";
            font_size = 96;
            font_family = "Geist Light";
            position = "0, 140";
            halign = "center";
            valign = "center";
          }
        ];
        input-field = {
          monitor = "";
          size = "420, 60";
          outline_thickness = 1;
          rounding = config.my.theme.rounding;
          inner_color = c "surface" "ff";
          outer_color = c "border" "ff";
          check_color = c "accent" "ff";
          fail_color = c "red" "ff";
          capslock_color = c "yellow" "ff";
          font_color = c "text" "ff";
          font_family = "Geist";
          placeholder_text = "senha";
          fail_text = "$PAMFAIL";
          fade_on_empty = false;
          position = "0, -60";
          halign = "center";
          valign = "center";
        };
      };
    };

    # The lock as its OWN UNIT, because locking is a SECURITY function and cannot be hostage to an
    # idle daemon anything can stop. The 6h outage and the remote lockout: the notes.
    systemd.user.services.lockscreen = {
      Unit = {
        Description = "Lock screen (Quickshell, hyprlock as the fallback)";
        # With no graphical session there is nothing to lock, and the lock dies with it.
        PartOf = [ "graphical-session.target" ];
        After = [ "graphical-session.target" ];
        # A lock that fails is a screen left OPEN: say so on the phone, since nobody is at the desk.
        OnFailure = [ "lockscreen-lock-failed.service" ];
      };
      Service = {
        Type = "simple"; # it runs while the screen is locked and exits on unlock
        # A hyprlock started by hand from a TTY (the rescue) owns the screen: never a second lock.
        # ExecCondition and not ExecStartPre: failing here SKIPS silently instead of marking failed.
        ExecCondition = "${bash}/bin/bash -c '! ${pidof} hyprlock'";
        ExecStart = lib.getExe lockLaunch;
      };
      # NO Install/wantedBy ON PURPOSE: what locks is the click, the idle or the boot's own line.
    };

    # The alarm for a failed lock: urgent on the phone (ntfy), with where to look.
    systemd.user.services.lockscreen-lock-failed = {
      Unit.Description = "Pushes an alarm when the lock screen fails to start or crashes";
      Service = {
        Type = "oneshot";
        ExecStart = "${lib.getExe notify} -p urgent -T lock \"Lock screen FAILED on %H\" \"lockscreen.service failed; the screen may be UNLOCKED. journalctl --user -u lockscreen\"";
      };
    };

    # The idle lock deferred by fullscreen video. A unit of its own because it has to OUTLIVE the
    # `on-timeout` that fired it, sometimes by a whole movie, and rule 15 wants one declared owner.
    systemd.user.services.lockscreen-idle-lock = {
      Unit = {
        Description = "Locks on idle, holding it back while fullscreen video plays";
        # A PENDING lock belongs to the daemon that scheduled it: the Sunshine guard stops hypridle
        # so the stream does not lock, and this has to die with it.
        PartOf = [ "hypridle.service" ];
        After = [ "hypridle.service" ];
      };
      Service = {
        Type = "simple"; # it stays alive while a video plays and exits right after locking
        ExecStart = lib.getExe idleGate;
      };
      # NO Install: hypridle's listener is the only trigger, the same as the lock above.
    };

    # hypridle: after 5 min it locks (not under fullscreen video) and holds Eco. NO dpms-off, which
    # broke moon/Sunshine (see the notes).
    services.hypridle = {
      enable = true;
      settings = {
        general = {
          # It delegates to the unit above; `start` is idempotent, so never a second lock.
          lock_cmd = "${systemctlBin} --user start lockscreen.service";
          # If it ever suspends (it does not today), lock before sleeping.
          before_sleep_cmd = "${loginctlBin} lock-session";
          # Kept true: the gate below is the SINGLE decision point, so no app can hold an inhibit
          # forever and disable locking in silence.
          ignore_dbus_inhibit = true;
        };
        listener = [
          # 5 min: lock THROUGH the gate. There is NO dpms-off listener; the monitor stays on so moon
          # always captures.
          {
            timeout = 300;
            on-timeout = "${systemctlBin} --user start lockscreen-idle-lock.service";
            # Back at the keyboard cancels a lock that was still waiting for the video to end.
            on-resume = "${systemctlBin} --user stop lockscreen-idle-lock.service";
          }
          # 5 min away: the automatic Eco hold (modules/nixos/hardware/power.nix), skipped under a game.
          {
            timeout = 300;
            on-timeout = "${systemctlBin} --user start power-idle-eco.service";
            on-resume = "${systemctlBin} --user stop power-idle-eco.service";
          }
        ];
      };
    };
  };
}
