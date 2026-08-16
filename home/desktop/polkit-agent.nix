# THE POLKIT AGENT: without one, polkitd decides but NOBODY asks for the password, so every
# auth_admin action failed silently (01/08/2026). The trap: docs/notes/desktop-plumbing.md
{ pkgs, ... }:

{
  systemd.user.services.hyprpolkitagent = {
    Unit = {
      Description = "The polkit authentication agent (Hyprland)";
      PartOf = [ "graphical-session.target" ];
      After = [ "graphical-session.target" ];
      # Outside a Wayland session the unit becomes a clean no-op instead of restarting forever.
      ConditionEnvironment = "WAYLAND_DISPLAY";
    };

    Service = {
      # The binary lives in libexec/, not bin/, so `getExe` does not find it.
      ExecStart = "${pkgs.hyprpolkitagent}/libexec/hyprpolkitagent";
      Slice = "session.slice"; # it dies with the session instead of becoming an orphan
      Restart = "on-failure";
      RestartSec = 3;
      TimeoutStopSec = 5;
      # The same brake as the autostart-* units: a loop DIES visibly instead of running in silence.
      StartLimitIntervalSec = 300;
      StartLimitBurst = 3;
    };

    Install.WantedBy = [ "graphical-session.target" ];
  };
}
