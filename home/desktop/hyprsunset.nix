# BLUE LIGHT FILTER (hyprsunset), through the compositor's CTM, so it never enters a screenshot.
# Why 13 profiles, and why the night is aggressive: docs/notes/desktop/hyprsunset.md
{ ... }:

{
  services.hyprsunset = {
    enable = true;
    settings = {
      max-gamma = 150; # the ceiling for the MANUAL override (SUPER+Vol); the schedule no longer dims

      # Profiles by time of day, COLOR ONLY: the dimming moved to the real backlight over DDC
      # (home/desktop/backlight.nix), which reads these same times. No gamma here means 1.0.
      profile = [
        {
          time = "0:00";
          temperature = 2000;
        } # the small hours: the warmest point
        {
          time = "6:00";
          temperature = 3000;
        } # dawn: it starts cooling down
        {
          time = "7:00";
          temperature = 4000;
        } # morning
        {
          time = "8:00";
          identity = true;
        } # daytime (8h to 17h30): neutral, no filter, full brightness
        {
          time = "17:30";
          temperature = 5000;
        } # late afternoon: the 1st warming (no dim yet)
        {
          time = "18:00";
          temperature = 3800;
        } # ARRIVING FROM WORK: the curve's biggest step, this is where the relief starts
        {
          time = "18:30";
          temperature = 3500;
        }
        {
          time = "19:00";
          temperature = 3200;
        } # from here down the color ruins media; see the header
        {
          time = "20:00";
          temperature = 3000;
        }
        {
          time = "21:00";
          temperature = 2800;
        }
        {
          time = "22:00";
          temperature = 2600;
        } # pre-sleep: less blue
        {
          time = "23:00";
          temperature = 2400;
        }
        {
          time = "23:30";
          temperature = 2200;
        } # the final transition into the small hours
      ];
    };
  };
}
