# BACKLIGHT over DDC/CI: both panels held at ONE declared brightness and white point.
# The seat ACL that makes it work with no root, and the retry: docs/notes/desktop/backlight.md
{
  osConfig,
  pkgs,
  ...
}:

let
  # Rule 19: everything this module reaches for, named once.
  inherit (pkgs)
    coreutils
    ddcutil
    writeShellApplication
    ;

  # The BASELINE both panels are held at. The same NUMBER is not the same LIGHT (350 nits against
  # 300), so this is the knob to turn the day they stop matching by eye.
  level = 45;
  # 6500 K, the only white point both advertise. The LG shipped reporting 0x09 (10000 K), which its
  # OWN capabilities string does not list, which is what made the blue light filter look broken.
  preset = "0x05";

  sync = writeShellApplication {
    name = "backlight-sync";
    runtimeInputs = [
      coreutils
      ddcutil
    ];
    text = ''
      want="''${1:-${toString level}}"

      # ONE detect per attempt: it costs ~1.5 s, and asking it per monitor doubles that for nothing.
      # The display NUMBER follows ddcutil's enumeration, so it is DERIVED from the connector the
      # SSOT holds (rule 11) instead of a literal that a replug would invalidate.
      apply() {
        local map hit conn n
        map="$(ddcutil detect --brief 2>/dev/null | awk '
          /^Display /      { d = $2 }
          /DRM connector:/ { print d, $3 }')"
        hit=0
        for conn in ${osConfig.my.monitors.primary} ${osConfig.my.monitors.secondary}; do
          n="$(printf '%s\n' "$map" | awk -v c="$conn" '$2 ~ ("-" c "$") { print $1; exit }')"
          if [ -n "$n" ]; then
            ddcutil --display "$n" setvcp 10 "$want" >/dev/null 2>&1 || true
            ddcutil --display "$n" setvcp 14 ${preset} >/dev/null 2>&1 || true
            hit=1
          fi
        done
        [ "$hit" = 1 ]
      }

      # The i2c nodes are reachable through the SEAT's ACL, which logind writes when the session
      # takes the seat. A start that wins that race sees no display at all, the same shape of race
      # the mouse's DPI had, so it retries instead of failing silently.
      t=0
      while [ "$t" -lt 10 ]; do
        if apply; then exit 0; fi
        t=$((t + 1))
        sleep 2
      done
      exit 0
    '';
  };
in
{
  home.packages = [ sync ]; # `backlight-sync [0-100]` by hand, both panels at once

  systemd.user.services.backlight-sync = {
    Unit = {
      Description = "Holds both panels at the declared brightness and white point (DDC/CI)";
      PartOf = [ "graphical-session.target" ];
      After = [ "graphical-session.target" ];
    };
    Service = {
      Type = "oneshot";
      ExecStart = "${sync}/bin/backlight-sync";
    };
    Install.WantedBy = [ "graphical-session.target" ];
  };
}
