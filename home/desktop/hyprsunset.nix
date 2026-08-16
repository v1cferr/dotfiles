# BLUE LIGHT FILTER (hyprsunset), through the compositor's CTM, so it never enters a screenshot.
# Why 13 profiles, and why the night is aggressive: docs/notes/desktop/hyprsunset.md
{ ... }:

{
  services.hyprsunset = {
    enable = true;
    settings = {
      max-gamma = 150; # the gamma ceiling in % (default 100); slack for tuning through IPC

      # Profiles by time of day. gamma = PERCEIVED brightness, and it is the only auto-dim that
      # reaches BOTH screens (the DDC attempt was reverted; see the notes). No gamma = back to 1.0.
      profile = [
        {
          time = "0:00";
          temperature = 2000;
          gamma = 0.8;
        } # the small hours: warm plus dark
        {
          time = "6:00";
          temperature = 3000;
          gamma = 0.9;
        } # dawn: it cools down and brightens
        {
          time = "7:00";
          temperature = 4000;
          gamma = 1.0;
        } # morning: normal brightness back
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
          gamma = 0.9;
        } # pre-sleep: less blue plus a light dim
        {
          time = "23:00";
          temperature = 2400;
          gamma = 0.85;
        }
        {
          time = "23:30";
          temperature = 2200;
          gamma = 0.8;
        } # the final transition into the small hours
      ];
    };
  };
}
