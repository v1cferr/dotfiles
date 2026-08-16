# THE POLKIT AGENT: what shows the password dialog when a GRAPHICAL app needs authorization
# (mounting another user's disk, writing to a block device, controlling a systemd unit from the
# GUI and so on).
#
# THE GAP THIS CLOSES (found on 01/08/2026): `polkitd` was running, but there was NO agent at all.
# The daemon alone only decides "allowed / not allowed" through the rules; what asks the human for
# the password is the agent. Without it, every action requiring `auth_admin` failed SILENTLY: the
# app asked for authorization, nobody answered, and the user only saw "permission denied" with no
# prompt. Discovered trying to elevate `woeusbgui`, but the hole was general.
#
# WHY hyprpolkitagent: it is the Hyprland ecosystem's (Qt6/QML), it matches the Qt/Kvantum desktop
# here, and upstream already ships a ready systemd unit; we only rewrite it in Nix so there is ONE
# OWNER (rule 14) instead of depending on the package's file.
#
# A KNOWN TRAP, `graphical-session.target`: in many Hyprland+NixOS setups that target stays
# INACTIVE and everything depending on it silently does not come up (home-manager#8547). Here it
# is active (the same mechanism already raises this repo's autostart-*), so the default `WantedBy`
# works. If the autostarts ever stop coming up, this agent stops with them, and the symptom will
# be "the password prompt disappeared", which does not look like a target problem.
#
# TO CHECK that it is up:  systemctl --user status hyprpolkitagent
# ═══════════════════════════════════════════════════════════════════════════
{ pkgs, ... }:

{
  systemd.user.services.hyprpolkitagent = {
    Unit = {
      Description = "The polkit authentication agent (Hyprland)";
      PartOf = [ "graphical-session.target" ];
      After = [ "graphical-session.target" ];
      # It only makes sense inside a Wayland session; outside one the unit becomes a clean no-op
      # instead of restarting against a display that does not exist.
      ConditionEnvironment = "WAYLAND_DISPLAY";
    };

    Service = {
      # The binary lives in libexec/, not in bin/, so `getExe` does not find it.
      ExecStart = "${pkgs.hyprpolkitagent}/libexec/hyprpolkitagent";
      Slice = "session.slice"; # it dies with the session instead of becoming an orphan
      Restart = "on-failure";
      RestartSec = 3;
      TimeoutStopSec = 5;
      # The same brake as the autostart-* units (autostart.nix's rule): if it goes into a loop, the
      # unit DIES visibly in `systemctl --user --failed` instead of running in silence.
      StartLimitIntervalSec = 300;
      StartLimitBurst = 3;
    };

    Install.WantedBy = [ "graphical-session.target" ];
  };
}
