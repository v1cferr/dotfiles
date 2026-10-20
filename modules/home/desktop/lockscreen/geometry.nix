# The lock screen's ONE geometry model: every glass card per monitor and layout, read by the renderer
# (as JSON) and by the hyprlock labels. Offsets are from the screen's CENTER, y down: docs/notes/desktop/lockscreen.md
{ lib, rounding }:

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

  # ── ASUS, 2560x1440: editorial on one axis. The clock and date at the top; then who is
  # unlocking, as ONE group (the avatar, name, handle and the field); the quote at the foot. The art
  # stays the protagonist: a feathered scrim behind the type, small glass only where it holds
  # something (the avatar, the field, the quote). ──
  # `zones` are where text sits (card-relative x y w h): the scrim is measured there, not the box.
  column = card "column" 0 (-215) 1280 590 0.2 // {
    material = "scrim";
    zones = [
      [
        240
        8
        800
        140
      ] # clock digits
      [
        400
        174
        480
        30
      ] # date
      [
        440
        404
        400
        36
      ] # name
      [
        520
        440
        240
        24
      ] # handle
    ];
  };
  # The avatar: a 112 px glass circle with the logo in it, 50 px above the name.
  avatar = card "avatar" 0 (-182) 112 112 0.6 // {
    radius = 56;
  };
  # The field: hyprlock draws its state hairline on this glass, with the same corner.
  auth = card "auth" 0 38 480 70 0.6 // {
    edge = false;
  };
  # The quote on a quiet reading surface, its foot 182 px off the screen's edge.
  quote = card "quote" 0 398 1200 280 0.4;

  # ── LG, 1080x1920: independent Bento cards, each its own glass, the art visible between them.
  # 72 px margins, 24 px gaps, rows from 184 px down; the lower ~460 px stay the print. ──
  lgW = 1080;
  lgH = 1920;
  margin = 72;
  gap = 24;
  fullW = lgW - 2 * margin; # 936
  halfW = (fullW - gap) / 2; # 456
  # Each row's top and height, top to bottom: energy, Claude, system + processes, weather + media.
  rowH = [
    328
    328
    304
    240
  ];
  rowTop = i: builtins.foldl' (acc: h: acc + h + gap) 184 (lib.take i rowH);
  lgCard =
    id: col: row: w:
    let
      h = builtins.elemAt rowH row;
      cx =
        {
          full = 0;
          left = -(halfW + gap) / 2;
          right = (halfW + gap) / 2;
        }
        .${col};
    in
    card id cx (rowTop row + h / 2 - lgH / 2) w h 0.72;
  energy = lgCard "energy" "full" 0 fullW;
  claude = lgCard "claude" "full" 1 fullW;
  system = lgCard "system" "left" 2 halfW;
  procs = lgCard "procs" "right" 2 halfW;
  weather = lgCard "weather" "left" 3 halfW;
  media = lgCard "media" "right" 3 halfW;
  # Ambient has no media card: the weather takes the whole last row instead of an empty surface.
  weatherWide = lgCard "weather" "full" 3 fullW;
in
{
  inherit radius;
  cards = {
    inherit
      column
      avatar
      auth
      quote
      ;
    inherit
      energy
      claude
      system
      procs
      weather
      media
      weatherWide
      ;
  };

  # Where the LG's text goes: x from the screen's LEFT edge, y from its CENTER (hyprlock halign
  # left, valign center), both measured from a card's top-left corner; `pad` is every card's inset.
  lg = rec {
    pad = 32;
    x = c: dx: lgW / 2 + builtins.elemAt c.center 0 - builtins.elemAt c.size 0 / 2 + dx;
    y = c: dy: builtins.elemAt c.center 1 - builtins.elemAt c.size 1 / 2 + dy;
    inner = c: builtins.elemAt c.size 0 - 2 * pad; # a card's text width
  };
  lgPos = x: y: "${toString x}, ${toString (-y)}";

  monitors = {
    primary = {
      size = [
        2560
        1440
      ]; # the declared logical size; the renderer prefers the live one
      layouts.main = [
        column
        avatar
        auth
        quote
      ];
    };
    secondary = {
      size = [
        lgW
        lgH
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
}
