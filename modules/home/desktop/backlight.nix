# BACKLIGHT over DDC/CI: both panels on one white point, and one LAMP curve through the day.
# The seat ACL, the retry and why the times are not declared here: docs/notes/desktop/backlight.md
{
  config,
  lib,
  osConfig,
  pkgs,
  ...
}:

let
  # Rule 19: everything this module reaches for, named once.
  inherit (pkgs)
    coreutils
    ddcutil
    gawk
    writeShellApplication
    ;

  # 6500 K, the only white point both advertise. The LG shipped reporting 0x09 (10000 K), which its
  # OWN capabilities string does not list, which is what made the blue light filter look broken.
  preset = "0x05";

  # The LAMP's level through the day. The same NUMBER is not the same LIGHT on both panels (350
  # nits against 300), so this is the knob to turn the day they stop matching by eye.
  dayLevel = 45; # what a moment with nothing declared before it falls back to
  levels = {
    "0:00" = 15; # the small hours: about a third of the day's light
    "6:00" = 25;
    "7:00" = 40;
    "8:00" = 45; # daytime
    "18:00" = 40; # arriving from work, where the curve's biggest step already is
    "19:00" = 35;
    "20:00" = 30;
    "21:00" = 25;
    "22:00" = 22;
    "23:00" = 18;
    "23:30" = 15;
  };

  # THE TIMES ARE NOT DECLARED HERE (rule 11). The day's rhythm is hyprsunset's profile list, and
  # this reads it: moving "arriving from work" there moves the lamp with it, which is the point.
  minutesOf =
    t:
    let
      p = lib.splitString ":" t;
    in
    60 * lib.toIntBase10 (builtins.elemAt p 0) + lib.toIntBase10 (builtins.elemAt p 1);

  times = lib.sort (a: b: minutesOf a < minutesOf b) (
    map (p: p.time) config.services.hyprsunset.settings.profile
  );

  # "minutes level" per moment, chronological, with the carry-forward already resolved: only the
  # moments where the LIGHT changes need a line above.
  walked =
    lib.foldl'
      (
        acc: t:
        let
          lvl = levels.${t} or acc.last;
        in
        {
          last = lvl;
          out = acc.out ++ [ "${toString (minutesOf t)} ${toString lvl}" ];
        }
      )
      {
        last = dayLevel;
        out = [ ];
      }
      times;

  table = lib.concatStringsSep "\n" walked.out;

  sync = writeShellApplication {
    name = "backlight-sync";
    runtimeInputs = [
      coreutils
      ddcutil
      gawk
    ];
    text = ''
      want="''${1:-${toString dayLevel}}"

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

  schedule = writeShellApplication {
    name = "backlight-schedule";
    runtimeInputs = [
      coreutils
      gawk
    ];
    text = ''
      # The table is generated from hyprsunset's own times; the last row of the day is the default,
      # which is what makes the curve WRAP past midnight instead of falling back to daylight.
      now=$(( 10#$(date +%H) * 60 + 10#$(date +%M) ))
      want="$(printf '%s\n' ${lib.escapeShellArg table} | awk -v n="$now" '
        { mins[NR] = $1; lv[NR] = $2 }
        END { l = lv[NR]; for (i = 1; i <= NR; i++) if (mins[i] <= n) l = lv[i]; print l }')"

      # A tick where the level did not change must not cost a 2.9 s DDC round trip. The state lives
      # in the runtime dir, so a boot always reapplies.
      state="''${XDG_RUNTIME_DIR:-/tmp}/backlight-level"
      if [ "''${1:-}" = force ]; then rm -f "$state"; fi
      if [ -f "$state" ] && [ "$(cat "$state")" = "$want" ]; then exit 0; fi

      if ${sync}/bin/backlight-sync "$want"; then printf '%s' "$want" > "$state"; fi
    '';
  };
in
{
  home.packages = [
    sync # `backlight-sync [0-100]` by hand, both panels at once
    schedule # `backlight-schedule` applies whatever the curve says for right now
  ];

  systemd.user.services.backlight = {
    Unit = {
      Description = "Both panels at the curve's level and the declared white point (DDC/CI)";
      PartOf = [ "graphical-session.target" ];
      After = [ "graphical-session.target" ];
    };
    Service = {
      Type = "oneshot";
      ExecStart = "${schedule}/bin/backlight-schedule force";
    };
    Install.WantedBy = [ "graphical-session.target" ];
  };

  # One timer, one OnCalendar per moment of the day, GENERATED from the same list of times.
  systemd.user.timers.backlight = {
    Unit.Description = "Walks the lamp through the day, on hyprsunset's own times";
    Timer = {
      OnCalendar = map (
        t:
        let
          p = lib.splitString ":" t;
        in
        "*-*-* ${lib.fixedWidthString 2 "0" (builtins.elemAt p 0)}:${builtins.elemAt p 1}:00"
      ) times;
      Persistent = true; # a machine that was asleep at 23:00 catches up on resume
    };
    Install.WantedBy = [ "timers.target" ];
  };
}
