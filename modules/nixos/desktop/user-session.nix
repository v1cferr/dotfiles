# OWN SESSION: one greeter entry that runs a script from the home of whoever logs in, so a person
# can try any compositor from their own Home Manager: docs/decisions/0018-a-shared-laptop.md
{ pkgs, ... }:

let
  inherit (pkgs) writeShellApplication writeTextFile;

  # Relative to $HOME, and written once: the launcher and the entry's name both read it.
  script = ".config/session/start";

  launcher = writeShellApplication {
    name = "own-session";
    text = ''
      start="$HOME/${script}"
      if [ ! -x "$start" ]; then
        echo "own-session: $start is missing or not executable, so there is nothing to start" >&2
        exit 1
      fi
      # Through a LOGIN shell, so the profile (and Home Manager's session variables) is loaded
      # before the compositor starts.
      # shellcheck disable=SC2016
      exec "''${SHELL:-/bin/sh}" -l -c 'exec "$1"' own-session "$start"
    '';
  };

  session =
    (writeTextFile {
      name = "own-session";
      destination = "/share/wayland-sessions/own-session.desktop";
      text = ''
        [Desktop Entry]
        Name=Own session (~/${script})
        Comment=Runs the script each person keeps in their own home
        Exec=${launcher}/bin/own-session
        Type=Application
      '';
    })
    // {
      providedSessions = [ "own-session" ]; # what services.displayManager checks the file against
    };
in
{
  services.displayManager.sessionPackages = [ session ];
}
