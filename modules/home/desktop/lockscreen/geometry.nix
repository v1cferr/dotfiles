# The lock screen's ONE geometry model: every glass card per monitor and layout, read by the renderer
# (as JSON) and by the hyprlock labels. Offsets are from the screen's CENTER, y down: docs/notes/desktop/lockscreen.md
{ rounding }:

let
  # A lock card is a MAJOR surface: the desktop's corner plus sp1, one step up the concentric scale.
  radius = rounding + 4;

  # `alpha` is the card's baseline opacity; the renderer raises it only where contrast needs it.
  card = id: x: y: w: h: alpha: {
    inherit id alpha radius;
    center = [
      x
      y
    ];
    size = [
      w
      h
    ];
  };

  # ── ASUS, 2560x1440: four cards on one axis, 32 px apart, an 800 px composition ──
  identity = card "identity" 0 (-312) 384 160 0.5;
  clock = card "clock" 0 (-88) 768 224 0.54;
  auth = card "auth" 0 96 480 80 0.66;
  quote = card "quote" 0 288 960 240 0.6;

  # ── LG, 1080x1920: a 2 x 3 grid from 184 px down, 56 px margins, 24 px gutters, 472 px columns ──
  colL = -248; # 56 + 472 / 2 - 540
  colR = 248;
  energy = card "energy" colL (-592) 472 368 0.56; # rows: 184 + 368 / 2 - 960
  claude = card "claude" colR (-592) 472 368 0.56;
  system = card "system" colL (-212) 472 344 0.58; # 184 + 368 + 24 + 344 / 2 - 960
  procs = card "procs" colR (-212) 472 344 0.58;
  weather = card "weather" colL 112 472 256 0.54; # 184 + 368 + 24 + 344 + 24 + 256 / 2 - 960
  media = card "media" colR 112 472 256 0.54;
  # Ambient: no empty media card, the weather takes the whole row.
  weatherWide = card "weather" 0 112 968 256 0.54;
in
{
  inherit radius;
  cards = {
    inherit
      identity
      clock
      auth
      quote
      energy
      claude
      system
      procs
      weather
      media
      weatherWide
      ;
  };

  monitors = {
    primary = {
      size = [
        2560
        1440
      ]; # the declared logical size; the renderer prefers the live one
      layouts.main = [
        identity
        clock
        auth
        quote
      ];
    };
    secondary = {
      size = [
        1080
        1920
      ]; # rotated: 1920x1080 on its side
      layouts = {
        ambient = [
          energy
          claude
          system
          procs
          weatherWide
        ];
        media = [
          energy
          claude
          system
          procs
          weather
          media
        ];
      };
    };
  };

  # A hyprlock `position` for a point inside a card, center anchored: hyprlock's y grows UP.
  at =
    c: dx: dy:
    "${toString (builtins.elemAt c.center 0 + dx)}, ${toString (-(builtins.elemAt c.center 1 + dy))}";

  # The same point measured from the card's top-LEFT corner, for a label anchored on the left
  # (halign left, valign top): needs the monitor's size.
  atLeft =
    size: c: dx: dy:
    let
      W = builtins.elemAt size 0;
      H = builtins.elemAt size 1;
      x = W / 2 + builtins.elemAt c.center 0 - builtins.elemAt c.size 0 / 2 + dx;
      y = H / 2 + builtins.elemAt c.center 1 - builtins.elemAt c.size 1 / 2 + dy;
    in
    "${toString x}, ${toString (-y)}";
}
