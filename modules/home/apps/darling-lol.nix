# darling-lol: League's macOS client through Darling, run as an on-demand --user service.
# The ban risk, the namespace and why the input does not follow nixpkgs: docs/notes/apps/darling-lol.md
{ pkgs, inputs, ... }:

let
  darling-lol = inputs.darling-lol.packages.${pkgs.stdenv.hostPlatform.system}.default;
in
{
  # The CLI stays on PATH for maintenance (`--installer`, `--stop`, `--update`).
  home.packages = [ darling-lol ];

  # The launcher OWNS the user namespace Darling lives in: a terminal hangup tears the game down,
  # so the session starts it as a unit instead (rule 15).
  systemd.user.services.darling-lol = {
    Unit = {
      Description = "League of Legends through Darling (darling-lol)";
      PartOf = [ "graphical-session.target" ];
      After = [ "graphical-session.target" ];
    };
    Service = {
      ExecStart = "${darling-lol}/bin/darling-lol";
      # The installer region is not remembered: without these the client opens as EUW.
      Environment = [
        "RCLOL_REGION=BR"
        "RCLOL_LOCALE=pt_BR"
      ];
      # SIGTERM to the launcher only: it shuts Darling down from inside its namespace.
      KillMode = "mixed";
      TimeoutStopSec = 120;
    };
  };

  # Same id as upstream's entry, so the menu shows this one: start the unit, no terminal.
  xdg.desktopEntries.darling-launcher = {
    name = "League of Legends (Darling)";
    exec = "systemctl --user start darling-lol.service";
    icon = "darling-launcher";
    terminal = false;
    categories = [ "Game" ];
  };
}
