# The lock screen's ONE geometry model: every glass card per monitor and layout, read by the renderer
# (as JSON) and by the hyprlock labels. Offsets are from the screen's CENTER, y down: docs/notes/desktop/lockscreen.md
{ rounding }:

let
  card = id: x: y: w: h: {
    inherit id;
    center = [
      x
      y
    ];
    size = [
      w
      h
    ];
    radius = rounding;
  };

  # The main monitor: the time and the password, one card and one smaller glass under it.
  clock = card "clock" 0 (-60) 800 264;
  auth = card "auth" 0 150 400 56;

  # The standing monitor: a stack anchored low, so the photo keeps the upper half. Ambient is the
  # same stack without its top card, so no label ever moves between the two layouts.
  quote = card "quote" 0 520 760 200;
  weather = card "weather" 0 322 760 148;
  media = card "media" 0 160 760 128;
in
{
  cards = {
    inherit
      clock
      auth
      quote
      weather
      media
      ;
  };

  monitors = {
    primary = {
      size = [
        2560
        1440
      ]; # the declared logical size; the renderer prefers the live one
      layouts.main = [
        clock
        auth
      ];
    };
    secondary = {
      size = [
        1080
        1920
      ]; # rotated: 1920x1080 on its side
      layouts = {
        ambient = [
          weather
          quote
        ];
        media = [
          media
          weather
          quote
        ];
      };
    };
  };

  # A hyprlock `position` for a point inside a card: hyprlock's y grows UP from the center.
  at =
    c: dx: dy:
    "${toString (builtins.elemAt c.center 0 + dx)}, ${toString (-(builtins.elemAt c.center 1 + dy))}";
}
