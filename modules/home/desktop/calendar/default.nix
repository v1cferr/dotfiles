# The VERIFIED CALENDAR's data: the holiday registry (registry/), validated and expanded into dated
# occurrences at BUILD time, so Quickshell reads it offline. Model and sources: docs/notes/desktop/calendar.md
{ pkgs, ... }:

let
  inherit (pkgs) python3 runCommand;
  # The years the panel can show; outside them it says there is no data, never guesses.
  calendarJson = runCommand "calendar.json" { nativeBuildInputs = [ python3 ]; } ''
    python3 -I ${./scripts/registry.py} build ${./registry} --from 2024 --to 2032 > $out
  '';
in
{
  home.file.".config/theme/calendar.json".source = calendarJson;
}
