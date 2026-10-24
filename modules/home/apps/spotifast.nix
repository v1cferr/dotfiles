# Spotifast: a native Spotify client (~200 MB instead of CEF), its colors fed from the palette.
# Why a COPY and not a symlink, and the one-time theme pick: docs/notes/apps/spotifast.md
{
  config,
  lib,
  osConfig,
  pkgs,
  ...
}:

let
  inherit (pkgs)
    coreutils
    libnotify
    notify
    soloist
    writeShellApplication
    ;

  # A Soloist build dies 90 days after it is made, and its version IS that date (pkgs/soloist), so
  # the deadline is known without asking the binary. Daily from 14 days out: desktop plus phone.
  soloistExpiry = writeShellApplication {
    name = "soloist-expiry";
    runtimeInputs = [
      coreutils
      libnotify
      notify
    ];
    text = ''
      left=$(( ($(date -ud "${soloist.version} + 90 days" +%s) - $(date -u +%s)) / 86400 ))
      echo "soloist ${soloist.version}: $left day(s) left"
      [ "$left" -gt 14 ] && exit 0
      if [ "$left" -le 0 ]; then
        msg="The Soloist build EXPIRED, so there is no sound. Run update, then rebuild."
      else
        msg="The Soloist build expires in $left day(s). Run update, then rebuild."
      fi
      notify-send -a Soloist -u critical "Soloist is expiring" "$msg" || true
      notify -p high -T warning "Soloist is expiring" "$msg" || true
    '';
  };

  # The API key's env file, rendered by sops (modules/nixos/core/secrets.nix). No key in the vault
  # yet = no receiver, instead of a unit that fails on every login.
  soloistEnv = osConfig.sops.templates."soloist.env".path or null;

  p = lib.mapAttrs (_: v: "#${v}") config.my.theme.palette; # the single source (modules/home/desktop/palette.nix)

  # The app's palette format, mapped like the spicetify text scheme it replaces (green accent).
  # A fixed name, so the pick in settings.json survives a my.theme.name switch.
  theme = pkgs.writeText "spotifast-theme.json" (
    builtins.toJSON {
      base = "dark"; # the same polarity Stylix gets (modules/home/desktop/stylix.nix)
      colors = {
        inherit (p)
          surface
          text
          dim
          shadow
          ;
        window = p.bg;
        panel = p.bg;
        surface_hover = p.track;
        surface_active = p.border;
        outline = p.track;
        secondary = p.subtext;
        accent = p.green;
        accent_hover = p.teal;
        on_accent = p.bg;
        danger = p.red;
        warning = p.yellow;
      };
    }
  );
in
{
  home.packages = [ pkgs.spotifast ]; # the vendored release binary, pkgs/spotifast

  # A REAL file: the app skips symlinks in its themes folder, so home.file cannot own it.
  home.activation.spotifastTheme = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    run install -Dm644 ${theme} "''${XDG_CONFIG_HOME:-$HOME/.config}/spotifast/themes/dotfiles.json"
  '';

  # THE SPEAKER: Spotify refuses librespot the audio keys for many accounts, so spotifast plays
  # through Soloist, Spotify's own Connect receiver, picked once in its device list.
  systemd.user.services.soloist = lib.mkIf (soloistEnv != null) {
    Unit = {
      Description = "Soloist: this machine as a Spotify Connect speaker";
      After = [ "pipewire-pulse.service" ];
      Wants = [ "pipewire-pulse.service" ];
    };
    Service = {
      # The binary ignores SOLOIST_API_KEY in its environment, so systemd expands it into the flag.
      ExecStart = "${lib.getExe soloist} --device-name ${osConfig.networking.hostName} --cache-size 1024 --api-key \${SOLOIST_API_KEY}";
      EnvironmentFile = soloistEnv;
      StateDirectory = "soloist"; # the device identity and session, so it stays paired
      CacheDirectory = "soloist";
      Restart = "on-failure";
      RestartSec = 10;
      # Exit 10 = an EXPIRED build (90 days): restarting cannot fix it, `update` plus a rebuild does.
      RestartPreventExitStatus = 10;
    };
    Install.WantedBy = [ "default.target" ];
  };

  # The nag that keeps the speaker alive: `update` bumps it, but only if somebody runs it in time.
  systemd.user.services.soloist-expiry = lib.mkIf (soloistEnv != null) {
    Unit.Description = "Warns before the Soloist build expires";
    Service = {
      Type = "oneshot";
      ExecStart = lib.getExe soloistExpiry;
    };
  };
  systemd.user.timers.soloist-expiry = lib.mkIf (soloistEnv != null) {
    Unit.Description = "Daily Soloist expiry check";
    Timer = {
      OnCalendar = "10:00";
      Persistent = true; # machine off at 10:00 means it checks on the next boot
    };
    Install.WantedBy = [ "timers.target" ];
  };
}
