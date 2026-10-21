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
  # unlocking, as ONE group (the logo, frameless, the name, the handle, the field); the quote at the
  # foot. The art stays the protagonist: a soft halo under each LINE of type (v5.2, no broad scrim),
  # light glass only where something sits on it (the field, the quote). ──
  # `zones` are where text sits (card-relative x y w h, and its own contrast target if large:
  # WCAG's 3.0 for large text, the card's 4.5 otherwise; the logo's zone comes from the logo itself).
  column = card "column" 0 (-215) 1280 590 0 // {
    material = "halo";
    zones = [
      [
        240
        8
        800
        140
        3.0
      ] # clock digits, 144 pt
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
        3.0
      ] # name, 20 pt
      [
        520
        440
        240
        24
      ] # handle
    ];
  };
  # The field: hyprlock draws its state hairline on this glass, with the same corner.
  auth = card "auth" 0 38 480 70 0.3 // {
    edge = false;
  };
  # The quote on a light reading surface, its foot 182 px off the screen's edge.
  quote = card "quote" 0 398 1200 280 0.22;

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
    card id cx (rowTop row + h / 2 - lgH / 2) w h 0; # the material (default.nix) sets the baseline
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
