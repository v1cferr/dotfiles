# DISCORD RICH PRESENCE for Claude Code: the daemon plus its config, fully declarative (no
# `claude-presence setup`). The hook that feeds it is system-level: docs/notes/apps/claude-code.md
{
  pkgs,
  osConfig,
  lib,
  ...
}:

let
  # Every package this module reaches for, named ONCE and up front: an entry that stops being
  # used fails the build under deadnix, so the list cannot rot into a lie (rule 16).
  inherit (pkgs)
    claude-code-discord-status
    nodejs
    ;

  ccds = claude-code-discord-status;
  daemonEntry = "${ccds}/lib/node_modules/claude-code-discord-status/dist/daemon/index.js";
in
lib.mkIf osConfig.my.services.discord-rpc {
  home.packages = [ ccds ]; # the `claude-presence` CLI, for diagnosis (status/doctor/preview)

  # The generated config. The DIRECTORY stays writable, since the daemon writes pid/log/aggregate
  # there, and that is STATE (rule 6).
  home.file.".claude-presence/config.json".text = builtins.toJSON {
    discordClientId = "1472915568930848829"; # upstream's default public app
    daemonPort = 19452; # the daemon's local port (the default; the hook uses the same one)
    preset = "minimal"; # the activity card's style
    daemonPath = daemonEntry; # referenced only in the hook's autostart fallback
  };

  # It comes up with the graphical session (Discord lives there) and reconnects on its own. With
  # no Discord it just logs and carries on, instead of restarting in a loop.
  systemd.user.services.claude-presence-daemon = {
    Unit = {
      Description = "Claude Code's Discord Rich Presence (daemon)";
      After = [ "graphical-session.target" ];
      PartOf = [ "graphical-session.target" ];
    };
    Service = {
      ExecStart = "${nodejs}/bin/node ${daemonEntry}";
      Restart = "on-failure";
      RestartSec = 5;
    };
    Install.WantedBy = [ "graphical-session.target" ];
  };
}
