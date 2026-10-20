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

  # ── ASUS, 2560x1440: editorial, no cards. Two shaded zones on one axis: the column (logo, name,
  # clock, date, field) and the quote's band at the foot. The art stays the protagonist. ──
  # `zones` are where text sits (card-relative x y w h): the shade is measured there, not the box.
  column = card "column" 0 (-160) 1280 600 0.2 // {
    material = "scrim";
    zones = [
      [
        500
        96
        280
        56
      ] # name, handle
      [
        100
        190
        1080
        160
      ] # clock digits
      [
        400
        396
        480
        32
      ] # date
      [
        430
        490
        420
        60
      ] # field
    ];
  };
  # Up to 3 lines of text, 2 of the original and the credit: 240 px, its foot 80 px off the edge.
  quote = card "quote" 0 520 1600 240 0.2 // {
    material = "scrim";
    zones = [
      [
        240
        20
        1120
        200
      ]
    ];
  };

  # ── LG, 1080x1920: ONE glass panel, 72 px from each side and 160 from the top and foot, split
  # by hairlines into sections on the 8 px grid. Positions inside it are panel-relative. ──
  panelW = 936;
  panelH = 1600;
  inset = 56; # the text's left edge and every rule's ends
  sections = {
    energy = {
      top = 0;
      h = 448;
    };
    claude = {
      top = 448;
      h = 384;
    };
    system = {
      top = 832;
      h = 448;
    };
    last = {
      top = 1280;
      h = 320;
    };
  };
  hr = y: [
    inset
    y
    (panelW - inset)
    y
  ];
  rules = map (s: hr s.top) [
    sections.claude
    sections.system
    sections.last
  ];
  # Media splits the last row: the weather on the left, the media on the right.
  split = [
    [
      (panelW / 2)
      (sections.last.top + 40)
      (panelW / 2)
      (panelH - 40)
    ]
  ];
  panel = extra: card "panel" 0 0 panelW panelH 0.56 // { rules = rules ++ extra; };
  lgW = 1080;
  lgH = 1920;
  px0 = (lgW - panelW) / 2; # the panel's left edge on the screen
  col3 = (panelW - 2 * inset - 2 * 32) / 3; # three columns, 32 px gutters
in
{
  inherit radius;
  cards = {
    inherit
      column
      quote
      ;
    panel = panel [ ];
  };

  # Where the LG's text goes: x from the screen's LEFT edge, y from its CENTER (hyprlock halign
  # left, valign center), and each section's top and height as the panel sees them.
  lg = {
    inherit sections;
    left = px0 + inset;
    right = px0 + panelW / 2 + inset; # the right half of a split row
    thirds = map (i: px0 + inset + i * (col3 + 32)) [
      0
      1
      2
    ];
    half = panelW / 2 - 2 * inset; # a half's text width
    third = col3;
    full = panelW - 2 * inset;
    y = s: dy: s.top - panelH / 2 + dy;
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
        quote
      ];
    };
    secondary = {
      size = [
        lgW
        lgH
      ]; # rotated: 1920x1080 on its side
      layouts = {
        ambient = [ (panel [ ]) ];
        media = [ (panel split) ];
      };
    };
  };

  # A hyprlock `position` for a point inside a card, center anchored: hyprlock's y grows UP.
  at =
    c: dx: dy:
    "${toString (builtins.elemAt c.center 0 + dx)}, ${toString (-(builtins.elemAt c.center 1 + dy))}";
}
